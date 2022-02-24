---
title: Android DataStore
date: 2021.09.01  
updated: 2022.02.24  
---

> [github blog](https://lzyprime.github.io)    
> qq: 2383518170    
> wx: lzyprime    

## λ：
当前 `DataStore 1.0.0`。

`DataStore`的封装已经试过好多方式。仍不满意。大概总结一下路数：

1. 为 `DataStore<Preferences>` 提供`[]`访问。

2. 通过`getValue, setValue` 实现委托构造。

3. 利用`()`运算符加`suspend`, 从而实现挂起效果。

这里最大的限制是`[]`, `getValue, setValue` 是不能加`suspend`的。所以要么传`CoroutineScope`进来，要么加`runBloacking`。但`runBlocking` 就丧失了`DataStore`的优势，退化成 `SharedPreference`.

```kotlin
// api preview
val kUserId = stringPreferencesKey("user_id")

// 1.
val userId: String? = anyDataStore[kUserId]
val userId: String = anyDataStore[kUserId, "0"]
anyDataStore[kUserId] = "<new value>"

// 2.
var userId: String by anyDataStore(...)
userId = "<new value>"
```

## DataStore API

> [DataStore 文档](https://developer.android.google.cn/topic/libraries/architecture/datastore)

当前`DataStore 1.0.0`，目的是替代之前的`SharedPreference`, 解决它的诸多问题。除了Preference简单的`key-value`形式，还有`protobuf`版本。但是感觉鸡肋，小数据`key-value`就够了，大数据建议`Room`处理数据库。所以介于中间的部分，或者真的需要类型化的，真的有吗？

`DataStore`以`Flow`的方式提供数据，所以跑在协程里，可以不阻塞UI。

### interface

`DataStore`的接口非常简单，一个`data`, 一个`fun updateData`:

```kotlin
// T = Preferences
public interface DataStore<T> {
    public val data: Flow<T>
    public suspend fun updateData(transform: suspend (t: T) -> T): T
}

public suspend fun DataStore<Preferences>.edit(transform: suspend (MutablePreferences) -> Unit): Preferences {
    return this.updateData { it.toMutablePreferences().apply { transform(this) } }
}
```

`data: Flow<Preferences>`。 `Preferences`可以看作是个`Map<Preferences.Key<*>, Any>`。

同时为了数据修改方便，提供了个`edit`的拓展函数，调用的就是`updateData`函数。

### 获取实例

```kotlin
val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "datastore_name")
```

`preferencesDataStore` 只为`Context`下的属性提供只读的委托：`ReadOnlyProperty<Context, DataStore<Preferences>>`。

所以前边非要定成`Context`的拓展属性，属性名不一定非是这个, `val Context.DS by ...` 也可以。

搞清楚kotlin的`属性委托`和`拓展属性`，就懂了这行代码。

`preferencesDataStore`相当于创建了个`fileDir/<datastore_name>.preferences_pb`的文件, 存数据。

### Preferences.Key

```kotlin
public abstract class Preferences internal constructor() {
    public class Key<T> internal constructor(public val name: String){ ... }
}

//create: 
val USER_ID = stringPreferencesKey("user_id")
val Guide = booleanPreferencesKey("guide")
```

都被加了`internal`限制，所以在外边调不了构造。然后通过`stringPreferencesKey(name: String)`等一系列函数，创建特定类型的`Key`， 好处是限定了类型的范围，不会创出不支持类型的`Key`, 比如`Key<UserInfo>`，`Key<List<*>>`。

同时通过`Preferences.Key<T>`保证类型安全，明确存的是`T`类型数据。而`SharedPreference`, 可以冲掉之前的值类型：

```kotlin
SharedPreference.edit{
    it["userId"] = 1 
    it["userId"] = "new user id"
}
``` 

### 使用：

```kotlin
// 取值 -------------
val userIdFlow: Flow<String> = context.dataStore.data.map { preferences ->
    // No type safety.
    preferences[USER_ID].orEmpty()
}

anyCoroutineScope.launch {
    repo.login(userIdFlow.first())
    userIdFlow.collect { 
        ...
    }
}

// or
val userId = runBlocking {
    userIdFlow.first()
}

// 更新值 ------------
anyCoroutineScope.launch {
    context.dataStore.edit {
        it[USER_ID] = "new user id"
    }
}
```

`Flow<Preference>.map{}`流转换， 在`preference`这个 "Map" 里取出`UserId`的值，有可能没有值。得到一个`Flow<T>`。

在协程里取当前值`Flow.first()`, 或者实时监听变化。也可以`runBlocking`变成阻塞式的。当然这就会和`SharedPreference`一样的效果，阻塞UI, 导致卡顿或崩溃。尤其是第一次在`data`中取值，文件读入会花点时间。所以可以在初始化时，预热一下:

```kotlin
anyCoroutineScope.launch { context.dataStore.data.first() }
```

## 封装过程

### `[]` 操作符

#### 1. `return Flow<T?> || Flow<T>`

由于`get set` 函数无法加 `suspend`, 所以`get`只能以`Flow`的形式返回值. 而如果想实现`set`的效果，就要`runBlocking`， 这样`DataStore`就失去了优势。
```kotlin

operator fun <T> DataStore<Preferences>.get(key: Preferences.Key<T>): Flow<T?> = data.map{ it[key] }

operator fun <T> DataStore<Preferences>.get(key: Preferences.Key<T>, defaultValue: T): Flow<T> = data.map{ it[key] }

// operator fun <T> DataStore<Preferences>.set(key: Preferences.Key<T>, value: T?) = runBlocking {
//    edit { if(value != null) it[key] = value else it -= key }
// }

// use:
val userId: Flow<String?> = anyDataStore[kUserId]
val userId: Flow<String> = anyDataStore[kUserId, ""]
// anyDataStore[kUserId] = "<new value>"
```

#### 2. 为了解决`set`, 有了把`CoroutineScope`传进来的版本： 

但是由于`set`过程不阻塞，如果立刻取值，可能任务执行的不及时，导致取到的是旧值。 而且如果`scope`生命结束仍没执行完，则保存失败。

```kotlin
operator fun <T> DataStore<Preferences>.set(key: Preferences.Key<T>, scope: CoroutineScope, value: T?) {
    scope.launch {
        edit { if(value != null) it[key] = value else it -= key }
    }
}

// use:
anyDataStore[kUserId, anyScope] = "<new value>"
```

#### 3. 包裹`DataStore`, 加`cache`优化。

加入`cache`处理更新不及时问题，但有可能 `预热DataStore` 操作不及时，导致`cache`错乱。 `get`使用了`runBlocking`，仍有隐患。

```kotlin
class DS(
    private val dataStore: DataStore<Preferences>,
    private val scope: CoroutineScope,
) {
    private val cache = mutablePreferencesOf()

    init {
        // 预热 DataStore
        scope.launch {
            cache += dataStore.data.first()
        }
    }

    operator fun <T> get(key: Preferences.Key<T>): T? =
        cache[key] ?: runBlocking {
            dataStore.data.map { it[key] }.first()?.also { cache[key] = it }
        }

    operator fun <T> set(key:Preferences.Key<T>, value:T?) {
        if(value != null) cache[key] = value
        scope.launch {
            dataStore.edit { if(value != null) it[key] = value else it -= key }
        }
    }

    companion object {
        private const val STORE_NAME = "global_store"
        private val Context.dataStore by preferencesDataStore(STORE_NAME)
    }
}

// use:
// val ds: DS // 依赖注入或instance拿到单例
val userId = ds[kUserId]
ds[kUserId] = "<new value>"
```

> #### 总之`[]`难解决的是`runBlocking`执行。

### `value class`, `()`操作符

1. 内联类限定对`DataStore`的访问。`[]`只提供`get`操作，返回`Flow`。
2. 通过`()`操作符暴露`DataStore<T>.edit`.

```kotlin
@JvmInline
value class DS(private val dataStore: DataStore<Preferences>) {

    operator fun <T> get(key: Preferences.Key<T>) =
        dataStore.data.map { it[key] }
    
    suspend operator fun invoke(block: suspend (MutablePreferences) -> Unit) = 
        dataStore.edit(block)

    companion object {
        private const val STORE_NAME = "global_store"
        private val Context.dataStore by preferencesDataStore(STORE_NAME)
    }
}

// use
val userId = ds[kUserId]
suspend {
    ds {
        it[kUserId] = "<new value>"
        it -= kUserId
    }
}
```


### 属性委托

```kotlin
abstract class PreferenceItem<T>(flow: Flow<T>) : Flow<T> by flow {
    abstract suspend fun update(v: T?)
}

operator fun <T> DataStore<Preferences>.invoke(
    buildKey: (name: String) -> Preferences.Key<T>,
    defaultValue: T,
) = ReadOnlyProperty<Any?, PreferenceItem<T>> { _, property ->
    val key = buildKey(property.name)
    object : PreferenceItem<T>(data.map { it[key] ?: defaultValue }) {
        override suspend fun update(v: T?) {
            edit {
                if (v == null) {
                    it -= key
                } else {
                    it[key] = v
                }
            }
        }
    }
}

// use
val userId: PreferenceItem<String> by anyDataStore(::stringPreferencesKey, "0")

suspend {
    userId.update("<new value>")
}
```

`Preferences.Key<T>`可以通过判别 `T` 的类型然后选择对应构造函数，匹配失败抛异常。

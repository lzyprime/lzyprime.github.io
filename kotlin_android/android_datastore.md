---
title: Android DataStore
date: 2021.09.01  
updated: 2021.09.01  
---

> [github blog](https://lzyprime.github.io)    
> qq: 2383518170    
> wx: lzyprime    

## λ：

经过几番修改。对`DataStore`的封装方式初步定下，虽然还是不满意，但已经是目前能想到的最好的方式。等有了新想法再改。

目前：

```kotlin
// key
val UserId = stringPreferencesKey("user_id")

// use:
val userId = DS[UserId] // 取值
DS[UserId] = "new user id" // 设值
```

```kotlin
// or delegate read and write:
var userId by UserId(defaultValue = "") // 需要设置属性为空时的默认值。userId: String
repo.login(userId)
userId = "new user id"
```

```kotlin
// or readOnly
val userId by UserId // 只读. userId: String?
if(!userId.isNullOrEmpty()) repo.login(userId)
```

`DS`:
```kotlin
// DS:
@JvmInline
value class DSManager(private val dataStore: DataStore<Preferences>) : DataStore<Preferences> {
    ...
}

val DS: DSManager by lazy {...}
```

提供了两套获取方式。一种是像map一样的访问风格。一种是靠属性委托的方式。`运算符重载`， `属性委托`， `内联类(用于收缩函数范围)`

记录一下是如何一步步混沌邪恶的。

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

### as Map

最常使用的也就是对某个数据的取值赋值。所以很容易想到重载`operator get`,`operator set`。也就是中括号`[]`运算符：

```kotlin
suspend operator fun <T> DataStore<Preferences>.get(key: Preferences.Key<T>): T? = data.map{ it[key] }.first()
suspend operator fun <T> DataStore<Preferences>.set(key: Preferences.Key<T>, value:T) = edit { it[key] = value }

// use:
scope.launch {
    val userId = context.dataStore[UserId]
    context.dataStore[UserId] = "new user id"
}
```

看着还行， ***但是！！！， 这两个函数不允许加`suspend`*** 。除非不是运算符函数，而是普通函数：`val userId = context.dataStore.get(UserId)`。

那用`runBlocking`做成阻塞式的？那不就开倒车了，`get`还好，但是`set`绝不能这么搞。

所以有了把`CoroutineScope`传进来的版本：

```kotlin
private val cache = mutablePreferencesOf()

operator fun <T> get(key: Preferences.Key<T>): T? = cache[key] ?: runBlocking { data.map { it[key] }.first() }?.also { cache[key] = it }
operator fun <T> DataStore<Preferences>.set(key: Preferences.Key<T>, scope: CoroutineScope, value: T) {
    cache[key] = value
    scope.launch(Dispatchers.IO) { edit { it[key] = value } }
}

// use:
val userId = context.dataStore[UserId]
context.dataStore[UserId, lifecycleScope] = "new user id"
```

- 此时这两个函数都不必在协程块里跑了。但是由于`set`过程不阻塞，相当于提交任务，如果立刻取值，可能任务执行的不及时，导致取值失败或错误。就加了`cache: MutablePreference`，同时也优化一下`get`操作的速度。
- `set` 太丑了，而且`CoroutineScope`一般存活在某个View的生存周期内，View一死，`set`操作就被取消了。而塞完之值立马杀死View是很常见的，比如登录过程，登录成功后保存值，然后就跳转主页了。所以这个任务应该提到`Application`级别的`CoroutineScope`中。

然后就有了：

```kotlin
// UnsplashApplication.kt
@HiltAndroidApp
class UnsplashApplication : Application() {
    @ApplicationScope
    @Inject
    lateinit var applicationScope: CoroutineScope

    init {
        instance = this
    }

    companion object {
        private lateinit var instance: UnsplashApplication

        operator fun getValue(ref: Any?, property: KProperty<*>): UnsplashApplication = instance
    }
}

// DS.kt
private val application by UnsplashApplication
operator fun <T> DataStore<Preferences>.set(key: Preferences.Key<T>, value: T) {
    cache[key] = value
    application.applicationScope.launch { edit { it[key] = value } }
}
```

但仍有问题：如果不通过`set`, 而是`updateData`函数。 `cache`就不会更新，而且`get, set`文件顶级写，`import`的时候是`import package_path.get`，污染环境。

所以通过内联类收缩一下范围, 同时在`updateData`时更新`cache`：

```kotlin
@JvmInline
value class DSManager(private val dataStore: DataStore<Preferences>) : DataStore<Preferences> {
    override val data: Flow<Preferences> get() = dataStore.data
    init {
        application.applicationScope.launch { cache += data.first() }
    }
    override suspend fun updateData(transform: suspend (t: Preferences) -> Preferences): Preferences {
        transform(cache)
        return dataStore.updateData(transform)
    }

    operator fun <T> set(key: Preferences.Key<T>, value: T) { ... }

    operator fun <T> get(key: Preferences.Key<T>): T? = ...

    suspend operator fun invoke(transform: suspend (MutablePreferences) -> Unit) = edit(transform)
}

val DS by lazy {
    DSManager(application.dataStore)
}

// operator invoke use:
DS {
    it -= UserId
    it[Sig] = "xxx"
}

val userId = DS[UserId]
DS[UserId] = "new user id"
```

同时，利用了`invoke`也就是括号`()`运算符，提供`edit`操作， 就有了现在的版本。但是仍会有风险在，还是`cache`问题，预热不及时等问题。保存副本，就有了数据不一致风险。

可以选择干掉`cache`，不提供`set`, `get`扔`Flow<T>`回去, `application`也不用站在全局。

用内联类，或者普通类，通过委托，实现`DataStore<T>`接口，同样上边的情况也可以用普通类处理，但是不要靠委托实现接口。否则`override`时，拿不到`super.xxx()`的行为。

普通类处理：

```kotlin
class DSManager(context: Context): DataStore<Preferences> by context.dataStore {
    operator fun <T> get(key: Preferences.Key<T>): Flow<T?> = data.map{ it[key] }
    suspend operator fun invoke(transform: suspend (MutablePreferences) -> Unit) = edit(transform)
}

val DS by lazy {
    val application by UnsplashApplication
    DSManager(context)
}

// use
val userIdFlow = DS[UserId]
scope.launch { val userId = userIdFlow.first() }
```

### value by delegate

如果场景严格一点：`DataStore`只提供指定`key-value`的访问，不允许其他地方自定义`Key`。

向上面的访问方式，自然就限制不了，其他人可以在任何文件中定义一个`Key`, 然后取值赋值。

很容易做：单例，`DataStore`私有，指暴露想开放的变量。并且`cache`也不会有什么问题。把要暴露的值做成`CoroutineScope`的拓展属性，或者继续使用`applicationScope`。同时也可以控制是否可写，是否可删除:

```kotlin
object DS {
    private val ds by lazy {
        val application by UnsplashApplication
        application.dataStore
    }

    private val cache = mutablePreferencesOf()

    private val UserId = stringPreferencesKey("user_id")

    var CoroutineScope.userId: String
        get() = cache[UserId] ?: runBlocking { ds.data.map { it[UserId].orEmpty() }.first() }
        set(value) {
            cache[UserId] = value
            launch { ds.edit { it[UserId] = value } }
        } 
    
    // or
    var userId: String
        get() = cache[UserId] ?: runBlocking { ds.data.map { it[UserId].orEmpty() }.first() }
        set(value) {
            cache[UserId] = value
            val application by UnsplashApplication
            application.applicationScope.launch { ds.edit { it[UserId] = value } }
        } 
    
    // 可删除：
    var userId: String？
        get() = cache[UserId] ?: runBlocking { ds.data.map { it[UserId] }.first() }
        set(value) {
            val application by UnsplashApplication
            if(value == null) {
                cache[UserId] = value
                application.applicationScope.launch { ds.edit { it -= UserId } }
            } else {
                cache[UserId] = value
                application.applicationScope.launch { ds.edit { it[UserId] = value } }
            }
        }     
}
```

可以。但是每个变量都要写这么一份重复内容，太废了。这不就是`属性委托`编译器处理后的效果。所以做成委托：

```kotlin
object DS {
    private val ds by lazy {
        val application by UnsplashApplication
        application.dataStore
    }

    private val cache = mutablePreferencesOf()

    private fun <T> safeKeyDelegate(key: Preferences.Key<T>, defaultValue: T) =
        object : ReadWriteProperty<Any?, T> {
            override fun getValue(thisRef: Any?, property: KProperty<*>): T =
                cache[key] ?: runBlocking { ds.data.map { it[key] ?: defaultValue }.first() }

            override fun setValue(thisRef: Any?, property: KProperty<*>, value: T) {
                cache[key] = value
                application.applicationScope.launch { ds.edit { it[key] = value } }
            }

        }

    var userId: String by safeKeyDelegate(stringPreferencesKey("user_id"), "")
}

```

`ReadWriteProperty<Any?, T>`处理一下。可删除：`ReadWriteProperty<Any?, T?>`, 限定可见范围：`ReadWriteProperty<UserInfo, T>`。

使用:

```kotlin
login(DS.userId)
DS.userId = "new user id"
```

### key by delegate

条件放宽一点，可以自定义Key， 然后通过Key去DataStore里获取值：

```kotlin
operator fun <T> Preferences.Key<T>.invoke(defaultValue: T) = object : ReadWriteProperty<Any?, T> {
            override fun getValue(thisRef: Any?, property: KProperty<*>): T =
                cache[key] ?: runBlocking { ds.data.map { it[key] ?: defaultValue }.first() }

            override fun setValue(thisRef: Any?, property: KProperty<*>, value: T) {
                cache[key] = value
                application.applicationScope.launch { ds.edit { it[key] = value } }
            }
        }

operator fun <T> Preferences.Key<T>.provideDelegate(ref: Any?, property: KProperty<*>) = object : ReadWriteProperty<Any?, T?> {
    override fun setValue(thisRef: Any?, property: KProperty<*>, value: T?) {
        if(value == null) {...} else {...}
    }
    
    override fun getValue(thisRef: Any?, property: KProperty<*>): T? = ...
}

private val UserId = stringPreferencesKey("user_id")
```

使用： 

```kotlin

// 有默认值，读写, var
var userId by UserId("default value")
login(userId)
userId = "xxx"

//有默认值，只读，val
val  userId by UserId("default value")

// 无默认值(可删除)，读写，var
var userId:String? by UserId

// 无默认值(可删除)，只读, val
val userId:String? by UserId
```

## ~λ：

大概就这些套路，根据项目实际情况，选择封装方式。排列组合一下。
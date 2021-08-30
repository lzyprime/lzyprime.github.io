---
title: gradle迁到kts, 以及module管理
date: 2021.08.29
updated: 2021.08.29
tag: [kotlin, gradle]
category: 
  - [kotlin]
  - [gradle]
---

> [github blog](https://lzyprime.github.io)    
> qq: 2383518170    
> wx: lzyprime    

## λ：

##### 仓库地址: [https://github.com/lzyprime/android_demos](https://github.com/lzyprime/android_demos)

本来想把`compose`版本分离成单独分支：`dev_compose`； 但是后来发现与`dev`分支除了`view`层不太一样，剩下的全是同样代码；甚至`view`层一些`compose`组件也全是一样的。

`model`层里，对数据组织和封装在频繁的改动，想找到更合理易用的方式，比如对`DataStore`的提供和使用方式，已经调整过好几版，目前的仍不是满意版本。

如果两个分支，这部分代码同步就很烦人。`git sub module`, `git rebase`, 手动复制。哪一个都不方便。

所以，把`view`以外公用的部分，抽成单独的`gradle module`, `compose`的`view`部分也抽成一个`module`。然后在`gradle`脚本里配好依赖关系。

同时，将`gradle`脚本由 `Groovy` 迁到 `KTS`。

## gradle kts

> [gradle 官网文档](https://docs.gradle.org/current/userguide/userguide.html)

> [android 官网迁移文档](https://developer.android.google.cn/studio/build/migrate-to-kts)

迁移完发现`android`官网文档居然也提了这事。


### 好处

- 相比`groovy`, 对`kotlin`更熟悉。脚本易读性提高，对脚本中每一步在执行什么，什么意思更容易掌握，点开看源码和注释。
- 更规范，去糖。`groovy`为了脚本编写便捷，提供了一堆简便写法，而很多其实是靠字符串解析，看是否符合规则，然后去调用真正的接口。
- 接口废弃等提醒。`gradle`即将废弃接口，接口警告信息等等，都会向`kotlin`代码一样，直接突出显示。
- 用`KTS`版本去学习`gradle`的用法。之后就算是`groovy`版本的，也能看个大概，看着官网文档和基础语法也能写的差不多。可能简便写法不怎么会，但是中规中矩的脚本能跑应该没问题。

### 坏处

- 相比`groovy`, 肯定还是简陋，不完善。包括文档里，常常会有只支持`groovy`的提示。

### 迁移过程

> [gradle 迁移文档](https://docs.gradle.org/current/userguide/migrating_from_groovy_to_kotlin_dsl.html)

给`gradle脚本`文件名加上`.kts`后缀(如`build.gradle -> build.gradle.kts`), 然后`sync`一下, 解决所有报错。每次最好只改一个文件，否则报错难修。

- 字符串必须全是双引号
- 函数调用加括号。如`classpath`, `implementation`等等后面空格加字符串的，一般是函数调用。改成`classpath(xxx)`样式
- 属性值，如 `minSdk`, `targetSdk`, `versionCode`等等被做成了属性。同时如果属性为`bool`类型，名字会变成`isXXX`的形式。
- `tasks`, `ext`, `extra`, `buildSrc`

#### `tasks`

每个`task`, 包含`name:String`， `args:Map`，`configureClosure: Function`. `groovy`提供了一堆简便写法，但最终肯定归到这三部分。以`task clean`为例。

```groovy
// groovy
task clean(type: Delete) {
    delete rootProject.buildDir
}
```

如果点进去，会发现批到的是`task(name:String)`，后边部分都会当字符串处理。这就是`groovy`提供便捷写法的方式之一，字符串解析。最后相当于：

```groovy
// 伪代码
task(
    args: {"type": Delete::class}, 
    name: "clean", 
    configureClosure: { // Delete
        delete(rootProject.buildDir)
    },
)
```

的确简便写法够简洁形象，就像声明一个函数。可是不看源码之类的，谁知道是什么。

`kotlin`也提供了一堆简便写法，以`incline function`的形式，可以一层层点到最后。

> [gradle 任务文档](https://docs.gradle.org/current/userguide/migrating_from_groovy_to_kotlin_dsl.html#creating_tasks)

#### `ext`问题

`KTS` 也有 `ext`函数，但如果像之前在`buildScript`块里写，就会报错。点进去就知道原因：

```kotlin
val org.gradle.api.Project.`ext`: org.gradle.api.plugins.ExtraPropertiesExtension get() =
    (this as org.gradle.api.plugins.ExtensionAware).extensions.getByName("ext") as org.gradle.api.plugins.ExtraPropertiesExtension

fun org.gradle.api.Project.`ext`(configure: Action<org.gradle.api.plugins.ExtraPropertiesExtension>): Unit =
    (this as org.gradle.api.plugins.ExtensionAware).extensions.configure("ext", configure)
```

也就是尝试把当前对象转为`ExtensionAware`。在`groovy`中，`buildScript`是`Project`的方法，`Project`实现了`ExtensionAware`接口。在`KTS`里，`buildScript` 来自`KotlinBuildScript`抽象类, 是个`ProjectDelegate`，用委托的方式访问`Project`, 往上找基类也的确是`Project`。

但是`buildScript`函数接收的是操作`ScriptHandlerScope`类型。

```kotlin
@Suppress("unused")
open fun buildscript(@Suppress("unused_parameter") block: ScriptHandlerScope.() -> Unit): Unit =
        internalError()

// use:
buildscript { // this: ScriptHandlerScope
    ...
}
```

也就是说，代码块里的 `this` 是个 `ScriptHandlerScope`, 并没有实现`ExtensionAware`。 所以`ScriptHandlerScope as ExtensionAware`失败了。

这也是为什么`ext`在顶级块里写或者在`allprojects`块里可以正常工作：

```kotlin
buildScript {...}

// this: ProjectDelegate
ext {
    set("key", "value")
}

allprojects { // this: Project
    ext {
        set("k", "v")
    }
}

tasks.register<Delete>("clean") {
    rootProject.ext["key1"] // 指定Project
    delete(rootProject.buildDir)
}
```

但这只是定义的时候，使用的话，同样因为这种限制，要看清楚作用域，是否能转为`ExtensionAware`，还要搞清楚是谁的。

同时受`kotlin`静态语言的限制，想直接`Project.ext.key1`, 甚至`Project.key1`使用，是不可能的。就得`Project.ext["key1"]`。


```kotlin
tasks.register<Delete>("clean") {
    val key1 = rootProject.ext["key1"] // 指定Project
    delete(rootProject.buildDir)
}
```

但是在`buildScript`里这么写又过不去。此时通过`ExtensionAware.extentions.getByName("ext")`还拿不到。其实在`groovy`中也是点不进去的，可以看看`groovy`怎么处理的，怎么达到动态语言的效果。

#### `ext` -> `extra`

所以这东西基本就废了。然后提供了`extra`。

```kotlin
buildscript {
    val gradleVersion by extra("7.0.1")
    val kotlinVersion by extra{ "1.5.21" }

    extra["activityVersion"] = "1.3.1"
    extra["lifecycleVersion"] = "2.3.1"
}

// module project
val kotlinVersion: String by rootProject.extra

val activityVersion: String by rootProject.extra
val lifecycleVersion: String by rootProject.extra
```

如果通过委托属性的方式获取值。需要显式声明类型。源码：

```kotlin
val ExtensionAware.extra: ExtraPropertiesExtension
    get() = extensions.extraProperties
```

也就是说，其实和`ext`拿到的是一样的，`Project.ext`其实就是在把`ExtensionAware.extensions.extraProperties`抛出去。

所以基础的`set get`等仍然好使。额外添加了一堆委托属性和函数，方便创建获取变量。

`val kkk by extra(vvv)`:

```kotlin
// val kkk by extra(vvv)
operator fun <T> ExtraPropertiesExtension.invoke(initialValue: T): InitialValueExtraPropertyDelegateProvider<T> =
    InitialValueExtraPropertyDelegateProvider.of(this, initialValue)
    // InitialValueExtraPropertyDelegateProvider(extra, vvv)


class InitialValueExtraPropertyDelegateProvider<T>
private constructor(
    private val extra: ExtraPropertiesExtension,
    private val initialValue: T
) {
    companion object {
        fun <T> of(extra: ExtraPropertiesExtension, initialValue: T) =
            InitialValueExtraPropertyDelegateProvider(extra, initialValue)
    }

    operator fun provideDelegate(thisRef: Any?, property: kotlin.reflect.KProperty<*>): InitialValueExtraPropertyDelegate<T> {
        // 插入, 变量名(kkk) 作为key
        extra.set(property.name, initialValue)
        return InitialValueExtraPropertyDelegate.of(extra)
        // InitialValueExtraPropertyDelegate(extra)
    }
}

class InitialValueExtraPropertyDelegate<T>
private constructor(
    private val extra: ExtraPropertiesExtension
) {
    companion object {
        fun <T> of(extra: ExtraPropertiesExtension) =
            InitialValueExtraPropertyDelegate<T>(extra)
    }

    // 赋值操作。 kkk = nvvv -> extra.set(kkk, nvvv)
    operator fun setValue(receiver: Any?, property: kotlin.reflect.KProperty<*>, value: T) =
        extra.set(property.name, value)

    // 取值操作。val nk = kkk -> val nk = extra.get(kkk)
    @Suppress("unchecked_cast")
    operator fun getValue(receiver: Any?, property: kotlin.reflect.KProperty<*>): T =
        uncheckedCast(extra.get(property.name))
}
```

中规中矩的委托。`val kkk: T by extra`也是一样：

```kotlin
operator fun ExtraPropertiesExtension.provideDelegate(receiver: Any?, property: KProperty<*>): MutablePropertyDelegate =
    if (property.returnType.isMarkedNullable) NullableExtraPropertyDelegate(this, property.name)
    else NonNullExtraPropertyDelegate(this, property.name)

private
class NonNullExtraPropertyDelegate(
    private val extra: ExtraPropertiesExtension,
    private val name: String
) : MutablePropertyDelegate {

    override fun <T> getValue(receiver: Any?, property: KProperty<*>): T =
        if (!extra.has(name)) cannotGetExtraProperty("does not exist")
        else uncheckedCast(extra.get(name) ?: cannotGetExtraProperty("is null"))

    override fun <T> setValue(receiver: Any?, property: KProperty<*>, value: T) =
        extra.set(property.name, value)

    private
    fun cannotGetExtraProperty(reason: String): Nothing =
        throw InvalidUserCodeException("Cannot get non-null extra property '$name' as it $reason")
}
```

`getValue`, `setValue`是根据变量类型做类型转换。所以要写类型，还要写对。

#### buildSrc

> [kotlin dsl plugin 文档](https://docs.gradle.org/current/userguide/kotlin_dsl.html#sec:kotlin-dsl_plugin)

另外完成共享的方式。在`rootProject`目录下创建`buildSrc`文件夹，并创建`build.gradle.kts`。

```text
/
|-buildSrc
  |- src/main/kotlin/xxx.kt
  |- build.gradle.kts
```

```kotlin
//buildSrc/build.gradle.kts
plugins {
    `kotlin-dsl`
}

repositories {
    mavenCentral()
}
```

`src/main/kotlin`下的内容在工程内共享。所以可以把变量定义在这：

```kotlin
// src/main/kotlin/versions.kt
const val kotlinVersion = "1.5.30"
...
```

其他地方可以直接用。

好处是往`gradle`添加附加功能更方便，易于管理。

弊端就是变量如果放在这，IDE可视化的Project Structure识别失败，就会一直提示有内容可以更新。

## module 管理

没什么可讲的。new 一个 module。 根据需要选择类型。然后就是`build.gradle.kts`处理好依赖和构建。`settings.gradle.kts`中`include`。

当 A_module 依赖 B_module:

```kotlin
// A_module build.gradle.kts
dependencies {
    implementation(project(":B_module"))
```

更多具体操作可以看文档。转成`KTS`不就是为了文档读着更容易。
---
title: gradle android 配置 build 变体
date: 2022.08.19
updated: 2022.08.19
---

# λ：

> ##### 仓库地址: [https://github.com/lzyprime/android_demos](https://github.com/lzyprime/android_demos)

之前想复用data层, ui层分别用`compose`和传统`view`分别实现。所以通过`gradle moudle`组织工程: 

- `core`: 通用部分, 包括data层，viewModel，共用资源文件等
- `view`: view实现
- `compose`: compose实现

但是实际体验之后，发现还是有很多弊端：

- Hilt依赖注入跨moudle的问题
- Application, Manifest文件维护两份（view, compose），但大部分逻辑相同
- gralde 依赖声明，module 存在相同依赖，管理繁琐

初衷本来只是隔离ui层实现和部分资源文件，所以改为通过`sourceSet`实现:

```kotlin
val useCompose by project.extra(false) 
android {
    sourceSets {
        getByName("main") {
            if (useCompose) {
                kotlin.srcDir("src/ui/compose")
                res.srcDir("src/ui/compose/res")
            } else {
                res.srcDir("src/ui/view/res")
                kotlin.srcDir("src/ui/view")
            }
        }
    }
}
```

> [android 配置 build 变体](https://developer.android.google.cn/studio/build/build-variants)

- buildTypes
- dependencies
- productFlavors
- sourceSets

实现 配置，源码，资源文件 多版本控制

# sourceSet 源码集

sourceSet 是 gradle 本身就提供的接口，用来组织项目源码。 [gradle sourceSets](https://docs.gradle.org/current/dsl/org.gradle.api.tasks.SourceSet.html)

```groovy
// build.gradle
plugins {
    id 'java'
}

sourceSets {
  main {
    java {
      exclude 'some/unwanted/package/**'
    }
  }
}
```

`android gradle plugin` 自己也有一个sourceSet, 目的很简单，就是先塞一些默认行为：[android sourceSet 默认源码集](https://developer.android.com/studio/build#sourcesets)。 `kts`版本的api相比`groovy`要少一部分，没有exclude 等操作

- `src/main/` 此源代码集包含所有 `变体` 共用的代码和资源。
- `src/<buildType>/` 创建此源代码集可加入特定 buildType 专用的代码和资源。 比如常用的 `debug`，`release`。在 android.buildTypes 中配置
- `src/<productFlavor>/` 创建此源代码集可加入特定`产品变种`专用的代码和资源。在 android.productFlavors 配置

```kotlin
// build.gradle.kts
android {
    ...
    sourceSets { // NamedDomainObjectContainer<out AndroidSourceSet>
        getByName("main") { // AndroidSourceSet
            ...
        }
    }
}
```

`NamedDomainObjectContainer`：buildTypes，sourceSets都是此类型。kv容器。

```kotlin
@Incubating
interface AndroidSourceSet : Named {

    /** Returns the name of this source set. */
    override fun getName(): String

    /** The Java source for this source-set */
    val java: AndroidSourceDirectorySet
    /** The Java source for this source-set */
    fun java(action: AndroidSourceDirectorySet.() -> Unit)
    
    ... 
    ...

    fun setRoot(path: String): Any
}

@Incubating
interface AndroidSourceDirectorySet : Named {

    override fun getName(): String
    // 追加规则, set += srcDir
    fun srcDir(srcDir: Any): Any
    // 追加规则 set += srcDirs
    fun srcDirs(vararg srcDirs: Any): Any
    // 覆盖规则 set = srcDirs
    fun setSrcDirs(srcDirs: Iterable<*>): Any
}
```

# productFlavors 产品变种

如果用 productFlavors 分离ui不同版本：

- 创建 `src/view`, `src/compose` 源码集
- 以`uiType`为维度， 添加 `view`, `compose` 变种

```kotlin
android {
    ...
    flavorDimensions += "uiType" // 变种维度
    productFlavors { // NamedDomainObjectContainer<out ProductFlavorT>
        create("view") { // ApplicationProductFlavor
            dimension = "uiType"
            applicationIdSuffix = ".view"
            versionNameSuffix = "-view"
        }
        create("compose") {
            dimension = "uiType"
            applicationIdSuffix = ".compose"
            versionNameSuffix = "-compose"
        }
    }
}
```

当查看productFlavors支持的可配置项时，会发现与android.defaultConfig, andoird.buildTypes中内容很像。`defaultConfig`实际上属于productFlavors，提供所有变体的默认配置。`buildType`也可视作一个变种维度`flavorDimensions`, 并且默认有`debug`和`release`两个变体

```kotlin
interface ApplicationProductFlavor : ApplicationBaseFlavor, ProductFlavor

interface ApplicationBaseFlavor : BaseFlavor, ApplicationVariantDimension
interface ProductFlavor : Named, BaseFlavor, ExtensionAware, HasInitWith<BaseFlavor>
interface BaseFlavor : VariantDimension, HasInitWith<BaseFlavor>

// ==> 
interface ApplicationProductFlavor : BaseFlavor, VariantDimension, ApplicationVariantDimension
```


## buildTypes 

```kotlin
// app build.gradle.kts

android {
    defaultConfig { // ApplicationDefaultConfig
        ...
    }
    buildTypes { // NamedDomainObjectContainer<out BuildTypeT>
        getByName("release") { // ApplicationBuildType
            isMinifyEnabled = true
        }

        getByName("debug") {
            applicationIdSuffix = ".debug"
            isDebuggable = true
        }

        create("staging") {
            initWith(getByName("debug"))
            applicationIdSuffix = ".debugStaging"
        }
    }
}
```

`ApplicationDefaultConfig`， `ApplicationBuildType` 追踪完继承关系会发现和 `ApplicationProductFlavor` 的基本一致
```kotlin
interface ApplicationDefaultConfig : ApplicationBaseFlavor, DefaultConfig {}

interface ApplicationBaseFlavor : BaseFlavor, ApplicationVariantDimension
interface BaseFlavor : VariantDimension, HasInitWith<BaseFlavor>
interface ApplicationVariantDimension : VariantDimension

interface DefaultConfig : BaseFlavor {}

// 所以跟到最后，有用的基类：
interface ApplicationDefaultConfig：BaseFlavor, VariantDimension, ApplicationVariantDimension，
```

```kotlin
interface ApplicationBuildType : BuildType, ApplicationVariantDimension

interface BuildType : Named, VariantDimension, ExtensionAware, HasInitWith<BuildType>

// 所以跟到最后，有用的config基类：
interface ApplicationBuildType : VariantDimension, ExtensionAware, ApplicationVariantDimension
```

## 变种构建

所谓的变种最后都会被提交成一个task, 并且维度会自动进行组合。由于创建了新的维度`uiType`, 所以会得到四种构建方式：`debugView, debugCompose, releaseView, releaseCompose`。

以`debugCompose`为例，sourceSet会默认加入`src/debugCompose`, `src/debug`, `src/compose`, `src/main`

可以在`androidComponents.beforeVariants` 中配置过滤规则:

variantBuilder 携带了 `android` 块中配置的内容

```kotlin
android {
    ...
}
androidComponents {
    beforeVariants { variantBuilder -> // ApplicationVariantBuilder
        if (variantBuilder.productFlavors.containsAll(listOf("uiType" to "view"))) {
            variantBuilder.enabled = false
        }
    }
}
```

# dependencies 依赖管理

源码管理解决后，就是依赖部分：

- 公共依赖的库
- 只有`view`需要的库
- 只有`compose`需要的库

自然可以通过 `useCompose` 变量判断：

```kotlin
dependencies {
    if (useCompose) {
        ...
    } else {
        ...
    }
    ...
}
```


但当我们创建buildType和productFlavors的同时， 会通过 [gradle dependency configurations](https://docs.gradle.org/current/userguide/declaring_dependencies.html#sec:what-are-dependency-configurations) 提供对应的依赖配置: `<buildType>Implementation`， `<productFlavor>Implementation`。 但是对于buildType + productFlavors 的组合型构建变体没有自动创建，需要自己声明。

```kotlin
val composeDebugImplementation by configurations
// configurations {
//    composeDebugImplementation {}
// }
dependencies {
    releaseImplementation("....")
    composeImplementation("....")
    composeDebugImplementation("....")
}
```


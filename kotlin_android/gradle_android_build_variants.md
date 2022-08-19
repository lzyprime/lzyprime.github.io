---
title: gradle android配置变体构建
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

> [android build配置](https://developer.android.com/studio/build)

- dependencies
- productFlavors
- sourceSet

实现 配置，源码，资源文件 多版本控制

# sourceSet

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

`android gradle plugin` 自己也有一个sourceSet, 目的很简单，就是先塞一些默认行为：[android sourceSet 默认源码集](https://developer.android.com/studio/build#sourcesets)

每个module 默认源码集在 `main/`。 `kts`版本的api相比`groovy`要少一部分，没有exclude 等操作

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

    fun setRoot(path: String): Any
}

@Incubating
interface AndroidSourceDirectorySet : Named {

    override fun getName(): String
    // 追加规则
    fun srcDir(srcDir: Any): Any
    // 追加规则
    fun srcDirs(vararg srcDirs: Any): Any
    // 覆盖规则
    fun setSrcDirs(srcDirs: Iterable<*>): Any
}

```

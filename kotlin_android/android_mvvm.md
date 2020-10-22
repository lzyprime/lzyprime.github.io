# android mvvm架构

> [lzyprime 博客 (github)](https://lzyprime.github.io)   
> 创建时间：2020.10.22  
> qq及邮箱：2383518170  

## λ：[官网_应用架构指南](https://developer.android.com/jetpack/guide)

`MVVM` 现在热门的架构，官网这篇文章给出了如何搭建。

用到的组件和功能：

## 添加组件

### 网络：Retrofit + kotlin 协程

我也试过其他框架：[Fuel](https://github.com/kittinunf/fuel), [Ktor Client](https://ktor.kotlincn.net/clients/index.html)。但是迫于业务需求，最后保留了Retrofit。如果网络请求比较简单，推荐这两个框架。

> - [Retrofit 官网](https://square.github.io/retrofit/)
> - [kotlin 协程 官网文档](https://www.kotlincn.net/docs/reference/coroutines/coroutines-guide.html)

```gradle
// app gradle

dependencies {
    ...

    //Retrofit
    def retrofit_version = "x.x.x"
    implementation "com.squareup.retrofit2:retrofit:$retrofit_version"
    implementation "com.squareup.retrofit2:converter-gson:$retrofit_version" //json转换，官网提供多个方案，任选其一
}
```
### lifecycle-ktx
>  - androidx.lifecycle:lifecycle-runtime-ktx
>  - androidx.lifecycle:lifecycle-livedata-ktx
>  - androidx.lifecycle:lifecycle-viewmodel-ktx
>  - androidx.activity:activity-ktx

#### LiveData 组织数据
> - [LiveData 官网文档](https://developer.android.com/topic/libraries/architecture/livedata)

数据可观察同时自动考虑状态改变、生命周期等
```gradle
// app gradle
def lifecycle_version = "x.x.x"
implementation "androidx.lifecycle:lifecycle-livedata-ktx:$lifecycle_version"
```
- ktx:
  - androidx.lifecycle:lifecycle-runtime-ktx
  - androidx.lifecycle:lifecycle-livedata-ktx
  - androidx.lifecycle:lifecycle-viewmodel-ktx
  - androidx.activity:activity-ktx
- 依赖注入：[Hilt](https://developer.android.com/training/dependency-injection) 
- 数据库：[Room](https://developer.android.com/topic/libraries/architecture/room) (暂时没需求)

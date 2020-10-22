# android mvvm架构

> [lzyprime 博客 (github)](https://lzyprime.github.io)   
> 创建时间：2020.10.22  
> qq及邮箱：2383518170  

## λ：[官网_应用架构指南](https://developer.android.google.cn/jetpack/guide)

`MVVM` 现在热门的架构，官网这篇文章给出了如何搭建。

用到的组件和功能：

## 添加组件

### 网络：Retrofit + kotlin 协程

我也试过其他框架：[Fuel](https://github.com/kittinunf/fuel), [Ktor Client](https://ktor.kotlincn.net/clients/index.html)。但是迫于业务需求，最后保留了Retrofit。如果网络请求比较简单，可以试试这两个框架，由`kotlin`实现，和协程配合更好。

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
### lifecycle ktx：ViewModel, LiveData
>  - [Lifecycle 官网文档](https://developer.android.google.cn/jetpack/androidx/releases/lifecycle?hl=zh_cn#declaring_dependencies)
> - [ViewModel 官网文档](https://developer.android.google.cn/topic/libraries/architecture/viewmodel?hl=zh_cn)
> - [LiveData 官网文档](https://developer.android.google.cn/topic/libraries/architecture/livedata)

- androidx.lifecycle:lifecycle-runtime-ktx
- androidx.lifecycle:lifecycle-livedata-ktx
- androidx.lifecycle:lifecycle-viewmodel-ktx
- androidx.activity:activity-ktx

其中`activity-ktx`目的：
```kotlin
    class MyActivity : AppCompatActivity() {

        override fun onCreate(savedInstanceState: Bundle?) {
            // Create a ViewModel the first time the system calls an activity's onCreate() method.
            // Re-created activities receive the same MyViewModel instance created by the first activity.

            // Use the 'by viewModels()' Kotlin property delegate
            // from the activity-ktx artifact
            val model: MyViewModel by viewModels()
            model.getUsers().observe(this, Observer<List<User>>{ users ->
                // update UI
            })
        }
    }
```

### 依赖注入：Hlit
> - [Hilt 官方文档](https://developer.android.google.cn/training/dependency-injection)
> - [Hilt 和 Jetpack集成](https://developer.android.google.cn/training/dependency-injection/hilt-jetpack)

### 数据库：Room

> - [Room 官方文档](https://developer.android.google.cn/topic/libraries/architecture/room) (暂时没需求)

## MVVM
### 0. Utils
```kotlin
object Net {

    private const val PROP_BASE_URL ="https://"
    private const val DEBUG_BASE_URL = "http://"
    private val BASE_URL get() = DEBUG_BASE_URL


    val retrofit: Retrofit by lazy {
        val client = OkHttpClient.Builder()
            .addInterceptor { chain ->
               // 拦截器
            }
            .cookieJar(object : CookieJar {
                // cookies处理
                ...
            })
            .build()

        Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(client)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
    }
}
```
### 1.model
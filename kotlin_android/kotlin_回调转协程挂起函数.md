---
title: kotlin 回调转协程挂起函数
updated: 2021.8.7
date: 2021.8.7
tags: [ kotlin, android ]
categories:
 - [ kotlin_android ]
---

## λ：

今天起 [android demo](https://github.com/lzyprime/android_demos) 项目新加个sdk：[腾讯云IM](https://cloud.tencent.com/product/im)，最近正在用，而且接口多，涉及到的需求也挺全。正好练手。同时也有`flutter`的sdk。顺路把`flutter`也写了。

大多数sdk或者库在提供api时，对于异步处理一般都是提供回调。好处是通用，兼容，不管java, kotlin，不用管其他依赖库。 坏处就不用再提了。

IM也不例外是一堆回调，MVVM模式下，一层层传回调上去就很low，所以把IM用到的接口整理成`Service`，在里边把回调包成kotlin 协程挂起函数。

## suspendCancellableCoroutine

```kotlin
public suspend inline fun <T> suspendCancellableCoroutine(crossinline block: (CancellableContinuation<T>) -> Unit): T 

public suspend inline fun <T> suspendCoroutine(crossinline block: (Continuation<T>) -> Unit): T
```

协程库提供的两个`内联函数`。通过操作其中的`CancellableContinuation`提交结果。点进去看源码，查看支持的操作。

```kotlin
public interface Continuation<in T> {
    public val context: CoroutineContext

    public fun resumeWith(result: Result<T>)
}

public interface CancellableContinuation<in T> : Continuation<T> {
    public val isActive: Boolean

    public val isCompleted: Boolean

    public val isCancelled: Boolean

    public fun cancel(cause: Throwable? = null): Boolean

    public fun invokeOnCancellation(handler: CompletionHandler)

    ... 试验性接口
}

public inline fun <T> Continuation<T>.resume(value: T): Unit = resumeWith(Result.success(value))

public inline fun <T> Continuation<T>.resumeWithException(exception: Throwable): Unit = resumeWith(Result.failure(exception))

public inline fun <T> Continuation(context: CoroutineContext, crossinline resumeWith: (Result<T>) -> Unit): Continuation<T>
```

忽略掉被打了标签的接口(不确定，试验性，即将废弃，等)，看函数名基本就知道干嘛用，还剩这么点。 同时提供一堆`拓展函数`。

所以可以通过 `resume` 和 `resumeWithException` 提交回调返回的结果。

通过`invokeOnCancellation`注册取消时要执行的任务，比如关闭流之类的。

如IM中获取所有已加入群，当回调返回为失败时，直接提交一个空列表。或者提交个`Throwable`。

```kotlin
suspend fun getJoinedGroupList(): List<V2TIMGroupInfo> =
        suspendCancellableCoroutine { continuation ->
            V2TIMManager.getGroupManager().getJoinedGroupList(object : V2TIMValueCallback<List<V2TIMGroupInfo>> {
                    override fun onSuccess(t: List<V2TIMGroupInfo>) {
                        continuation.resume(t)
                    }

                    override fun onError(code: Int, desc: String?) {
                        continuation.resume(emptyList())
//                     continuation.resumeWithException(Exception("code: $code, desc: $desc"))
                    }
                })
        }
```

## callbackFlow, SharedFlow, StateFlow

有些回调是在实时监听数据。比如位置信息，音量变化，IM中数据变化，新消息送达等等。所以这种回调用 `kotlin Flow 和 Channel` 处理。

- [kotlin Flow官网文档](https://www.kotlincn.net/docs/reference/coroutines/flow.html)
- [Android 上的 Kotlin 数据流](https://developer.android.google.cn/kotlin/flow)
- [Android 上 StateFlow 和 SharedFlow
](https://developer.android.google.cn/kotlin/flow/stateflow-and-sharedflow)

### callbackFlow

现在`callbackFlow`仍标记为`@ExperimentalCoroutinesApi`。所以等 ***鸡啄完了米，狗舔完了面，火烧断了锁*** 。我再用。

允许在不同的`CoroutineContext`中提交数据。刨一下源码:

```kotlin
public fun <T> callbackFlow(@BuilderInference block: suspend ProducerScope<T>.() -> Unit): Flow<T> = CallbackFlowBuilder(block)

private class CallbackFlowBuilder<T>(...) : ChannelFlowBuilder<T>(...)

private open class ChannelFlowBuilder<T>(...) : ChannelFlow<T>(...)
```

最底层就是个`ChannelFlow`，也就是开个带缓冲区`Channel`来收集数据，在`Flow`里接收数据。

而`CallbackFlowBuilder`在此基础上加了`awaitClose`: 当流要关闭时要执行的操作，常见的是注销掉回调函数。如果没有`awaitClose`，将会抛出`IllegalStateException`异常。

所以提交数据的方式和`SendChannel`一样。

```kotlin
callbackFlow<T> {
    send(T) // 发送数据
    offer(T) // 允许在协程外提交
    sendBlocking(T) //尝试用offer提交，如果失败则runBlocking{ send(T) }，阻塞式提交
    awaitClose(block: () -> Unit = {}) // 关闭时执行的操作
}
```

```kotlin
// demo
fun flowFrom(api: CallbackBasedApi): Flow<T> = callbackFlow {
    val callback = object : Callback {
        override fun onNextValue(value: T) {
            try {
                sendBlocking(value)
            } catch (e: Exception) {

            }
        }
        override fun onApiError(cause: Throwable) {
            cancel(CancellationException("API Error", cause))
        }
        override fun onCompleted() = channel.close()
    }
    api.register(callback)
    awaitClose { api.unregister(callback) }
}
```

### SharedFlow

取代`BroadcastChannel`。

`SharedFlow`, `MutableSharedFlow` 都是 `interface`。 同时提供了`fun MutableSharedFlow`用于快速构造。

```kotlin
public fun <T> MutableSharedFlow(
    replay: Int = 0,
    extraBufferCapacity: Int = 0,
    onBufferOverflow: BufferOverflow = BufferOverflow.SUSPEND
): MutableSharedFlow<T> 
```

`replay`：重播n个之前收到的数据给新订阅者。 >= 0

`extraBufferCapacity`：除了重播之外缓冲区大小。当缓冲区不满时，提交数据不会挂起

`onBufferOverflow`：缓冲区溢出时的策略（replay != 0 || extraBufferCapacity != 0 才有效）。默认SUSPEND: 暂停发送，DROP_OLDEST：删掉最旧数据，DROP_LATEST：删掉最新数据。

通过`emit(T)`在协程中提交数据。

`tryEmit(T): Boolean` 尝试在不挂起的情况下提交数据，成功则返回`true`。 如果`onBufferOverflow = BufferOverflow.SUSPEND` ，在缓冲区满时，`tryEmit`会返回`false`，直到有新空间。而如果是`DROP_OLDEST`或`DROP_LATEST`，不会阻塞，`tryEmit`永为`true`。

所以我用`MutableSharedFlow`替代`callbackFlow`的提交过程。

```kotlin
// demo
val resFlow = MutableSharedFlow<Res<T>>(
    extraBufferCapacity = 1,
    onBufferOverflow: BufferOverflow = BufferOverflow.DROP_OLDEST
)

fun registerCallback() {
    val callback = object : Callback {
        override fun onNextValue(value: T) {
            resFlow.tryEmit(Res.Success(value))
        }
        override fun onApiError(cause: Throwable) {
            resFlow.tryEmit(Res.Failed(cause))
        }
        override fun onCompleted() {
            resFlow.tryEmit(Res.Finish)
        }
    }
    api.register(callback)
}
```

### StateFlow

继承自`SharedFlow`，同样也提供了快速构造的函数。函数必须提交一个初始的`value`。底层相当于开了一个 `MutableSharedFlow(replay = 1, onBufferOverflow = BufferOverflow.DROP_OLDEST)`.

```kotlin
public interface StateFlow<out T> : SharedFlow<T> {
    public val value: T
}

public interface MutableStateFlow<T> : StateFlow<T>, MutableSharedFlow<T> {
    public override var value: T
    public fun compareAndSet(expect: T, update: T): Boolean
}

@Suppress("FunctionName")
public fun <T> MutableStateFlow(value: T): MutableStateFlow<T> = StateFlowImpl(value ?: NULL)
```
`compareAndSet`: 如果当前值为`expect`, 则更新为`update`。如果更新则返回`true`(包括`current == expect && current == update` 的情况)。

```kotlin
// demo
class LatestNewsViewModel(
private val newsRepository: NewsRepository) : ViewModel() {

    private val _uiState = MutableStateFlow(LatestNewsUiState.Success(emptyList()))
    val uiState: StateFlow<LatestNewsUiState> = _uiState

    init {
        viewModelScope.launch {
            newsRepository.favoriteLatestNews.collect { favoriteNews ->
                    _uiState.value = LatestNewsUiState.Success(favoriteNews)
                }
        }
    }
}

sealed class LatestNewsUiState {
    data class Success(news: List<ArticleHeadline>): LatestNewsUiState()
    data class Error(exception: Throwable): LatestNewsUiState()
}
```
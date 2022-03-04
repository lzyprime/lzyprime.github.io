---
title: Android RecyclerView
updated: 2022.02.25  
date: 2020.02.25  
---

# λ：

```bash
# 仓库地址: https://github.com/lzyprime/android_demos/tree/recyclerview

git clone -b recyclerview https://github.com/lzyprime/android_demos
```

`RecyclerView`作 Android 列表项的展示组件。相比`ListView`，缓存机制做的更细致，提升流畅度。以空间换时间

两个重要参数：
1. `LayoutManager`: 排版
2. `RecyclerView.Adapter`: 列表项获取方式

# LayoutManager

`LayoutManager` 可以在`xml`中直接配置. 也可在逻辑代码中设置。

```xml
// xml
   <androidx.recyclerview.widget.RecyclerView
        ...
        // LayoutManager类型
        app:layoutManager="androidx.recyclerview.widget.GridLayoutManager"
        // 几栏
        app:spanCount="1"
        />
```

全部可配参数：

![](android_recyclerview/1.png)

## 1. LinearLayoutManager

```kotlin
public class LinearLayoutManager extends RecyclerView.LayoutManager implements
        ItemTouchHelper.ViewDropHandler, RecyclerView.SmoothScroller.ScrollVectorProvider
```

单栏线性布局。无法多栏展示。构造函数参数：

1. orientation: 方向
2. reverseLayout: 反转，倒序列表项

> stackFromEnd 用来兼容 android.widget.AbsListView.setStackFromBottom(boolean)。相当于reverseLayout 的效果。

同时实现了`ItemTouchHelper.ViewDropHandler`, `RecyclerView.SmoothScroller.ScrollVectorProvider`

![](android_recyclerview/2.png)


## 2. GridLayoutManager

```kotlin
public class GridLayoutManager extends LinearLayoutManager
```

网格布局。`LinearLayoutManager` 升级版，可以通过`spanCount`设置分几栏

![](android_recyclerview/3.png)

## 3. StaggeredGridLayoutManager

```kotlin
public class StaggeredGridLayoutManager extends RecyclerView.LayoutManager implements
        RecyclerView.SmoothScroller.ScrollVectorProvider
```

流布局。 当列表项尺寸不一致时, `GridLayoutManager` 根据尺寸较大项确定网格尺寸。导致较小项会有空白部分。`StaggeredGridLayoutManager` 则紧凑拼接每一项。 通过 `setGapStrategy(int)` 设置间隙处理策略。

![](android_recyclerview/4.png)


## Adapter

### `RecyclerView.Adapter<VH : RecyclerView.ViewHolder>`

```java
public abstract static class Adapter<VH extends ViewHolder> {
    ...
    @NonNull
    public abstract VH onCreateViewHolder(@NonNull ViewGroup parent, int viewType);

    public abstract void onBindViewHolder(@NonNull VH holder, int position);

    public abstract int getItemCount();
}

public abstract static class ViewHolder {
    public ViewHolder(@NonNull View itemView) { ... }
}
```

一个`Adapter`至少需要`override`这三个函数。 

#### `getItemCount`

返回列表项的个数。

#### `onCreateViewHolder`, `getItemViewType`

创建一个`ViewHolder`, 如果 `ViewHolder` 有多种类型，可以通过`viewType`参数判断。 `viewType` 的值来自 `getItemViewType(position: Int)` 函数。默认返回0。 `0 <= position < getItemCount()`

以聊天消息为例:

```kotlin
sealed class Msg {
    data class Text(val content: String) : Msg()
    data class Image(val url: String) : Msg()
    data class Video(...) : Msg()
    ...
}

class MsgListAdapter : RecyclerView.Adapter<MsgListAdapter.MsgViewHolder>() {
    sealed class MsgViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        class Text(...) : MsgViewHolder(...)
        class Image(...) : MsgViewHolder(...)
        ...
    }

    private var dataList: List<Msg> = listOf()

    override fun getItemViewType(position: Int): Int =
        when (dataList[position]) {
            is Msg.Text -> 1
            is Msg.Image -> 2
            ...
        }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): MsgViewHolder =
        when (viewType) {
            1 -> MsgViewHolder.Text(...)
            2 -> MsgViewHolder.Image(...)
            ...
        }
}
```

#### onBindViewHolder

`View` 创建完成，开始绑定数据。包括事件监听注册。

```kotlin
class VBViewHolder<VB : ViewBinding>(private val binding : VB) : ViewHolder(binding.root) {
    fun bind(data: T, onClick:() -> Unit) {
        binding.data = data
        ...
        binding.anyView.setOnClickListener { onClick() }
        ...
    }
}

class Adapter(private val onItemClick: () -> Unit) : RecyclerView.Adapter<VBViewHolder<XXX>>() {
    override fun onBindViewHolder(holder: VBViewHolder<XXX>, position: Int) =
        holder.bindHolder(dataList[position], onItemClick)
}
```

#### 更新

由于缓存机制，更新完数据源, `ViewHolder` 也并不会立刻刷新。需要通过`Adapter`的一系列方法，显式通知发生变化的列表项。

- `notifyDataSetChanged()`
- `notifyItemChanged(position: Int), notifyItemChanged(position: Int, payload: Any?)`
- `notifyItemRangeChanged(positionStart: Int, itemCount: Int), notifyItemRangeChanged(positionStart: Int, itemCount: Int, payload: Any?)`
- `notifyItemMoved(fromPosition: Int, toPosition: Int)`
- `notifyItemInserted(position: Int)`
- `notifyItemRangeInserted(positionStart: Int, itemCount: Int)`
- `notifyItemRemoved(position: Int)`
- `notifyItemRangeRemoved(positionStart: Int, itemCount: Int)`

`payload: Any?` 要配合 `Adapter` 的 `onBindViewHolder(holder: VH, position: Int, payloads: MutableList<Any>)` 实现 `View` 的局部刷新。否则，执行 `onBindViewHolder(holder: VBViewHolder<VH>, position: Int)`


# 缓存机制

主要逻辑在 `RecyclerView.Recycler`。 缓存主要有 `Scrap`, `CachedView`, `RecycledViewPool`。 `ViewCacheExtension` 用于额外自定义缓存。

- `Scrap`: 当前正在展示的部分。
- `CachedView`: 刚划出展示区域的部分，默认最大存储 `DEFAULT_CACHE_SIZE = 2`。 `FIFO`更新
- `RecycledViewPool`: `CachedView` 淘汰后，只保留 `ViewHolder`, 清空数据绑定。 复用时需要重新执行`onBindViewHolder`。

`RecycledViewPool` 内部是一个`SparseArray<ScrapData>` 下标为 `holder.viewType`。`ScrapData` 内嵌`ArrayList<ViewHolder>`, 默认最大存储 `DEFAULT_MAX_SCRAP = 5` 个 `ViewHolder`。 所以简化一下`RecycledViewPool ~= SparseArray<ArrayList<ViewHolder>>`。

```java
public final class Recycler {
    final ArrayList<ViewHolder> mAttachedScrap = new ArrayList<>();
    ArrayList<ViewHolder> mChangedScrap = null;

    final ArrayList<ViewHolder> mCachedViews = new ArrayList<ViewHolder>();

    private final List<ViewHolder>
            mUnmodifiableAttachedScrap = Collections.unmodifiableList(mAttachedScrap);

    private int mRequestedCacheMax = DEFAULT_CACHE_SIZE;
    int mViewCacheMax = DEFAULT_CACHE_SIZE;

    RecycledViewPool mRecyclerPool;

    private ViewCacheExtension mViewCacheExtension;

    static final int DEFAULT_CACHE_SIZE = 2;

    ...
}
```

```java
public static class RecycledViewPool {
    private static final int DEFAULT_MAX_SCRAP = 5;

    static class ScrapData {
        final ArrayList<ViewHolder> mScrapHeap = new ArrayList<>();
        int mMaxScrap = DEFAULT_MAX_SCRAP;
        long mCreateRunningAverageNs = 0;
        long mBindRunningAverageNs = 0;
    }

    SparseArray<ScrapData> mScrap = new SparseArray<>();

    private int mAttachCount = 0;
    ...
}
```

## 取, `getViewForPosition`

跟一下该函数就大概知道各级缓存如何配合。

```java
@NonNull
public View getViewForPosition(int position) {
    return getViewForPosition(position, false);
}

View getViewForPosition(int position, boolean dryRun) {
    return tryGetViewHolderForPositionByDeadline(position, dryRun, FOREVER_NS).itemView;
}
```

```java
@Nullable
RecyclerView.ViewHolder tryGetViewHolderForPositionByDeadline(int position, boolean dryRun, long deadlineNs) {
    ...
    boolean fromScrapOrHiddenOrCache = false;
    RecyclerView.ViewHolder holder = null;
    // 0) If there is a changed scrap, try to find from there
    if (mState.isPreLayout()) {
        holder = getChangedScrapViewForPosition(position);
        fromScrapOrHiddenOrCache = holder != null;
    }
    // 1) Find by position from scrap/hidden list/cache
    if (holder == null) {
        holder = getScrapOrHiddenOrCachedHolderForPosition(position, dryRun);
        ...
    }
    if (holder == null) {
        final int offsetPosition = mAdapterHelper.findPositionOffset(position);
        ...
        final int type = mAdapter.getItemViewType(offsetPosition);
        // 2) Find from scrap/cache via stable ids, if exists
        if (mAdapter.hasStableIds()) {
            holder = getScrapOrCachedViewForId(mAdapter.getItemId(offsetPosition), type, dryRun);
            ...
        }
        if (holder == null && mViewCacheExtension != null) {
            // We are NOT sending the offsetPosition because LayoutManager does not
            // know it.
            final View view = mViewCacheExtension.getViewForPositionAndType(this, position, type);
            ...
        }
        if (holder == null) { // fallback to pool
            ...
            holder = getRecycledViewPool().getRecycledView(type);
            ...
        }
        if (holder == null) {
            ...
            holder = mAdapter.createViewHolder(RecyclerView.this, type);
            ...
        }
    }
    ...

    return holder;
}
```

- `getChangedScrapViewForPosition`
- `getScrapOrHiddenOrCachedHolderForPosition`
- `getScrapOrCachedViewForId`
- `mViewCacheExtension.getViewForPositionAndType`
- `getRecycledViewPool().getRecycledView(type)`
- `mAdapter.createViewHolder(RecyclerView.this, type)`

## 放，`recycleView`

跟一下该函数，了解放入缓存过程和策略

```java
public void recycleView(@NonNull View view) {
    ViewHolder holder = getChildViewHolderInt(view);
    ... // 清空flag

    recycleViewHolderInternal(holder);
    ...
}

void recycleViewHolderInternal(ViewHolder holder) {
    ... 
    final boolean transientStatePreventsRecycling = holder.doesTransientStatePreventRecycling();
    @SuppressWarnings("unchecked") final boolean forceRecycle = mAdapter != null && transientStatePreventsRecycling && mAdapter.onFailedToRecycleView(holder);
    boolean cached = false;
    boolean recycled = false;
    
    if (forceRecycle || holder.isRecyclable()) {
        if (mViewCacheMax > 0 && !holder.hasAnyOfTheFlags(...)) {
            // Retire oldest cached view
            int cachedViewSize = mCachedViews.size();
            if (cachedViewSize >= mViewCacheMax && cachedViewSize > 0) {
                recycleCachedViewAt(0);
                cachedViewSize--;
            }

            int targetCacheIndex = cachedViewSize;
            if (ALLOW_THREAD_GAP_WORK && cachedViewSize > 0 && !mPrefetchRegistry.lastPrefetchIncludedPosition(holder.mPosition)) {
                // when adding the view, skip past most recently prefetched views
                int cacheIndex = cachedViewSize - 1;
                while (cacheIndex >= 0) {
                    int cachedPos = mCachedViews.get(cacheIndex).mPosition;
                    if (!mPrefetchRegistry.lastPrefetchIncludedPosition(cachedPos)) {
                        break;
                    }
                    cacheIndex--;
                }
                targetCacheIndex = cacheIndex + 1;
            }
            mCachedViews.add(targetCacheIndex, holder);
            cached = true;
        }
        if (!cached) {
            addViewHolderToRecycledViewPool(holder, true);
            recycled = true;
        }
    } else {
        ... // Log
    }
    // even if the holder is not removed, we still call this method so that it is removed
    // from view holder lists.
    mViewInfoStore.removeViewHolder(holder);
    if (!cached && !recycled && transientStatePreventsRecycling) {
        holder.mBindingAdapter = null;
        holder.mOwnerRecyclerView = null;
    }
}
```

- `mCachedViews.add(targetCacheIndex, holder)`
- `addViewHolderToRecycledViewPool`

# 简化 & 封装 & 工具

一个 `Adapter` 的实现，大多数时候只关注 `onBindViewHolder` 的过程，以及数据更新时 `notify` 更新逻辑。剩下的操作，基本是重复的。

## ListAdapter

默认实现了`fun getItemCount() = dataList.size()`。

需要一个 `DiffUtil.ItemCallback<T>`，内部构造`mDiffer: AsyncListDiffer<T>`, 用于比较列表项的变化，然后自动刷新。 

通过 `submitList(List<T>?)` 提交数据。

通过 `getItem(position: Int): T = dataList[position]` 获取当前位置对应数据。

省去了数据更新和`notify`的过程， 只需要关注`onCreateViewHolder`, `onBindViewHolder`。 

***PS: 注意 `submitList()`和传引用问题。*** 做数据比较时 `previousList, currentList` 以及 `Item` 的比较，全是靠引用拿到，`diff(previousList[index], currentList[index])`。所以如果 `submitList()` 如果提交的同一份`List`， diff比较就会失效。 

如果使用 `Paging3` 分页库, 在View层会有 `PagingDataAdapter`, 与 `ListAdapter` 类似。 将数据源 `PagingData` 等设置好后，列表便可以自动刷新，加载更多等。

```java
public abstract class ListAdapter<T, VH extends RecyclerView.ViewHolder>
extends RecyclerView.Adapter<VH> {
    final AsyncListDiffer<T> mDiffer;
    private final AsyncListDiffer.ListListener<T> mListener = ...;

    protected ListAdapter(@NonNull DiffUtil.ItemCallback<T> diffCallback) { ... }
    protected ListAdapter(@NonNull AsyncDifferConfig<T> config) { ... }

    public void submitList(@Nullable List<T> list) { mDiffer.submitList(list); }
    public void submitList(@Nullable List<T> list, @Nullable final Runnable commitCallback) { mDiffer.submitList(list, commitCallback); }

    protected T getItem(int position) { return mDiffer.getCurrentList().get(position); }

    @Override public int getItemCount() { return mDiffer.getCurrentList().size(); }

    @NonNull public List<T> getCurrentList() { return mDiffer.getCurrentList(); }

    public void onCurrentListChanged(@NonNull List<T> previousList, @NonNull List<T> currentList) {}
}
```

## DSL + ViewBinding

继续简化。 

- 大部分`ViewHolder` 靠 `ViewBinding` 实现。 那 `onCreateViewHolder()` 也基本是重复的操作。

- `ViewBinding`的创建过程也基本一致：`ViewBinding.inflate(...)`。 可以用 [《android ViewBinding, DataBinding》](./viewbinding_databinding.md) 中的老方法，靠反射拿到。所以只需要 `Adapter<VB : ViewBinding>`，`onCreateViewHolder()` 也可以省了。

- `DiffUtil.ItemCallback<T>` 的实现也基本重复。 通常只需要两个lambda表达式说明情况。

```kotlin
// ViewHolder
data class BindingViewHolder<VB : ViewBinding>(val binding: VB) : RecyclerView.ViewHolder(binding.root)
```

```kotlin
// DiffUtil.ItemCallback<T>
inline fun <reified T> diffItemCallback(
    crossinline areItemsTheSame: (oldItem: T, newItem: T) -> Boolean,
    crossinline areContentsTheSame: (oldItem: T, newItem: T) -> Boolean = { o, n -> o == n },
) = object : DiffUtil.ItemCallback<T>() {
    override fun areItemsTheSame(oldItem: T, newItem: T): Boolean =
        areItemsTheSame(oldItem, newItem)

    override fun areContentsTheSame(oldItem: T, newItem: T): Boolean =
        areContentsTheSame(oldItem, newItem)
}
```

```kotlin
// ListAdapter<T, VH : ViewHolder>
fun <T, VH : RecyclerView.ViewHolder> dslListAdapter(
    diffItemCallback: DiffUtil.ItemCallback<T>,
    createHolder: (parent: ViewGroup, viewType: Int) -> VH,
    bindHolder: VH.(position: Int, data: T) -> Unit,
) = object : ListAdapter<T, VH>(diffItemCallback) {
    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH =
        createHolder(parent, viewType)

    override fun onBindViewHolder(holder: VH, position: Int) =
        holder.bindHolder(position, getItem(position))
}
```

```kotlin
/** 
* ListAdapter<T, BindingViewHolder<VB : ViewBinding>>
* 
* inflate 不传时，通过反射拿到VB的inflate 
* */
inline fun <T, reified VB : ViewBinding> dslBindingListAdapter(
    diffItemCallback: DiffUtil.ItemCallback<T>,
    noinline inflate: ((parent: ViewGroup, viewType: Int) -> VB)? = null,
    crossinline bindHolder: VB.(position: Int, data: T) -> Unit,
) = dslListAdapter(
    diffItemCallback,
    { p, v ->
        BindingViewHolder(
            inflate?.invoke(p, v) ?: VB::class.java.getMethod(
                "inflate",
                LayoutInflater::class.java,
                ViewGroup::class.java,
                Boolean::class.java
            ).invoke(null, LayoutInflater.from(p.context), p, false) as VB
        )
    },
    { p, d -> binding.bindHolder(p, d) },
)
```

使用：

```kotlin
val adapter = dslBindingListAdapter<Comment, ListItemSingleLineTextBinding>(
    diffItemCallback({ o, n -> o.id == n.id }, { o, n -> o == n }),
) { _, data ->
    // this is ListItemSingleLineTextBinding, 
    // data: Comment(id: Int, content: String)
    titleText.text = data
}
```

此外还有各种库也做了封装。最好靠(ksp，kapt)注解和编译器插件在编译期做代码生成，靠反射不保险还额外费资源

## `ItemTouchHelper`

列表项滑动和拖拽。

```java
public class ItemTouchHelper extends RecyclerView.ItemDecoration implements RecyclerView.OnChildAttachStateChangeListener
```

```kotlin
// use:
ItemTouchHelper(callback: ItemTouchHelper.Callback).attachToRecyclerView(recyclerView: RecyclerView?)
```

### `ItemTouchHelper.Callback`

需要设定滑动和拖拽的方向`START(LEFT), END(RIGHT), UP, DOWN`。

可通过`onChildDraw(), onChildDrawOver()` 等自定义滑动和拖拽过程中的行为。

```kotlin
object: ItemTouchHelper.Callback() {
    override fun getMovementFlags(recyclerView: RecyclerView, viewHolder: RecyclerView.ViewHolder): Int {
        // 返回滑动和拖拽的方向
    }

    override fun onMove(recyclerView: RecyclerView, viewHolder: RecyclerView.ViewHolder, target: RecyclerView.ViewHolder): Boolean {
        viewHolder // 被拖拽holder
        target // 正在经过holder
        // 返回是否允许滑动
    }

    override fun onSwiped(viewHolder: RecyclerView.ViewHolder, direction: Int) {
        direction // 滑动方向
    }
}
```

### `ItemTouchHelper.SimpleCallback`

`ItemTouchHelper.Callback` 简版实现。构造函数传入滑动和拖拽方向。只需要关注`onMove()` 和 `onSwiped()`过程。

```java
public abstract static class SimpleCallback extends Callback {
    public SimpleCallback(int dragDirs, int swipeDirs)
    ...
}
```

### 自定义行为

```kotlin
override fun onChildDraw(
    c: Canvas, // holder所占区域的Canvas
    recyclerView: RecyclerView,
    viewHolder: RecyclerView.ViewHolder,
    dX: Float, // 用户动作引起的x移量
    dY: Float, // 用户动作引起的y移量
    actionState: Int, // 交互类型，swipe | drag
    isCurrentlyActive: Boolean, // 用户是否正在控制
) { ... }
```

#### `onChildDraw`的默认实现：`translationX = dX, translationY = dY`

```java
public void onDraw(Canvas c, RecyclerView recyclerView, View view, float dX, float dY,
        int actionState, boolean isCurrentlyActive) {
    ...
    view.setTranslationX(dX);
    view.setTranslationY(dY);
}
```

#### dX, dY:

关于`dX, dY`的计算规则，要从头一点点看，`attachToRecyclerView()` 之后。

```java
public void attachToRecyclerView(@Nullable RecyclerView recyclerView) { ...
    setupCallbacks();
... }

private void setupCallbacks() { ...
    mRecyclerView.addOnItemTouchListener(mOnItemTouchListener);
... }

private final OnItemTouchListener mOnItemTouchListener = new OnItemTouchListener() { ...
    select(...)
... };

void select(@Nullable ViewHolder selected, int actionState) { ...
    swipeIfNecessary(...)
... }

private int swipeIfNecessary(ViewHolder viewHolder) {
    checkHorizontalSwipe(...)
    checkVerticalSwipe(...)
}

// flags: 方向
private int checkHorizontalSwipe(ViewHolder viewHolder, int flags) { ...
    mCallback.getSwipeVelocityThreshold(...) // 速度临界点
    mCallback.getSwipeEscapeVelocity(...) // 最小速度
    final float threshold = mRecyclerView.getWidth() * 
    mCallback.getSwipeThreshold(viewHolder); // 位置临界点，默认0.5
... }
```

主要关注`swipe`过程，以及松手之后。

```kotlin
// 以水平滑动为例：
// 如果是默认行为： dx == holder.translationX
val oldDX // 开始滑动时的位置，也就是上次停止的位置。 abs(oldDX) == 0 || abs(oldDX) == holder.width

// 正在滑动时
val diffX: Int // 手指滑动偏移量
dX = oldDX + diffX

// 松开时：
val isSwiped = 是否超过了速度临界点或者位置临界点
if(true) {
    // 如果超过，dx 最终值根据oldDX和滑动方向确定。 
    // 最终值 = 如果之前为未滑动状态，则划出屏幕。如果之前未划出屏幕，则置为未滑动
    // 值变化靠动画补全
    dx = anim(curDX -> (abs(oldDX) == 0 ? holder.width : 0) * (direction == LEFT ? -1 : 1))
} else {
    // 如果未超过，dx开始还原回初始值
    dx = anim(curDX -> oldDX)
}
```

松手后会根据是否超过临界值，而选择最终位置。

#### demo: 添加震动, 半透明效果, 自定义绘制等

```kotlin
override fun onChildDraw(
    c: Canvas,
    recyclerView: RecyclerView,
    viewHolder: RecyclerView.ViewHolder,
    dX: Float,
    dY: Float,
    actionState: Int,
    isCurrentlyActive: Boolean
) {
    val midWidth = c.width / 2
    val absCurrentX = abs(viewHolder.itemView.translationX)

    // 震动
    if (absCurrentX < midWidth && abs(dX) >= midWidth) {
        val vibrator = requireContext().getSystemService(Vibrator::class.java) as Vibrator
        if (vibrator.hasVibrator()) {
            vibrator.vibrate(VibrationEffect.createOneShot(50, 255))
        }
    }

    // 半透明
    viewHolder.itemView.alpha = if (absCurrentX >= midWidth) 0.5f else 1f

    // 背景
    if (dX != 0f) {
        c.drawRect(
            0f,
            viewHolder.itemView.top.toFloat(),
            c.width.toFloat(),
            viewHolder.itemView.bottom.toFloat(),
            Paint().apply { color = Color.RED },
        )
    }

    super.onChildDraw(c, recyclerView, viewHolder, dX, dY, actionState, isCurrentlyActive)
}
```

#### 二次滑动，展示侧滑菜单

最难控的就是`dX, dY`的变化。可以把`getSwipeVelocityThreshold` 速度临界点禁掉，只靠位置推算是否滑动成功。同时还要判断失去焦点时还原。

虽然能写出来，但是并不稳定。如果真有需求，不如自己实现`ItemTouchHelper`，大部分代码不用动，修改滑动判定，和松手后anim动画设置即可。

## ConcatAdapter

`Adapter` 拼接。

需要引入`recyclerview`库

```kotlin
implementation("androidx.recyclerview:recyclerview:latest")
```

```java
public ConcatAdapter(@NonNull Adapter<? extends ViewHolder>... adapters)

public ConcatAdapter(@NonNull List<? extends Adapter<? extends ViewHolder>> adapters)

@SafeVarargs
public ConcatAdapter(
        @NonNull Config config,
        @NonNull Adapter<? extends ViewHolder>... adapters)

public ConcatAdapter(
        @NonNull Config config,
        @NonNull List<? extends Adapter<? extends ViewHolder>> adapters)
```

# ~λ：

2.25 开始写，现在 3.4 了。虽然内容多，中间也断断续续，但写总结仍然很耗时。 单纯看这些源码，写demo，也就花一下午，但整理要花这么久。

没有需求一阵子了。公司客户端开发需求并不多。而且本来也是我的个人爱好，当初只是人手不够暂时支援，结果越走越远，快要回不去后端了。

现在没有需求，打算回后端，从工作以来，写客户端（kotlin, flutter）的时间比后端还多。顶多LeetCode刷题用一下语言(`kotlin, scala, c++, rust`)，平时自己玩一下`Linux`，但真正的开发，没怎么正经写过。

所以，就算换工作，也只能投递客户端，投后端基本没戏。
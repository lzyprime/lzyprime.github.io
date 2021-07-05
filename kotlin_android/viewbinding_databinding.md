---
title: android ViewBinding, DataBinding
updated: 2021.04.23
date: 2021.04.23
---

## [kotlin & android 笔记](https://lzyprime.github.io/kotlin_android/kotlin_android)

---

## λ：

```bash
# ViewBinding DataBinding
# 仓库地址: https://github.com/lzyprime/android_demos
# branch: viewBinding

git clone -b viewBinding https://github.com/lzyprime/android_demos
```

最近几个月忙于写需求，积累了太多要总结的东西。当然也正是这几个月的大量实践，对一些知识有了新的认识和发现。

`ViewBinding` `DataBinding` 通过 `xml` 声明，生成对应代码，刨开生成的源码看一下，大概就能明白原理。

有用的可能就是 `val binding by viewBinding<T>()` 的两个拓展函数实现。其余就是如官网文档一样的备忘录内容，方便知识点查找。

## ViewBinding

> [ViewBinding 官网](https://developer.android.google.cn/topic/libraries/view-binding)

### 生成的源码

ViewBinding 库代替之前的`kotlin-android-extensions`, 根据布局文件 `layout/example.xml` 生成对应的`[ExampleBinding]`.

以`[FragmentDetailBinding]`为例, 看一下生成的源码。

```java
public final class FragmentDetailBinding implements ViewBinding {
  @NonNull
  private final FrameLayout rootView;

  @NonNull
  public final ImageView imageView;

  private FragmentDetailBinding(@NonNull FrameLayout rootView, @NonNull ImageView imageView) {
    this.rootView = rootView;
    this.imageView = imageView;
  }

  @Override
  @NonNull
  public FrameLayout getRoot() {
    return rootView;
  }

  @NonNull
  public static FragmentDetailBinding inflate(@NonNull LayoutInflater inflater) {
    return inflate(inflater, null, false);
  }

  @NonNull
  public static FragmentDetailBinding inflate(@NonNull LayoutInflater inflater,
      @Nullable ViewGroup parent, boolean attachToParent) {
    View root = inflater.inflate(R.layout.fragment_detail, parent, false);
    if (attachToParent) {
      parent.addView(root);
    }
    return bind(root);
  }

  @NonNull
  public static FragmentDetailBinding bind(@NonNull View rootView) {
    // The body of this method is generated in a way you would not otherwise write.
    // This is done to optimize the compiled bytecode for size and performance.
    int id;
    missingId: {
      id = R.id.imageView;
      ImageView imageView = rootView.findViewById(id);
      if (imageView == null) {
        break missingId;
      }

      return new FragmentDetailBinding((FrameLayout) rootView, imageView);
    }
    String missingId = rootView.getResources().getResourceName(id);
    throw new NullPointerException("Missing required view with ID: ".concat(missingId));
  }
}

```

基类`[ViewBinding]`是`interface`, 只有一个`getRoot`方法，返回显示的`View`

``` java
/** A type which binds the views in a layout XML to fields. */
public interface ViewBinding {
    /**
     * Returns the outermost {@link View} in the associated layout file. If this binding is for a
     * {@code <merge>} layout, this will return the first view inside of the merge tag.
     */
    @NonNull
    View getRoot();
}
```

每份生成的代码:

- 根据`layout/fragment_detail.xml`下划线名称生成对应驼峰类名`FragmentDetailBinding`
- 根据布局文件中组件`id`, 生成对应驼峰式成员名，类型为组件类型. 如`imageView: ImageView`
- 根部局生成为`rootView`

构造函数私有，需要的参数为上述根据`id`生成的成员.

```java
private FragmentDetailBinding(@NonNull FrameLayout rootView, @NonNull ImageView imageView)
```

同时生成3个静态函数作为`工厂构造`

- 两个`inflate`用传入的 `[inflater: LayoutInflater]` 获得对应的`View`. 
- 调用`bind`，通过`findViewById`获得各个组件, 然后通过私有构造得到`[FragmentDetailBinding]`

也就是说, `findViewById` 的过程靠生成代码解决，所以在拿到一个`ViewBinding`实例时, 可以通过成员直接访问。

`kotlin 伪代码大概写一下工厂构造的调用关系`

```kotlin

fun inflate(inflater: LayoutInflater): FragmentDetailBinding = inflate(inflater, null, false)

fun inflate(inflater: LayoutInflater, 
            parent: ViewGroup, 
            attachToParent: Boolean,
        ): FragmentDetailBinding {
            ...
            val root: View = inflater.inflate(...)
            ...
            return bind(root)
        }

fun bind(rootView: View): FragmentDetailBinding {
    // findViewById
    val imageView = rootView.findViewById(R.id.imageView)

    return FragmentDetailBinding(rootView, imageView)
}
```

### 使用

- 当前没有View, 需要新建

```kotlin
// 官网例子：
// Activity
class ResultProfileActivity : AppCompatActivity(){
    private lateinit var binding: ResultProfileBinding

    override fun onCreate(savedInstanceState: Bundle) {
        super.onCreate(savedInstanceState)
        // 通过 inflate 新建
        binding = ResultProfileBinding.inflate(layoutInflater)
        val view = binding.root
        setContentView(view)
    }
}

// Fragment
class ResultProfileFragment : Fragment() {
    private var _binding: ResultProfileBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        _binding = ResultProfileBinding.inflate(inflater, container, false)
        val view = binding.root
        return view
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
```

- 已有视图，直接通过`bind`获得

```kotlin
// Fragment 构造直接传 R.layout.fragment_detail
class DetailFragment : Fragment(R.layout.fragment_detail) {
    private var _binding: FragmentDetailBinding? = null
    private val binding get() = _binding!!
    
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // 此时R.layout.fragment_detail对应View已存在，直接 bind
        _binding = FragmentDetailBinding.bind(view)
        ...
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
```

同理其他地方，没有视图调用`inflate`构造，有视图调用`bind`直接获得.

### Activity, Fragment 使用优化

存在的问题: 

- 过程重复。 每个`Activity`和`Fragment`中，流程相同，仅仅是具体`[ViewBinding]`的区别。
- `Fragment`中, `onDestroyView`时要将`_binding`置空，对于`binding`的操作时机靠自己保证，时序自己保证。
- `lateinit var` 在代码扫描中视为风险行为，不建议使用(个人项目随意)。

仿照

```kotlin 
val model: VM by viewModels<VM>()
``` 

通过`拓展函数, 委托, 反射`, 实现类似

```kotlin
val binding: FragmentDetailBinding by viewBinding<FragmentDetailBinding>()
```


```kotlin
/**
 * 用于[Activity]生成对应[ViewBinding].
 *
 * @exception ClassCastException 当 [VB] 无法通过
 * `VB.inflate(LayoutInflater.from(this#Activity))` 构造成功时抛出
 * */
@MainThread
inline fun <reified VB : ViewBinding> Activity.viewBinding() = object : Lazy<VB> {
    private var cached: VB? = null
    override val value: VB
        get() =
            cached ?: VB::class.java.getMethod(
                "inflate",
                LayoutInflater::class.java,
            ).invoke(null, layoutInflater).let {
                if (it is VB) {
                    cached = it
                    it
                } else {
                    throw ClassCastException()
                }
            }

    override fun isInitialized(): Boolean = cached != null
}

// example
class MainActivity : AppCompatActivity() {
    private val binding by viewBinding<ActivityMainBinding>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 确保调用该函数设置binding.root
        setContentView(binding.root)
    }
}
```

`Activity`内联拓展函数，通过调用`inflate(inflater: LayoutInflater)`版本生成`binding`。需要自己确保在`onCreate`之后使用，否则拿不到`Activity.layoutInflater`, 构造失败

```kotlin
/**
 * 用于 [Fragment] 内构造对应 [ViewBinding].
 *
 *  @exception ClassCastException 当 [VB] 无法通过 `VB.bind(view)` 构造成功时抛出
 *
 * 函数会自动注册[Fragment.onDestroyView]时的注销操作.
 * */
@MainThread
inline fun <reified VB : ViewBinding> Fragment.viewBinding() = object : Lazy<VB> {
    private var cached: VB? = null

    override val value: VB
        get() = cached ?: VB::class.java.getMethod(
            "bind",
            View::class.java,
        ).invoke(VB::class.java, this@viewBinding.requireView()).let {
            if (it is VB) {
                // 监听Destroy事件
                viewLifecycleOwner.lifecycle.addObserver(object : LifecycleObserver {
                    @OnLifecycleEvent(Lifecycle.Event.ON_DESTROY)
                    fun onDestroyView() {
                        cached = null
                    }
                })
                cached = it
                it
            } else {
                throw ClassCastException()
            }
        }

    override fun isInitialized(): Boolean = cached != null
}

// example
class ExampleFragment:Fragment(R.layout.example_fragment) {
    private val binding by viewBinding<ExampleFragmentBinding>()
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        // 确保在此之后使用binding
        binding.xxxTextView.text = "sssss"
    }
}
```

`Fragment`内联拓展函数，通过调用`bind(rootView: View)`版本生成`binding`。

前提是调用`Fragment(@LayoutRes)`版本构造, 利用`Fragment`默认的`onCreateView`行为得到`View`。因此要在`onViewCreated`后使用`binding`。否则`Fragment.requireView()`拿不到view, `bind`失败。

通过`viewLifecycleOwner.lifecycle`监听`Destroy`行为，将`cached`赋为`null`, 当重新构建`View`时，`binding`的`isInitialized() == false`, 认为没有初始化，重新走`value get()`中的逻辑，达到重新绑定的效果。

--- 

总结：原有问题仍有一部分未解决(如: 自己保证执行时序), 但一定程度上减少了重复代码，尤其是`Fragment`中。

## DataBinding

> [DataBinding 官网](https://developer.android.google.cn/topic/libraries/data-binding)

`DataBinding`相当于`ViewBinding++`

在`xml`中传递和使用数据

```xml
<?xml version="1.0" encoding="utf-8"?>
    <!-- layout作为根 -->
    <layout xmlns:android="http://schemas.android.com/apk/res/android">
        <!-- 数据 -->
       <data>
           <variable name="user" type="com.example.User"/>
       </data>
        <!-- 布局 -->
       <LinearLayout
           android:orientation="vertical"
           android:layout_width="match_parent"
           android:layout_height="match_parent">
           <TextView android:layout_width="wrap_content"
               android:layout_height="wrap_content"
               android:text="@{user.firstName}"/> <!-- 使用数据 -->
           <TextView android:layout_width="wrap_content"
               android:layout_height="wrap_content"
               android:text="@{user.lastName}"/> <!-- 使用数据 -->
       </LinearLayout>
    </layout>
```

```kotlin
// data class User(val firstName: String, val lastName: String)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val binding: ActivityMainBinding = DataBindingUtil.setContentView(
                this, R.layout.activity_main)

        binding.user = User("Test", "User")
    }
```

基类`[ViewDataBinding]`

```java
public abstract class ViewDataBinding extends BaseObservable implements ViewBinding
```

- 实现了`[ViewBinding]`, 生成的代码中`inflate, bind`函数签名相同，内部实现略有不同，所以上边`by viewBinding<T>()`仍然适用。

- 同时继承`[BaseObservable]`, 使得本身成为`[Observable]`, 可观察者

除了像`ViewBinding`中构造方式, 还可以使用`DataBindingUtil`：

```kotlin
// Activity, 等价于 inflate + setContentView 
val binding = DataBindingUtil.setContentView(this, R.layout.activity_main)

// or
val binding = DataBindingUtil.inflate(layoutInflater, R.layout.list_item, viewGroup, false)
```

### 绑定表达式

#### `<data>` 中

```xml
<data>
    <!-- 声明 -->
    <variable name="user" type="com.example.User"/>
    <!-- 导入 -->
    <import type="android.view.View"/>
    <!-- 类型别名 -->
    <import type="com.example.real.estate.View" alias="Vista"/>

    <!-- 集合 -->
    <import type="android.util.SparseArray"/>
    <import type="java.util.Map"/>
    <import type="java.util.List"/>
    <variable name="list" type="List&lt;String>"/>
    <variable name="sparse" type="SparseArray&lt;String>"/>
    <variable name="map" type="Map&lt;String, String>"/>
    <variable name="index" type="int"/>
    <variable name="key" type="String"/>
    <!-- 在布局中使用
        android:text="@{list[index]}"
        android:text="@{sparse[index]}"
        android:text="@{map[key]}" 
    -->
</data>
```

#### 布局中，表达式

- 算术运算符 `+ - / * %`
- 字符串连接运算符 `+`
- 逻辑运算符 `&& ||`
- 二元运算符 `& | ^`
- 一元运算符 `+ - ! ~`
- 移位运算符 `>> >>> <<`
- 比较运算符 `== > < >= <=`
- `instanceof`
- 分组运算符 `()`
- 字面量运算符 - 字符、字符串、数字、null
- 类型转换
- 方法调用
- 字段访问
- 数组访问 `[]`
- 三元运算符 `?:`


```xml
<!-- 当链式调用中存在可空类型时, 如： -->
<TextView android:text="@{a.b.c.d.e}"/>
<!-- 相当于 -->
<TextView android:text="@{a?.b?.c?.d?.e}"/>
<!-- 其中有一环为空, 则表达式值为null -->
```

```xml
<TextView android:text="@{expr ?? defautValue}"/>
<!-- 相当于 -->
<TextView android:text="@{expr != null ? expr : defautValue}"/>
```

```xml
<!-- 资源引用 -->
android:padding="@{large ? @dimen/largePadding : @dimen/smallPadding}"
android:text="@{@string/nameFormat(firstName, lastName)}"
...
```

```xml
<!-- function -->
<data>
    <variable name="task" type="com.android.example.Task" />
    <variable name="presenter" type="com.android.example.Presenter" />
</data>
<LinearLayout android:onClick="@{() -> presenter.onSaveClick(task)}" />
...
</LinearLayout>


<!--
class Presenter {
    fun onSaveClick(view: View, task: Task){}
}
-->
android:onClick="@{(theView) -> presenter.onSaveClick(theView, task)}"

<!--
class Presenter {
    fun onCompletedChanged(task: Task, completed: Boolean){}
}
-->
android:onCheckedChanged="@{(cb, isChecked) -> presenter.completeChanged(task, isChecked)}"

<!-- ?: -->
android:onClick="@{(v) -> v.isVisible() ? doSomething() : void}"
```

### 适配器

现有的 `资源引用表达式` 满足大多数情况，但也有例外，常见为`ImageView`中。所以用适配器指定处理方法

- `@BindingMethods`

```kotlin
// 将 android:tint 交由 setImageTintList(ColorStateList) 处理, 而非原有 setTint()
@BindingMethods(value = [
    BindingMethod(
        type = android.widget.ImageView::class,
        attribute = "android:tint",
        method = "setImageTintList")])
```

- `@BindingAdapter`

```kotlin
@BindingAdapter(value = ["imageUrl", "placeholder"], requireAll = false)
fun setImageUrl(imageView: ImageView, url: String?, placeHolder: Drawable?) {
    if (url == null) {
        imageView.setImageDrawable(placeholder);
    } else {
        MyImageLoader.loadInto(imageView, url, placeholder);
    }
}

//xml
<ImageView app:imageUrl="@{venue.imageUrl}" app:error="@{@drawable/venueError}" />
```

- `@BindingConversion`, 自定义转换

```kotlin
@BindingConversion
fun convertColorToDrawable(color: Int) = ColorDrawable(color)

//xml
<View android:background="@{isError ? @drawable/error : @color/white}" .../>
```

- `@TargetApi`, 监听器有多个方法时，需要拆分处理

```kotlin
// View.OnAttachStateChangeListener 为例
// 有两个方法：onViewAttachedToWindow(View) 和 onViewDetachedFromWindow(View)

// 1. 拆分

@TargetApi(Build.VERSION_CODES.HONEYCOMB_MR1)
interface OnViewDetachedFromWindow {
    fun onViewDetachedFromWindow(v: View)
}

@TargetApi(Build.VERSION_CODES.HONEYCOMB_MR1)
interface OnViewAttachedToWindow {
    fun onViewAttachedToWindow(v: View)
}

// 2. BindAdapter

@BindingAdapter(
        "android:onViewDetachedFromWindow",
        "android:onViewAttachedToWindow",
        requireAll = false
)
fun setListener(view: View, detach: OnViewDetachedFromWindow?, attach:OnViewAttachedToWindow?) {
   ...
}

// 3. xml中使用
```

### `Observable`, `LiveData`作为数据

数据更新时，UI自动刷新

- `ObservableBoolean`
- `ObservableByte`
- `ObservableChar`
- `ObservableShort`
- `ObservableInt`
- `ObservableLong`
- `ObservableFloat`
- `ObservableDouble`
- `ObservableParcelable`
- `ObservableArrayList`
- `ObservableArrayMap`

```kotlin
// 自定义
class User : BaseObservable() {
    @get:Bindable // 给getter方法打标签, BR中会生成对应条目
    var firstName: String = ""
        set(value) {
            field = value
            notifyPropertyChanged(BR.firstName) // 刷新UI
        }
    @get:Bindable
    var lastName: String = ""
        set(value) {
            field = value
            notifyPropertyChanged(BR.lastName) // 刷新UI
        }
}
```

或者用 `LiveData`, 在代码中需要调用`setLifecycleOwner()`

```xml
<!-- data class User(val firstName: LiveData<String>, val lastName: LiveData<String>) -->
<!-- xml中 -->
<data>
    <variable name="duration" type="LiveData<String>"/>
    <variable name="user" type="com.example.User"/>
</data>

<TextView android:text="@{user.firstName}"/>
<TextView android:text="@{duration}"/>
```

```kotlin
// kotlin
class ExampleFragment : Fragment(R.layout.example_fragment) {
    ...
    binding.duration = liveData<String> { emitSource(...) }
    binding.user = model.user
    binding.setLifecycleOwner(viewLifecycleOwner)
    ...
}
```

结合两者使用：

```kotlin
open class ObservableViewModel : ViewModel(), Observable {
    private val callbacks: PropertyChangeRegistry = PropertyChangeRegistry()
    
    // 添加订阅
    override fun addOnPropertyChangedCallback(
            callback: Observable.OnPropertyChangedCallback) {
        callbacks.add(callback)
    }

    // 取消订阅
    override fun removeOnPropertyChangedCallback(
            callback: Observable.OnPropertyChangedCallback) {
        callbacks.remove(callback)
    }

    // 全量刷新
    fun notifyChange() {
        callbacks.notifyCallbacks(this, 0, null)
    }
    
    // 精确刷新
    fun notifyPropertyChanged(fieldId: Int) {
        callbacks.notifyCallbacks(this, fieldId, null)
    }
}
```

### 数据双向绑定 `@={}`

```xml
<CheckBox
    android:id="@+id/rememberMeCheckBox"
    android:checked="@={viewmodel.rememberMe}"
/>
```

```kotlin
class LoginViewModel : BaseObservable {
    // val data = ...

    @Bindable
    fun getRememberMe(): Boolean = data.rememberMe

    fun setRememberMe(value: Boolean) {
        if (data.rememberMe != value) {
            data.rememberMe = value

            // React to the change.
            saveData()

            notifyPropertyChanged(BR.remember_me)
        }
    }
}
```

使用`@InverseBindingAdapter`和`@InverseBindingMethod`, 自定义双向绑定

```kotlin
// 1. 数据变动时调用的方法
@BindingAdapter("time")
@JvmStatic fun setTime(view: MyView, newValue: Time) {
    // Important to break potential infinite loops.
    if (view.time != newValue) {
        view.time = newValue
    }
}

// 2. view变动时调用的方法
@InverseBindingAdapter("time")
@JvmStatic fun getTime(view: MyView) : Time {
    return view.getTime()
}

// 3. 变动时机和方式, 后缀`AttrChanged`
@BindingAdapter("app:timeAttrChanged")
@JvmStatic fun setListeners(
        view: MyView,
        attrChange: InverseBindingListener
) {
    // 使用 InverseBindingListener 告知数据绑定系统，特性已更改
    // 数据绑定系统调用@InverseBindingAdapter绑定的方法

    // warning: 避免陷入循环刷新.
}
```

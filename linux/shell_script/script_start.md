---
title: shell 脚本
date: 2022.03.30
updated: 2022.07.15
---

# λ：

# 限定范围

```bash
#!/bin/bash
set -euf # 开启选项
# set -x -o pipefail 

# set +euf # 关闭选项
...
```

大部分教程到这就开始写脚本逻辑部分了，但是第二行`set -euf`可能比第一行还有用，而且第一行也不是非写不可，`bash <script_name>.sh` 也可以跑。

- `#!` 声明脚本文件的解释器
  - 常用解释器是`sh(bash, zsh)`, 除此之外之外还有`csh(tcsh)`, `ash`, `ksh` 等等，是有语法差异的，而且就算是`sh, bash, zsh`也不是完全的子集和包含关系。所以一定要确定好解释器和环境
  - `cat /etc/shells` 查看支持的解释器
  - 现在好多linux发行版`/bin/sh`只是`/bin/bash`软链接，执行时相当于`bash --posix`。（`MacOS`还是实际程序，并非软链，不知道是不是`UNIX，BSD`都这样）
- `# 注释内容` 注释
- `set`, `-` 开启选项， `+`关闭选项
  - `-e (-o errexit)` 若指令传回值不等于0，则立即退出shell
  - `-u (-o nounset)` 当执行时使用到未定义过的变量，则显示错误信息。
  - `-f (-o noglob)` Disable pathname expansion. 路径名禁止使用通配符
  - `-x (-o xtrace)` 打印正在执行的语句
  - `-o pipefail` 管道连接的命令(`cmd1|cmd2|cmd3`)，会有subshell问题，后边命令不受 `-e` 影响, 也就是说其中有命令失败时，结果仍会传递给下一条命令。
- `bash -euf <script_name>.sh` 也可以开启选项
- `echo $-` 查看当前开启的选项

> - `set` 是`bash`的内建命令，可以 `help set` 查看具体用法
> - `man builtin` 了解内建命令
> - 如果使用未定义的变量，值会是 `""` 空串，这在路径拼接时尤为危险：`rm -rf $WORKSPACE/`, 如果 `WORKSPACE` 是个未定义变量，这条语句直接变成`rm -rf /`



# 命令 & 组合命令

```bash
man bash
# 打开手册后搜索 SHELL GRAMMAR，
/SHELL GRAMMAR
```

## 简单命令 `Simple Commands`

> A  simple  command  is  a sequence of optional variable assignments followed by blank-separated words and redirections, and terminated by a control operator.
>
> 简单命令是一个由若干`可选变量`组成的序列，参数之间`空格`或者`重定向符`连接，并且由`控制操作符`终止
>
> 控制操作符：`|| & && ; ;; ( ) | <newline>`

- `echo "hello world" > file1.txt`
- 第一个变量`echo`为要执行的命令，同时会被作为参数0传递。
- `"hello world", file1.txt` 为命令参数，`>` 重定向符
- 返回值是它的退出状态，0为成功(true)。如果命令被信号 n 终止，则返回 128+n

## 管道 `Pipelines`

> A pipeline is a sequence of one or more commands separated by the character |. 
>
> `[time [-p]] [ ! ] command [ | command2 ... ]`

管道是一个或多个命令的组成的序列，由字符 | 分隔。 方括号中为可选参数，所以 ***一条命令也算作是个管道***

- 前一个命令的标准输出会做为下一个命令的标准输入
- 会产生`subshell`，每条指令都会在新的子shell中执行。
- 返回值为最后一条命令执行的结果。 如果设置了`pipefail`选项，则其中一条命令失败时直接结束并返回结果。

```bash
# example
cat /etc/shells | grep /bin
```

## 命令列表 `Lists`

> A list is a sequence of one or more pipelines separated by one of the operators ;, &, &&, or ||, and optionally terminated by one of ;, &, or \<newline\>.

简单讲就是一串管道(命令)。 

- `&&,||`优先级相同。若以此符号结尾，后边必须要有另一条命令。
  - `pipe1 || pipe2 && pipe3`, 和其他语言类似，会有截断效果：若cmd1成功则之后cmd2 && cmd3不执行，如果cmd2失败，cmd3不执行。
- `;,&` 优先级相同。次于 `&&, ||`
  - `pipe; pipe2; pipe3;`, 以`;`结尾的命令，命令依次执行，整条List的返回值为最后一条命令的值。
  - `cmd1& cmd2& cmd3&`, 以`&`结尾的命令，会产生`subshell`, 也就是新起一个子shell执行该命令，并且当前shell不会等待子shell执行完毕，直接返回0。
- `<换行符>`，最常见的结尾。

## 复合命令 `Compound Commands`

### 各种括号

- `(list)`, 会产生`subshell`, list在subshell中执行。
- `{ list; }`，组命令。list在当前shell执行，返回值为list的返回值。
  - list中的每条命令必须以`;`或者换行符结尾。
  - `list;` 与 `{ }` 之间必须空格分割。
  - `{ }` 是两个保留字，所以整条语句在能识别保留字的区域内才有效。
- `((expression))`, `expression：算数表达式`，参考[表达式求值](./expression.md)。
  - 等同于 `let expression`
- `[[ expression ]]`，`expression：条件表达式`， 参考[表达式求值](./expression.md)。
  - `[[ ]]` 是两个保留字，所以整条语句在能识别保留字的区域内才有效。
  - `expression` 与 `[[ ]]` 要以空格分割。

### for

- `for name [ [ in [ word ... ] ] ; ] do list ; done`


-----------


## 变量

- `变量名=值`, 等号两边不加空格，否则 `变量名` 会当成指令，`=` 和 `值` 是参数。 
- `${变量名}` 或 `$变量名` 取值, `${}`为了截断变量名和上下文，如 `${str1}2`, 没有花括号变量名会识别为`str12`

```bash
str1="string1"

echo "str1: $str1"
echo "str2: ${str1}2"
```

## 数组

shell 数组更像 `map<int, T>`

```shell
# 数组, 数组名=("val1" "val2" "val3")
empty_arr=() # 空数组
arr=("val1" "val2" "val3  3  3")

# 使用：
${arr[50]} # 取值，如果不存在就是空字符串
arr[100]="new val" # 赋值
${#arr[@]} # 当前元素个数
```

## 引号，转义字符

shell 操作基本都是在做字符串处理。环境变量里`IFS(Internal Field Seprator)`为当前分隔符的值。打印一下默认值：

```bash
# 由于全是转义字符，用 od 命令处理一下，否则看不到

echo $IFS | od -c

# output:
# 0000000      \t  \n  \0  \n
# 0000005

echo $IFS | od -a

# output:
# 0000000  sp  ht  nl nul  nl
# 0000005
```

所以如果字符串中空格，tab，换行等，会被识别成两个字符串。


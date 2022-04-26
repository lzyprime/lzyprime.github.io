---
title: shell 脚本
date: 2022.03.30
updated: 2022.03.30
---

# λ：

# 限定环境 & 脚本安全

```shell
#!/bin/bash
set -euf

...
```

`#!` 告诉系统其后路径所指定的程序即是解释此脚本文件的 Shell 程序

# 变量&运算

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


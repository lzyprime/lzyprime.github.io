---
title: 表达式求值
date: 2022.03.30
updated: 2022.03.30
---

# 表达式

- `( expression )`
  - 返回表达式的值。
  - 改变运算优先级: `expr1 && (expr2 || expr3)`
- `! expression`
- `expression1 && expression2`, expression1 == false, expression2不执行
- `expression1 || expression2`, expression1 == true, expression2不执行

# 条件表达式: `CONDITIONAL EXPRESSIONS`

使用 `[[ 复合命令, test, [ 内置命令` 来测试文件属性, 执行字符串和算术比较。 

- `test, [` 命令根据参数的数量确定它们的行为。
- 表达式中使用文件：如果系统提供特殊文件则直接使用。否则，如果其中一个主文件的任何文件参数的格式为 /dev/fd/n，则检查文件描述符n。如果主文件之一的文件参数是 /dev/stdin、/dev/stdout、 /dev/stderr 分别检查文件描述符 0、1、2。除非另有说明，否则主文件为符号链接时，在链接的目标上操作，而不是链接本身。

> - 当与 [[ 一起使用时，< 和 > 运算符使用当前语言环境按字典顺序排序。

表达式由以下一元或二元基元组成:

| expression file | 为真 | true if |
|:-:|:-:|:-:|
| -t fd   | 文件描述符 fd 已打开并指向终端 | True if file descriptor fd is open and refers to a terminal. |
| -a file | 文件存在 | True if file exists. |
| -e file | 文件存在 | True if file exists and is a block special file. |
| -b file | 块特殊文件 | True if file exists and is a character special file. |
| -c file | 字符特殊文件 | True if file exists and is a directory. |
| -d file | 目录类型 | True if file exists. |
| -f file | 常规文件 | True if file exists and is a regular file. |
| -g file | set-group-id. | True if file exists and is set-group-id. |
| -h file | 符号链接 | True if file exists and is a symbolic link. |
| -L file | 符号链接 | True if file exists and is a symbolic link. |
| -k file | 设置了 `sticky` 位 | True if file exists and its `sticky` bit is set. |
| -p file | 命名管道（FIFO） | True if file exists and is a named pipe (FIFO). |
| -r file | 可读 | True if file exists and is readable. |
| -w file | 可写 | True if file exists and is writable. |
| -x file | 可执行 | True if file exists and is executable. |
| -s file | 大小 > 0 | True if file exists and has a size greater than zero. |
| -u file | `set-user-id` 位被设置 | True if file exists and its set-user-id bit is set. |
| -G file | 由有效ground_id拥有 | True if file exists and is owned by the effective group id. |
| -O file | 由有效user_id拥有 | True if file exists and is owned by the effective user id. |
| -N file | 自上次阅读以来已被修改 | True if file exists and has been modified since it was last read. |
| -S file | socket | True if file exists and is a socket. |
|file1 -ef file2 | file1 和 file2 引用自相同的设备和 inode 号 | True if file1 and file2 refer to the same device and inode numbers. |
|file1 -nt file2 | file1 比 file2 新（根据修改日期），或者 file1 存在而 file2 不存在 | True if file1 is newer (according to modification date) than file2, or if file1 exists and file2 does not. |
|file1 -ot file2 | file1 比 file2 旧，或者 file2 存在而 file1 不存在 | True if file1 is older than file2, or if file2 exists and file1 does not. |

| expression shell_env | 为真 | true if |
|:-:|:-:|:-:|
|-o optname | shell 选项 optname 已启用 | True if the shell option optname is enabled. |
|-v varname | shell 变量 varname 已设置（已被赋值） | True if the shell variable varname is set (has been assigned a value). |
|-R varname | shell 变量 varname 已设置并且是名称引用 | True if the shell variable varname is set and is a name reference. |

| expression string | 为真 | true if |
|:-:|:-:|:-:|
|-z string | 字符串长度 == 0 | True if the length of string is zero. |
| string | 字符串长度 != 0 | True if the length of string is non-zero. |
| -n string | 字符串长度 != 0 | True if the length of string is non-zero. |
|string1 = string2 | | True if the strings are equal. |
|string1 == string2 | `[[` 下支持，如果启用shell的`nocasematch`，忽略大小写 | True if the strings are equal. |
| string1 != string2 | `[[`下如果启用shell的`nocasematch`，忽略大小写 | True if the strings are not equal. |
| string1 < string2 | `[[`时使用当前语言环境按字典顺序, 否则ASCII字典序比较 | True if string1 sorts before string2 lexicographically. |
| string1 > string2 | `[[`时使用当前语言环境按字典顺序, 否则ASCII字典序比较  | True if string1 sorts after string2 lexicographically. |
| =~ | `[[` 下支持，正则匹配| |

- `=~`, 正则匹配，右侧为模式串。如果模式串语法错误，指令退出状态为2。
  - ***右侧模式串为正则表达式时，不能加引号，否则会作为字符串进行比较***
  - 并非所有解释器都支持该语法，比如`zsh`便不支持。

```bash
# 正则模式串不能加引号, 否则会作为字符串进行比较

[[ example.com =~ ^.*.com$ ]] && echo true || echo false # true
[[ example.com =~ "^.*.com$" ]] && echo true || echo false # false
[[ ^.*.com$ =~ "^.*.com$" ]] && echo true || echo false # true
```

| arg1 OP arg2 | as |
|:-:|:-:|
|-eq| == |
|-ne| != |
|-lt| < |
|-le| <= |
|-gt| > |
|-ge| >= |

- arg1, arg2 为整数
- 当在`[[ ]]`中， arg1 和 arg2 会做为 `算术表达式` 求值。


# 算数表达式 `ARITHMETIC EVALUATION`

shell是弱类型，所有的`值`大多数情况都当作是字符串处理的。比如 `a=1;a+=1;echo $a` 结果是 `11` 而不是 `2`。

要想把内容作为数值进行计算，需要用`let, declare, (())`。 

```bash
a=1; let a+=1; echo $a

declare -i a=1; a+=1; echo $a

a=1; ((a+=1)); echo $a
```

`let` 和 `(())`等效。支持的运算类似C语言。按优先级:

- `val++ val--`
- `--val ++val`
- `+val -val`
- `!val ~val`
- `val ** n`, 幂运算
- `* / %`
- `+ -`
- `<< >>`, 位运算
- `<= >= < >`
- `== !=`
- `&`
`^`
- `|`
- `&&`
- `||`
- `expr?expr:expr`
- `= *= /= %= += -= <<= >>= &= ^= |=`
- `expr1 , expr2`, 逗号


## 算数表达式，指令退出状态

- 表达式求值，同c: `!0 == true; 0 == false`
- 表达式作为指令, 退出状态, 根据表达式值确定：`表达式值 == true ? 0 : 1`

```bash
# let expr

a=1
let a-- # 或((a--))
echo $? # 上一条语句退出状态，0(true)

a=1
let --a # 或 ((--a))
echo $? # 1(false)
```

- 首先确定表达式范围：`a--` 和 `--a`
- `a--` 作为数值处理，整条表达式值为1(true)，所以整条`let a--`作为命令处理，执行结果为 true(0)
- 同理 `--a`, 数值表达式为0(false), 整条命令`let --a`结果为false(1)

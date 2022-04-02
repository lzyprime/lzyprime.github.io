#!/bin/bash 
set -euf

[ "$#" = 0 ] || [ "$1" = "" ] && echo "文件路径" && exit
file=$(realpath "$1")

blog_dir=$(dirname "$(dirname "$(realpath "$0")")")

[ "$blog_dir/${file#"$blog_dir/"}" != "$file" ] && echo "非法路径" && exit

[ -f "$file" ] && echo "文件已存在" && exit

tmp_title=$(basename "${file%.md}")
read -p "title(default: $tmp_title): "  title
title="${title:-$tmp_title}"

cat > $file << EEE
---
title: $title
date: $(date "+%Y.%m.%d")
updated: $(date "+%Y.%m.%d")
---

# λ：

EEE
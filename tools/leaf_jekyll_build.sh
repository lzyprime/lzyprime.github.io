#!/bin/bash
set -euf

root_dir="$(dirname $(realpath "$0"))/build_work"

rm -rf "$root_dir"
mkdir -p "$root_dir"

ls --ignore tools "$root_dir/../../" | xargs -I {} cp -r "$root_dir/../../"{} "$root_dir"
cd $root_dir

declare -A post2title
declare -A post2date
# posts
while read i; do
    [ "$(dirname "$i")" = "$root_dir" ] || [ "$(basename $(dirname "$i")).md" = "$(basename "$i")" ] && continue
    header_index=() && while read index; do header_index[${#header_index[@]}]="$index"; done < <(egrep -n "^\-\-\-" "$i" | awk -F":" '{print $1}')
    declare -A header=() && while read key; do eval $(echo $key | awk -F": " '{print "header[\""$1"\"]=\""$2"\""}'); done < <(head -n +${header_index[0]} -n ${header_index[1]} "$i")
    post2title["$i"]=${header[title]}
    post2date["$i"]=${header[updated]:-header[date]}
done < <(find "$root_dir" -type f -name "*.md")

post_list() {
  local relative_path=$1
  local posts="$2"

  echo '<div class="box home-box"> <div class="post-list">'

  while read i; do
    post=$(echo $i | awk -F'|' '{print $1}') 
    echo "<a class=\"post-link\" href=\"$(realpath "$post" --relative-to "$relative_path" | awk -F".md" '{print $1}')\"> <h4>${post2title[$post]}</h4><p>${post2date[$post]}</p></a>";
  done < <(for post in ${posts[@]}; do echo "$post|${post2date["$post"]}"; done | sort -t '|' -k 2 -r)

  echo '</div></div>'
}

tags=()
while read i; do
    [ "$i" = "$root_dir" ] && continue

    posts=() && while read post; do [ "$(basename $(dirname "$post")).md" != "$(basename "$post")" ] && posts[${#posts[@]}]="$post"; done < <(find "$i" -type f -name "*.md")
    [ ${#posts[@]} = 0 ] && continue

    tag=$(realpath "$i" --relative-to "$root_dir")
    tags[${#tags[@]}]="$tag"
    
    toc_file_name="$i/$(basename $i)"

cat > "$toc_file_name.md" << EEE
---
title: $tag
layout: page
---
    
$([ -f "$toc_file_name.temp" ] && cat "$toc_file_name.temp")

### post

$(post_list "$i" "${posts[*]}")
EEE

done < <(find "$root_dir" -type d)

# index.md
cat > "index.md" << EEE
---
layout: home
---

<h2 class="post-list-heading">posts</h2>
$(post_list "$root_dir" "${!post2title[*]}")

EEE

# _config.yml
cat > _config.yml << EEE
remote_theme: lzyprime/jekyll-theme-leaf
title: I'm Prime
description: 十方三世，尽在一念

header_pages: [/$(for i in ${tags[@]}; do printf ", $i/$(basename $i).md"; done)]

defaults:
  -
    scope:
      path: "" # 一个空的字符串代表项目中所有的文件
    values:
      layout: "post"

EEE

# CNAME
cat > CNAME << EEE
lzyprime.top
EEE


# README
cat > README.md << EEE
update at $(date "+%Y.%m.%d %H:%M")
EEE

find "$root_dir" -type f -name "*.temp" | while read i; do rm -f "$i"; done

git init
git add .
git commit -m "update at $(date "+%Y.%m.%d %H:%M")"
git remote add origin "git@github.com:lzyprime/lzyprime.github.io.git"
git push -f origin master:main

echo "https://lzyprime.top"
#!/bin/bash
set -euf

root_dir="$(dirname $(realpath "$0"))/build_work"

rm -rf "$root_dir"
mkdir "$root_dir"

ls --ignore tools "$root_dir/../../" | xargs -I {} cp -r "$root_dir/../../"{} "$root_dir"

cd $root_dir

declare -A post2title
declare -A post2date

while read i; do
    [ "$(dirname "$i")" = "$root_dir" ] || [ "$(basename $(dirname "$i")).md" = "$(basename "$i")" ] && continue
    header_index=() && while read index; do header_index[${#header_index[@]}]="$index"; done < <(egrep -n "^\-\-\-" "$i" | awk -F":" '{print $1}')
    declare -A header=() && while read www; do eval $(echo $www | awk -F": " '{print "header[\""$1"\"]=\""$2"\""}'); done < <(head -n +${header_index[0]} -n ${header_index[1]} "$i")
    post2title["$i"]=${header[title]}
    post2date["$i"]=${header[updated]:-header[date]}
done < <(find "$root_dir" -type f -name "*.md")

tags=()
while read i; do
    [ "$i" = "$root_dir" ] && continue

    posts=() && while read post; do [ "$(basename $(dirname "$post")).md" != "$(basename "$post")" ] && posts[${#posts[@]}]="$post"; done < <(find "$i" -type f -name "*.md")
    [ ${#posts[@]} = 0 ] && continue

    tag=$(realpath "$i" --relative-to "$root_dir")
    tags[${#tags[@]}]="$tag"
    
    toc_file_name="$i/$(basename $i)"

cat > "$toc_file_name.md" << EEE
# <center>$tag</center>
    
$([ -f "$toc_file_name.temp" ] && cat "$toc_file_name.temp")


| | |
|:-|-:|
$(for post in ${posts[@]}; do echo "| [${post2title["$post"]}]($(realpath "$post" --relative-to "$i")) | ${post2date["$post"]} |"; done | sort -t "|" -k 3 -r)
EEE

done < <(find "$root_dir" -type d)

# index.md
cat > "index.md" << EEE
# <center>I'm prime</center>

## tags

### | $(for tag in ${tags[@]}; do printf "***[$tag]($tag/$(basename "$tag").md)*** | "; done)

## Repository

- [android demos](https://lzyprime.top/android_demos)
- [flutter demos](https://lzyprime.top/flutter_demos)

---

| | |
|:-|-:|
$(for post in ${!post2title[@]}; do echo "| [${post2title["$post"]}]($(realpath "$post" --relative-to "$root_dir")) | ${post2date["$post"]} |"; done | sort -t "|" -k 3 -r)

EEE

# _config.yml
cat > _config.yml << EEE
theme: jekyll-theme-hacker
title: I'm Prime
description: 十方三世，尽在一念
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


echo "https://lzyprime.top"
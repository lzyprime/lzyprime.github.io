#!/bin/bash

function dfs() {
	for i in `ls`; do
		if [ -d "$i" ]; then
			cd "$i"
			dfs
			cd ../
		elif [[ "$i" =~ .*.md$ ]]; then 
			filename=$(basename "$i" .md)
			sed -i "" "s#($filename/#(../$filename/#" $i
			echo $filename finish
		fi
	done
}

function update_source() {
	rm -rf ../source/_posts
	mkdir ../source/_posts
	for i in `ls`; do
		if [ -d "$i" ]; then
			cp -r "$i" ../source/_posts
		fi
	done
}

function push() {
	git init
	git add .
	git commit -m "update"
	git remote add origin git@github.com:lzyprime/lzyprime.github.io.git
	git push origin main -f
}

update_source
cd ../source/_posts
dfs
cd ../../
hexo clean
hexo d

read -p "push:[Y/n]" i

if [[ "$i" = "" ]] || [[ "$i" = "Y" ]] || [[ "$i" = "y" ]]; then
	cd public
	push
fi
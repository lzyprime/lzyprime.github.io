#!/bin/bash

cp -r . ../tmp_master
cd ../tmp_master
rm -rf .git update_master.sh
git init
git add .
git commit -m "update`date '+%Y-%m-%d %H:%M'`"
git remote add origin "https://github.com/lzyprime/lzyprime.github.io.git"
git push -f origin master
cd ..
rm -rf tmp_master

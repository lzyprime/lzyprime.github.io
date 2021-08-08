if [[ "$1" = "" ]]; then
    read -p "文件名(默认`date '+%Y%m%d'`)：" new_filename
else
    new_filename="$i"
fi

if [[ "$new_filename" = "" ]]; then 
    new_filename="`date '+%Y%m%d'`"
fi

cat > "$new_filename".md << EEE
---
title: 
date: `date '+%Y.%m.%d'`
updated: `date '+%Y.%m.%d'`
tag: []
category: []
---
EEE
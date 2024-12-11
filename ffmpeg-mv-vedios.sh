#!/bin/bash

# 设置语言环境
export LC_ALL=C
export LANG=C

rootDirectory="/share/CACHEDEV1_DATA/Public/Plex/Mosaics"

# 遍历 rootDirectory 的下一级目录
for dir in "$rootDirectory"/*/; do
  find "$dir" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mkv" \) | while read file; do
    fileName=$(basename "$file")
    bangou=$(basename "$fileName" ".mkv")
    bangou=$(basename "$fileName" ".mp4")
    bangou=$(basename "$fileName" -hack)
    destDir="$dir/$bangou"
    destFile="$destDir/$fileName"

    if [[ -e "$destFile" ]]; then
      rm -f "$destFile" "$destDir/$bangou.mkv" "$destDir/$bangou-hack.mkv"
      mv "$file" "$destFile"
      echo "已移动 $fileName 到 $bangou/$fileName"
    fi
  done
done

#!/bin/bash

# 设置语言环境
export LC_ALL=C
export LANG=C

rootDirectory="/share/CACHEDEV1_DATA/Public/Plex/Mosaics"

# 遍历 rootDirectory 的下一级目录
for dir in "$rootDirectory"/*/; do
  find "$dir" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mkv" \) | while read file; do
    fileName=$(basename "$file")
    fileName=$(basename "$fileName" ".mp4")
    bangou=$(basename "$fileName" "-hack")
    bangou=$(basename "$bangou" "-C")
    bangou=$(basename "$bangou" "-leak")
    bangou=$(basename "$bangou" "-流出")
    destDir="$dir/$bangou"
    destFile="$destDir/$fileName.mp4"

    if [[ -e "$destDir/$fileName.nfo" ]]; then
      rm -f "$destDir/$fileName.mp4" "$destDir/$fileName.mkv"
      mv "$file" "$destFile"
      echo "已移动 $fileName.mp4 到 $bangou/$fileName.mp4"
    fi
  done
done

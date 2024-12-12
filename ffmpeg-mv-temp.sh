#!/bin/bash

# 设置语言环境
export LC_ALL=C
export LANG=C

rootDirectory="/share/CACHEDEV1_DATA/Public/Plex/Mosaics"

process_file() {
  local dir="$1"
  local dirName=$(basename "$dir")
  
  # 遍历目录下的所有文件
  for file in "$dir"/*; do
    # 检查是否为文件（非目录）
    if [[ -f "$file" ]]; then
      local fileName=$(basename "$file")
      local fileExt="${fileName##*.}"
      local fileNameWithoutExt="${fileName%.*}"
      local newFileName=""
      local nfoFileChanged=false

      # 处理图片文件
      if [[ "$fileName" == *"-fanart.jpg" ]]; then
        newFileName="fanart.jpg"
        nfoFileChanged=true
      elif [[ "$fileName" == *"-poster.jpg" ]]; then
        newFileName="poster.jpg"
        nfoFileChanged=true
      elif [[ "$fileName" == *"-thumb.jpg" ]]; then
        newFileName="thumb.jpg"
        nfoFileChanged=true
      fi

      # 处理视频和 NFO 文件
      if [[ "$fileName" == *"-流出.mp4" ]]; then
        newFileName="${dirName}-leak.mp4"
      elif [[ "$fileName" == *"-流出.nfo" ]]; then
        newFileName="${dirName}-leak.nfo"
      elif [[ "$fileName" == *"-无码流出.mp4" ]]; then
        newFileName="${dirName}-leak.mp4"
      elif [[ "$fileName" == *"-无码流出.nfo" ]]; then
        newFileName="${dirName}-leak.nfo"
      elif [[ "$fileName" == *"-C.mp4" ]]; then
        newFileName="${dirName}.mp4"
      elif [[ "$fileName" == *"-C.nfo" ]]; then
        newFileName="${dirName}.nfo"
      fi

      # 如果需要重命名，执行重命名操作
      if [[ -n "$newFileName" ]]; then
        mv "$file" "$dir/$newFileName"
        echo "重命名: $fileName -> $newFileName"
      fi

      # 如果图片文件被修改，则更新对应的 NFO 文件
      if [[ "$nfoFileChanged" == true ]]; then
        local nfoFile="${dir}/${fileNameWithoutExt/-fanart/}.nfo"
        if [[ -f "$nfoFile" ]]; then
          sed -i "s|<poster>.*-poster\.jpg</poster>|<poster>poster.jpg</poster>|g" "$nfoFile"
          sed -i "s|<thumb>.*-thumb\.jpg</thumb>|<thumb>thumb.jpg</thumb>|g" "$nfoFile"
          sed -i "s|<fanart>.*-fanart\.jpg</fanart>|<fanart>fanart.jpg</fanart>|g" "$nfoFile"
          echo "更新 NFO 文件: $nfoFile"
        fi
      fi
    fi
  done
}

# 遍历 rootDirectory 的下一级目录
for dir in "$rootDirectory"/*/; do
  actorDirectory=${dir%/} # 移除尾部的斜杠
  actorName=$(basename "$dir")

  for bangouDir in "$actorDirectory"/*/; do
    bangouDirectory=${bangouDir%/} # 移除尾部的斜杠
    process_file $bangouDirectory   
  done

done

echo "脚本执行完毕" # 调试信息

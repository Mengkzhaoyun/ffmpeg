#!/bin/bash

# 设置语言环境
export LC_ALL=C
export LANG=C

rootDirectory="/share/CACHEDEV1_DATA/Public/Plex/Leak"
stream_height="720" # 720p视频

process_file() {
  local file="$1"
  local dirName="$2"

  # 使用 ffprobe 获取视频信息
  # /share/CACHEDEV1_DATA/Public/Plex/Leak/DV-1349/DV-1349-流出.wmv
  local info=$(ffprobe -v quiet -print_format json -show_format -show_streams "$file")
  local height=$(jq -r '.streams[0].height // empty' <<<"$info")

  if [[ $height == $stream_height ]]; then

    local fileName=$(basename "$file")
    local bangou=$(basename "$fileName" .mp4)
    bangou=$(basename "$bangou" .mkv)
    bangou=$(basename "$bangou" .wmv)
    bangou="${bangou%-hack}"
    bangou="${bangou%-C}"
    bangou="${bangou%-流出}"
    bangou="${bangou%-无码流出}"
    bangou="${bangou%-leak}"

    rm -rf $rootDirectory/$bangou
    echo "delete \$leak/$bangou"

  fi
}

# 遍历 rootDirectory 的下一级目录
for dir in "$rootDirectory"; do
  dir=${dir%/} # 移除尾部的斜杠
  dirName=$(basename "$dir")

  # 处理目录中的文件
  find "$dir" -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.wmv" \) | while read -r file; do
    process_file "$file" "$dirName"
  done
done

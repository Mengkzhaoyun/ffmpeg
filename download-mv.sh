#!/bin/bash

# 设置语言环境
export LC_ALL=C
export LANG=C

srcDirectory="/share/CACHEDEV1_DATA/Public/Plex/Downloads"
dstDirectory="/share/CACHEDEV1_DATA/Public/Plex/Mosaics"

# 创建一个空字典
declare -A mosaic_dict

process_dict() {
  # 遍历第一级子目录
  for dir in "$dstDirectory"/*/; do
    # 获取目录名并处理
    dir_name=$(basename "$dir" | sed 's/^[^-]*-//')
    # 将目录名和目录路径添加到字典中
    mosaic_dict["$dir_name"]="$dir"
  done

  # 从配置文件读取额外的映射关系
  while IFS='=' read -r key value; do
    mosaic_dict["$key"]="$value"
  done < "$dstDirectory/actors_mapping.txt"
}

process_file() {
  local file="$1"
  local dirName="$2"

  # 获取演员名单
  local actors
  IFS=$'\n' read -d '' -r -a actors < <(xmlstarlet sel -t -v "//actor/name" "$file" && printf '\0')

  for actor in "${actors[@]}"; do
    dstDir=${mosaic_dict[$actor]}

    # 判断 dstDir 是否非空
    if [[ -n "$dstDir" ]]; then
      echo "mv $dirName to $dstDir"
      mv $srcDirectory/$dirName "$dstDir"
      return # 直接返回，不再继续处理其他演员
    fi
  done
}

process_dict

# 遍历 rootDirectory 的下一级目录
for dir in "$srcDirectory"/*/; do
  dir=${dir%/} # 移除尾部的斜杠
  dirName=$(basename "$dir")

  # 处理目录中的文件
  find "$dir" -type f -name "*.nfo" | while read -r file; do
    process_file "$file" "$dirName"
  done
done

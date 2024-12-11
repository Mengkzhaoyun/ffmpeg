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

  mosaic_dict["楓カレン"]="/share/CACHEDEV1_DATA/Public/Plex/Mosaics/1000-楓花恋/"
  mosaic_dict["Miru"]="/share/CACHEDEV1_DATA/Public/Plex/Mosaics/1005-Miru/"
  mosaic_dict["楓ふうあ"]="/share/CACHEDEV1_DATA/Public/Plex/Mosaics/2001-枫富爱/"
  mosaic_dict["水川潤"]="/share/CACHEDEV1_DATA/Public/Plex/Mosaics/2001-由愛可奈/"
  mosaic_dict["香椎りあ"]="/share/CACHEDEV1_DATA/Public/Plex/Mosaics/3002-香椎花乃/"
  mosaic_dict["雅さやか"]="/share/CACHEDEV1_DATA/Public/Plex/Mosaics/3002-香椎花乃/"
  mosaic_dict["花沢ひまり"]="/share/CACHEDEV1_DATA/Public/Plex/Mosaics/9001-木下ひまり/"
  mosaic_dict["JULIA"]="/share/CACHEDEV1_DATA/Public/Plex/Mosaics/9001-Julia/"
  mosaic_dict["めぐり（藤浦めぐ）"]="/share/CACHEDEV1_DATA/Public/Plex/Mosaics/9001-藤浦めぐ/"
  mosaic_dict["小倉七海"]="/share/CACHEDEV1_DATA/Public/Plex/Mosaics/9001-兒玉七海/"
  mosaic_dict["森沢かな（飯岡かなこ）"]="/share/CACHEDEV1_DATA/Public/Plex/Mosaics/9001-森沢かな/"

  # # 打印字典内容
  # for key in "${!mosaic_dict[@]}"; do
  #   echo "$key: ${mosaic_dict[$key]}"
  # done
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

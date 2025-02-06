#!/bin/bash

# 设置语言环境
export LC_ALL=C
export LANG=C

srcDirectory="/share/CACHEDEV1_DATA/Public/Plex/Downloads"
dstDirectory="/share/CACHEDEV1_DATA/Public/Plex/Mosaics"
yaml_file="$dstDirectory/actors.yaml"  # 定义 YAML 文件路径

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

  # 从 YAML 文件读取演员信息
  actors_count=$(yq eval '.actors | length' "$yaml_file")

  for ((i=0; i<actors_count; i++)); do
    name=$(yq eval ".actors[$i].name" "$yaml_file")
    aliases=$(yq eval ".actors[$i].aliases | join(\",\")" "$yaml_file")  # 获取别名
    
    # 只有当 aliases 非空且 mosaic_dict[$name] 存在时才处理别名
    if [[ -n "$aliases" && -n "${mosaic_dict[$name]}" ]]; then
      # 将每个别名与真实名字的路径保存到 actor_aliases 字典中
      IFS=',' read -r -a alias_array <<< "$aliases"  # 将别名转换为数组
      for alias in "${alias_array[@]}"; do
        mosaic_dict["$alias"]="${mosaic_dict[$name]}"  # 将别名与真实名字的路径关联
      done
    fi
  done
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
  newdir=${dir%/} # 移除尾部的斜杠
  dirName=$(basename "$newdir")

  # 处理目录中的文件
  find "$dir" -type f -name "*.nfo" | while read -r file; do
    process_file "$file" "$dirName"
  done
done

#!/bin/bash

# 设置语言环境
export LC_ALL=C
export LANG=C

srcDirectory="/share/CACHEDEV1_DATA/Public/Plex/Downloads"
dstDirectory="/share/CACHEDEV1_DATA/Public/Plex/Mosaics"
DST_YAML="$dstDirectory/actors.yaml" # 定义 YAML 文件路径

# 创建一个空字典
declare -A mosaic_dict
declare -A ACTOR_DICT

# 错误处理函数
handle_error() {
  local message="$1"
  echo "错误: $message" >&2
  exit 1
}

# 初始化演员字典 (来自nfo.sh)
init_actor_dict() {
  [[ -f "$DST_YAML" ]] || handle_error "找不到 YAML 文件 $DST_YAML"

  local actors_count=$(yq eval '.actors | length' "$DST_YAML")

  for ((i = 0; i < actors_count; i++)); do
    local name=$(yq eval ".actors[$i].name" "$DST_YAML")
    local thumb=$(yq eval ".actors[$i].thumb" "$DST_YAML")
    local aliases=$(yq eval ".actors[$i].aliases" "$DST_YAML")
    # 检查 aliases 是否为 null 或空
    if [[ "$aliases" != "null" && -n "$aliases" ]]; then
      aliases=$(yq eval ".actors[$i].aliases | join(\",\")" "$DST_YAML")
    else
      aliases=""
    fi

    [[ -n "$name" ]] || continue # 跳过没有名字的条目
    ACTOR_DICT["$name"]="$thumb;$aliases"
  done

  echo "成功加载 ${#ACTOR_DICT[@]} 个演员信息"
}

# 重映射演员信息 (来自nfo.sh)
remap_actor() {
  local current_name="$1"
  local current_thumb="$2"
  local dir_name="$3"

  local result_name="$current_name"
  local result_thumb="$current_thumb"

  # 处理单演员情况
  if [[ -n "$dir_name" ]]; then
    local actor_info="${ACTOR_DICT[$dir_name]}"
    if [[ -n "$actor_info" ]]; then
      IFS=';' read -r thumb aliases <<<"$actor_info"
      if [[ "$current_name" == "$dir_name" ]]; then
        echo "$current_name;$thumb"
        return
      fi
      if [[ -n "$aliases" ]]; then
        IFS=',' read -r -a alias_array <<<"$aliases"
        for alias in "${alias_array[@]}"; do
          if [[ "$current_name" == "$alias" ]]; then
            echo "$dir_name;$thumb"
            return
          fi
        done
      fi
    fi
  # 处理多演员情况
  else
    for actor_name in "${!ACTOR_DICT[@]}"; do
      local actor_info="${ACTOR_DICT[$actor_name]}"
      IFS=';' read -r thumb aliases <<<"$actor_info"

      if [[ "$current_name" == "$actor_name" ]]; then
        echo "$current_name;$thumb"
        return
      fi

      if [[ -n "$aliases" ]]; then
        IFS=',' read -r -a alias_array <<<"$aliases"
        for alias in "${alias_array[@]}"; do
          if [[ "$current_name" == "$alias" ]]; then
            echo "$actor_name;$thumb"
            return
          fi
        done
      fi
    done
  fi

  echo "$current_name;$current_thumb"
}

# 更新 NFO 文件 (来自nfo.sh)
update_nfo() {
  local nfo_file="$1"
  local current_name="$2"
  local current_thumb="$3"
  local new_name="$4"
  local new_thumb="$5"

  if [[ -n "$new_name" && "$current_name" != "$new_name" ]]; then
    xmlstarlet ed -L \
      -u "//actor[name='$current_name']/thumb" -v "$new_thumb" \
      -u "//actor[name='$current_name']/name" -v "$new_name" \
      "$nfo_file"
    echo "更新 NFO 文件: $nfo_file"
  elif [[ -z "$current_thumb" && -n "$new_thumb" ]]; then
    xmlstarlet ed -L \
      -s "//actor[name='$current_name']" -t elem -n "thumb" -v "$new_thumb" \
      "$nfo_file"
    echo "更新 NFO 文件: $nfo_file, 为演员 $current_name 增加 thumb 属性: $new_thumb"
  elif [[ -n "$new_thumb" && "$current_thumb" != "$new_thumb" ]]; then
    xmlstarlet ed -L \
      -u "//actor[name='$current_name']/thumb" -v "$new_thumb" \
      "$nfo_file"
    echo "更新 NFO 文件: $nfo_file"
  fi
}

# 处理单个 NFO 文件 (来自nfo.sh，稍作修改)
process_nfo() {
  local nfo_file="$1"
  local dir_name="$2"

  local nfo_content
  nfo_content=$(cat "$nfo_file") || {
    echo "警告: 找不到 NFO 文件: $nfo_file"
    return
  }

  # 提取演员信息
  local actor_nodes
  actor_nodes=$(echo "$nfo_content" | xmlstarlet sel -t -m "//actor" -v "name" -o ":" -v "thumb" -n)

  [[ -n "$actor_nodes" ]] || {
    echo "警告: NFO 文件 $nfo_file 中没有找到演员信息"
    return
  }

  local actor_count
  actor_count=$(echo "$actor_nodes" | wc -l)

  while IFS= read -r actor_info; do
    [[ -n "$actor_info" ]] || continue

    local current_name current_thumb
    IFS=':' read -r current_name current_thumb <<<"$actor_info"

    local result
    if ((actor_count > 1)); then
      result=$(remap_actor "$current_name" "$current_thumb")
    else
      result=$(remap_actor "$current_name" "$current_thumb" "$dir_name")
    fi

    IFS=';' read -r new_name new_thumb <<<"$result"
    update_nfo "$nfo_file" "$current_name" "$current_thumb" "$new_name" "$new_thumb"
  done <<<"$actor_nodes"
}

process_dict() {
  # 遍历第一级子目录
  for dir in "$dstDirectory"/*/; do
    # 获取目录名并处理
    dir_name=$(basename "$dir" | sed 's/^[^-]*-//')
    # 将目录名和目录路径添加到字典中（移除尾部斜杠）
    mosaic_dict["$dir_name"]="${dir%/}"
  done

  # 从 YAML 文件读取演员信息
  actors_count=$(yq eval '.actors | length' "$DST_YAML")

  for ((i = 0; i < actors_count; i++)); do
    name=$(yq eval ".actors[$i].name" "$DST_YAML")
    aliases=$(yq eval ".actors[$i].aliases" "$DST_YAML")

    # 只有当 aliases 非空且 mosaic_dict[$name] 存在时才处理别名
    if [[ "$aliases" != "null" && -n "$aliases" && -n "${mosaic_dict[$name]}" ]]; then
      # 将每个别名与真实名字的路径保存到 actor_aliases 字典中
      aliases=$(yq eval ".actors[$i].aliases | join(\",\")" "$DST_YAML")
      IFS=',' read -r -a alias_array <<<"$aliases" # 将别名转换为数组
      for alias in "${alias_array[@]}"; do
        mosaic_dict["$alias"]="${mosaic_dict[$name]}" # 将别名与真实名字的路径关联
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
      mv "$srcDirectory/$dirName" "$dstDir"
      
      # 获取移动后目录的真实演员名（从目录名提取）
      local real_dir_name=$(basename "$dstDir" | sed 's/^[^-]*-//')
      
      # 移动后立即更新元数据
      find "$dstDir/$dirName" -type f -name "*.nfo" | while read -r nfo_file; do
        echo "更新NFO元数据: $nfo_file"
        process_nfo "$nfo_file" "$real_dir_name"
      done
      
      return # 直接返回，不再继续处理其他演员
    fi
  done
}

# 主程序开始
process_dict
init_actor_dict  # 初始化演员信息字典，用于元数据更新

# 遍历 rootDirectory 的下一级目录
for dir in "$srcDirectory"/*/; do
  newdir=${dir%/} # 移除尾部的斜杠
  dirName=$(basename "$newdir")

  # 处理目录中的文件
  find "$dir" -type f -name "*.nfo" | while read -r file; do
    process_file "$file" "$dirName"
  done
done

#!/bin/bash

# 定义常量
readonly DOWNLOADS_DIRECTORY="/share/CACHEDEV1_DATA/Public/Plex/Downloads"
readonly MOSAICS_DIRECTORY="/share/CACHEDEV1_DATA/Public/Plex/Mosaics"
readonly CACHE_DIRECTORY="$MOSAICS_DIRECTORY/.cache"
readonly DST_YAML="$CACHE_DIRECTORY/actors.yaml"

# 声明关联数组
declare -A ACTOR_DICT

# 错误处理函数
handle_error() {
  local message="$1"
  echo "错误: $message" >&2
  exit 1
}

# 确保缓存目录存在
ensure_cache_directory() {
  if [[ ! -d "$CACHE_DIRECTORY" ]]; then
    echo "缓存目录不存在，创建目录: $CACHE_DIRECTORY"
    mkdir -p "$CACHE_DIRECTORY" || handle_error "无法创建缓存目录 $CACHE_DIRECTORY"
  fi
}

# 初始化演员字典
init_actor_dict() {
  # 确保缓存目录存在
  ensure_cache_directory
  
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

# 重映射演员信息（多演员模式）
remap_actor() {
  local current_name="$1"
  local current_thumb="$2"

  # Downloads 目录只使用多演员匹配模式
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

  echo "$current_name;$current_thumb"
}

# 更新 NFO 文件
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

# 处理单个 NFO 文件
process_nfo() {
  local nfo_file="$1"

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

  while IFS= read -r actor_info; do
    [[ -n "$actor_info" ]] || continue

    local current_name current_thumb
    IFS=':' read -r current_name current_thumb <<<"$actor_info"

    local result
    result=$(remap_actor "$current_name" "$current_thumb")

    IFS=';' read -r new_name new_thumb <<<"$result"

    update_nfo "$nfo_file" "$current_name" "$current_thumb" "$new_name" "$new_thumb"
  done <<<"$actor_nodes"
}

# 处理 Downloads 目录
process_downloads_directory() {
  echo "处理 Downloads 目录..."
  
  [[ -d "$DOWNLOADS_DIRECTORY" ]] || handle_error "Downloads 目录不存在: $DOWNLOADS_DIRECTORY"
  
  local processed_count=0
  
  # Downloads 目录直接包含视频目录，没有演员目录层级
  for dir in "$DOWNLOADS_DIRECTORY"/*/; do
    [[ -d "$dir" ]] || continue

    while IFS= read -r -d '' nfo_file; do
      process_nfo "$nfo_file"
      ((processed_count++))
    done < <(find "$dir" -type f -name "*.nfo" -print0)
  done
  
  echo "处理完成，共处理 $processed_count 个 NFO 文件"
}

# 主程序
main() {
  init_actor_dict
  process_downloads_directory
}

# 执行主程序
main

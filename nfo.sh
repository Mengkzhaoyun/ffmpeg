#!/bin/bash

# 定义常量
readonly DST_DIRECTORY="/share/CACHEDEV1_DATA/Public/Plex/Mosaics"
readonly DST_YAML="$DST_DIRECTORY/actors.yaml"

# 声明关联数组
declare -A ACTOR_DICT

# 错误处理函数
handle_error() {
  local message="$1"
  echo "错误: $message" >&2
  exit 1
}

# 初始化演员字典
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

# 重映射演员信息
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
      # 调试信息：输出当前处理的演员信息
      # echo "处理演员【多演员】: 名称: $current_name, 头像: $current_thumb, 目录: $dir_name, 演员信息: ${ACTOR_DICT[$dir_name]}"
      result=$(remap_actor "$current_name" "$current_thumb")
    else
      # 调试信息：输出当前处理的演员信息
      # echo "处理演员【单演员】: 名称: $current_name, 头像: $current_thumb, 目录: $dir_name, 演员信息: ${ACTOR_DICT[$dir_name]}"
      result=$(remap_actor "$current_name" "$current_thumb" "$dir_name")
    fi

    IFS=';' read -r new_name new_thumb <<<"$result"

    # 调试信息：输出更新的信息
    # echo "更新演员: 当前名称: $current_name, 新名称: $new_name, 新头像: $new_thumb"

    update_nfo "$nfo_file" "$current_name" "$current_thumb" "$new_name" "$new_thumb"
  done <<<"$actor_nodes"
}

# 主程序
main() {
  init_actor_dict

  # 遍历目录处理 NFO 文件
  for dir in "$DST_DIRECTORY"/*/; do
    [[ -d "$dir" ]] || continue

    local dir_name
    dir_name=$(basename "$dir" | sed 's/^[^-]*-//')

    # 检查 ACTOR_DICT 中是否存在该演员
    if [[ -n "${ACTOR_DICT[$dir_name]}" ]]; then
      echo "处理目录: $dir_name"
    else
      continue
    fi

    while IFS= read -r -d '' nfo_file; do
      process_nfo "$nfo_file" "$dir_name"
    done < <(find "$dir" -type f -name "*.nfo" -print0)
  done
}

# 执行主程序
main

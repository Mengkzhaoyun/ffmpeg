#!/bin/bash

# 设置语言环境
export LC_ALL=C
export LANG=C

# 默认参数
USE_CACHE=true

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --use-cache)
      USE_CACHE=true
      shift
      ;;
    -h|--help)
      echo "用法: $0 [选项]"
      echo "选项:"
      echo "  --use-cache    使用缓存文件加速处理"
      echo "  -h, --help     显示此帮助信息"
      exit 0
      ;;
    *)
      echo "未知参数: $1"
      echo "使用 -h 或 --help 查看帮助"
      exit 1
      ;;
  esac
done

rootDirectory="/share/CACHEDEV1_DATA/Public/Plex/Mosaics"
cacheDirectory="$rootDirectory/.cache"
globalCacheFile="$cacheDirectory/ffmpeg.md"
bitrate_threshold=6200      # 视频的码率阈值 (6200 kbps)
winSrcDirectory='\\nas-mengk\Public\Plex\Mosaics'
winDesDirectory='C:\Users\Mengk\Videos'

# 显示运行模式
if $USE_CACHE; then
  echo "运行模式: 启用缓存"
else
  echo "运行模式: 不使用缓存"
fi

# 创建缓存目录
mkdir -p "$cacheDirectory"

# 清理旧的任务文件
find "$rootDirectory" -maxdepth 1 -name "*.task" -type f -delete

# 清理历史子目录缓存文件
echo "清理历史缓存文件..."
find "$rootDirectory" -name "ffmpeg.md" -not -path "$globalCacheFile" -type f -delete

# 全局缓存内存对象
declare -A global_cache
cache_modified=false

# 检查缓存目录是否存在，不存在则重新创建
ensure_cache_directory() {
  if [ ! -d "$cacheDirectory" ]; then
    echo "缓存目录不存在，重新创建: $cacheDirectory"
    mkdir -p "$cacheDirectory"
    cache_modified=true  # 标记需要重新保存缓存
  fi
}

# 读取全局缓存到内存
load_global_cache() {
  if $USE_CACHE && [ -f "$globalCacheFile" ]; then
    echo "读取全局缓存文件..."
    while IFS= read -r line; do
      # 跳过标题行和分隔符行
      if [[ "$line" =~ ^\|.*\|.*\|.*\|.*\|.*\|.*\|$ ]] && [[ ! "$line" =~ ^[[:space:]]*\|[[:space:]]*文件夹 ]] && [[ ! "$line" =~ ^[[:space:]]*\|[-:]+\| ]]; then
        # 解析缓存行: | 文件夹 | 文件名 | 修改日期 | 文件大小 | 编码 | 码率 (kbps) | 高度 |
        local folder=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
        local filename=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
        local mtime=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4}')
        local size=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $5); print $5}')
        local codec=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $6); print $6}')
        local bitrate=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $7); print $7}')
        local height=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $8); print $8}')
        
        local cache_key="${folder}/${filename}"
        global_cache["$cache_key"]="$mtime|$size|$codec|$bitrate|$height"
      fi
    done < "$globalCacheFile"
    echo "缓存加载完成，共 ${#global_cache[@]} 条记录"
  fi
}

# 保存全局缓存
save_global_cache() {
  if $USE_CACHE && ($cache_modified || [ ${#global_cache[@]} -gt 0 ]); then
    # 确保缓存目录存在
    ensure_cache_directory
    
    echo "保存全局缓存文件..."
    {
      echo "# FFmpeg 视频信息全局缓存"
      echo ""
      echo "| 文件夹 | 文件名 | 修改日期 | 文件大小 | 编码 | 码率 (kbps) | 高度 |"
      echo "|---|---|---|---|---|---|---|"
      
      # 按文件夹分组输出
      local current_folder=""
      for cache_key in $(printf '%s\n' "${!global_cache[@]}" | sort); do
        local folder="${cache_key%/*}"
        local filename="${cache_key##*/}"
        local cache_data="${global_cache[$cache_key]}"
        
        IFS='|' read -r mtime size codec bitrate height <<< "$cache_data"
        echo "| $folder | $filename | $mtime | $size | $codec | $bitrate | $height |"
      done
    } > "$globalCacheFile"
    echo "全局缓存已保存"
  fi
}

# 清理缓存中已删除的文件
cleanup_cache_for_folder() {
  local folder="$1"
  local existing_files=("${@:2}")
  
  # 创建现有文件的关联数组
  declare -A existing_files_map
  for file in "${existing_files[@]}"; do
    existing_files_map["$file"]=1
  done
  
  # 检查缓存中的文件是否还存在
  local keys_to_remove=()
  for cache_key in "${!global_cache[@]}"; do
    if [[ "$cache_key" == "$folder/"* ]]; then
      local filename="${cache_key##*/}"
      if [[ -z "${existing_files_map[$filename]}" ]]; then
        keys_to_remove+=("$cache_key")
      fi
    fi
  done
  
  # 删除不存在的文件缓存
  for key in "${keys_to_remove[@]}"; do
    unset global_cache["$key"]
    cache_modified=true
    echo "清理缓存: $key (文件已删除)"
  done
}

process_file() {
  local file="$1"
  local dirName="$2"
  local dirTask="$3"

  local fileName=$(basename "$file")
  local cache_key="${dirName}/${fileName}"
  local info codec bitrate height
  local found_in_cache=false
  
  # 获取文件的修改时间和大小
  local file_mtime=$(stat -c %Y "$file")
  local file_size=$(stat -c %s "$file")

  # 检查缓存
  if $USE_CACHE && [[ -n "${global_cache[$cache_key]}" ]]; then
    IFS='|' read -r cached_mtime cached_size cached_codec cached_bitrate cached_height <<< "${global_cache[$cache_key]}"
    
    # 比较文件修改时间和大小
    if [[ "$file_mtime" == "$cached_mtime" && "$file_size" == "$cached_size" ]]; then
      codec="$cached_codec"
      bitrate="$cached_bitrate"
      height="$cached_height"
      bitrate=$((bitrate * 1000)) # 将缓存中的kbps转回bps以兼容后续逻辑
      found_in_cache=true
      echo "从缓存读取: $fileName"
    else
      echo "缓存过期: $fileName (时间或大小不匹配)"
    fi
  fi

  # 如果缓存中没有找到或缓存过期，则运行 ffprobe
  if ! $found_in_cache; then
    if $USE_CACHE; then
      echo "使用 ffprobe 分析: $fileName"
    fi
    
    # 使用 ffprobe 获取视频信息
    info=$(ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null)
    if [[ $? -eq 0 && -n "$info" ]]; then
      bitrate=$(jq -r '.format.bit_rate // empty' <<<"$info" 2>/dev/null)
      codec=$(jq -r '.streams[0].codec_name // empty' <<<"$info" 2>/dev/null)
      height=$(jq -r '.streams[0].height // empty' <<<"$info" 2>/dev/null)

      # 更新缓存
      if $USE_CACHE && [[ -n "$bitrate" && -n "$codec" && -n "$height" ]]; then
        local bitrate_kbps=$((bitrate / 1000))
        global_cache["$cache_key"]="$file_mtime|$file_size|$codec|$bitrate_kbps|$height"
        cache_modified=true
        echo "更新缓存: $fileName"
      fi
    else
      echo "警告: 无法分析文件 $fileName"
      return
    fi
  fi

  if [[ -n "$bitrate" ]]; then
    # 将 bitrate 从 bps 转换为 kbps
    bitrate=$((bitrate / 1000))

    local needs_compression=false
    # 根据编码类型选择不同的码率阈值
    if [[ "$bitrate" -gt "$bitrate_threshold" ]]; then
      needs_compression=true
    fi

    if $needs_compression; then
      # 将 kbps 转换为 Mbps 并保留一位小数
      local bitrate_mbps=$(awk "BEGIN {printf \"%.1f\", $bitrate/1000}")
      echo "文件: $file, 编码：$codec, 码率: ${bitrate_mbps} Mbps, 符合压缩条件"

      local bangou=$(basename "$(dirname "$file")") # 获取最近目录名

      local winSrcFile="$winSrcDirectory\\$dirName\\$bangou\\$fileName"
      # 判断文件名是否包含 -hack 或 -leak
      # 去掉文件名的类型后缀
      local baseName="${fileName%.*}"
      if [[ "$baseName" == *"-hack" ]]; then
        local winDesFile="$winDesDirectory\\$dirName\\$bangou-hack.mp4"
      elif [[ "$baseName" == *"-leak" ]]; then
        local winDesFile="$winDesDirectory\\$dirName\\$bangou-leak.mp4"
      elif [[ "$baseName" == *"-流出" ]]; then
        local winDesFile="$winDesDirectory\\$dirName\\$bangou-流出.mp4"
      elif [[ "$baseName" == *"-C" ]]; then
        local winDesFile="$winDesDirectory\\$dirName\\$bangou-C.mp4"
      else
        local winDesFile="$winDesDirectory\\$dirName\\$bangou.mp4"
      fi

      echo "\"Custom\" \"Plex MP4 HEVC(H265)\" \"$winSrcFile\" \"$winDesFile\"" >>"$dirTask"
    fi
  fi
}

# 确保缓存目录存在
ensure_cache_directory

# 初始化全局缓存文件
if $USE_CACHE && [ ! -f "$globalCacheFile" ]; then
  echo "创建全局缓存文件: $globalCacheFile"
  {
    echo "# FFmpeg 视频信息全局缓存"
    echo ""
    echo "| 文件夹 | 文件名 | 修改日期 | 文件大小 | 编码 | 码率 (kbps) | 高度 |"
    echo "|---|---|---|---|---|---|---|"
  } > "$globalCacheFile"
fi

# 加载全局缓存到内存
load_global_cache

# 遍历 rootDirectory 的下一级目录
for dir in "$rootDirectory"/*/; do
  # 跳过缓存目录
  if [[ "$dir" == "$cacheDirectory/" ]]; then
    continue
  fi
  
  dir=${dir%/} # 移除尾部的斜杠
  dirName=$(basename "$dir")
  dirTask="$rootDirectory/$dirName.task"
  
  echo "处理目录: $dirName"
  
  # 收集当前目录中的所有视频文件
  video_files=()
  while IFS= read -r -d '' file; do
    video_files+=("$(basename "$file")")
  done < <(find "$dir" -type f \( -name "*.mp4" -o -name "*.mkv" \) -print0)
  
  # 清理当前目录的缓存（删除已不存在的文件）
  cleanup_cache_for_folder "$dirName" "${video_files[@]}"
  
  # 处理目录中的文件 (使用进程替换避免子shell问题)
  while IFS= read -r -d '' file; do
    process_file "$file" "$dirName" "$dirTask"
  done < <(find "$dir" -type f \( -name "*.mp4" -o -name "*.mkv" \) -print0)

  # 如果任务文件不为空，进行编码转换
  if [ -s "$dirTask" ]; then
    iconv -f UTF-8 -t UTF-16 -o "$dirTask.utf16le" "$dirTask"
    mv "$dirTask.utf16le" "$dirTask"
    echo "任务：$dirTask"
  fi
done

# 保存全局缓存
save_global_cache

echo "脚本执行完毕"
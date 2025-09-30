#!/bin/bash

# 设置语言环境
export LC_ALL=C
export LANG=C

rootDirectory="/share/CACHEDEV1_DATA/Public/Plex/Mosaics"
bitrate_threshold=6000      # 视频的码率阈值 (6000 kbps)
winSrcDirectory='\\nas-mengk\Public\Plex\Mosaics'
winDesDirectory='C:\Users\Mengk\Videos'

# 清理旧的任务文件
find "$rootDirectory" -maxdepth 1 -name "*.task" -type f -delete

process_file() {
  local file="$1"
  local dirName="$2"
  local dirTask="$3"
  local cacheFile="$4" # 新增：缓存文件路径

  local fileName=$(basename "$file")
  local info codec bitrate height
  local found_in_cache=false

  # --- 新增：缓存读取逻辑 ---
  if [ -f "$cacheFile" ]; then
    # 从缓存文件中查找当前文件的记录
    local cache_line=$(grep -F "| $fileName |" "$cacheFile")
    if [[ -n "$cache_line" ]]; then
      # 如果找到，直接从缓存行中解析数据，避免调用 ffprobe
      codec=$(echo "$cache_line" | awk -F'|' '{gsub(/ /, "", $3); print $3}')
      bitrate=$(echo "$cache_line" | awk -F'|' '{gsub(/ /, "", $4); print $4}')
      height=$(echo "$cache_line" | awk -F'|' '{gsub(/ /, "", $5); print $5}')
      bitrate=$((bitrate * 1000)) # 将缓存中的kbps转回bps以兼容后续逻辑
      found_in_cache=true
    fi
  fi

  # 如果缓存中没有找到，则运行 ffprobe
  if ! $found_in_cache; then
    # 使用 ffprobe 获取视频信息
    info=$(ffprobe -v quiet -print_format json -show_format -show_streams "$file")
    bitrate=$(jq -r '.format.bit_rate // empty' <<<"$info")
    codec=$(jq -r '.streams[0].codec_name // empty' <<<"$info")
    height=$(jq -r '.streams[0].height // empty' <<<"$info")

    # --- 新增：将新信息写入缓存文件 ---
    if [[ -n "$bitrate" && -n "$codec" && -n "$height" ]]; then
      local bitrate_kbps=$((bitrate / 1000))
      echo "| $fileName | $codec | $bitrate_kbps | $height |" >> "$cacheFile"
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

# 遍历 rootDirectory 的下一级目录
for dir in "$rootDirectory"/*/; do
  dir=${dir%/} # 移除尾部的斜杠
  dirName=$(basename "$dir")
  dirTask="$rootDirectory/$dirName.task"
  
  # --- 新增：定义并初始化缓存文件 ---
  cacheFile="$dir/ffmpeg.md"
  if [ ! -f "$cacheFile" ]; then
    # 如果缓存文件不存在，创建并写入表头
    echo "# FFmpeg 视频信息缓存" > "$cacheFile"
    echo "" >> "$cacheFile"
    echo "| 文件名 | 编码 | 码率 (kbps) | 高度 |" >> "$cacheFile"
    echo "|---|---|---|---|" >> "$cacheFile"
  fi

  # 处理目录中的文件
  find "$dir" -type f \( -name "*.mp4" -o -name "*.mkv" \) | while read -r file; do
    process_file "$file" "$dirName" "$dirTask" "$cacheFile"
  done

  # 如果任务文件不为空，进行编码转换
  if [ -s "$dirTask" ]; then
    iconv -f UTF-8 -t UTF-16 -o "$dirTask.utf16le" "$dirTask"
    mv "$dirTask.utf16le" "$dirTask"
    echo "任务：$dirTask"
  fi
done

echo "脚本执行完毕"
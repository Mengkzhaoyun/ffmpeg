#!/bin/bash

# 设置语言环境
export LC_ALL=C
export LANG=C

rootDirectory="/share/CACHEDEV1_DATA/Public/Plex/Mosaics"
bitrate_threshold=6000 # 6000 kbps (约等于 6 Mbps)
winSrcDirectory='\\nas-mengk\Public\Plex\Mosaics'
winDesDirectory='C:\Users\Mengk\Videos'

# 清理旧的任务文件
find "$rootDirectory" -maxdepth 1 -name "*.task" -type f -delete

process_file() {
  local file="$1"
  local dirName="$2"
  local dirTask="$3"

  # 使用 ffprobe 获取视频信息
  local info=$(ffprobe -v quiet -print_format json -show_format -show_streams "$file")
  local bitrate=$(jq -r '.format.bit_rate // empty' <<<"$info")
  local codec=$(jq -r '.streams[0].codec_name // empty' <<<"$info")

  [[ "$codec" == "hevc" ]] && { return; } # 调试信息

  if [[ -n "$bitrate" ]]; then
    # 将 bitrate 从 bps 转换为 kbps
    bitrate=$((bitrate / 1024))

    if [[ "$bitrate" -gt "$bitrate_threshold" ]]; then
      # 将 kbps 转换为 Mbps 并保留一位小数
      local bitrate_mbps=$(awk "BEGIN {printf \"%.1f\", $bitrate/1000}")
      echo "文件: $file, 编码：$codec, 码率: ${bitrate_mbps} Mbps"

      local fileName=$(basename "$file")
      local bangou=$(basename "$fileName" .mp4)
      local bangou=$(basename "$fileName" .mkv)
      bangou="${bangou%-hack}"
      bangou="${bangou%-C}"

      local winSrcFile="$winSrcDirectory\\$dirName\\$bangou\\$fileName"
      local winDesFile="$winDesDirectory\\$dirName\\$bangou-hack.mp4"

      echo "\"MP4\" \"Optimum quality and size\" \"$winSrcFile\" \"$winDesFile\"" >>"$dirTask"
    fi
  fi
}

# 遍历 rootDirectory 的下一级目录
for dir in "$rootDirectory"/*/; do
  dir=${dir%/} # 移除尾部的斜杠
  dirName=$(basename "$dir")
  dirTask="$rootDirectory/$dirName.task"

  # 处理目录中的文件
  find "$dir" -type f \( -name "*.mp4" -o -name "*.mkv" \) | while read -r file; do
    process_file "$file" "$dirName" "$dirTask"
  done

  # 如果任务文件不为空，进行编码转换
  if [ -s "$dirTask" ]; then
    iconv -f UTF-8 -t UTF-16 -o "$dirTask.utf16le" "$dirTask"
    mv "$dirTask.utf16le" "$dirTask"
    echo "任务：$dirTask"
  fi
done

echo "脚本执行完毕" # 调试信息

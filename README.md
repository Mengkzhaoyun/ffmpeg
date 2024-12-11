# movevedios

## tasks

```bash
# 压缩视频自动化任务
## 生成压缩视频task
bash ffmpeg.sh

## 将压缩完的视频拷贝至对应Mosaics

## 将压缩完的视频迁移至Mosaics子目录
bash ffmpeg-mv-vedios.sh

# 下载任务
## 将downloads刮削视频迁移至Mosaics目录
bash download-mv.sh
```

## install

```bash
sudo apt install -y ffmpeg bc jq parallel xmlstarlet
```

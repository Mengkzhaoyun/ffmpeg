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

## nfo

### run

```bash
cp .tmp/actors.yaml /share/CACHEDEV1_DATA/Public/Plex/Mosaics/actors.yaml && bash nfo.sh

bash nfo.sh
```

### xmlstarlet

```bash
sudo apt update && \
sudo apt install -y ffmpeg bc jq parallel xmlstarlet
```

### yq

```bash
sudo curl \
  -x $SOCKS5_PROXY_LOCAL \
  -fL https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_linux_amd64 \
  -o /usr/local/bin/yq && \
sudo chmod +x /usr/local/bin/yq
```

### shfmt

```bash
sudo apt update && \
sudo apt install -y shfmt util-linux

sudo chmod +x /usr/bin/shfmt
```

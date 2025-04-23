#!/bin/bash

# 进入 FEMU 文件夹
cd FEMU || { echo "FEMU 文件夹不存在，请检查路径"; exit 1; }

# 检查 build-femu 文件夹是否存在
if [ ! -d "build-femu" ]; then
  # 如果不存在，则创建 build-femu 文件夹
  mkdir build-femu
  echo "创建 build-femu 文件夹"
fi

# 进入 build-femu 文件夹
cd build-femu || { echo "无法进入 build-femu 文件夹"; exit 1; }

echo "当前目录: $(pwd)"

# Copy femu script
cp ../femu-scripts/femu-copy-scripts.sh .
./femu-copy-scripts.sh .
# only Debian/Ubuntu based distributions supported
sudo ./pkgdep.sh
#!/bin/bash

# rootfs-img.sh - 直接挂载并填充 rootfs 镜像（无压缩）

# 检查参数
if [ -z "$1" ]; then
    echo "用法: $0 <tar.gz 根文件系统>"
    exit 1
fi

TAR_FILE="$1"
ROOTFS_DIR="rootfs"
IMAGE_NAME="linuxroot.img"

# 检查 tar 文件是否存在
if [ ! -f "$TAR_FILE" ]; then
    echo "错误: 文件 $TAR_FILE 不存在"
    exit 1
fi

# 清理旧数据
rm -rf "$ROOTFS_DIR" "$IMAGE_NAME"
mkdir -p "$ROOTFS_DIR"

# 创建镜像（6GB 固定大小）
echo "创建 6GB 大小的镜像..."
dd if=/dev/zero of="$IMAGE_NAME" bs=1M count=6000
mkfs.ext4 -F "$IMAGE_NAME"

# 挂载镜像
mount "$IMAGE_NAME" "$ROOTFS_DIR" || {
    echo "挂载失败，请确认 root 权限"
    exit 1
}

# 解压 tar.gz
echo "解压 $TAR_FILE 到镜像中..."
sudo tar -xzf "$TAR_FILE" -C "$ROOTFS_DIR"

# 卸载
sudo umount "$ROOTFS_DIR"

# 检查并修复文件系统
sudo e2fsck -p -f "$IMAGE_NAME"

# 缩小文件系统
sudo resize2fs -M "$IMAGE_NAME"

# 清理
rm -rf "$ROOTFS_DIR"

echo "✅ 镜像已生成: $IMAGE_NAME"

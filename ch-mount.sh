#!/bin/bash

if [[ $# -ne 2 ]]; then
    echo "参数错误: 需要两个参数"
    echo "用法: $0 [-m|-u] ROOTFS_DIR"
    echo "  -m: 挂载虚拟文件系统"
    echo "  -u: 卸载虚拟文件系统"
    exit 1
fi

ACTION=$1
ROOTFS_DIR=$2

case $ACTION in
    -m)
        echo "挂载虚拟文件系统到 $ROOTFS_DIR"
        sudo mount -t proc /proc $ROOTFS_DIR/proc
        sudo mount -t sysfs /sys $ROOTFS_DIR/sys
        sudo mount -o bind /dev $ROOTFS_DIR/dev
        sudo mount -o bind /dev/pts $ROOTFS_DIR/dev/pts
        ;;
    -u)
        echo "从 $ROOTFS_DIR 卸载虚拟文件系统"
        sudo umount -lf $ROOTFS_DIR/dev/pts 2>/dev/null || true
        sudo umount -lf $ROOTFS_DIR/dev 2>/dev/null || true
        sudo umount -lf $ROOTFS_DIR/proc 2>/dev/null || true
        sudo umount -lf $ROOTFS_DIR/sys 2>/dev/null || true
        ;;
    *)
        echo "无效操作: $ACTION"
        echo "可用操作: -m (挂载), -u (卸载)"
        exit 1
        ;;
esac

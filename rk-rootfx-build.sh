#!/bin/bash -x

# 选择构建目标
if [ -z "$TARGET" ]; then
    /bin/echo "-------------------------------------"
    /bin/echo "请选择构建目标:"
    /bin/echo "1) xfce (轻量级桌面)"
    /bin/echo "2) lite (最小化无桌面)"
    /bin/echo "-------------------------------------"
    read -p "请输入选项 (1/2): " choice

    case $choice in
        1) TARGET=xfce ;;
        2) TARGET=lite ;;
        *) /bin/echo "无效选项，退出!"; exit 1 ;;
    esac
fi

# 设置默认架构
ARCH="arm64"
ROOTFS_DIR="ubuntu-rootfs"
OUTPUT_FILE="ubuntu-$TARGET-$ARCH-$(date +%Y%m%d).tar.gz"

echo "======================================"
echo "开始构建: $TARGET 版本"
echo "架构: $ARCH"
echo "输出文件: $OUTPUT_FILE"
echo "======================================"

# 清理并创建目录
rm -rf $ROOTFS_DIR
mkdir -p $ROOTFS_DIR

# 下载基础镜像
if [ ! -f "ubuntu-base-24.04.2-base-$ARCH.tar.gz" ]; then
    /bin/echo "下载 Ubuntu 24.04 基础镜像..."
    wget -q https://mirror.nju.edu.cn/ubuntu-cdimage/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.2-base-$ARCH.tar.gz
fi

# 解压基础系统
echo "解压基础系统..."
tar -xzf ubuntu-base-24.04.2-base-$ARCH.tar.gz -C $ROOTFS_DIR

# 准备chroot环境
echo "准备chroot环境..."
# curl -o ./main.sh -sSL https://linuxmirrors.cn/main.sh
# cp ./main.sh $ROOTFS_DIR/main.sh
# chmod +x $ROOTFS_DIR/main.sh

cp /etc/resolv.conf $ROOTFS_DIR/etc/
cp ./ubuntu.sources $ROOTFS_DIR/etc/apt/sources.list.d/

# 复制并设置 qemu-aarch64-static
cp /usr/bin/qemu-aarch64-static $ROOTFS_DIR/usr/bin/
chmod +x $ROOTFS_DIR/usr/bin/qemu-aarch64-static

# 挂载虚拟文件系统
echo "挂载虚拟文件系统..."
./ch-mount.sh -m "$ROOTFS_DIR" || {
    echo "挂载失败，退出!"
    exit 1
}

# 复制resolv.conf确保网络连接
cp /etc/resolv.conf "$ROOTFS_DIR/etc/resolv.conf"

# 分阶段执行chroot操作
echo "开始chroot配置..."
cat << 'EOF' | chroot "$ROOTFS_DIR" /usr/bin/qemu-aarch64-static /bin/bash
#!/bin/bash

# 设置环境变量
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C.UTF-8

# 错误处理函数
handle_error() {
    echo "错误发生在第 $1 行: $2" >&2
    exit 1
}
trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# 1. 修复基础系统
echo "第一步：修复基础系统..."
apt-get update || { echo "更新失败"; exit 1; }

# 强制安装关键包
critical_packages=(
    locales
    policykit-1
)

for pkg in "${critical_packages[@]}"; do
    apt-get install -y --allow-downgrades --no-install-recommends "$pkg" || {
        echo "无法安装关键包: $pkg" >&2
        exit 1
    }
done

# 2. 安装基础工具
echo "第二步：安装基础工具..."
base_tools=(
    iputils-ping
    net-tools
    ifupdown
    wpasupplicant
    openssh-server
    sudo
    vim
    curl
    wget
    rsyslog
    bash-completion
)

apt-get install -y --no-install-recommends "${base_tools[@]}" || {
    echo "基础工具安装失败" >&2
    exit 1
}

# 3. 安装其他工具
echo "安装其他工具..."
other_tools=(
    htop
    python3-pip
    u-boot-tools
    gpiod
    libgpiod-dev
)
apt-get install -y --no-install-recommends "${other_tools[@]}"
EOF

# 4. 选择性安装网络管理工具
if [ "$TARGET" = "minimal" ]; then
    echo "安装最小网络配置..."
    cat << 'EOF' | chroot "$ROOTFS_DIR" /usr/bin/qemu-aarch64-static /bin/bash
apt-get install -y --no-install-recommends ifupdown

EOF

else
    echo "安装NetworkManager..."
    cat << 'EOF' | chroot "$ROOTFS_DIR" /usr/bin/qemu-aarch64-static /bin/bash
network_packages=(
    network-manager
    netplan.io
    wireless-tools
)
apt-get install -y --no-install-recommends "${network_packages[@]}" || {
    echo "网络工具安装失败" >&2
    exit 1
}

EOF
fi
# 5. 桌面环境安装
if [ "$TARGET" = "xfce" ]; then
    echo "安装Xfce桌面环境..."
    cat << 'EOF' | chroot "$ROOTFS_DIR" /usr/bin/qemu-aarch64-static /bin/bash
desktop_packages=(
    xubuntu-core
    lightdm
    xfce4-terminal
    firefox
)
apt-get install -y --no-install-recommends "${desktop_packages[@]}" || {
    echo "桌面环境安装失败" >&2
    exit 1
}

EOF
fi

echo "配置系统设置..."
cat << 'EOF' | chroot "$ROOTFS_DIR" /usr/bin/qemu-aarch64-static /bin/bash
# 系统配置

# 用户配置
if ! id -u wqy >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo wqy || {
        echo "创建用户失败" >&2
        exit 1
    }
fi
echo "wqy:wqy123456" | chpasswd || echo "警告: 设置wqy密码失败" >&2
echo "root:root" | chpasswd || echo "警告: 设置root密码失败" >&2

# 系统设置
echo "tspi-ubuntu" > /etc/hostname
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "vm.swappiness=10" >> /etc/sysctl.conf

# 配置sudo
echo "wqy ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/cat-user
chmod 440 /etc/sudoers.d/cat-user

# 网络配置
mkdir -p /etc/network/interfaces.d
cat > /etc/network/interfaces << 'EOL'
auto lo
iface lo inet loopback
source-directory /etc/network/interfaces.d
EOL

# 配置DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 114.114.114.114" >> /etc/resolv.conf

# 清理
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EOF
echo "系统配置完成!"

# 检查执行结果
if [ $? -ne 0 ]; then
    echo "配置过程中出现错误"
else
    echo "系统配置成功完成"
fi

# 卸载虚拟文件系统
echo "卸载虚拟文件系统..."
./ch-mount.sh -u "$ROOTFS_DIR" || {
    echo "卸载失败" >&2
    exit 1
}

# 打包文件系统
echo "打包文件系统: $OUTPUT_FILE"
tar -zcf $OUTPUT_FILE -C $ROOTFS_DIR .

# 清理
rm -rf $ROOTFS_DIR
echo "======================================"
echo "构建成功! 输出文件: $OUTPUT_FILE"
echo "======================================"

FROM multiarch/qemu-user-static:x86_64-aarch64 as qemu

FROM ubuntu:24.04
COPY --from=qemu /usr/bin/qemu-aarch64-static /usr/bin

#维护者
MAINTAINER wuqiyang

# 设置环境变量，用于非交互式安装
ENV DEBIAN_FRONTEND=noninteractive

# 安装依赖工具
RUN apt update && \
    apt install -y curl bash

RUN curl -sSL https://linuxmirrors.cn/main.sh -o /tmp/main.sh && \
    bash /tmp/main.sh \
        --source mirrors.tuna.tsinghua.edu.cn \
        --protocol https \
        --ignore-backup-tips

RUN apt update \
    && apt -f install -y --no-install-recommends \
    && apt install --no-install-recommends -y \
        locales apt-utils binfmt-support \
        make sudo cpio bzip2 curl wget \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN localedef -c -f UTF-8 -i zh_CN zh_CN.utf8

ENV LANG zh_CN.utf8

#容器使用这个内核方法
# docker run --privileged --mount type=bind,source=/home/wuqiyang/linux/linux_sdk/ubuntu_rootfs/,target=/ubuntu_rootfs --name="ubuntu_rootfs" -it ubuntu_rootfs

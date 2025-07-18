# ubuntu-rootfs

```bash 
cat << 'EOF' | sudo -i
docker build . -t ubuntu-rootfs

cat << 'EOR' | docker run --privileged --mount type=bind,source=/home/wuqiyang/linux/linux_sdk/ubuntu_rootfs/,target=/ubuntu_rootfs --name="ubuntu_rootfs" -it ubuntu-rootfs

bash ./rk-rootfx-build.sh
bash ./rootfs-img.sh
EOR
EOF

# docker exec -it ubuntu_rootf /bin/bash
```

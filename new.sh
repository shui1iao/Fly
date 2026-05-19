#!/bin/bash
VERSION="0.1.1"

# 1. 环境检查
if [[ $EUID -ne 0 ]]; then
   echo "错误: 请使用 root 权限运行此脚本。"
   exit 1
fi

echo "=================================================="
echo "          服务器初始化与网络优化脚本"
echo "=================================================="

# 2. 更新系统并安装基础软件与 tcping 依赖
echo -e "\n[1/5] 更新软件源并安装基础组件..."
apt update && apt install curl wget unzip sudo iperf3 systemd-timesyncd tcptraceroute -y

# 3. 配置 SSH 密钥并实施硬化
echo -e "\n[2/5] 配置 SSH 密钥与安全策略..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh
curl -sSLf https://github.com/shuijiao1.keys >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

sed -i -e 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' \
       -e 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' \
       -e 's/^#\?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' \
       -e 's/^#\?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config

systemctl restart ssh
systemctl enable --now systemd-timesyncd

# 4. 安装网络测试工具
echo -e "\n[3/5] 安装 NextTrace..."
curl -sL https://nxtrace.org/nt | bash

echo -e "\n[4/5] 安装 tcping 与 Speedtest..."
wget http://www.vdberg.org/~richard/tcpping -O /usr/bin/tcping
chmod +x /usr/bin/tcping

curl -sL https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
apt-get install speedtest -y

# 5. 交互式 BBR 配置
echo -e "\n[5/5] 网络拥塞控制 (BBR) 配置"
echo "请选择适合您当前网络环境的 BBR 配置方案："
echo "  1) BBR (通用) "
echo "  2) BBR (大窗口) "
echo "  3) 跳过"
read -p "请输入选项 [1/2/3]: " BBR_CHOICE

# 写入主配置文件
SYSCTL_FILE="/etc/sysctl.d/99-custom.conf"

if [[ "$BBR_CHOICE" == "1" ]]; then
    echo "正在应用 BBR (通用) 配置..."
    cat > $SYSCTL_FILE << EOF
fs.file-max = 6815744
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.core.rmem_max=33554432
net.core.wmem_max=33554432
net.ipv4.tcp_rmem=4096 87380 33554432
net.ipv4.tcp_wmem=4096 16384 33554432
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.ipv4.ip_forward=1
net.ipv4.conf.all.route_localnet=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.default.forwarding=1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
EOF
    sysctl --system
    echo "BBR (通用) 已生效。"

elif [[ "$BBR_CHOICE" == "2" ]]; then
    echo "正在应用 BBR (大窗口) 配置..."
    cat > $SYSCTL_FILE << EOF
fs.file-max = 6815744
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 16384 67108864
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.ipv4.ip_forward=1
net.ipv4.conf.all.route_localnet=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.default.forwarding=1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
EOF
    sysctl --system
    echo "BBR (大窗口) 已生效。"

else
    echo "已跳过 BBR 配置。"
fi

echo -e "\n=================================================="
echo "初始化完成！请检查上述步骤是否有报错。"
echo "=================================================="

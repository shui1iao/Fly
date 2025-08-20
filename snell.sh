#!/bin/bash

# ==============================================================================
# Snell v5 自动化安装脚本
# ==============================================================================

# --- 步骤 1: 权限检查 ---
if [ "$(id -u)" -ne 0 ]; then
   echo "错误：此脚本需要以 root 权限运行。" >&2
   exit 1
fi

# --- 步骤 2: 更新软件包列表并安装必要工具 ---
echo "-->更新软件包列表并安装必要工具 (nano, wget, unzip)..."
apt-get update > /dev/null
apt-get install -y nano wget unzip > /dev/null
if [ $? -ne 0 ]; then
    echo "错误：工具安装失败。请检查 apt 源或网络连接。"
    exit 1
fi
echo "    工具安装完成。"

# --- 步骤 3: 下载、解压并部署 Snell ---
echo "--> 正在下载、解压并部署 Snell 服务器程序..."
wget -q --show-progress https://dl.nssurge.com/snell/snell-server-v5.0.0-linux-amd64.zip -O snell.zip
if [ $? -ne 0 ]; then
    echo "错误：Snell 下载失败！请检查网络或链接是否有效。"
    exit 1
fi

unzip -o snell.zip -d /usr/local/bin/ > /dev/null
chmod +x /usr/local/bin/snell-server
mkdir -p /etc/snell
rm snell.zip
echo "    Snell 程序部署完成。"

# --- 步骤 4: 用户输入端口和密码 ---
# 提示用户输入端口，留空则随机生成
read -p "请输入 Snell 的监听端口 (留空则随机生成): " snell_port
if [ -z "${snell_port}" ]; then
    while true; do
        # 生成 30001 到 65535 之间的随机端口
        snell_port=$(shuf -i 30001-65535 -n 1)
        # 检查端口是否可用
        if ! ss -lntu | grep -q ":${snell_port} "; then
            echo "    端口未输入，使用随机端口: ${snell_port}"
            break
        fi
    done
fi

# 提示用户输入密码，留空则随机生成
read -p "请输入 Snell 的密码 (PSK，留空则随机生成): " snell_psk
if [ -z "${snell_psk}" ]; then
    # 生成一个16位的、包含大小写字母、数字和特殊符号的复杂密码
    snell_psk=$(< /dev/urandom tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' | head -c 16)
    echo "    密码未输入，使用随机密码: ${snell_psk}"
fi

# --- 步骤 5: 配置确认 ---
echo ""
echo "============================================="
echo "端口 (Port):      ${snell_port}"
echo "密码 (PSK):       ${snell_psk}"
echo "============================================="
echo "安装将在 2 秒后继续，按 Ctrl+C 取消"
sleep 2

# --- 步骤 6: 生成配置文件并启动服务 ---
echo "--> (3/3) 正在创建配置文件..."
cat > /etc/snell/snell-server.conf <<EOF
[snell-server]
listen = ::0:${snell_port}
psk = ${snell_psk}
EOF

echo "--> 正在创建 systemd 服务并启动..."
cat > /etc/systemd/system/snell.service <<EOF
[Unit]
Description=Snell Proxy Service
After=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
LimitNOFILE=32768
ExecStart=/usr/local/bin/snell-server -c /etc/snell/snell-server.conf
AmbientCapabilities=CAP_NET_BIND_SERVICE
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=snell-server

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable snell > /dev/null 2>&1
systemctl restart snell

# --- 步骤 7: 显示结果 ---
echo "--> 正在获取服务器公网 IP 地址..."
ip_address=$(curl -s https://ipv4.icanhazip.com || curl -s https://api.ipify.org)

echo ""
echo "=================================================="
echo "🎉 Snell 服务器安装并配置成功！"
echo ""
echo "--------------- 服务状态 ---------------"
if systemctl is-active --quiet snell; then
  echo "状态: Active (running)"
else
  echo "状态: Inactive (dead) - 请使用 'journalctl -u snell' 查看日志"
fi
echo ""
echo "---------- 客户端配置信息 ----------"
echo "在Surge使用以下配置："
echo ""
echo "vps = snell, ${ip_address}, ${snell_port}, psk=${snell_psk}, version=5"
echo ""
echo "=================================================="

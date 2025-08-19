#!/bin/bash

# ==============================================================================
# Sing-box 安装脚本 (AnyTLS + SS2022 + ShadowTLS)
# ==============================================================================

# --- 步骤 1: 环境检查与核心程序安装 ---

# 确保脚本以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
   echo "错误：此脚本需要以 root 权限运行。" >&2
   exit 1
fi

echo "--> 准备环境并安装 sing-box 核心程序..."
echo ""

echo "--> 正在安装必要工具 (curl, openssl)..."
apt-get update > /dev/null
apt-get install -y curl openssl > /dev/null
if [ $? -ne 0 ]; then
    echo "错误：基础工具安装失败。请检查 apt 源或网络连接。"
    exit 1
fi
echo "    基础工具安装完成。"

echo "--> 正在下载并安装 sing-box (beta)..."
curl -fsSL https://sing-box.app/install.sh | sh -s -- --beta
if [ $? -ne 0 ]; then
    echo "错误：sing-box 安装失败。"
    exit 1
fi
echo "    sing-box 安装成功。"
echo ""


# --- 步骤 2: 用户交互与配置 ---

echo "--> 请输入您的配置信息..."
echo "    (对于端口和部分密码，留空将使用默认或随机值)"
echo ""

read -p "请输入您的域名 (用于证书和SNI，例如 my.domain.com): " domain
if [ -z "$domain" ]; then
    echo "错误：域名不能为空！"
    exit 1
fi

# 端口分配逻辑
read -p "请输入 AnyTLS 的监听端口 (留空则随机): " anytls_port
read -p "请输入 ShadowTLS 的监听端口 (留空则默认为 8443): " shadowtls_port
read -p "请输入 Shadowsocks 的 UDP 端口 (留空则随机): " ss_port

# 如果 shadowtls_port 为空，分配默认值
[ -z "$shadowtls_port" ] && shadowtls_port="8443"

# 为 anytls_port 和 ss_port 分配随机端口
if [ -z "$anytls_port" ]; then
    while true; do
        anytls_port=$(shuf -i 30001-65535 -n 1)
        if ! ss -lntu | grep -q ":${anytls_port} "; then break; fi
    done
fi

if [ -z "$ss_port" ]; then
    while true; do
        ss_port=$(shuf -i 30001-65535 -n 1)
        if [[ "${ss_port}" != "${anytls_port}" ]] && ! ss -lntu | grep -q ":${ss_port} "; then break; fi
    done
fi

# 密码分配逻辑
read -p "请输入 AnyTLS 的密码 (留空则随机生成): " anytls_password
read -p "请输入 ShadowTLS 的密码 ( 留空则随机生成): " stls_password
read -p "请输入 Shadowsocks 的密码 ( 留空则自动生成): " ss_password

[ -z "$anytls_password" ] && anytls_password=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 16 | head -n 1)
[ -z "$stls_password" ] && stls_password=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 16 | head -n 1)

# 如果 ss_password 为空，立即使用 sing-box 命令生成
if [ -z "$ss_password" ]; then
    ss_password=$(sing-box generate rand --base64 16)
    echo "    -> 已生成随机密码: ${ss_password}"
fi

# --- 步骤 3: 配置确认与最终部署 ---

echo ""
echo "--> 配置信息"
echo "============================================="
echo "             最终配置详情"
echo "============================================="
echo "域名 (Domain/SNI):     ${domain}"
echo "---------------------------------------------"
echo "AnyTLS 端口:           ${anytls_port}"
echo "AnyTLS 密码:           ${anytls_password}"
echo "---------------------------------------------"
echo "ShadowTLS 端口:        ${shadowtls_port}"
echo "ShadowTLS 密码:        ${stls_password}"
echo "---------------------------------------------"
echo "Shadowsocks 端口:      ${ss_port}"
echo "Shadowsocks 密码:      ${ss_password}"
echo "============================================="
echo "配置将在 2 秒后应用，按 Ctrl+C 取消"
sleep 2

echo "--> 正在生成自签名证书..."
mkdir -p /etc/sing-box/cert
openssl ecparam -genkey -name prime256v1 -out /etc/sing-box/cert/private.key
openssl req -new -x509 -days 36500 -key /etc/sing-box/cert/private.key -out /etc/sing-box/cert/cert.pem -subj "/CN=${domain}"
echo "    证书生成完毕。"

echo "--> 正在创建 sing-box 配置文件..."
cat > /etc/sing-box/config.json <<EOF
{
    "inbounds": [
        {
            "type": "anytls",
            "tag": "anytls-in",
            "listen": "::",
            "listen_port": ${anytls_port},
            "users": [
                {
                    "password": "${anytls_password}"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "${domain}",
                "certificate_path": "/etc/sing-box/cert/cert.pem",
                "key_path": "/etc/sing-box/cert/private.key"
            }
        },
        {
            "type": "shadowtls",
            "tag": "shadowtls-in",
            "listen": "::",
            "listen_port": ${shadowtls_port},
            "detour": "ss-in",
            "version": 3,
            "users": [
                {
                    "password": "${stls_password}"
                }
            ],
            "handshake": {
                "server": "${domain}",
                "server_port": 443
            },
            "strict_mode": true
        },
        {
            "type": "shadowsocks",
            "tag": "ss-in",
            "listen": "::",
            "listen_port": ${ss_port},
            "method": "2022-blake3-aes-128-gcm",
            "password": "${ss_password}",
            "udp_fragment": true
        }
    ]
}
EOF
echo "    配置文件创建成功。"

echo "--> 正在启动并设置 sing-box 开机自启..."
systemctl restart sing-box
systemctl enable sing-box

# --- 步骤 4: 显示结果 ---

echo ""
echo "=================================================="
echo "🎉 sing-box 安装并配置成功！"
echo ""
echo "--------------- 服务状态 ---------------"
systemctl status sing-box --no-pager -l | grep -E "Loaded|Active|Main PID"
echo ""
echo "=================================================="
echo ""
echo "---------- 客户端配置信息 (AnyTLS) ----------"
echo "请将下面的 JSON 代码块复制到支持的客户端中："
echo '{
    "name": "AnyTLS-'$ip_address'",
    "type": "anytls",
    "server": "'$ip_address'",
    "port": '$anytls_port',
    "password": "'$anytls_password'",
    "client-fingerprint": "chrome",
    "udp": true,
    "sni": "'$domain'",
    "skip-cert-verify": true
}'
echo ""
echo "---------- 客户端配置信息 (ShadowTLS + SS2022) ----------"
echo "请将下面的 Surge 格式节点信息复制到客户端中："
echo "SS-ShadowTLS = ss, ${ip_address}, ${shadowtls_port}, encrypt-method=2022-blake3-aes-128-gcm, password=${ss_password}, shadow-tls-password=${stls_password}, shadow-tls-sni=${domain}, shadow-tls-version=3, udp-relay=true, udp-port=${ss_port}"
echo ""
echo "=================================================="

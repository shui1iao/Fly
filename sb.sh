#!/bin/bash

# ==============================================================================
# Sing-box 管理脚本 (模块化配置)
# ==============================================================================

# --- 函数: 检查 sing-box 安装和运行状态 ---
check_singbox_status() {
    # 检查 sing-box 是否安装
    if [ -f /usr/local/bin/sing-box ] && [ -f /etc/sing-box/config.json ]; then
        echo -e "\033[32msing-box 状态: 已安装并已配置\033[0m"
    elif [ -f /usr/local/bin/sing-box ]; then
        echo -e "\033[33msing-box 状态: 核心已安装，但未配置协议\033[0m"
    else
        echo -e "\033[31msing-box 状态: 未安装\033[0m"
    fi

    # 检查 sing-box 服务是否运行
    if systemctl is-active --quiet sing-box; then
        echo -e "\033[32m服务状态: 运行中\033[0m"
    else
        echo -e "\033[31m服务状态: 未运行\033[0m"
    fi
}

# --- 函数: 显示菜单 ---
show_menu() {
    echo ""
    check_singbox_status
    echo "=================================================="
    echo "           sing-box 管理脚本"
    echo "=================================================="
    echo "1. 安装 / 更新 sing-box 核心"
    echo "2. 配置 AnyTLS"
    echo "3. 配置 Shadowsocks (2022)"
    echo "4. 配置 ShadowTLS"
    echo "0. 退出脚本"
    echo "=================================================="
    echo -n "请输入选项 [0-4]: "
}

# --- 函数: 检查 root 权限 ---
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "错误：此脚本需要以 root 权限运行。" >&2
        exit 1
    fi
}

# --- 函数: 安装核心程序及依赖 ---
install_core() {
    echo "--> 正在安装必要工具 (curl, openssl)..."
    if ! apt-get update > /dev/null; then
        echo "错误：软件包列表更新失败。请检查网络连接或 apt 源。"
        exit 1
    fi
    if ! apt-get install -y curl openssl > /dev/null; then
        echo "错误：工具安装失败。请检查 apt 源或网络连接。"
        exit 1
    fi
    echo "    工具安装完成。"

    echo "--> 正在下载并安装 sing-box (beta)..."
    if ! curl -fsSL https://sing-box.app/install.sh | sh -s -- --beta; then
        echo "错误：sing-box 安装失败。"
        exit 1
    fi
    echo "    sing-box 安装成功。"
}

# --- 函数: 安装/更新 sing-box 核心 ---
install_singbox_core() {
    install_core
    echo ""
    echo -e "\033[32msing-box 核心安装/更新成功。\033[0m"
    echo "现在，请从菜单中选择一个协议进行配置。"
}


# --- 函数: 生成自签名证书 ---
generate_certificate() {
    local domain=$1
    echo "--> 正在生成自签名证书..."
    mkdir -p /etc/sing-box/cert
    if ! openssl ecparam -genkey -name prime256v1 -out /etc/sing-box/cert/private.key; then
        echo "错误：生成私钥失败。"
        exit 1
    fi
    if ! openssl req -new -x509 -days 36500 -key /etc/sing-box/cert/private.key -out /etc/sing-box/cert/cert.pem -subj "/CN=${domain}"; then
        echo "错误：生成证书失败。"
        exit 1
    fi
    echo "    证书生成完毕。"
}

# --- 函数: 获取公网 IP ---
get_public_ip() {
    ip_address=$(curl -s https://ipv4.icanhazip.com || curl -s https://api.ipify.org)
    if [ -z "$ip_address" ]; then
        echo "警告：无法获取公网 IP 地址，请手动检查。"
        ip_address="<您的服务器IP>"
    fi
    echo "$ip_address"
}

# --- 函数: 配置 AnyTLS ---
install_anytls() {
    if [ ! -f /usr/local/bin/sing-box ]; then
        echo "sing-box 核心未安装，将首先为您安装核心..."
        install_core
    fi

    echo "--> 请输入 AnyTLS 配置信息..."
    read -p "请输入您的域名 (用于证书和SNI，例如 my.domain.com): " domain
    if [ -z "$domain" ]; then
        echo "错误：域名不能为空！"
        return 1
    fi

    read -p "请输入 AnyTLS 的监听端口 (留空则随机): " anytls_port
    if [ -z "$anytls_port" ]; then
        while true; do
            anytls_port=$(shuf -i 30001-65535 -n 1)
            if ! ss -lntu | grep -q ":${anytls_port} "; then break; fi
        done
        echo "    AnyTLS 端口未输入，使用随机端口: ${anytls_port}"
    fi

    read -p "请输入 AnyTLS 的密码 (留空则随机生成): " anytls_password
    if [ -z "$anytls_password" ]; then
        anytls_password=$(< /dev/urandom tr -dc 'A-Za-z0-9@%$^&/-_+' | head -c 16)
        echo "    AnyTLS 密码未输入，使用随机密码: ${anytls_password}"
    fi

    echo ""
    echo "--> 配置信息"
    echo "============================================="
    echo "域名 (Domain/SNI):     ${domain}"
    echo "AnyTLS 端口:           ${anytls_port}"
    echo "AnyTLS 密码:           ${anytls_password}"
    echo "============================================="
    echo "配置将在 2 秒后应用，按 Ctrl+C 取消"
    sleep 2

    generate_certificate "$domain"

    echo "--> 正在创建 AnyTLS 配置文件..."
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
        }
    ]
}
EOF
    echo "    配置文件创建成功。"

    echo "--> 正在启动并设置 sing-box 开机自启..."
    systemctl restart sing-box
    systemctl enable sing-box

    ip_address=$(get_public_ip)

    echo ""
    echo "=================================================="
    echo "🎉 AnyTLS 安装并配置成功！"
    echo ""
    echo "--------------- 服务状态 ---------------"
    systemctl status sing-box --no-pager -l | grep -E "Loaded|Active|Main PID"
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
    echo "=================================================="
}

# --- 函数: 配置 Shadowsocks ---
install_shadowsocks() {
    if [ ! -f /usr/local/bin/sing-box ]; then
        echo "sing-box 核心未安装，将首先为您安装核心..."
        install_core
    fi

    echo "--> 请输入 Shadowsocks 配置信息..."
    read -p "请输入 Shadowsocks 的监听端口 (留空则随机): " ss_port
    if [ -z "$ss_port" ]; then
        while true; do
            ss_port=$(shuf -i 30001-65535 -n 1)
            if ! ss -lntu | grep -q ":${ss_port} "; then break; fi
        done
        echo "    Shadowsocks 端口未输入，使用随机端口: ${ss_port}"
    fi

    read -p "请输入 Shadowsocks 的密码 (留空则自动生成): " ss_password
    if [ -z "$ss_password" ]; then
        ss_password=$(sing-box generate rand --base64 16)
        echo "    Shadowsocks 密码未输入，使用随机密码: ${ss_password}"
    fi

    echo ""
    echo "--> 配置信息"
    echo "============================================="
    echo "Shadowsocks 端口:    ${ss_port}"
    echo "Shadowsocks 密码:    ${ss_password}"
    echo "============================================="
    echo "配置将在 2 秒后应用，按 Ctrl+C 取消"
    sleep 2

    echo "--> 正在创建 Shadowsocks 配置文件..."
    cat > /etc/sing-box/config.json <<EOF
{
    "inbounds": [
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

    ip_address=$(get_public_ip)

    echo ""
    echo "=================================================="
    echo "🎉 Shadowsocks 安装并配置成功！"
    echo ""
    echo "--------------- 服务状态 ---------------"
    systemctl status sing-box --no-pager -l | grep -E "Loaded|Active|Main PID"
    echo ""
    echo "---------- 客户端配置信息 (Shadowsocks) ----------"
    echo "请将下面的 Surge 格式节点信息复制到客户端中："
    echo "SS = ss, ${ip_address}, ${ss_port}, encrypt-method=2022-blake3-aes-128-gcm, password=${ss_password}, udp-relay=true"
    echo ""
    echo "=================================================="
}

# --- 函数: 配置 ShadowTLS ---
install_shadowtls() {
    if [ ! -f /usr/local/bin/sing-box ]; then
        echo "sing-box 核心未安装，将首先为您安装核心..."
        install_core
    fi

    echo "--> 请输入 ShadowTLS 配置信息..."
    read -p "请输入您的域名 (用于 SNI，例如 my.domain.com): " domain
    if [ -z "$domain" ]; then
        echo "错误：域名不能为空！"
        return 1
    fi

    read -p "请输入 ShadowTLS 的监听端口 (留空则默认为 443): " shadowtls_port
    [ -z "$shadowtls_port" ] && shadowtls_port="443"

    read -p "请输入 Shadowsocks 的本地端口 (留空则随机): " ss_port
    if [ -z "$ss_port" ]; then
        while true; do
            ss_port=$(shuf -i 30001-65535 -n 1)
            if [[ "${ss_port}" != "${shadowtls_port}" ]] && ! ss -lntu | grep -q ":${ss_port} "; then break; fi
        done
        echo "    Shadowsocks 本地端口未输入，使用随机端口: ${ss_port}"
    fi

    read -p "请输入 ShadowTLS 的密码 (留空则随机生成): " stls_password
    if [ -z "$stls_password" ]; then
        stls_password=$(< /dev/urandom tr -dc 'A-Za-z0-9@%$^&/-_+' | head -c 16)
        echo "    ShadowTLS 密码未输入，使用随机密码: ${stls_password}"
    fi

    read -p "请输入 Shadowsocks 的密码 (留空则自动生成): " ss_password
    if [ -z "$ss_password" ]; then
        ss_password=$(sing-box generate rand --base64 16)
        echo "    Shadowsocks 密码未输入，使用随机密码: ${ss_password}"
    fi

    echo ""
    echo "--> 配置信息"
    echo "============================================="
    echo "域名 (Domain/SNI):    ${domain}"
    echo "ShadowTLS 端口:       ${shadowtls_port}"
    echo "ShadowTLS 密码:       ${stls_password}"
    echo "Shadowsocks 密码:     ${ss_password}"
    echo "(Shadowsocks 本地端口: ${ss_port})"
    echo "============================================="
    echo "配置将在 2 秒后应用，按 Ctrl+C 取消"
    sleep 2

    echo "--> 正在创建 ShadowTLS + SS 配置文件..."
    cat > /etc/sing-box/config.json <<EOF
{
    "inbounds": [
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
            "listen": "127.0.0.1",
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

    ip_address=$(get_public_ip)

    echo ""
    echo "=================================================="
    echo "🎉 ShadowTLS 安装并配置成功！"
    echo ""
    echo "--------------- 服务状态 ---------------"
    systemctl status sing-box --no-pager -l | grep -E "Loaded|Active|Main PID"
    echo ""
    echo "---------- 客户端配置信息 (ShadowTLS + SS2022) ----------"
    echo "请将下面的 Surge 格式节点信息复制到客户端中："
    echo "SS-ShadowTLS = ss, ${ip_address}, ${shadowtls_port}, encrypt-method=2022-blake3-aes-128-gcm, password=${ss_password}, shadow-tls-password=${stls_password}, shadow-tls-sni=${domain}, shadow-tls-version=3, udp-relay=true"
    echo ""
    echo "=================================================="
}

# --- 主程序: 检查 root 权限并显示菜单 ---
check_root

while true; do
    show_menu
    read choice
    case $choice in
        1)
            install_singbox_core
            ;;
        2)
            install_anytls
            ;;
        3)
            install_shadowsocks
            ;;
        4)
            install_shadowtls
            ;;
        0)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效选项，请输入 0-4。"
            ;;
    esac
    echo ""
    echo "按 Enter 键返回菜单..."
    read -r
done

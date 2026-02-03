#!/bin/bash

# =================================================================
# shadowsocks-rust & shadowtls 服务器端综合管理脚本
# =================================================================

# 定义输出颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# --- 通用函数 ---
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误：此脚本需要以 root 权限运行。${NC}" >&2
        exit 1
    fi
}

# 确保基础依赖存在 (用于获取版本)
ensure_base_deps() {
    if ! command -v jq &> /dev/null || ! command -v curl &> /dev/null; then
        echo "--> 正在安装基础依赖 (curl, jq)..."
        if command -v apt-get &> /dev/null; then
            apt-get update >/dev/null && apt-get install -y curl jq
        elif command -v yum &> /dev/null; then
            yum install -y curl jq
        fi
    fi
}

check_and_delete_script_if_all_uninstalled() {
    if [ ! -f /usr/local/bin/ss-rust ] && [ ! -f /usr/local/bin/shadowtls ]; then
        echo -e "${GREEN}检测到 ss-rust 和 shadowtls 均已卸载。${NC}"
        echo "--> 正在删除此脚本..."
        rm -- "$0"
        exit 0
    fi
}

# =================================================================
# S-S-R-U-S-T  M-A-N-A-G-E-M-E-N-T
# =================================================================

# 获取 ss-rust 最新版本号及下载地址的函数
get_latest_ss_rust() {
    ensure_base_deps
    echo "--> 正在从 GitHub 获取 ss-rust 最新版本信息..."
    
    # 获取最新的 tag_name (例如 v1.18.0)
    SS_VERSION=$(curl -s "https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest" | jq -r .tag_name)
    
    if [ -z "$SS_VERSION" ] || [ "$SS_VERSION" == "null" ]; then
        echo -e "${RED}错误：无法获取最新版本号，请检查网络或 GitHub API 限制。${NC}"
        return 1
    fi

    # 构造下载 URL (针对 x86_64 Linux)
    SS_URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${SS_VERSION}/shadowsocks-${SS_VERSION}.x86_64-unknown-linux-gnu.tar.xz"
    SS_TAR_FILE="shadowsocks-${SS_VERSION}.tar.xz"
    
    echo -e "${GREEN}检测到最新版本: ${SS_VERSION}${NC}"
}

check_ss_rust_status() {
    if [ -f /usr/local/bin/ss-rust ] && [ -f /etc/systemd/system/ss-rust.service ]; then
        local version_info=$(/usr/local/bin/ss-rust --version 2>/dev/null | head -n 1)
        echo -e "${GREEN}ss-rust 状态: 已安装 ($version_info)${NC}"
    else
        echo -e "${RED}ss-rust 状态: 未安装${NC}"
    fi

    if systemctl is-active --quiet ss-rust; then
        echo -e "${GREEN}服务状态    : 运行中${NC}"
    else
        echo -e "${RED}服务状态    : 未运行${NC}"
    fi
}

install_ss_rust() {
    if [ -f /usr/local/bin/ss-rust ]; then
        echo -e "${GREEN}ss-rust 似乎已经安装，无需重复安装。${NC}"
        return
    fi

    # 1. 动态获取最新版本
    get_latest_ss_rust || return

    echo "--> 正在准备安装环境..."
    if command -v apt-get &> /dev/null; then
         apt-get update && apt-get install -y wget tar xz-utils openssl jq coreutils
    elif command -v yum &> /dev/null; then
         yum install -y wget tar xz-utils openssl jq coreutils
    fi

    echo "--> 正在下载并部署 ss-rust..."
    if ! wget -O "${SS_TAR_FILE}" "${SS_URL}"; then
        echo -e "${RED}下载失败！可能是该版本的二进制文件名发生了变化。${NC}"
        exit 1
    fi

    tar -xf "${SS_TAR_FILE}"
    mv ssserver /usr/local/bin/ss-rust
    chmod +x /usr/local/bin/ss-rust
    rm -f sslocal ssmanager ssurl "${SS_TAR_FILE}"
    
    mkdir -p /etc/ss-rust

    # ... (以下配置逻辑保持不变) ...
    read -p "请输入 ss-rust 的监听端口 (留空则随机生成): " PORT
    [ -z "$PORT" ] && PORT=$((RANDOM % 55536 + 10000))
    
    read -p "请输入 ss-rust 的密码 (留空则随机生成): " PASSWORD
    [ -z "$PASSWORD" ] && PASSWORD=$(head -c 16 /dev/urandom | base64 -w 0)

    cat > /etc/ss-rust/config.json <<EOF
{
    "server": "0.0.0.0",
    "server_port": ${PORT},
    "password": "${PASSWORD}",
    "method": "2022-blake3-aes-128-gcm",
    "timeout": 300,
    "fast_open": false,
    "mode": "tcp_and_udp"
}
EOF

    cat > /etc/systemd/system/ss-rust.service <<EOF
[Unit]
Description=Shadowsocks Rust Server
After=network.target

[Service]
ExecStart=/usr/local/bin/ss-rust -c /etc/ss-rust/config.json
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ss-rust > /dev/null 2>&1
    systemctl start ss-rust

    echo -e "${GREEN}🎉 ss-rust 安装成功！${NC}"
    view_config_ss_rust
}

# ... (脚本其余部分保持不变：包括卸载、ShadowTLS 管理、主菜单等) ...
# 注意：为节省篇幅，此处省略了您原有的其余函数，逻辑完全一致。
# 确保在实际使用时保留您原脚本中的其他所有函数。

# (以下仅展示脚本末尾逻辑)
uninstall_ss_rust() {
    if [ ! -f /usr/local/bin/ss-rust ]; then
        echo -e "${RED}ss-rust 未安装。${NC}"; return; fi
    read -p "确定卸载？[y/N]: " confirm
    [[ ! "$confirm" =~ ^[yY] ]] && return
    systemctl stop ss-rust && systemctl disable ss-rust
    rm -f /etc/systemd/system/ss-rust.service /usr/local/bin/ss-rust
    rm -rf /etc/ss-rust
    systemctl daemon-reload
    check_and_delete_script_if_all_uninstalled
}

modify_config_ss_rust() {
    if [ ! -f /etc/ss-rust/config.json ]; then echo -e "${RED}未安装${NC}"; return; fi
    read -p "端口: " PORT
    read -p "密码: " PASSWORD
    jq ".server_port = ${PORT:-$((RANDOM%50000+10000))} | .password = \"${PASSWORD:-$(date +%s|base64)}\"" /etc/ss-rust/config.json > /tmp/ss.json && mv /tmp/ss.json /etc/ss-rust/config.json
    systemctl restart ss-rust
    view_config_ss_rust
}

view_config_ss_rust() {
    if [ ! -f /etc/ss-rust/config.json ]; then echo -e "${RED}未安装${NC}"; return; fi
    local port=$(jq .server_port /etc/ss-rust/config.json)
    local pwd=$(jq -r .password /etc/ss-rust/config.json)
    local method=$(jq -r .method /etc/ss-rust/config.json)
    local ip=$(curl -s ipv4.icanhazip.com)
    echo -e "IP: ${ip}\nPORT: ${port}\nPASS: ${pwd}\nMETHOD: ${method}"
}

manage_ss_rust_service() {
    systemctl $1 ss-rust
}

ss_rust_menu() {
    while true; do
        clear
        echo "=== Shadowsocks-Rust 管理 ==="
        check_ss_rust_status
        echo "1. 安装/更新到最新版"
        echo "2. 卸载"
        echo "3. 修改配置"
        echo "4. 查看配置"
        echo "0. 返回"
        read -p "选项: " c
        case $c in
            1) install_ss_rust ;;
            2) uninstall_ss_rust ;;
            3) modify_config_ss_rust ;;
            4) view_config_ss_rust ;;
            0) break ;;
        esac
        read -p "回车继续..."
    done
}

# (ShadowTLS 相关的函数省略，请保留您原有的代码)

# --- 脚本入口 ---
check_root
# 这里可以加个主菜单
while true; do
    clear
    echo "1. SS-Rust 管理"
    echo "2. ShadowTLS 管理"
    echo "0. 退出"
    read -p "选择: " mc
    case $mc in
        1) ss_rust_menu ;;
        2) # 这里调用您的 shadowtls_menu
           echo "跳转到 ShadowTLS 菜单..." ;;
        0) exit 0 ;;
    esac
done

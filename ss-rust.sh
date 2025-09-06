#!/bin/bash

# =================================================================
# shadowsocks-rust 服务器端综合管理脚本
# 描述: 提供菜单式操作，用于安装、卸载、配置和管理 ss-rust 服务。
# =================================================================

# 定义输出颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 定义软件版本和下载链接
SS_VERSION="v1.23.5"
SS_URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${SS_VERSION}/shadowsocks-${SS_VERSION}.x86_64-unknown-linux-gnu.tar.xz"
SS_TAR_FILE="shadowsocks-${SS_VERSION}.x86_64-unknown-linux-gnu.tar.xz"

# --- 函数: 检查 ss-rust 安装和运行状态 ---
check_ss_rust_status() {
    # 检查 ss-rust 是否安装
    if [ -f /usr/local/bin/ss-rust ] && [ -f /etc/systemd/system/ss-rust.service ]; then
        echo -e "${GREEN}ss-rust 状态: 已安装${NC}"
    else
        echo -e "${RED}ss-rust 状态: 未安装${NC}"
    fi

    # 检查 ss-rust 服务是否运行
    if systemctl is-active --quiet ss-rust; then
        echo -e "${GREEN}服务状态: 运行中${NC}"
    else
        echo -e "${RED}服务状态: 未运行${NC}"
    fi
}

# --- 函数: 显示菜单 ---
show_menu() {
    clear
    echo "=================================================="
    echo "          shadowsocks-rust 综合管理脚本"
    echo "=================================================="
    check_ss_rust_status
    echo "--------------------------------------------------"
    echo "1. 安装 ss-rust"
    echo "2. 卸载 ss-rust"
    echo "3. 修改 ss-rust 配置 (端口/密码)"
    echo "4. 查看 ss-rust 配置"
    echo "5. 启动 ss-rust 服务"
    echo "6. 停止 ss-rust 服务"
    echo "7. 重启 ss-rust 服务"
    echo "8. 查看 ss-rust 运行状态"
    echo "0. 退出脚本"
    echo "=================================================="
    echo -n "请输入选项 [0-8]: "
}

# --- 函数: 检查 root 权限 ---
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误：此脚本需要以 root 权限运行。${NC}" >&2
        exit 1
    fi
}

# --- 函数: 确保 jq 已安装 ---
ensure_jq() {
    if ! command -v jq &> /dev/null; then
        echo "--> 检测到依赖工具 jq 未安装，正在尝试自动安装..."
        if command -v apt-get &> /dev/null; then
            apt-get update >/dev/null && apt-get install -y jq
        elif command -v yum &> /dev/null; then
            yum install -y jq
        else
            echo -e "${RED}无法自动安装 jq。请手动安装 (sudo apt install jq / sudo yum install jq) 后再试。${NC}"
            return 1
        fi
        if ! command -v jq &> /dev/null; then
            echo -e "${RED}jq 安装失败，请检查包管理器或手动安装。${NC}"
            return 1
        fi
        echo "    jq 安装成功。"
    fi
    return 0
}

# --- 函数: 安装 ss-rust ---
install_ss_rust() {
    if [ -f /usr/local/bin/ss-rust ]; then
        echo -e "${GREEN}ss-rust 似乎已经安装，无需重复安装。${NC}"
        return
    fi

    echo "--> 正在准备安装环境..."
    if command -v apt-get &> /dev/null; then
         apt-get update && apt-get install -y wget tar xz-utils openssl jq
    elif command -v yum &> /dev/null; then
         yum install -y wget tar xz-utils openssl jq
    else
         echo -e "${RED}无法确定包管理器，请手动安装 wget, tar, xz-utils, openssl, jq。${NC}"
         exit 1
    fi

    echo "--> 正在下载、解压并部署 ss-rust..."
    if ! wget -O "${SS_TAR_FILE}" "${SS_URL}"; then
        echo -e "${RED}下载 ss-rust 失败！请检查网络或链接是否有效。${NC}"
        exit 1
    fi

    if ! tar -xf "${SS_TAR_FILE}"; then
        echo -e "${RED}解压 ss-rust 失败！${NC}"
        rm -f "${SS_TAR_FILE}"
        exit 1
    fi
    mv ssserver /usr/local/bin/ss-rust
    chmod +x /usr/local/bin/ss-rust
    rm -f sslocal ssmanager ssurl "${SS_TAR_FILE}"
    echo "    ss-rust 程序部署完成。"
    
    mkdir -p /etc/ss-rust

    # --- 用户输入端口和密码 ---
    read -p "请输入 ss-rust 的监听端口 (留空则随机生成 10000-65535): " PORT
    if [ -z "$PORT" ]; then
        PORT=$((RANDOM % 55536 + 10000))
        echo -e "    端口未输入，使用随机端口: ${GREEN}$PORT${NC}"
    fi

    read -p "请输入 ss-rust 的密码 (留空则随机生成): " PASSWORD
    if [ -z "$PASSWORD" ]; then
        PASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9@%\$\^&/-_+' | head -c 16)
        echo -e "    密码未输入，使用随机密码: ${GREEN}$PASSWORD${NC}"
    fi

    # --- 创建配置文件 ---
    echo "--> 正在创建配置文件..."
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

    # --- 创建 systemd 服务文件 ---
    echo "--> 正在创建 systemd 服务..."
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

    # --- 启动服务 ---
    echo "--> 正在启动服务并设置开机自启..."
    systemctl daemon-reload
    systemctl enable ss-rust > /dev/null 2>&1
    systemctl start ss-rust

    echo -e "${GREEN}🎉 ss-rust 服务器安装并配置成功！${NC}"
    view_config
}

# --- 函数: 卸载 ss-rust ---
uninstall_ss_rust() {
    if [ ! -f /usr/local/bin/ss-rust ]; then
        echo -e "${RED}ss-rust 未安装，无需卸载。${NC}"
        return
    fi
    
    echo -e "${RED}警告：此操作将停止 ss-rust 服务并删除所有相关文件，包括此脚本本身。${NC}"
    read -p "您确定要继续吗？[y/N]: " confirm
    if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
        echo "卸载操作已取消。"
        return
    fi
    
    systemctl stop ss-rust
    systemctl disable ss-rust > /dev/null 2>&1
    
    rm -f /etc/systemd/system/ss-rust.service
    rm -f /usr/local/bin/ss-rust
    rm -rf /etc/ss-rust
    
    systemctl daemon-reload
    
    echo -e "${GREEN}ss-rust 已成功卸载。${NC}"
    echo "--> 正在删除此脚本..."
    rm -- "$0"
}

# --- 函数: 修改配置 ---
modify_config() {
    if [ ! -f /etc/ss-rust/config.json ]; then
        echo -e "${RED}ss-rust 未安装，无法修改配置。${NC}"
        return
    fi
    
    ensure_jq || return

    read -p "请输入新的监听端口 (留空则随机生成): " PORT
    if [ -z "$PORT" ]; then
        PORT=$((RANDOM % 55536 + 10000))
        echo -e "    端口未输入，使用随机端口: ${GREEN}$PORT${NC}"
    fi

    read -p "请输入新的密码 (留空则随机生成): " PASSWORD
    if [ -z "$PASSWORD" ]; then
        PASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9@%\$\^&/-_+' | head -c 16)
        echo -e "    密码未输入，使用随机密码: ${GREEN}$PASSWORD${NC}"
    fi

    # --- 更新配置文件 ---
    jq ".server_port = ${PORT} | .password = \"${PASSWORD}\"" /etc/ss-rust/config.json > /etc/ss-rust/config.json.tmp && mv /etc/ss-rust/config.json.tmp /etc/ss-rust/config.json

    systemctl restart ss-rust
    
    echo -e "${GREEN}🎉 ss-rust 配置已更新！${NC}"
    view_config
}

# --- 函数: 查看配置 ---
view_config() {
    if [ ! -f /etc/ss-rust/config.json ]; then
        echo -e "${RED}ss-rust 未安装，无法查看配置。${NC}"
        return
    fi
    
    ensure_jq || return
    
    local port=$(jq .server_port /etc/ss-rust/config.json)
    local password=$(jq -r .password /etc/ss-rust/config.json)
    local method=$(jq -r .method /etc/ss-rust/config.json)
    
    local ip_address=$(curl -s https://ipv4.icanhazip.com || curl -s https://api.ipify.org)
    if [ -z "$ip_address" ]; then
        ip_address="<您的服务器IP>"
    fi

    echo "------------------------------------------"
    echo "         ss-rust 当前配置信息"
    echo "------------------------------------------"
    echo -e "端口 (Port)      : ${GREEN}${port}${NC}"
    echo -e "密码 (Password)  : ${GREEN}${password}${NC}"
    echo -e "加密 (Method)    : ${GREEN}${method}${NC}"
    echo "------------------------------------------"
    echo "Surge 客户端配置:"
    echo -e "${GREEN}VPS = ss, ${ip_address}, ${port}, encrypt-method=${method}, password=${password}, udp-relay=true${NC}"
    echo "------------------------------------------"
}

# --- 函数: 启动服务 ---
start_ss_rust() {
    if systemctl is-active --quiet ss-rust; then
        echo -e "${GREEN}ss-rust 服务已经在运行中。${NC}"
    else
        systemctl start ss-rust && echo -e "${GREEN}ss-rust 服务启动成功。${NC}" || echo -e "${RED}ss-rust 服务启动失败。${NC}"
    fi
}

# --- 函数: 停止服务 ---
stop_ss_rust() {
    if ! systemctl is-active --quiet ss-rust; then
        echo -e "${GREEN}ss-rust 服务当前未运行。${NC}"
    else
        systemctl stop ss-rust && echo -e "${GREEN}ss-rust 服务已停止。${NC}" || echo -e "${RED}ss-rust 服务停止失败。${NC}"
    fi
}

# --- 函数: 重启服务 ---
restart_ss_rust() {
    if [ ! -f /etc/systemd/system/ss-rust.service ]; then
        echo -e "${RED}ss-rust 未安装，无法重启。${NC}"
        return
    fi
    systemctl restart ss-rust && echo -e "${GREEN}ss-rust 服务重启成功。${NC}" || echo -e "${RED}ss-rust 服务重启失败。${NC}"
}

# --- 函数: 检查运行状态 ---
check_ss_rust_running() {
    if [ ! -f /etc/systemd/system/ss-rust.service ]; then
        echo -e "${RED}ss-rust 未安装，无法查看状态。${NC}"
        return
    fi
    systemctl status ss-rust
}

# --- 主程序 ---
check_root

while true; do
    show_menu
    read choice
    case $choice in
        1) install_ss_rust ;;
        2) uninstall_ss_rust ;;
        3) modify_config ;;
        4) view_config ;;
        5) start_ss_rust ;;
        6) stop_ss_rust ;;
        7) restart_ss_rust ;;
        8) check_ss_rust_running ;;
        0)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项，请输入 0-8。${NC}"
            ;;
    esac
    echo ""
    echo "按 Enter 键返回菜单..."
    read -r
done


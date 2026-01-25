#!/bin/bash

# =================================================================
# anytls 管理脚本 (修复 Mihomo 缩进版)
# 描述: 自动获取 GitHub 最新版本安装，同时显示 Surge 和 Mihomo 配置。
# =================================================================

# 定义输出颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# --- 函数: 检查 anytls 安装和运行状态 ---
check_anytls_status() {
    if [ -f /usr/local/bin/anytls-server ] && [ -f /etc/systemd/system/anytls.service ]; then
        echo -e "${GREEN}anytls 状态: 已安装${NC}"
    else
        echo -e "${RED}anytls 状态: 未安装${NC}"
    fi

    if systemctl is-active --quiet anytls; then
        echo -e "${GREEN}服务状态: 运行中${NC}"
    else
        echo -e "${RED}服务状态: 未运行${NC}"
    fi
}

# --- 函数: 显示菜单 ---
show_menu() {
    clear
    echo "=================================================="
    echo "          anytls-go 综合管理脚本 (v1.3)"
    echo "=================================================="
    check_anytls_status
    echo "--------------------------------------------------"
    echo "1. 安装 anytls"
    echo "2. 卸载 anytls"
    echo "3. 修改 anytls 配置 (端口/密码)"
    echo "4. 查看 anytls 配置"
    echo "5. 启动 anytls 服务"
    echo "6. 停止 anytls 服务"
    echo "7. 重启 anytls 服务"
    echo "8. 查看 anytls 运行状态"
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

# --- 函数: 显示配置信息 (通用模块) ---
# 参数: $1=ip, $2=port, $3=password
display_configuration() {
    local ip=$1
    local port=$2
    local pwd=$3

    echo "------------------------------------------"
    echo "           anytls 配置详情"
    echo "------------------------------------------"
    echo -e "地址 (IP)        : ${GREEN}${ip}${NC}"
    echo -e "端口 (Port)      : ${GREEN}${port}${NC}"
    echo -e "密码 (Password)  : ${GREEN}${pwd}${NC}"
    echo "------------------------------------------"
    
    echo "1. Surge 配置文件:"
    echo -e "${GREEN}VPS = anytls, ${ip}, ${port}, password=\"${pwd}\", skip-cert-verify=true, udp-relay=true, reuse=false${NC}"
    
    echo ""
    echo "2. Mihomo (Clash Meta) 配置文件:"
    # 注意：下面这一行前面已经加了两个空格
    echo -e "${GREEN}  - {\"name\":\"VPS\",\"server\":\"${ip}\",\"port\":${port},\"password\":\"${pwd}\",\"skip-cert-verify\":true,\"reuse\":false,\"type\":\"anytls\"}${NC}"
    echo "------------------------------------------"
}

# --- 函数: 安装 anytls ---
install_anytls() {
    if [ -f /usr/local/bin/anytls-server ]; then
        echo -e "${GREEN}anytls 似乎已经安装，无需重复安装。${NC}"
        return
    fi

    echo "--> 正在准备安装环境..."
    if ! command -v curl &> /dev/null || ! command -v unzip &> /dev/null || ! command -v shuf &> /dev/null || ! command -v grep &> /dev/null; then
        echo "--> 检测到依赖缺失，正在尝试自动安装..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y curl unzip coreutils grep
        elif command -v yum &> /dev/null; then
            yum install -y curl unzip coreutils grep
        else
            echo -e "${RED}无法确定包管理器，请手动安装 curl, unzip, coreutils, grep 后再运行此脚本。${NC}"
            exit 1
        fi
    fi

    echo "--> 正在获取 anytls 最新版本信息..."
    LATEST_URL=$(curl -s https://api.github.com/repos/anytls/anytls-go/releases/latest | grep "browser_download_url" | grep "linux_amd64.zip" | head -n 1 | cut -d '"' -f 4)

    if [ -z "$LATEST_URL" ]; then
        echo -e "${RED}获取最新版本失败，尝试使用备用版本 (v0.0.12)...${NC}"
        LATEST_URL="https://github.com/anytls/anytls-go/releases/download/v0.0.12/anytls_0.0.12_linux_amd64.zip"
    else
        echo -e "    检测到最新版本下载地址: ${GREEN}$LATEST_URL${NC}"
    fi

    echo "--> 正在下载 anytls..."
    if ! curl -sL -o anytls.zip "$LATEST_URL"; then
        echo -e "${RED}下载 anytls 失败！请检查网络连接。${NC}"
        exit 1
    fi

    echo "--> 正在解压并部署..."
    if ! unzip -o anytls.zip; then
        echo -e "${RED}解压 anytls 失败！${NC}"
        rm anytls.zip
        exit 1
    fi
    
    if [ -f anytls-server ]; then
        mv anytls-server /usr/local/bin/
    else
        FIND_SERVER=$(find . -maxdepth 1 -name "anytls*server*" | head -n 1)
        if [ -n "$FIND_SERVER" ]; then
             mv "$FIND_SERVER" /usr/local/bin/anytls-server
        else
             echo -e "${RED}错误：解压后未找到 anytls-server 文件。${NC}"
             exit 1
        fi
    fi

    rm -f anytls-client* readme.md anytls.zip anytls*.zip
    chmod +x /usr/local/bin/anytls-server
    echo "    anytls 程序部署完成。"

    read -p "请输入 anytls 的监听端口 (留空则随机生成 10000-65535): " PORT
    if [ -z "$PORT" ]; then
        PORT=$((RANDOM % 55536 + 10000))
        echo -e "    使用随机端口: ${GREEN}$PORT${NC}"
    fi

    read -p "请输入 anytls 的密码 (留空则随机生成): " PASSWORD
    if [ -z "$PASSWORD" ]; then
        ALPHANUM=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c 14)
        SPECIAL_CHARS='-/@'
        S1_INDEX=$(($RANDOM % 3))
        S1=${SPECIAL_CHARS:$S1_INDEX:1}
        REMAINING_CHARS=${SPECIAL_CHARS//$S1/}
        S2_INDEX=$(($RANDOM % 2))
        S2=${REMAINING_CHARS:$S2_INDEX:1}
        COMBINED_CHARS="${ALPHANUM}${S1}${S2}"
        PASSWORD=$(echo "$COMBINED_CHARS" | grep -o . | shuf | tr -d '\n')
        echo -e "    使用随机密码: ${GREEN}$PASSWORD${NC}"
    fi

    echo "--> 正在创建 systemd 服务..."
    cat > /etc/systemd/system/anytls.service <<EOF
[Unit]
Description=AnyTLS Service
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/anytls-server -l 0.0.0.0:${PORT} -p ${PASSWORD}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    echo "--> 正在启动服务..."
    systemctl daemon-reload
    systemctl enable anytls > /dev/null 2>&1
    systemctl start anytls

    echo "--> 正在获取 IP..."
    local ip_address=$(curl -s https://ipv4.icanhazip.com || curl -s https://api.ipify.org)
    [ -z "$ip_address" ] && ip_address="<您的服务器IP>"

    echo -e "${GREEN}🎉 anytls 安装成功！${NC}"
    display_configuration "$ip_address" "$PORT" "$PASSWORD"
}

# --- 函数: 卸载 anytls ---
uninstall_anytls() {
    if [ ! -f /usr/local/bin/anytls-server ]; then
        echo -e "${RED}anytls 未安装。${NC}"
        return
    fi
    
    echo -e "${RED}警告：将停止服务并删除所有文件。${NC}"
    read -p "确认继续? [y/N]: " confirm
    if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
        echo "操作取消。"
        return
    fi
    
    systemctl stop anytls
    systemctl disable anytls > /dev/null 2>&1
    rm -f /etc/systemd/system/anytls.service
    rm -f /usr/local/bin/anytls-server
    systemctl daemon-reload
    
    echo -e "${GREEN}anytls 已卸载。${NC}"
    rm -- "$0"
    echo "脚本已自毁，退出。"
    exit 0
}

# --- 函数: 修改配置 ---
modify_config() {
    if [ ! -f /etc/systemd/system/anytls.service ]; then
        echo -e "${RED}anytls 未安装。${NC}"
        return
    fi

    read -p "新端口 (留空随机): " PORT
    if [ -z "$PORT" ]; then
        PORT=$((RANDOM % 55536 + 10000))
    fi

    read -p "新密码 (留空随机): " PASSWORD
    if [ -z "$PASSWORD" ]; then
        ALPHANUM=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c 14)
        SPECIAL_CHARS='-/@'
        S1_INDEX=$(($RANDOM % 3))
        S1=${SPECIAL_CHARS:$S1_INDEX:1}
        REMAINING_CHARS=${SPECIAL_CHARS//$S1/}
        S2_INDEX=$(($RANDOM % 2))
        S2=${REMAINING_CHARS:$S2_INDEX:1}
        COMBINED_CHARS="${ALPHANUM}${S1}${S2}"
        PASSWORD=$(echo "$COMBINED_CHARS" | grep -o . | shuf | tr -d '\n')
    fi

    cat > /etc/systemd/system/anytls.service <<EOF
[Unit]
Description=AnyTLS Service
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/anytls-server -l 0.0.0.0:${PORT} -p ${PASSWORD}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl restart anytls
    
    local ip_address=$(curl -s https://ipv4.icanhazip.com || curl -s https://api.ipify.org)
    [ -z "$ip_address" ] && ip_address="<您的服务器IP>"
    
    echo -e "${GREEN}🎉 配置已更新！${NC}"
    display_configuration "$ip_address" "$PORT" "$PASSWORD"
}

# --- 函数: 查看配置 ---
view_config() {
    if [ ! -f /etc/systemd/system/anytls.service ]; then
        echo -e "${RED}anytls 未安装。${NC}"
        return
    fi
    
    local exec_start_line=$(grep 'ExecStart' /etc/systemd/system/anytls.service)
    local port=$(echo "$exec_start_line" | sed -n 's/.*-l 0\.0\.0\.0:\([0-9]*\).*/\1/p')
    local password=$(echo "$exec_start_line" | sed -n 's/.*-p \(.*\)/\1/p')
    
    echo "--> 正在获取 IP..."
    local ip_address=$(curl -s https://ipv4.icanhazip.com || curl -s https://api.ipify.org)
    [ -z "$ip_address" ] && ip_address="<您的服务器IP>"

    # 调用通用显示函数
    display_configuration "$ip_address" "$port" "$password"
}

# --- 服务管理函数 ---
start_anytls() {
    if systemctl is-active --quiet anytls; then
        echo -e "${GREEN}服务已在运行。${NC}"
    else
        systemctl start anytls && echo -e "${GREEN}启动成功。${NC}" || echo -e "${RED}启动失败。${NC}"
    fi
}

stop_anytls() {
    if ! systemctl is-active --quiet anytls; then
        echo -e "${GREEN}服务未运行。${NC}"
    else
        systemctl stop anytls && echo -e "${GREEN}停止成功。${NC}" || echo -e "${RED}停止失败。${NC}"
    fi
}

restart_anytls() {
    if [ ! -f /etc/systemd/system/anytls.service ]; then
        echo -e "${RED}anytls 未安装。${NC}"
        return
    fi
    systemctl restart anytls && echo -e "${GREEN}重启成功。${NC}" || echo -e "${RED}重启失败。${NC}"
}

check_anytls_running() {
    if [ ! -f /etc/systemd/system/anytls.service ]; then
        echo -e "${RED}anytls 未安装。${NC}"
        return
    fi
    systemctl status anytls
}

# --- 主程序 ---
check_root

while true; do
    show_menu
    read choice
    case $choice in
        1) install_anytls ;;
        2) uninstall_anytls ;;
        3) modify_config ;;
        4) view_config ;;
        5) start_anytls ;;
        6) stop_anytls ;;
        7) restart_anytls ;;
        8) check_anytls_running ;;
        0) echo "退出。"; exit 0 ;;
        *) echo -e "${RED}无效选项。${NC}" ;;
    esac
    echo ""
    echo "按 Enter 键返回菜单..."
    read -r
done

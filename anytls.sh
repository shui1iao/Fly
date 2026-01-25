#!/bin/bash

# =================================================================
# anytls 管理脚本 (自动更新版 + Surge/Mihomo配置)
# 描述: 自动获取 GitHub 最新版本安装，提供 Surge 和 Mihomo 格式配置。
# =================================================================

# 定义输出颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# --- 函数: 检查 anytls 安装和运行状态 ---
check_anytls_status() {
    # 检查 anytls 是否安装
    if [ -f /usr/local/bin/anytls-server ] && [ -f /etc/systemd/system/anytls.service ]; then
        echo -e "${GREEN}anytls 状态: 已安装${NC}"
    else
        echo -e "${RED}anytls 状态: 未安装${NC}"
    fi

    # 检查 anytls 服务是否运行
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
    echo "          anytls-go 综合管理脚本 (自动更新版)"
    echo "=================================================="
    check_anytls_status
    echo "--------------------------------------------------"
    echo "1. 安装 anytls (自动下载最新版)"
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

# --- 函数: 安装 anytls ---
install_anytls() {
    if [ -f /usr/local/bin/anytls-server ]; then
        echo -e "${GREEN}anytls 似乎已经安装，无需重复安装。${NC}"
        return
    fi

    echo "--> 正在准备安装环境..."
    # 检查基本依赖
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
    # 利用 GitHub API 获取最新 release 的下载链接 (针对 linux_amd64)
    # 逻辑: 请求 API -> 过滤 browser_download_url -> 过滤 linux_amd64.zip -> 取第一条 -> 提取 URL
    LATEST_URL=$(curl -s https://api.github.com/repos/anytls/anytls-go/releases/latest | grep "browser_download_url" | grep "linux_amd64.zip" | head -n 1 | cut -d '"' -f 4)

    if [ -z "$LATEST_URL" ]; then
        echo -e "${RED}获取最新版本失败（可能是 GitHub API 限制或网络问题）。${NC}"
        echo "--> 正在尝试使用备用版本 (v0.0.12)..."
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
        echo -e "${RED}解压 anytls 失败！文件可能已损坏。${NC}"
        rm anytls.zip
        exit 1
    fi
    
    # 这里需要注意：解压后的文件名可能包含版本号，需要用通配符匹配并重命名
    if [ -f anytls-server ]; then
        mv anytls-server /usr/local/bin/
    else
        # 尝试查找当前目录下解压出来的 server 文件 (应对文件名带版本号的情况)
        FIND_SERVER=$(find . -maxdepth 1 -name "anytls*server*" | head -n 1)
        if [ -n "$FIND_SERVER" ]; then
             mv "$FIND_SERVER" /usr/local/bin/anytls-server
        else
             echo -e "${RED}错误：解压后未找到 anytls-server 文件。${NC}"
             exit 1
        fi
    fi

    # 清理垃圾文件
    rm -f anytls-client* readme.md anytls.zip anytls*.zip
    chmod +x /usr/local/bin/anytls-server
    echo "    anytls 程序部署完成。"

    # --- 用户输入端口和密码 ---
    read -p "请输入 anytls 的监听端口 (留空则随机生成 10000-65535): " PORT
    if [ -z "$PORT" ]; then
        PORT=$((RANDOM % 55536 + 10000))
        echo -e "    端口未输入，使用随机端口: ${GREEN}$PORT${NC}"
    fi

    read -p "请输入 anytls 的密码 (留空则随机生成): " PASSWORD
    if [ -z "$PASSWORD" ]; then
        # --- 新的密码生成逻辑 ---
        ALPHANUM=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c 14)
        SPECIAL_CHARS='-/@'
        S1_INDEX=$(($RANDOM % 3))
        S1=${SPECIAL_CHARS:$S1_INDEX:1}
        REMAINING_CHARS=${SPECIAL_CHARS//$S1/}
        S2_INDEX=$(($RANDOM % 2))
        S2=${REMAINING_CHARS:$S2_INDEX:1}
        COMBINED_CHARS="${ALPHANUM}${S1}${S2}"
        PASSWORD=$(echo "$COMBINED_CHARS" | grep -o . | shuf | tr -d '\n')
        echo -e "    密码未输入，使用随机密码: ${GREEN}$PASSWORD${NC}"
    fi

    # --- 创建 systemd 服务文件 ---
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

    # --- 启动服务 ---
    echo "--> 正在启动服务并设置开机自启..."
    systemctl daemon-reload
    systemctl enable anytls > /dev/null 2>&1
    systemctl start anytls

    # --- 获取 IP 并显示最终配置 ---
    echo "--> 正在获取服务器公网 IP 地址..."
    local ip_address=$(curl -s https://ipv4.icanhazip.com || curl -s https://api.ipify.org)
    if [ -z "$ip_address" ]; then
        echo -e "${RED}警告：无法获取公网 IP 地址，请手动替换下面的 'IP' 字段。${NC}"
        ip_address="<您的服务器IP>"
    fi

    echo -e "${GREEN}🎉 anytls 服务器安装并配置成功！${NC}"
    echo "------------------------------------------"
    echo -e "端口 (Port)      : ${GREEN}${PORT}${NC}"
    echo -e "密码 (Password)  : ${GREEN}${PASSWORD}${NC}"
    echo "------------------------------------------"
    echo "Surge 配置文件:"
    echo -e "${GREEN}VPS = anytls, ${ip_address}, ${PORT}, password=\"${PASSWORD}\", skip-cert-verify=true, udp-relay=true${NC}, reuse=false"
    echo "Mihomo 配置文件:"
    echo -e "${GREEN}- {\"name\":\"VPS\",\"server\":\"${ip_address}\",\"port\":${PORT},\"password\":\"${PASSWORD}\",\"skip-cert-verify\":true,\"reuse\":false,\"type\":\"anytls\"}${NC}"
    echo "------------------------------------------"
}

# --- 函数: 卸载 anytls ---
uninstall_anytls() {
    if [ ! -f /usr/local/bin/anytls-server ]; then
        echo -e "${RED}anytls 未安装，无需卸载。${NC}"
        return
    fi
    
    echo -e "${RED}警告：此操作将停止 anytls 服务并删除所有相关文件，包括此脚本本身。${NC}"
    read -p "您确定要继续吗？[y/N]: " confirm
    if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
        echo "卸载操作已取消。"
        return
    fi
    
    echo "--> 正在停止并禁用 anytls 服务..."
    systemctl stop anytls
    systemctl disable anytls > /dev/null 2>&1
    
    echo "--> 正在删除 anytls 文件..."
    rm -f /etc/systemd/system/anytls.service
    rm -f /usr/local/bin/anytls-server
    
    systemctl daemon-reload
    
    echo -e "${GREEN}anytls 已成功卸载。${NC}"
    echo "--> 正在删除此脚本..."
    rm -- "$0"
    echo "脚本自身也已被删除。即将退出。"
    exit 0
}

# --- 函数: 修改配置 ---
modify_config() {
    if [ ! -f /etc/systemd/system/anytls.service ]; then
        echo -e "${RED}anytls 未安装，无法修改配置。${NC}"
        return
    fi

    read -p "请输入新的监听端口 (留空则随机生成): " PORT
    if [ -z "$PORT" ]; then
        PORT=$((RANDOM % 55536 + 10000))
        echo -e "    端口未输入，使用随机端口: ${GREEN}$PORT${NC}"
    fi

    read -p "请输入新的密码 (留空则随机生成): " PASSWORD
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
        echo -e "    密码未输入，使用随机密码: ${GREEN}$PASSWORD${NC}"
    fi

    # --- 更新 systemd 服务文件 ---
    echo "--> 正在更新配置文件并重启服务..."
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
    
    # --- 获取 IP 并显示最终配置 ---
    echo "--> 正在获取服务器公网 IP 地址..."
    local ip_address=$(curl -s https://ipv4.icanhazip.com || curl -s https://api.ipify.org)
    if [ -z "$ip_address" ]; then
        echo -e "${RED}警告：无法获取公网 IP 地址，请手动替换下面的 'IP' 字段。${NC}"
        ip_address="<您的服务器IP>"
    fi
    
    echo -e "${GREEN}🎉 anytls 配置已更新！${NC}"
    echo "------------------------------------------"
    echo -e "新端口 (Port)      : ${GREEN}${PORT}${NC}"
    echo -e "新密码 (Password)  : ${GREEN}${PASSWORD}${NC}"
    echo "------------------------------------------"
    echo "Surge 配置文件:"
    echo -e "${GREEN}VPS = anytls, ${ip_address}, ${PORT}, password=\"${PASSWORD}\", skip-cert-verify=true, udp-relay=true${NC}, reuse=false"
    echo "Mihomo 配置文件:"
    echo -e "${GREEN}- {\"name\":\"VPS\",\"server\":\"${ip_address}\",\"port\":${PORT},\"password\":\"${PASSWORD}\",\"skip-cert-verify\":true,\"reuse\":false,\"type\":\"anytls\"}${NC}"
    echo "------------------------------------------"
}

# --- 函数: 查看配置 ---
view_config() {
    if [ ! -f /etc/systemd/system/anytls.service ]; then
        echo -e "${RED}anytls 未安装，无法查看配置。${NC}"
        return
    fi
    
    local exec_start_line=$(grep 'ExecStart' /etc/systemd/system/anytls.service)
    local port=$(echo "$exec_start_line" | sed -n 's/.*-l 0\.0\.0\.0:\([0-9]*\).*/\1/p')
    local password=$(echo "$exec_start_line" | sed -n 's/.*-p \(.*\)/\1/p')
    
    echo "--> 正在获取服务器公网 IP 地址..."
    local ip_address=$(curl -s https://ipv4.icanhazip.com || curl -s https://api.ipify.org)
    if [ -z "$ip_address" ]; then
        echo -e "${RED}警告：无法获取公网 IP 地址，请手动替换下面的 'IP' 字段。${NC}"
        ip_address="<您的服务器IP>"
    fi

    echo "------------------------------------------"
    echo "           anytls 当前配置信息"
    echo "------------------------------------------"
    echo -e "端口 (Port)      : ${GREEN}${port}${NC}"
    echo -e "密码 (Password)  : ${GREEN}${password}${NC}"
    echo "------------------------------------------"
    echo "Surge 配置文件:"
    echo -e "${GREEN}VPS = anytls, ${ip_address}, ${port}, password=\"${password}\", skip-cert-verify=true, udp-relay=true${NC}, reuse=false"
    echo "Mihomo 配置文件:"
    echo -e "${GREEN}- {\"name\":\"VPS\",\"server\":\"${ip_address}\",\"port\":${port},\"password\":\"${password}\",\"skip-cert-verify\":true,\"reuse\":false,\"type\":\"anytls\"}${NC}"
    echo "------------------------------------------"
}

# --- 函数: 启动服务 ---
start_anytls() {
    if systemctl is-active --quiet anytls; then
        echo -e "${GREEN}anytls 服务已经在运行中。${NC}"
    else
        echo "--> 正在启动 anytls 服务..."
        if systemctl start anytls; then
            echo -e "${GREEN}anytls 服务启动成功。${NC}"
        else
            echo -e "${RED}anytls 服务启动失败，请查看日志。${NC}"
        fi
    fi
}

# --- 函数: 停止服务 ---
stop_anytls() {
    if ! systemctl is-active --quiet anytls; then
        echo -e "${GREEN}anytls 服务当前未运行。${NC}"
    else
        echo "--> 正在停止 anytls 服务..."
        if systemctl stop anytls; then
            echo -e "${GREEN}anytls 服务已停止。${NC}"
        else
            echo -e "${RED}anytls 服务停止失败。${NC}"
        fi
    fi
}

# --- 函数: 重启服务 ---
restart_anytls() {
    if [ ! -f /etc/systemd/system/anytls.service ]; then
        echo -e "${RED}anytls 未安装，无法重启。${NC}"
        return
    fi
    echo "--> 正在重启 anytls 服务..."
    if systemctl restart anytls; then
        echo -e "${GREEN}anytls 服务重启成功。${NC}"
    else
        echo -e "${RED}anytls 服务重启失败，请查看日志。${NC}"
    fi
}

# --- 函数: 检查运行状态 ---
check_anytls_running() {
    if [ ! -f /etc/systemd/system/anytls.service ]; then
        echo -e "${RED}anytls 未安装，无法查看状态。${NC}"
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

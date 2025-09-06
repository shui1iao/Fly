#!/bin/bash

# ==============================================================================
# Snell v5 管理脚本
# ==============================================================================

# --- 函数: 检查 Snell 安装和运行状态 ---
check_snell_status() {
    # 检查 Snell 是否安装
    if [ -f /usr/local/bin/snell-server ] && [ -f /etc/snell/snell-server.conf ]; then
        echo -e "\033[32mSnell 状态: 已安装\033[0m"
    else
        echo -e "\033[31mSnell 状态: 未安装\033[0m"
    fi

    # 检查 Snell 服务是否运行
    if systemctl is-active --quiet snell; then
        echo -e "\033[32m服务状态: 运行中\033[0m"
    else
        echo -e "\033[31m服务状态: 未运行\033[0m"
    fi
}

# --- 函数: 显示菜单 ---
show_menu() {
    echo "=================================================="
    echo "          Snell v5 管理脚本"
    echo "=================================================="
    check_snell_status
    echo "1. 安装 Snell"
    echo "2. 卸载 Snell"
    echo "3. 修改 Snell 配置"
    echo "4. 查看 Snell 配置"
    echo "5. 查看 Snell 运行状态"
    echo "6. 启动 Snell 服务"
    echo "7. 停止 Snell 服务"
    echo "8. 重启 Snell 服务"
    echo "0. 退出脚本"
    echo "=================================================="
    echo -n "请输入选项 [0-8]: "
}

# --- 函数: 检查 root 权限 ---
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "错误：此脚本需要以 root 权限运行。" >&2
        exit 1
    fi
}

# --- 函数: 安装 Snell ---
install_snell() {
    # --- 步骤 1: 更新软件包列表并安装必要工具 ---
    echo "--> 更新软件包列表并安装必要工具 (nano, wget, unzip)..."
    if ! apt-get update > /dev/null; then
        echo "错误：软件包列表更新失败。请检查网络连接或 apt 源。"
        exit 1
    fi
    if ! apt-get install -y nano wget unzip > /dev/null; then
        echo "错误：工具安装失败。请检查 apt 源或网络连接。"
        exit 1
    fi
    echo "    工具安装完成。"

    # --- 步骤 2: 下载、解压并部署 Snell ---
    echo "--> 正在下载、解压并部署 Snell 服务器程序..."
    if ! wget -q --show-progress https://dl.nssurge.com/snell/snell-server-v5.0.0-linux-amd64.zip -O snell.zip; then
        echo "错误：Snell 下载失败！请检查网络或链接是否有效。"
        exit 1
    fi

    if ! unzip -o snell.zip -d /usr/local/bin/ > /dev/null; then
        echo "错误：Snell 解压失败！"
        rm snell.zip
        exit 1
    fi
    chmod +x /usr/local/bin/snell-server
    mkdir -p /etc/snell
    rm snell.zip
    echo "    Snell 程序部署完成。"

    # --- 步骤 3: 用户输入端口和密码 ---
    read -p "请输入 Snell 的监听端口 (留空则随机生成): " snell_port
    if [ -z "${snell_port}" ]; then
        while true; do
            snell_port=$(shuf -i 30001-65535 -n 1)
            if ! ss -lntu | grep -q ":${snell_port} "; then
                echo "    端口未输入，使用随机端口: ${snell_port}"
                break
            fi
        done
    fi

    read -p "请输入 Snell 的密码 (PSK，留空则随机生成): " snell_psk
    if [ -z "${snell_psk}" ]; then
        # 生成一个16位的随机密码
        snell_psk=$(< /dev/urandom tr -dc 'A-Za-z0-9@%$^&/-_+' | head -c 16)
        echo "    密码未输入，使用随机密码: ${snell_psk}"
    fi

    # --- 步骤 4: 配置确认 ---
    echo ""
    echo "============================================="
    echo "端口 (Port):      ${snell_port}"
    echo "密码 (PSK):       ${snell_psk}"
    echo "============================================="
    echo "安装将在 2 秒后继续，按 Ctrl+C 取消"
    sleep 2

    # --- 步骤 5: 生成配置文件 ---
    echo "--> 正在创建配置文件..."
    cat > /etc/snell/snell-server.conf <<EOF
[snell-server]
listen = ::0:${snell_port}
psk = ${snell_psk}
EOF

    # --- 步骤 6: 创建 systemd 服务并启动 ---
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
    systemctl start snell

    # --- 步骤 7: 显示结果 ---
    echo "--> 正在获取服务器公网 IP 地址..."
    ip_address=$(curl -s https://ipv4.icanhazip.com || curl -s https://api.ipify.org)
    if [ -z "$ip_address" ]; then
        echo "警告：无法获取公网 IP 地址，请手动检查。"
    fi

    echo ""
    echo "=================================================="
    echo "🎉 Snell 服务器安装并配置成功！"
    echo ""
    echo "--------------- 服务状态 ---------------"
    systemctl status snell
    echo ""
    echo "---------- 客户端配置信息 ----------"
    echo "在Surge使用以下配置："
    echo ""
    echo "vps = snell, ${ip_address:-<您的服务器IP>}, ${snell_port}, psk=${snell_psk}, version=5"
    echo ""
    echo "=================================================="
}

# --- 函数: 卸载 Snell ---
uninstall_snell() {
    echo "警告：此操作将彻底卸载 Snell 并删除所有相关文件！"
    read -p "确定要继续吗？(y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "卸载操作已取消。"
        return
    fi

    echo "--> 正在停止并禁用 Snell 服务..."
    systemctl stop snell > /dev/null 2>&1
    systemctl disable snell > /dev/null 2>&1

    echo "--> 正在删除 Snell systemd 服务文件..."
    rm -f /etc/systemd/system/snell.service
    systemctl daemon-reload

    echo "--> 正在删除 Snell 可执行文件..."
    rm -f /usr/local/bin/snell-server

    echo "--> 正在删除 Snell 配置文件..."
    rm -rf /etc/snell

    echo "--> 正在删除此脚本..."
    rm -- "$0"

    echo ""
    echo "✅ Snell 已被彻底卸载。"
    echo "脚本自身也已被删除。退出。"
    exit 0
}


# --- 函数: 修改 Snell 配置 ---
modify_config() {
    if [ -f /etc/snell/snell-server.conf ]; then
        # --- 步骤 1: 用户输入新端口和密码 ---
        read -p "请输入新的 Snell 监听端口 (留空则随机生成): " snell_port
        if [ -z "${snell_port}" ]; then
            while true; do
                snell_port=$(shuf -i 30001-65535 -n 1)
                if ! ss -lntu | grep -q ":${snell_port} "; then
                    echo "    端口未输入，使用随机端口: ${snell_port}"
                    break
                fi
            done
        fi

        read -p "请输入新的 Snell 密码 (PSK，留空则随机生成): " snell_psk
        if [ -z "${snell_psk}" ]; then
            snell_psk=$(< /dev/urandom tr -dc 'A-Za-z0-9@%$^&/-_+' | head -c 16)
            echo "    密码未输入，使用随机密码: ${snell_psk}"
        fi

        # --- 步骤 2: 配置确认 ---
        echo ""
        echo "============================================="
        echo "新端口 (Port):    ${snell_port}"
        echo "新密码 (PSK):     ${snell_psk}"
        echo "============================================="
        echo "配置将在 2 秒后更新，按 Ctrl+C 取消"
        sleep 2

        # --- 步骤 3: 更新配置文件 ---
        echo "--> 正在更新配置文件..."
        cat > /etc/snell/snell-server.conf <<EOF
[snell-server]
listen = ::0:${snell_port}
psk = ${snell_psk}
EOF

        # --- 步骤 4: 显示客户端配置信息 ---
        echo "--> 正在获取服务器公网 IP 地址..."
        ip_address=$(curl -s https://ipv4.icanhazip.com || curl -s https://api.ipify.org)
        if [ -z "$ip_address" ]; then
            echo "警告：无法获取公网 IP 地址，请手动检查。"
        fi

        echo ""
        echo "=================================================="
        echo "🎉 Snell 配置已更新！"
        echo ""
        echo "---------- 客户端配置信息 ----------"
        echo "在Surge使用以下配置："
        echo ""
        echo "vps = snell, ${ip_address:-<您的服务器IP>}, ${snell_port}, psk=${snell_psk}, version=5"
        echo ""
        echo "=================================================="

        # --- 步骤 5: 自动重启服务 ---
        restart_snell
    else
        echo "错误：Snell 配置文件不存在，可能尚未安装。"
    fi
}

# --- 函数: 查看 Snell 配置 ---
view_config() {
    if [ -f /etc/snell/snell-server.conf ]; then
        echo "--> Snell 配置文件内容："
        cat /etc/snell/snell-server.conf
        echo ""
        ip_address=$(curl -s https://ipv4.icanhazip.com || curl -s https://api.ipify.org)
        # --- [BUG修复] 使用 awk 准确提取端口号 ---
        port=$(grep "listen" /etc/snell/snell-server.conf | awk -F':' '{print $NF}')
        psk=$(grep "psk" /etc/snell/snell-server.conf | cut -d'=' -f2 | tr -d ' ')
        echo "--> 客户端配置信息："
        echo "vps = snell, ${ip_address:-<您的服务器IP>}, ${port}, psk=${psk}, version=5"
    else
        echo "错误：Snell 配置文件不存在，可能尚未安装。"
    fi
}

# --- 函数: 查看 Snell 运行状态 ---
check_snell_running() {
    echo "--> Snell 服务运行状态："
    systemctl status snell
}

# --- 函数: 启动 Snell 服务 ---
start_snell() {
    if [ -f /etc/systemd/system/snell.service ]; then
        echo "--> 正在启动 Snell 服务..."
        systemctl daemon-reload
        systemctl enable snell > /dev/null 2>&1
        if systemctl start snell; then
            echo "    Snell 服务已启动并启用。"
            echo ""
            echo "--> Snell 服务运行状态："
            systemctl status snell
        else
            echo "    错误：Snell 服务启动失败，请使用 'journalctl -u snell' 查看日志。"
            echo ""
            echo "--> Snell 服务运行状态："
            systemctl status snell
        fi
    else
        echo "错误：Snell 服务未安装。"
    fi
}

# --- 函数: 停止 Snell 服务 ---
stop_snell() {
    if systemctl is-active --quiet snell || systemctl is-enabled --quiet snell; then
        echo "--> 正在停止 Snell 服务..."
        systemctl stop snell
        systemctl disable snell > /dev/null 2>&1
        echo "    Snell 服务已停止并禁用。"
        echo ""
        echo "--> Snell 服务运行状态："
        systemctl status snell
    else
        echo "错误：Snell 服务未安装或未运行。"
    fi
}

# --- 函数: 重启 Snell 服务 ---
restart_snell() {
    if [ -f /etc/systemd/system/snell.service ]; then
        echo "--> 正在重启 Snell 服务..."
        systemctl daemon-reload
        systemctl enable snell > /dev/null 2>&1
        if systemctl restart snell; then
            echo "    Snell 服务已重启并启用。"
            echo ""
            echo "--> Snell 服务运行状态："
            systemctl status snell
        else
            echo "    错误：Snell 服务重启失败，请使用 'journalctl -u snell' 查看日志。"
            echo ""
            echo "--> Snell 服务运行状态："
            systemctl status snell
        fi
    else
        echo "错误：Snell 服务未安装。"
    fi
}

# --- 主程序: 检查 root 权限并显示菜单 ---
check_root

while true; do
    show_menu
    read choice
    case $choice in
        1)
            install_snell
            ;;
        2)
            uninstall_snell
            ;;
        3)
            modify_config
            ;;
        4)
            view_config
            ;;
        5)
            check_snell_running
            ;;
        6)
            start_snell
            ;;
        7)
            stop_snell
            ;;
        8)
            restart_snell
            ;;
        0)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效选项，请输入 0-8。"
            ;;
    esac
    echo ""
    echo "按 Enter 键返回菜单..."
    read -r
done

#!/bin/bash

# ==============================================================================
# Snell v5 自动化管理脚本
# ==============================================================================

# --- 函数: 自动安装脚本到 /usr/local/bin/snell ---
install_script() {
    if [ ! -f /usr/local/bin/snell ]; then
        echo "--> 正在安装 snell 命令到 /usr/local/bin/snell..."
        # 检查是否通过 curl 运行
        if [ -n "$BASH_EXECUTION_STRING" ]; then
            # 如果通过 curl 运行，将脚本内容写入 /usr/local/bin/snell
            echo "$BASH_EXECUTION_STRING" > /usr/local/bin/snell
        else
            # 如果是本地运行，复制脚本自身
            cp "$0" /usr/local/bin/snell
        fi
        chmod +x /usr/local/bin/snell
        if [ $? -eq 0 ]; then
            echo "    snell 命令安装成功！"
            echo "    提示：现在您可以通过输入 'snell' 直接唤醒脚本。"
        else
            echo "    错误：snell 命令安装失败，请检查权限或磁盘空间。"
            exit 1
        fi
    else
        echo "    snell 命令已存在，跳过安装。"
    fi
}

# --- 函数: 显示菜单 ---
show_menu() {
    echo ""
    echo "=================================================="
    echo "        Snell v5 管理脚本"
    echo "=================================================="
    echo "1. 安装 Snell"
    echo "2. 查看 Snell 配置"
    echo "3. 启动 Snell 服务"
    echo "4. 停止 Snell 服务"
    echo "5. 重启 Snell 服务"
    echo "0. 退出脚本"
    echo "=================================================="
    echo -n "请输入选项 [0-5]: "
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
        snell_psk=$(< /dev/urandom tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' | head -c 16)
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
    if systemctl is-active --quiet snell; then
        echo "状态: Active (running)"
    else
        echo "状态: Inactive (dead) - 请使用 'journalctl -u snell' 查看日志"
    fi
    echo ""
    echo "---------- 客户端配置信息 ----------"
    echo "在Surge使用以下配置："
    echo ""
    echo "vps = snell, ${ip_address:-<您的服务器IP>}, ${snell_port}, psk=${snell_psk}, version=5"
    echo ""
    echo "=================================================="
}

# --- 函数: 查看 Snell 配置 ---
view_config() {
    if [ -f /etc/snell/snell-server.conf ]; then
        echo "--> Snell 配置文件内容："
        cat /etc/snell/snell-server.conf
        echo ""
        echo "--> 服务状态："
        if systemctl is-active --quiet snell; then
            echo "状态: Active (running)"
        else
            echo "状态: Inactive (dead) - 请使用 'journalctl -u snell' 查看日志"
        fi
        ip_address=$(curl -s https://ipv4.icanhazip.com || curl -s https://api.ipify.org)
        port=$(grep "listen" /etc/snell/snell-server.conf | cut -d':' -f2)
        psk=$(grep "psk" /etc/snell/snell-server.conf | cut -d'=' -f2 | tr -d ' ')
        echo ""
        echo "--> 客户端配置信息："
        echo "vps = snell, ${ip_address:-<您的服务器IP>}, ${port}, psk=${psk}, version=5"
    else
        echo "错误：Snell 配置文件不存在，可能尚未安装。"
    fi
}

# --- 函数: 启动 Snell 服务 ---
start_snell() {
    if [ -f /etc/systemd/system/snell.service ]; then
        echo "--> 正在启动 Snell 服务..."
        systemctl daemon-reload
        systemctl enable snell > /dev/null 2>&1
        if systemctl start snell; then
            echo "    Snell 服务已启动并启用。"
        else
            echo "    错误：Snell 服务启动失败，请使用 'journalctl -u snell' 查看日志。"
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
        else
            echo "    错误：Snell 服务重启失败，请使用 'journalctl -u snell' 查看日志。"
        fi
    else
        echo "错误：Snell 服务未安装。"
    fi
}

# --- 主程序: 检查 root 权限并安装脚本 ---
check_root
install_script

# --- 显示菜单并处理用户输入 ---
while true; do
    show_menu
    read choice
    case $choice in
        1)
            install_snell
            ;;
        2)
            view_config
            ;;
        3)
            start_snell
            ;;
        4)
            stop_snell
            ;;
        5)
            restart_snell
            ;;
        0)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效选项，请输入 0-5。"
            ;;
    esac
    echo ""
    echo "按 Enter 键返回菜单..."
    read -r
done

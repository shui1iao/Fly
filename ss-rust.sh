#!/bin/bash

# =================================================================
# shadowsocks-rust & shadowtls 服务器端综合管理脚本
# 描述: 提供一个主菜单，分别进入 ss-rust 和 shadowtls 的管理界面。
# =================================================================

# 定义输出颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# --- 通用函数 ---
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误：此脚本需要以 root 权限运行。${NC}" >&2
        exit 1
    fi
}

# --- 新增函数: 检查是否所有组件都已卸载，如果是则删除脚本 ---
check_and_delete_script_if_all_uninstalled() {
    # 检查 ss-rust 和 shadowtls 的二进制文件是否都不存在
    if [ ! -f /usr/local/bin/ss-rust ] && [ ! -f /usr/local/bin/shadowtls ]; then
        echo -e "${GREEN}检测到 ss-rust 和 shadowtls 均已卸载。${NC}"
        echo "--> 正在删除此脚本..."
        rm -- "$0"
        echo "脚本自身也已被删除。即将退出。"
        exit 0
    fi
}


# =================================================================
# S-S-R-U-S-T  M-A-N-A-G-E-M-E-N-T
# =================================================================

# --- ss-rust 变量定义 (这里改为了动态获取，不再硬编码版本号) ---
# SS_VERSION, SS_URL, SS_TAR_FILE 将在安装函数中动态生成

# --- 函数: 检查 ss-rust 安装和运行状态 ---
check_ss_rust_status() {
    if [ -f /usr/local/bin/ss-rust ] && [ -f /etc/systemd/system/ss-rust.service ]; then
        echo -e "${GREEN}ss-rust 状态: 已安装${NC}"
    else
        echo -e "${RED}ss-rust 状态: 未安装${NC}"
    fi

    if systemctl is-active --quiet ss-rust; then
        echo -e "${GREEN}服务状态    : 运行中${NC}"
    else
        echo -e "${RED}服务状态    : 未运行${NC}"
    fi
}

# --- 函数: URI 编码 ---
urlencode() {
    local LC_ALL=C
    local input="$1"
    local output=""
    local i char hex
    for ((i = 0; i < ${#input}; i++)); do
        char="${input:i:1}"
        case "$char" in
            [a-zA-Z0-9.~_-]) output+="$char" ;;
            *) printf -v hex '%%%02X' "'$char"; output+="$hex" ;;
        esac
    done
    printf '%s' "$output"
}

# --- 函数: 确保 jq 已安装 ---
ensure_jq() {
    if ! command -v jq &> /dev/null || ! command -v curl &> /dev/null; then
        echo "--> 检测到依赖工具 jq 或 curl 未安装，正在尝试自动安装..."
        if command -v apt-get &> /dev/null; then
            apt-get update >/dev/null && apt-get install -y jq curl
        elif command -v yum &> /dev/null; then
            yum install -y jq curl
        else
            echo -e "${RED}无法自动安装 jq/curl。请手动安装后再试。${NC}"
            return 1
        fi
    fi
    return 0
}

# --- 函数: 安装 ss-rust ---
install_ss_rust() {
    if [ -f /usr/local/bin/ss-rust ]; then
        echo -e "${GREEN}ss-rust 似乎已经安装，无需重复安装。${NC}"
        return
    fi

    # --- 新增: 自动获取最新版本逻辑 ---
    ensure_jq || exit 1
    echo "--> 正在获取 ss-rust 最新版本号..."
    SS_VERSION=$(curl -s "https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest" | jq -r .tag_name)
    if [ -z "$SS_VERSION" ] || [ "$SS_VERSION" == "null" ]; then
        echo -e "${RED}获取最新版本失败，请检查网络！${NC}"
        exit 1
    fi
    SS_URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${SS_VERSION}/shadowsocks-${SS_VERSION}.x86_64-unknown-linux-gnu.tar.xz"
    SS_TAR_FILE="shadowsocks-${SS_VERSION}.x86_64-unknown-linux-gnu.tar.xz"
    echo -e "${GREEN}检测到最新版本: ${SS_VERSION}${NC}"
    # ----------------------------

    echo "--> 正在准备安装环境..."
    if command -v apt-get &> /dev/null; then
         apt-get update && apt-get install -y wget tar xz-utils openssl jq coreutils
    elif command -v yum &> /dev/null; then
         yum install -y wget tar xz-utils openssl jq coreutils
    else
         echo -e "${RED}无法确定包管理器，请手动安装 wget, tar, xz-utils, openssl, jq, coreutils。${NC}"
         exit 1
    fi

    echo "--> 正在下载、解压并部署 ss-rust..."
    if ! wget -O "${SS_TAR_FILE}" "${SS_URL}"; then
        echo -e "${RED}下载 ss-rust 失败！请检查网络或链接是否有效。${NC}"
        exit 1
    fi

    tar -xf "${SS_TAR_FILE}"
    mv ssserver /usr/local/bin/ss-rust
    chmod +x /usr/local/bin/ss-rust
    rm -f sslocal ssmanager ssurl "${SS_TAR_FILE}"
    echo "    ss-rust 程序部署完成。"
    
    mkdir -p /etc/ss-rust

    read -p "请输入 ss-rust 的监听端口 (留空则随机生成): " PORT
    [ -z "$PORT" ] && PORT=$((RANDOM % 55536 + 10000))
    
    read -p "请输入 ss-rust 的密码 (留空则随机生成): " PASSWORD
    [ -z "$PASSWORD" ] && PASSWORD=$(head -c 16 /dev/urandom | base64 -w 0)

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

    systemctl daemon-reload
    systemctl enable ss-rust > /dev/null 2>&1
    systemctl start ss-rust

    echo -e "${GREEN}🎉 ss-rust 服务器安装并配置成功！${NC}"
    view_config_ss_rust
}

# --- 函数: 卸载 ss-rust ---
uninstall_ss_rust() {
    if [ ! -f /usr/local/bin/ss-rust ]; then
        echo -e "${RED}ss-rust 未安装，无需卸载。${NC}"
        return
    fi
    
    read -p "警告：确定要卸载 ss-rust 吗？[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[yY]([eE][sS])?$ ]]; then
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
    
    # 调用检查函数
    check_and_delete_script_if_all_uninstalled
}

# --- 函数: 修改 ss-rust 配置 ---
modify_config_ss_rust() {
    if [ ! -f /etc/ss-rust/config.json ]; then
        echo -e "${RED}ss-rust 未安装，无法修改配置。${NC}"; return; fi
    ensure_jq || return

    read -p "请输入新的监听端口 (留空则随机生成): " PORT
    [ -z "$PORT" ] && PORT=$((RANDOM % 55536 + 10000))

    read -p "请输入新的密码 (留空则随机生成): " PASSWORD
    [ -z "$PASSWORD" ] && PASSWORD=$(head -c 16 /dev/urandom | base64 -w 0)

    jq ".server_port = ${PORT} | .password = \"${PASSWORD}\"" /etc/ss-rust/config.json > /tmp/ss-config.tmp && mv /tmp/ss-config.tmp /etc/ss-rust/config.json

    systemctl restart ss-rust
    echo -e "${GREEN}🎉 ss-rust 配置已更新！${NC}"
    view_config_ss_rust
}

# --- 函数: 查看 ss-rust 配置 ---
view_config_ss_rust() {
    if [ ! -f /etc/ss-rust/config.json ]; then
        echo -e "${RED}ss-rust 未安装，无法查看配置。${NC}"; return; fi
    ensure_jq || return
    
    local port=$(jq .server_port /etc/ss-rust/config.json)
    local password=$(jq -r .password /etc/ss-rust/config.json)
    local method=$(jq -r .method /etc/ss-rust/config.json)
    local ip_address=$(curl -s https://ipv4.icanhazip.com || echo "<您的服务器IP>")

    echo "------------------------------------------"
    echo "          ss-rust 当前配置信息"
    echo "------------------------------------------"
    echo -e "端口 (Port)      : ${GREEN}${port}${NC}"
    echo -e "密码 (Password)  : ${GREEN}${password}${NC}"
    echo -e "加密 (Method)    : ${GREEN}${method}${NC}"
    echo "------------------------------------------"
    local ss_password_encoded=$(urlencode "${password}")
    local ss_tag=$(urlencode "VPS")

    echo "Surge 客户端配置:"
    echo -e "${GREEN}VPS = ss, ${ip_address}, ${port}, encrypt-method=${method}, password=${password}, udp-relay=true${NC}"
    echo "------------------------------------------"
    echo "URI 格式:"
    echo -e "${GREEN}ss://${method}:${ss_password_encoded}@${ip_address}:${port}#${ss_tag}${NC}"
    echo "------------------------------------------"
}

# --- 函数: ss-rust 服务管理 ---
manage_ss_rust_service() {
    if [ ! -f /etc/systemd/system/ss-rust.service ]; then
        echo -e "${RED}ss-rust 未安装。${NC}"; return; fi
    case $1 in
        start) systemctl start ss-rust && echo -e "${GREEN}服务启动成功。${NC}" || echo -e "${RED}服务启动失败。${NC}" ;;
        stop) systemctl stop ss-rust && echo -e "${GREEN}服务已停止。${NC}" || echo -e "${RED}服务停止失败。${NC}" ;;
        restart) systemctl restart ss-rust && echo -e "${GREEN}服务重启成功。${NC}" || echo -e "${RED}服务重启失败。${NC}" ;;
        status) systemctl status ss-rust ;;
    esac
}

# --- 函数: ss-rust 子菜单 ---
ss_rust_menu() {
    while true; do
        clear
        echo "=================================================="
        echo "            shadowsocks-rust 管理界面"
        echo "=================================================="
        check_ss_rust_status
        echo "--------------------------------------------------"
        echo "1. 安装 ss-rust"
        echo "2. 卸载 ss-rust"
        echo "3. 修改 ss-rust 配置"
        echo "4. 查看 ss-rust 配置"
        echo "5. 启动 ss-rust"
        echo "6. 停止 ss-rust"
        echo "7. 重启 ss-rust"
        echo "8. 查看运行状态"
        echo "0. 返回主菜单"
        echo "=================================================="
        read -p "请输入选项 [0-8]: " choice

        case $choice in
            1) install_ss_rust ;;
            2) uninstall_ss_rust ;;
            3) modify_config_ss_rust ;;
            4) view_config_ss_rust ;;
            5) manage_ss_rust_service start ;;
            6) manage_ss_rust_service stop ;;
            7) manage_ss_rust_service restart ;;
            8) manage_ss_rust_service status ;;
            0) return ;;
            *) echo -e "${RED}无效选项，请重试。${NC}" ;;
        esac
        [ "$choice" != "0" ] && read -p "按 Enter 键返回..."
    done
}


# =================================================================
# S-H-A-D-O-W-T-L-S  M-A-N-A-G-E-M-E-N-T
# =================================================================

# --- shadowtls 变量定义 ---
STLS_URL="https://github.com/ihciah/shadow-tls/releases/download/v0.2.25/shadow-tls-x86_64-unknown-linux-musl"

# --- 函数: 检查 shadowtls 安装和运行状态 ---
check_shadowtls_status() {
    if [ -f /usr/local/bin/shadowtls ] && [ -f /etc/systemd/system/shadowtls.service ]; then
        echo -e "${GREEN}shadowtls 状态: 已安装${NC}"
    else
        echo -e "${RED}shadowtls 状态: 未安装${NC}"
    fi

    if systemctl is-active --quiet shadowtls; then
        echo -e "${GREEN}服务状态      : 运行中${NC}"
    else
        echo -e "${RED}服务状态      : 未运行${NC}"
    fi
}

# --- 函数: 安装 shadowtls ---
install_shadowtls() {
    if [ -f /usr/local/bin/shadowtls ]; then
        echo -e "${GREEN}shadowtls 似乎已经安装。${NC}"; return; fi

    echo "--> 正在下载 shadowtls..."
    curl -L "$STLS_URL" -o /usr/local/bin/shadowtls
    chmod +x /usr/local/bin/shadowtls

    read -p "请输入 shadowtls 监听端口 (留空默认 8443): " LISTEN_PORT
    [ -z "$LISTEN_PORT" ] && LISTEN_PORT=8443
    
    read -p "请输入后端的 ss-rust 端口: " SS_PORT
    while [ -z "$SS_PORT" ]; do
        read -p "${RED}后端 ss-rust 端口不能为空，请重新输入: ${NC}" SS_PORT
    done

    read -p "请输入伪装域名 (留空默认 www.muji.com): " SNI_HOST
    [ -z "$SNI_HOST" ] && SNI_HOST="www.muji.com"
    
    read -p "请输入 shadowtls 密码 (留空随机生成): " PASSWORD
    if [ -z "$PASSWORD" ]; then
        ALPHANUM=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c 14)
        SPECIAL_CHARS='-/@'
        S1_INDEX=$(($RANDOM % 3)); S1=${SPECIAL_CHARS:$S1_INDEX:1}
        REMAINING_CHARS=${SPECIAL_CHARS//$S1/}; S2_INDEX=$(($RANDOM % 2)); S2=${REMAINING_CHARS:$S2_INDEX:1}
        COMBINED_CHARS="${ALPHANUM}${S1}${S2}"
        PASSWORD=$(echo "$COMBINED_CHARS" | grep -o . | shuf | tr -d '\n')
    fi

    echo "--> 正在创建 systemd 服务..."
    cat > /etc/systemd/system/shadowtls.service <<EOF
[Unit]
Description=ShadowTLS Server Service
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
LimitNOFILE=32767
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/shadowtls --v3 --strict server --listen 0.0.0.0:${LISTEN_PORT} --server 127.0.0.1:${SS_PORT} --tls ${SNI_HOST}:443 --password ${PASSWORD}

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable shadowtls > /dev/null 2>&1
    systemctl start shadowtls
    echo -e "${GREEN}🎉 shadowtls 服务器安装并配置成功！${NC}"
    view_config_shadowtls
}

# --- 函数: 卸载 shadowtls ---
uninstall_shadowtls() {
    if [ ! -f /usr/local/bin/shadowtls ]; then
        echo -e "${RED}shadowtls 未安装。${NC}"; return; fi
    
    read -p "警告：确定要卸载 shadowtls 吗？[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[yY]([eE][sS])?$ ]]; then
        echo "卸载操作已取消。"; return; fi
    
    systemctl stop shadowtls
    systemctl disable shadowtls > /dev/null 2>&1
    rm -f /etc/systemd/system/shadowtls.service
    rm -f /usr/local/bin/shadowtls
    systemctl daemon-reload
    echo -e "${GREEN}shadowtls 已成功卸载。${NC}"

    # 调用检查函数
    check_and_delete_script_if_all_uninstalled
}

# --- 函数: 查看 shadowtls 配置 ---
view_config_shadowtls() {
    if [ ! -f /etc/systemd/system/shadowtls.service ]; then
        echo -e "${RED}shadowtls 未安装。${NC}"; return; fi

    local exec_start=$(grep 'ExecStart=' /etc/systemd/system/shadowtls.service)
    # 使用更通用的正则表达式解析端口，以提高兼容性
    local listen_port=$(echo "$exec_start" | sed -n 's/.*--listen [^ ]*:\([0-9]*\).*/\1/p')
    local server_port=$(echo "$exec_start" | sed -n 's/.*--server [^ ]*:\([0-9]*\).*/\1/p')
    local sni_host=$(echo "$exec_start" | sed -n 's/.*--tls \([^:]*\):443.*/\1/p')
    local stls_password=$(echo "$exec_start" | sed -n 's/.*--password \([^ ]*\).*/\1/p')
    local ip_address=$(curl -s https://ipv4.icanhazip.com || echo "<您的服务器IP>")
    
    local ss_password="<ss密码>"
    local ss_method="2022-blake3-aes-128-gcm"
    if [ -f /etc/ss-rust/config.json ] && ensure_jq; then
        ss_password=$(jq -r .password /etc/ss-rust/config.json)
        ss_method=$(jq -r .method /etc/ss-rust/config.json)
    fi

    echo "------------------------------------------"
    echo "          shadowtls 当前配置信息"
    echo "------------------------------------------"
    echo -e "监听端口    : ${GREEN}${listen_port}${NC}"
    echo -e "密码        : ${GREEN}${stls_password}${NC}"
    echo -e "后端 SS 端口: ${GREEN}${server_port}${NC}"
    echo -e "伪装域名    : ${GREEN}${sni_host}${NC}"
    echo "------------------------------------------"
    local ss_password_encoded=$(urlencode "${ss_password}")
    local stls_password_encoded=$(urlencode "${stls_password}")
    local sni_encoded=$(urlencode "${sni_host}")
    local ss_tag=$(urlencode "VPS")

    echo "Surge 客户端配置:"
    echo -e "${GREEN}VPS = ss, ${ip_address}, ${listen_port}, encrypt-method=${ss_method}, password=${ss_password}, shadow-tls-password=${stls_password}, shadow-tls-sni=${sni_host}, shadow-tls-version=3, udp-relay=true${NC}"
    echo "------------------------------------------"
    echo "URI 格式:"
    echo -e "${GREEN}ss://${ss_method}:${ss_password_encoded}@${ip_address}:${listen_port}?shadow-tls-password=${stls_password_encoded}&shadow-tls-sni=${sni_encoded}&shadow-tls-version=3#${ss_tag}${NC}"
    echo "------------------------------------------"
}

# --- 函数: 修改 shadowtls 配置 ---
modify_config_shadowtls() {
    if [ ! -f /etc/systemd/system/shadowtls.service ]; then
        echo -e "${RED}shadowtls 未安装。${NC}"; return; fi

    read -p "请输入新的 shadowtls 监听端口 (留空默认 8443): " LISTEN_PORT
    [ -z "$LISTEN_PORT" ] && LISTEN_PORT=8443
    
    read -p "请输入新的后端 ss-rust 端口: " SS_PORT
    while [ -z "$SS_PORT" ]; do
        read -p "${RED}后端 ss-rust 端口不能为空，请重新输入: ${NC}" SS_PORT
    done

    read -p "请输入新的伪装域名 (留空默认 www.muji.com): " SNI_HOST
    [ -z "$SNI_HOST" ] && SNI_HOST="www.muji.com"
    
    read -p "请输入新的 shadowtls 密码 (留空随机): " PASSWORD
    if [ -z "$PASSWORD" ]; then
        ALPHANUM=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c 14)
        SPECIAL_CHARS='-/@'
        S1_INDEX=$(($RANDOM % 3)); S1=${SPECIAL_CHARS:$S1_INDEX:1}
        REMAINING_CHARS=${SPECIAL_CHARS//$S1/}; S2_INDEX=$(($RANDOM % 2)); S2=${REMAINING_CHARS:$S2_INDEX:1}
        COMBINED_CHARS="${ALPHANUM}${S1}${S2}"
        PASSWORD=$(echo "$COMBINED_CHARS" | grep -o . | shuf | tr -d '\n')
    fi

    local exec_line="ExecStart=/usr/local/bin/shadowtls --v3 --strict server --listen 0.0.0.0:${LISTEN_PORT} --server 127.0.0.1:${SS_PORT} --tls ${SNI_HOST}:443 --password ${PASSWORD}"
    sed -i "s|^ExecStart=.*|$exec_line|" /etc/systemd/system/shadowtls.service
    
    systemctl daemon-reload
    systemctl restart shadowtls
    echo -e "${GREEN}🎉 shadowtls 配置已更新！${NC}"
    view_config_shadowtls
}

# --- 函数: shadowtls 服务管理 ---
manage_shadowtls_service() {
    if [ ! -f /etc/systemd/system/shadowtls.service ]; then
        echo -e "${RED}shadowtls 未安装。${NC}"; return; fi
    case $1 in
        start) systemctl start shadowtls && echo -e "${GREEN}服务启动成功。${NC}" || echo -e "${RED}服务启动失败。${NC}" ;;
        stop) systemctl stop shadowtls && echo -e "${GREEN}服务已停止。${NC}" || echo -e "${RED}服务停止失败。${NC}" ;;
        restart) systemctl restart shadowtls && echo -e "${GREEN}服务重启成功。${NC}" || echo -e "${RED}服务重启失败。${NC}" ;;
        status) systemctl status shadowtls ;;
    esac
}

# --- 函数: shadowtls 子菜单 ---
shadowtls_menu() {
    while true; do
        clear
        echo "=================================================="
        echo "                shadowtls 管理界面"
        echo "=================================================="
        check_shadowtls_status
        echo "--------------------------------------------------"
        echo "1. 安装 shadowtls"
        echo "2. 卸载 shadowtls"
        echo "3. 修改 shadowtls 配置"
        echo "4. 查看 shadowtls 配置"
        echo "5. 启动 shadowtls"
        echo "6. 停止 shadowtls"
        echo "7. 重启 shadowtls"
        echo "8. 查看运行状态"
        echo "0. 返回主菜单"
        echo "=================================================="
        read -p "请输入选项 [0-8]: " choice

        case $choice in
            1) install_shadowtls ;;
            2) uninstall_shadowtls ;;
            3) modify_config_shadowtls ;;
            4) view_config_shadowtls ;;
            5) manage_shadowtls_service start ;;
            6) manage_shadowtls_service stop ;;
            7) manage_shadowtls_service restart ;;
            8) manage_shadowtls_service status ;;
            0) return ;;
            *) echo -e "${RED}无效选项，请重试。${NC}" ;;
        esac
        [ "$choice" != "0" ] && read -p "按 Enter 键返回..."
    done
}


# =================================================================
# M-A-I-N  M-E-N-U
# =================================================================
main_menu() {
    while true; do
        clear
        echo "=================================================="
        echo "       SS-Rust & ShadowTLS 综合管理脚本"
        echo "=================================================="
        echo "1. shadowsocks-rust 管理"
        echo "2. shadowtls 管理"
        echo "0. 退出脚本"
        echo "=================================================="
        read -p "请输入选项 [0-2]: " choice
        
        case $choice in
            1) ss_rust_menu ;;
            2) shadowtls_menu ;;
            0) break ;;
            *) echo -e "${RED}无效选项，请重试。${NC}"; sleep 1 ;;
        esac
    done
}

# --- 脚本入口 ---
check_root
main_menu
echo "脚本已退出。"

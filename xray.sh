#!/bin/bash

# =================================================================
# Xray (xtls-rprx-vision Reality) 服务器端管理脚本
# =================================================================

# 定义输出颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

XRAY_CONFIG_FILE="/usr/local/etc/xray/config.json"
XRAY_KEYS_FILE="/usr/local/etc/xray/reality.keys"

# --- 通用函数 ---
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

# --- 函数: 检查 Xray 安装和运行状态 ---
check_xray_status() {
    if [ -f /usr/local/bin/xray ] && [ -f "${XRAY_CONFIG_FILE}" ]; then
        echo -e "${GREEN}Xray 状态: 已安装${NC}"
    else
        echo -e "${RED}Xray 状态: 未安装${NC}"
    fi

    if systemctl is-active --quiet xray; then
        echo -e "${GREEN}服务状态 : 运行中${NC}"
    else
        echo -e "${RED}服务状态 : 未运行${NC}"
    fi
}

# --- 函数: 生成 Xray Reality 配置 ---
generate_xray_config() {
    echo "--> 正在收集 Reality 配置信息..."
    read -p "请输入外部监听端口 (例如 443, 留空随机): " EXT_PORT
    [ -z "$EXT_PORT" ] && EXT_PORT=$((RANDOM % 55536 + 10000))

    read -p "请输入内部 VLESS 端口 (留空随机): " INT_PORT
    [ -z "$INT_PORT" ] && INT_PORT=$((RANDOM % 55536 + 10000))
    
    read -p "请输入伪装域名 (例如 www.bing.com): " SNI_DOMAIN
    while [ -z "$SNI_DOMAIN" ]; do
        read -p "${RED}伪装域名不能为空，请重新输入: ${NC}" SNI_DOMAIN
    done

    # 新增：从用户输入中提取纯域名
    local sni_domain_cleaned=$(echo "${SNI_DOMAIN}" | cut -d':' -f1)

    echo "--> 正在生成 UUID 和 Reality 密钥对..."
    local uuid=$(/usr/local/bin/xray uuid)
    local key_pair=$(/usr/local/bin/xray x25519)
    local private_key=$(echo "$key_pair" | grep 'PrivateKey' | awk '{print $2}')
    local public_key=$(echo "$key_pair" | grep 'Password' | awk '{print $2}')
    local short_id=$(openssl rand -hex 8)
    
    # 保存私钥和公钥(Password)以便后续查看
    echo "PrivateKey: ${private_key}" > "${XRAY_KEYS_FILE}"
    echo "PublicKey: ${public_key}" >> "${XRAY_KEYS_FILE}"

    echo "--> 正在创建配置文件 ${XRAY_CONFIG_FILE}..."
    cat > "${XRAY_CONFIG_FILE}" <<EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "tag": "dokodemo-in",
            "port": ${EXT_PORT},
            "protocol": "dokodemo-door",
            "settings": {
                "address": "127.0.0.1",
                "port": ${INT_PORT},
                "network": "tcp"
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [ "tls" ],
                "routeOnly": true
            }
        },
        {
            "listen": "127.0.0.1",
            "port": ${INT_PORT},
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${uuid}",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "dest": "${sni_domain_cleaned}:443",
                    "serverNames": [ "${sni_domain_cleaned}" ],
                    "privateKey": "${private_key}",
                    "shortIds": [ "${short_id}", "0123456789abcdef" ]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [ "http", "tls", "quic" ],
                "routeOnly": true
            }
        }
    ],
    "outbounds": [
        { "protocol": "freedom", "tag": "direct" },
        { "protocol": "blackhole", "tag": "block" }
    ],
    "routing": {
        "rules": [
            {
                "inboundTag": [ "dokodemo-in" ],
                "domain": [ "${sni_domain_cleaned}" ],
                "outboundTag": "direct"
            },
            {
                "inboundTag": [ "dokodemo-in" ],
                "outboundTag": "block"
            }
        ]
    }
}
EOF
}

# --- 函数: 安装 Xray ---
install_xray() {
    if [ -f /usr/local/bin/xray ]; then
        echo -e "${GREEN}Xray 似乎已经安装。${NC}"; return; fi

    echo "--> 正在使用官方脚本安装 Xray 核心..."
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root
    if [ ! -f /usr/local/bin/xray ]; then
        echo -e "${RED}Xray 安装失败，请检查网络或官方脚本。${NC}"; exit 1; fi

    generate_xray_config

    echo "--> 正在测试配置并启动 Xray..."
    /usr/local/bin/xray -test -config "${XRAY_CONFIG_FILE}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}配置文件测试失败，请检查。${NC}"; exit 1; fi
    
    systemctl restart xray
    systemctl enable xray > /dev/null 2>&1
    echo -e "${GREEN}🎉 Xray (Reality) 安装并配置成功！${NC}"
    view_config_xray
}

# --- 函数: 卸载 Xray ---
uninstall_xray() {
    if [ ! -f /usr/local/bin/xray ]; then
        echo -e "${RED}Xray 未安装。${NC}"; return; fi
    
    read -p "警告：确定要卸载 Xray 吗？这将删除所有数据。[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[yY]([eE][sS])?$ ]]; then
        echo "卸载操作已取消。"; return; fi
    
    # 使用官方脚本卸载
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
    rm -f "${XRAY_KEYS_FILE}"
    echo -e "${GREEN}Xray 已成功卸载。${NC}"
}

# --- 函数: 查看 Xray 配置 ---
view_config_xray() {
    if [ ! -f "${XRAY_CONFIG_FILE}" ]; then
        echo -e "${RED}Xray 未安装。${NC}"; return; fi
    ensure_jq || return

    # 新增: 检查 JSON 文件有效性
    if ! jq . "${XRAY_CONFIG_FILE}" >/dev/null 2>&1; then
        echo -e "${RED}错误：配置文件 ${XRAY_CONFIG_FILE} 格式无效。${NC}"
        echo -e "${RED}请使用选项 '3. 修改 Xray 配置' 来重新生成，或手动修复文件。${NC}"
        return
    fi

    local ip_address=$(curl -s https://ipv4.icanhazip.com || echo "<您的服务器IP>")
    
    # 使用更健壮的 jq 查询，通过 tag 和 protocol 定位，避免依赖数组索引
    local ext_port=$(jq '.inbounds[] | select(.tag=="dokodemo-in") | .port' "${XRAY_CONFIG_FILE}")
    local vless_inbound=$(jq '.inbounds[] | select(.protocol=="vless")' "${XRAY_CONFIG_FILE}")

    if [ -z "$vless_inbound" ]; then
        echo -e "${RED}错误：在配置文件中找不到 VLESS 入站协议。${NC}"
        return
    fi

    local uuid=$(echo "$vless_inbound" | jq -r '.settings.clients[0].id')
    local flow=$(echo "$vless_inbound" | jq -r '.settings.clients[0].flow')
    local sni=$(echo "$vless_inbound" | jq -r '.streamSettings.realitySettings.serverNames[0]')
    local short_id=$(echo "$vless_inbound" | jq -r '.streamSettings.realitySettings.shortIds[0]')
    
    local public_key="<未找到>"
    if [ -f "${XRAY_KEYS_FILE}" ]; then
        public_key=$(grep 'PublicKey' "${XRAY_KEYS_FILE}" | awk '{print $2}')
    fi
    
    echo "------------------------------------------"
    echo "     Xray (Reality) 当前配置信息"
    echo "------------------------------------------"
    echo -e "监听地址   : ${GREEN}${ip_address}${NC}"
    echo -e "外部端口   : ${GREEN}${ext_port}${NC}"
    echo -e "UUID       : ${GREEN}${uuid}${NC}"
    echo -e "Flow       : ${GREEN}${flow}${NC}"
    echo -e "伪装域名   : ${GREEN}${sni}${NC}"
    echo -e "Short ID   : ${GREEN}${short_id}${NC}"
    echo -e "公钥 (pbk) : ${GREEN}${public_key}${NC}"
    echo "------------------------------------------"
    echo "VLESS 分享链接:"
    local vless_link="vless://${uuid}@${ip_address}:${ext_port}?encryption=none&flow=${flow}&security=reality&sni=${sni}&fp=chrome&pbk=${public_key}&sid=${short_id}&allowInsecure=1&type=tcp&headerType=none#VPS"
    echo -e "${GREEN}${vless_link}${NC}"
    echo "------------------------------------------"
}

# --- 函数: 修改 Xray 配置 ---
modify_config_xray() {
    if [ ! -f "${XRAY_CONFIG_FILE}" ]; then
        echo -e "${RED}Xray 未安装。${NC}"; return; fi

    echo "此操作将重新生成所有配置和密钥。"
    read -p "确定要继续吗？[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[yY]([eE][sS])?$ ]]; then
        echo "修改操作已取消。"; return; fi

    generate_xray_config

    /usr/local/bin/xray -test -config "${XRAY_CONFIG_FILE}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}新配置文件测试失败，请检查。配置未应用。${NC}"; return; fi

    systemctl restart xray
    echo -e "${GREEN}🎉 Xray (Reality) 配置已更新！${NC}"
    view_config_xray
}

# --- 函数: Xray 服务管理 ---
manage_xray_service() {
    if ! systemctl list-units --type=service | grep -q "xray.service"; then
        echo -e "${RED}Xray 服务未安装。${NC}"; return; fi
    case $1 in
        start) systemctl start xray && echo -e "${GREEN}服务启动成功。${NC}" || echo -e "${RED}服务启动失败。${NC}" ;;
        stop) systemctl stop xray && echo -e "${GREEN}服务已停止。${NC}" || echo -e "${RED}服务停止失败。${NC}" ;;
        restart) systemctl restart xray && echo -e "${GREEN}服务重启成功。${NC}" || echo -e "${RED}服务重启失败。${NC}" ;;
        status) systemctl status xray ;;
    esac
}

# --- 函数: Xray 主菜单 ---
xray_menu() {
    while true; do
        clear
        echo "=================================================="
        echo "       XTLS-RPRX-VISION Reality 管理脚本"
        echo "=================================================="
        check_xray_status
        echo "--------------------------------------------------"
        echo "1. 安装 Xray (Reality)"
        echo "2. 卸载 Xray"
        echo "3. 修改 Xray 配置"
        echo "4. 查看 Xray 配置"
        echo "5. 启动 Xray"
        echo "6. 停止 Xray"
        echo "7. 重启 Xray"
        echo "8. 查看运行状态"
        echo "0. 退出脚本"
        echo "=================================================="
        read -p "请输入选项 [0-8]: " choice

        case $choice in
            1) install_xray ;;
            2) uninstall_xray ;;
            3) modify_config_xray ;;
            4) view_config_xray ;;
            5) manage_xray_service start ;;
            6) manage_xray_service stop ;;
            7) manage_xray_service restart ;;
            8) manage_xray_service status ;;
            0) break ;;
            *) echo -e "${RED}无效选项，请重试。${NC}" ;;
        esac
        [ "$choice" != "0" ] && [ "$choice" != "8" ] && read -p "按 Enter 键返回..."
    done
}

# --- 脚本入口 ---
check_root
xray_menu
echo "脚本已退出。"


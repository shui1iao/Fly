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
    if [ -f /usr/local/bin/xray ]; then
        echo -e "${GREEN}Xray 核心: 已安装${NC}"
    else
        echo -e "${RED}Xray 核心: 未安装${NC}"
    fi

    if [ -f "${XRAY_CONFIG_FILE}" ]; then
        echo -e "${GREEN}配置状态 : 已配置${NC}"
        if systemctl is-active --quiet xray; then
            echo -e "${GREEN}服务状态 : 运行中${NC}"
        else
            echo -e "${RED}服务状态 : 未运行${NC}"
        fi
    else
        echo -e "${RED}配置状态 : 未配置${NC}"
    fi
}


# --- 函数: 生成 Reality 配置 ---
generate_reality_simple_config() {
    echo "--> 正在配置 Reality 配置..."
    read -p "请输入监听端口 (例如 443, 留空随机): " PORT
    [ -z "$PORT" ] && PORT=$((RANDOM % 55536 + 10000))

    read -p "请输入伪装域名 (留空则默认为 icloud.com): " SNI_DOMAIN
    [ -z "$SNI_DOMAIN" ] && SNI_DOMAIN="icloud.com"

    local sni_domain_cleaned=$(echo "${SNI_DOMAIN}" | cut -d':' -f1)

    echo "--> 正在生成 UUID 和 Reality 密钥对..."
    local uuid=$(/usr/local/bin/xray uuid)
    local key_pair=$(/usr/local/bin/xray x25519)
    local private_key=$(echo "$key_pair" | grep 'PrivateKey' | awk '{print $2}')
    local public_key=$(echo "$key_pair" | grep 'Password' | awk '{print $2}')

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
            "port": ${PORT},
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
                    "shortIds": [ "", "0123456789abcdef" ]
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
        {
            "protocol": "freedom",
            "tag": "direct"
        }
    ]
}
EOF
}


# --- 函数: 生成 Reality (防偷) 配置 ---
generate_reality_dokodemo_config() {
    echo "--> 正在配置 Reality (防偷)..."
    read -p "请输入外部监听端口 (例如 443, 留空随机): " EXT_PORT
    [ -z "$EXT_PORT" ] && EXT_PORT=$((RANDOM % 55536 + 10000))

    read -p "请输入内部 VLESS 端口 (留空随机): " INT_PORT
    [ -z "$INT_PORT" ] && INT_PORT=$((RANDOM % 55536 + 10000))
    
    read -p "请输入伪装域名 (留空则默认为 icloud.com): " SNI_DOMAIN
    [ -z "$SNI_DOMAIN" ] && SNI_DOMAIN="icloud.com"

    local sni_domain_cleaned=$(echo "${SNI_DOMAIN}" | cut -d':' -f1)

    echo "--> 正在生成 UUID 和 Reality 密钥对..."
    local uuid=$(/usr/local/bin/xray uuid)
    local key_pair=$(/usr/local/bin/xray x25519)
    local private_key=$(echo "$key_pair" | grep 'PrivateKey' | awk '{print $2}')
    local public_key=$(echo "$key_pair" | grep 'Password' | awk '{print $2}')
    
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
                    "shortIds": [ "", "0123456789abcdef" ]
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

# --- 函数: 安装 Xray 核心 ---
install_xray_core() {
    if [ -f /usr/local/bin/xray ]; then
        echo -e "${GREEN}Xray 核心已安装，无需重复操作。${NC}"
        return 0
    fi
    echo "--> 正在使用官方脚本安装 Xray 核心..."
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root
    if [ ! -f /usr/local/bin/xray ]; then
        echo -e "${RED}Xray 核心安装失败。${NC}"
        return 1
    else
        echo -e "${GREEN}Xray 核心安装成功。${NC}"
        echo "--> 正在清理旧的配置文件..."
        systemctl stop xray >/dev/null 2>&1
        rm -f "${XRAY_CONFIG_FILE}"
        rm -f "${XRAY_KEYS_FILE}"
        echo "    旧配置已清理。"
        return 0
    fi
}

# --- 函数: (包装器) 配置 Reality ---
configure_reality_simple() {
    if ! [ -f /usr/local/bin/xray ]; then
        echo "--> Xray 核心未安装，正在自动安装..."
        install_xray_core || return
    fi

    if [ -f "${XRAY_CONFIG_FILE}" ]; then
        read -p "检测到现有配置，继续将覆盖它。确定吗？[y/N]: " confirm
        if [[ ! "$confirm" =~ ^[yY] ]]; then echo "操作已取消。"; return; fi
    fi
    
    generate_reality_simple_config
    
    echo "--> 正在测试配置并启动 Xray..."
    /usr/local/bin/xray -test -config "${XRAY_CONFIG_FILE}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}配置文件测试失败，请检查。配置未应用。${NC}"; return; fi
    
    systemctl restart xray
    systemctl enable xray > /dev/null 2>&1
    echo -e "${GREEN}🎉 Xray Reality 配置成功！${NC}"
    view_config_xray
}

# --- 函数: (包装器) 配置 Reality (防偷) ---
configure_reality_dokodemo() {
    if ! [ -f /usr/local/bin/xray ]; then
        echo "--> Xray 核心未安装，正在自动安装..."
        install_xray_core || return
    fi
    
    if [ -f "${XRAY_CONFIG_FILE}" ]; then
        read -p "检测到现有配置，继续将覆盖它。确定吗？[y/N]: " confirm
        if [[ ! "$confirm" =~ ^[yY] ]]; then echo "操作已取消。"; return; fi
    fi

    generate_reality_dokodemo_config
    
    echo "--> 正在测试配置并启动 Xray..."
    /usr/local/bin/xray -test -config "${XRAY_CONFIG_FILE}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}配置文件测试失败，请检查。配置未应用。${NC}"; return; fi
    
    systemctl restart xray
    systemctl enable xray > /dev/null 2>&1
    echo -e "${GREEN}🎉 Xray Reality (防偷) 配置成功！${NC}"
    view_config_xray
}


# --- 函数: 卸载 Xray ---
uninstall_xray() {
    if [ ! -f /usr/local/bin/xray ]; then
        echo -e "${RED}Xray 未安装。${NC}"; return; fi
    
    read -p "警告：确定要卸载 Xray 吗？这将删除所有数据。[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[yY]([eE][sS])?$ ]]; then
        echo "卸载操作已取消。"; return; fi
    
    systemctl stop xray
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
    rm -f "${XRAY_KEYS_FILE}"
    echo -e "${GREEN}Xray 已成功卸载。${NC}"
}

# --- 函数: 查看 Xray 配置 ---
view_config_xray() {
    if [ ! -f "${XRAY_CONFIG_FILE}" ]; then
        echo -e "${RED}Xray 未配置。请先选择一个配置方案。${NC}"; return; fi
    ensure_jq || return

    if ! jq . "${XRAY_CONFIG_FILE}" >/dev/null 2>&1; then
        echo -e "${RED}错误：配置文件 ${XRAY_CONFIG_FILE} 格式无效。${NC}"; return; fi

    local ip_address=$(curl -s https://ipv4.icanhazip.com || echo "<您的服务器IP>")
    local public_key="<未找到>"
    if [ -f "${XRAY_KEYS_FILE}" ]; then
        public_key=$(grep 'PublicKey' "${XRAY_KEYS_FILE}" | awk '{print $2}')
    fi

    echo "------------------------------------------"
    echo "     Xray (Reality) 当前配置信息"
    echo "------------------------------------------"
    
    # 通过 tag 判断配置类型
    if jq -e '.inbounds[] | select(.tag=="dokodemo-in")' "${XRAY_CONFIG_FILE}" >/dev/null 2>&1; then
        # 防偷配置
        local ext_port=$(jq '.inbounds[] | select(.tag=="dokodemo-in") | .port' "${XRAY_CONFIG_FILE}")
        local vless_inbound=$(jq '.inbounds[] | select(.protocol=="vless")' "${XRAY_CONFIG_FILE}")
        local uuid=$(echo "$vless_inbound" | jq -r '.settings.clients[0].id')
        local flow=$(echo "$vless_inbound" | jq -r '.settings.clients[0].flow')
        local sni=$(echo "$vless_inbound" | jq -r '.streamSettings.realitySettings.serverNames[0]')
        local short_id=$(echo "$vless_inbound" | jq -r '.streamSettings.realitySettings.shortIds[0]')
        
        echo -e "配置类型   : ${GREEN}Reality (防偷)${NC}"
        echo -e "监听地址   : ${GREEN}${ip_address}${NC}"
        echo -e "外部端口   : ${GREEN}${ext_port}${NC}"
        echo -e "UUID       : ${GREEN}${uuid}${NC}"
        echo -e "Flow       : ${GREEN}${flow}${NC}"
        echo -e "伪装域名   : ${GREEN}${sni}${NC}"
        echo -e "Short ID   : ${GREEN}${short_id}${NC}"
        echo -e "公钥 (pbk) : ${GREEN}${public_key}${NC}"
        echo "------------------------------------------"
        echo "VLESS 分享链接:"
        local vless_link="vless://${uuid}@${ip_address}:${ext_port}?encryption=none&flow=${flow}&security=reality&sni=${sni}&fp=chrome&pbk=${public_key}&sid=${short_id}&allowInsecure=1&type=tcp&headerType=none#VPS_防偷"
        echo -e "${GREEN}${vless_link}${NC}"

    else
        # Reality 配置
        local vless_inbound=$(jq '.inbounds[] | select(.protocol=="vless")' "${XRAY_CONFIG_FILE}")
        local port=$(echo "$vless_inbound" | jq -r '.port')
        local uuid=$(echo "$vless_inbound" | jq -r '.settings.clients[0].id')
        local flow=$(echo "$vless_inbound" | jq -r '.settings.clients[0].flow')
        local sni=$(echo "$vless_inbound" | jq -r '.streamSettings.realitySettings.serverNames[0]')
        local short_id=$(echo "$vless_inbound" | jq -r '.streamSettings.realitySettings.shortIds[0]')

        echo -e "配置类型   : ${GREEN}Reality 配置${NC}"
        echo -e "监听地址   : ${GREEN}${ip_address}${NC}"
        echo -e "端口       : ${GREEN}${port}${NC}"
        echo -e "UUID       : ${GREEN}${uuid}${NC}"
        echo -e "Flow       : ${GREEN}${flow}${NC}"
        echo -e "伪装域名   : ${GREEN}${sni}${NC}"
        echo -e "Short ID   : ${GREEN}${short_id}${NC}"
        echo -e "公钥 (pbk) : ${GREEN}${public_key}${NC}"
        echo "------------------------------------------"
        echo "VLESS 分享链接:"
        local vless_link="vless://${uuid}@${ip_address}:${port}?encryption=none&flow=${flow}&security=reality&sni=${sni}&fp=chrome&pbk=${public_key}&sid=${short_id}&allowInsecure=1&type=tcp&headerType=none#VPS_Reality"
        echo -e "${GREEN}${vless_link}${NC}"
    fi
    echo "------------------------------------------"
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
        echo "1. 安装 Xray 核心"
        echo "2. 配置 Reality"
        echo "3. 配置 Reality (防偷)"
        echo "4. 卸载 Xray"
        echo "5. 查看 Xray 配置"
        echo "6. 启动 Xray"
        echo "7. 停止 Xray"
        echo "8. 重启 Xray"
        echo "9. 查看运行状态"
        echo "0. 退出脚本"
        echo "=================================================="
        read -p "请输入选项 [0-9]: " choice

        case $choice in
            1) install_xray_core ;;
            2) configure_reality_simple ;;
            3) configure_reality_dokodemo ;;
            4) uninstall_xray ;;
            5) view_config_xray ;;
            6) manage_xray_service start ;;
            7) manage_xray_service stop ;;
            8) manage_xray_service restart ;;
            9) manage_xray_service status ;;
            0) break ;;
            *) echo -e "${RED}无效选项，请重试。${NC}" ;;
        esac
        [ "$choice" != "0" ] && [ "$choice" != "9" ] && read -p "按 Enter 键返回..."
    done
}

# --- 脚本入口 ---
check_root
xray_menu
echo "脚本已退出。"


#!/usr/bin/env bash
# ==============================================================================
# OpenGFW Production One-Click Installer
# Repository: https://github.com/showcode1024/mygfw
# Supported OS: Linux (Debian, Ubuntu, CentOS, RHEL, AlmaLinux, Rocky)
# Architectures: amd64 (x86_64), arm64 (aarch64)
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/opt/opengfw"
BIN_PATH="${INSTALL_DIR}/opengfw"
CONFIG_PATH="${INSTALL_DIR}/config.yaml"
RULES_PATH="${INSTALL_DIR}/rules.yaml"
SERVICE_PATH="/etc/systemd/system/opengfw.service"
OPENGFW_VERSION="v0.4.3"

echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}          OpenGFW 一键生产级部署脚本 (mygfw)          ${NC}"
echo -e "${CYAN}======================================================${NC}"

# 1. 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR] 此脚本必须以 root 权限运行，请使用 sudo 或 root 用户执行。${NC}"
    exit 1
fi

# 2. 检查 systemd
if [[ ! -d /run/systemd/system ]]; then
    echo -e "${RED}[ERROR] 当前系统未运行 systemd，不支持作为服务自启。${NC}"
    exit 1
fi

# 3. 架构检测
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)
        BIN_ARCH="amd64"
        ;;
    aarch64|arm64)
        BIN_ARCH="arm64"
        ;;
    *)
        echo -e "${RED}[ERROR] 不支持的架构: ${ARCH}，OpenGFW 仅支持 amd64 / arm64。${NC}"
        exit 1
        ;;
esac
echo -e "${GREEN}[1/5] 系统架构检测通过: ${ARCH} (${BIN_ARCH})${NC}"

# 4. 安装底层依赖 (nftables, libnetfilter-queue, conntrack)
echo -e "${BLUE}[2/5] 正在安装必要内核与网络依赖 (nftables, netfilter-queue, conntrack)...${NC}"
if command -v apt-get &>/dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq nftables libnetfilter-queue1 conntrack curl ca-certificates
elif command -v dnf &>/dev/null; then
    dnf install -y nftables libnetfilter_queue conntrack-tools curl ca-certificates
elif command -v yum &>/dev/null; then
    yum install -y nftables libnetfilter_queue conntrack-tools curl ca-certificates
else
    echo -e "${YELLOW}[WARN] 未知包管理器，请确保系统中已手动安装 nftables、libnetfilter-queue、conntrack。${NC}"
fi

# 5. 下载 OpenGFW 二进制文件
echo -e "${BLUE}[3/5] 正在下载 OpenGFW 二进制程序 (${OPENGFW_VERSION})...${NC}"
mkdir -p "${INSTALL_DIR}"

DOWNLOAD_URL="https://github.com/HyNetworks/OpenGFW/releases/download/${OPENGFW_VERSION}/OpenGFW-linux-${BIN_ARCH}"
if ! curl -fsSL -o "${BIN_PATH}" "${DOWNLOAD_URL}"; then
    echo -e "${RED}[ERROR] 下载 OpenGFW 失败，请检查网络或 GitHub 连通性。${NC}"
    exit 1
fi
chmod +x "${BIN_PATH}"
echo -e "${GREEN}      程序文件已就绪: ${BIN_PATH}${NC}"

# 6. 生成配置文件 config.yaml
echo -e "${BLUE}[4/5] 正在写入生产级配置与安全规则...${NC}"
cat << 'EOF' > "${CONFIG_PATH}"
io:
  queueSize: 1024
  queueNum: 100          # 绑定的 Netfilter 队列号
  table: opengfw         # 自动管理的 nftables 表名
  connMarkAccept: 1001   # 内核硬件级直通标记 (0x3e9)
  connMarkDrop: 1002     # 内核硬件级丢弃标记 (0x3ea)
  rcvBuf: 4194304        # 接收套接字缓冲 (4MB，大流量防丢包)
  sndBuf: 4194304        # 发送套接字缓冲 (4MB)
  local: true            # 审查宿主机及监听端口流量
  rst: false             # 拦截时静默丢弃，不回传 TCP RST，防扫描探测

workers:
  count: 2               # 工作线程数
  queueSize: 16
  tcpMaxBufferedPagesTotal: 4096
  tcpMaxBufferedPagesPerConn: 64
  udpMaxStreams: 4096
EOF

# 7. 生成规则文件 rules.yaml
cat << 'EOF' > "${RULES_PATH}"
# 1. 封禁 Shadowsocks 与 原生密文 VMess-TCP (通过 FET 密文熵值与全加密流量特征识别)
- name: "Block_Shadowsocks_and_VMess"
  action: block
  log: true
  expr: fet != nil && fet.yes

# 2. 封禁明文 VMess-WS / HTTP WebSocket 代理 (无 TLS 加密的 WebSocket 握手)
- name: "Block_Plaintext_VMess_WS"
  action: block
  log: true
  expr: lower(string(http?.req?.headers?.upgrade)) == "websocket"

# 3. 封禁明文 SOCKS4/5 代理
- name: "Block_Socks"
  action: block
  log: true
  expr: socks != nil

# 4. 封禁 Trojan 代理协议
- name: "Block_Trojan"
  action: block
  log: true
  expr: trojan != nil && trojan.yes

# 5. 拦截境内域名 SNI 伪装 (防止租户拿国内大厂域名伪装引来墙封 IP，同时覆盖 TLS 与 QUIC)
- name: "Block_Domestic_SNI_Spoofing"
  action: block
  log: true
  expr: >
    let sni = lower(string(tls?.req?.sni) != "" ? string(tls?.req?.sni) : string(quic?.req?.sni));
    sni != "" && (
      sni endsWith ".cn" ||
      sni contains "douyin.com" ||
      sni contains "baidu.com" ||
      sni contains "qq.com" ||
      sni contains "bilibili.com" ||
      sni contains "taobao.com" ||
      sni contains "jd.com" ||
      sni contains "alipay.com" ||
      sni contains "163.com" ||
      sni contains "weibo.com" ||
      sni contains "zhihu.com"
    )
EOF

# 8. 写入 systemd 服务单元
cat << 'EOF' > "${SERVICE_PATH}"
[Unit]
Description=OpenGFW Deep Packet Inspection Firewall
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/opengfw
ExecStart=/opt/opengfw/opengfw -c /opt/opengfw/config.yaml /opt/opengfw/rules.yaml
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=3s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# 9. 启动并启用服务
echo -e "${BLUE}[5/5] 正在注册并启动 systemd 开机自启服务...${NC}"
systemctl daemon-reload
systemctl enable --now opengfw

sleep 1

# 10. 检查运行状态
if systemctl is-active --quiet opengfw; then
    echo -e "${GREEN}======================================================${NC}"
    echo -e "${GREEN}           🎉 OpenGFW 服务安装并启动成功！             ${NC}"
    echo -e "${GREEN}======================================================${NC}"
    echo -e "程序目录: ${INSTALL_DIR}"
    echo -e "配置文件: ${CONFIG_PATH}"
    echo -e "规则文件: ${RULES_PATH}"
    echo -e ""
    echo -e "${CYAN}常用管理命令：${NC}"
    echo -e "  查看服务状态:   ${YELLOW}systemctl status opengfw${NC}"
    echo -e "  查看实时拦截日志: ${YELLOW}journalctl -u opengfw -f${NC}"
    echo -e "  修改规则后重载: ${YELLOW}systemctl reload opengfw${NC}"
    echo -e "  查看内核规则表: ${YELLOW}nft list table inet opengfw${NC}"
    echo -e "  重启服务:       ${YELLOW}systemctl restart opengfw${NC}"
    echo -e "  停止服务:       ${YELLOW}systemctl stop opengfw${NC}"
    echo -e "======================================================"
else
    echo -e "${RED}[ERROR] OpenGFW 启动失败，请运行 'journalctl -u opengfw -e' 排查日志。${NC}"
    exit 1
fi

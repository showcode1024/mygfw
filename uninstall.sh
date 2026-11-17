#!/usr/bin/env bash
# ==============================================================================
# OpenGFW One-Click Uninstaller
# Repository: https://github.com/showcode1024/mygfw
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR] 此脚本必须以 root 权限运行。${NC}"
    exit 1
fi

echo -e "${YELLOW}正在停止并卸载 OpenGFW 服务...${NC}"

if systemctl is-active --quiet opengfw 2>/dev/null; then
    systemctl stop opengfw
fi

if systemctl is-enabled --quiet opengfw 2>/dev/null; then
    systemctl disable opengfw
fi

rm -f /etc/systemd/system/opengfw.service
systemctl daemon-reload

# 确保 nftables 表清理
nft delete table inet opengfw 2>/dev/null || true

# 删除安装目录
rm -rf /opt/opengfw

echo -e "${GREEN}OpenGFW 已彻底卸载并清理完毕！${NC}"

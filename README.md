# mygfw — OpenGFW 一键生产级部署脚本

基于 [HyNetworks/OpenGFW](https://github.com/HyNetworks/OpenGFW) 的深度包检测 (DPI) 自动化防火墙部署套件。专为 NAT VPS / 服务器设计，用于主动封禁高危代理协议和境内域名伪装，防止整机 IP 被墙。

---

## 🚀 一键快速安装

以 `root` 用户在服务器上执行以下单行命令即可全自动安装、配置并启动：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/showcode1024/mygfw/main/install.sh)
```
或者：
```bash
curl -fsSL https://raw.githubusercontent.com/showcode1024/mygfw/main/install.sh | bash
```

> **系统支持**：Debian 10+, Ubuntu 20.04+, CentOS 8+, AlmaLinux, Rocky Linux  
> **架构支持**：AMD64 (x86_64), ARM64 (aarch64)

---

## 🛡️ 防御与拦截特性

1. **封禁 Shadowsocks 与 原生密文 VMess-TCP**：通过 FET（全加密高熵流量特征）精准识别并阻断。
2. **封禁明文 VMess-WS**：检测无 TLS 加密的 HTTP WebSocket 握手 (`Upgrade: websocket`) 并阻断。
3. **封禁明文 SOCKS4/5 代理**：识别 SOCKS 握手特征并阻断。
4. **封禁 Trojan 代理协议**：识别 Trojan 协议特征并阻断。
5. **拦截境内 SNI 伪装**：拦截拿国内大厂（抖音、百度、腾讯、B站、淘宝、京东、网易、微博、知乎、各类 `.cn` 等）作为伪装域名的 TLS/QUIC 连接，彻底防范整机 IP 遭墙标记。
6. **合规流量内核级硬件直通**：正常流量（如 VLESS-Reality、正常外网 HTTPS、SSH 等）仅首包送审，识别合规后由 Linux 内核打标直通，吞吐极高、CPU 极低。
7. **零手工 iptables**：程序全自动接管 `nftables`，停止时规则全自动清除，不留任何内核残留。

---

## 🛠️ 常用管理命令

| 操作 | 命令 |
| :--- | :--- |
| **查看运行状态** | `systemctl status opengfw` |
| **查看实时拦截日志** | `journalctl -u opengfw -f` |
| **修改规则后热重载 (无需断网)** | `systemctl reload opengfw` |
| **检查内核规则表与加速统计** | `nft list table inet opengfw` |
| **重启防火墙** | `systemctl restart opengfw` |
| **停止防火墙** | `systemctl stop opengfw` |

---

## 📂 文件目录说明

* 安装路径：`/opt/opengfw/`
* 主程序文件：`/opt/opengfw/opengfw`
* 引擎配置：`/opt/opengfw/config.yaml`
* 拦截规则：`/opt/opengfw/rules.yaml`
* 系统服务：`/etc/systemd/system/opengfw.service`

---

## 🗑️ 一键彻底卸载

如需卸载 OpenGFW 并清理所有内核表和目录：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/showcode1024/mygfw/main/uninstall.sh)
```

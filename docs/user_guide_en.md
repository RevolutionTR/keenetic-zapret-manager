# 📘 Keenetic Zapret Manager — Complete User Guide

This document provides a full reference for **all main menus and sub-menus** in the script.

Suitable for both new and advanced users.

---

## 🚀 Installation — Up and Running in 30 Seconds

Keenetic Zapret Manager lets you bypass DPI restrictions with minimal configuration.

Installation is simpler than you think. Connect to your router via SSH and download the script with one of the commands below:

```bash
wget -O /opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh \
  https://raw.githubusercontent.com/RevolutionTR/keenetic-zapret-manager/main/keenetic_zapret_otomasyon_ipv6_ipset.sh
chmod +x /opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh
/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh
```

Or

```bash
curl -fsSL https://raw.githubusercontent.com/RevolutionTR/keenetic-zapret-manager/main/keenetic_zapret_otomasyon_ipv6_ipset.sh \
-o /opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh
chmod +x /opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh
/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh
```

---

# 🧭 Main Menu Map

| Menu | Description |
|------|-------------|
| 1 | Install Zapret |
| 2 | Remove Zapret |
| 3 | Start Zapret |
| 4 | Stop Zapret |
| 5 | Restart Zapret |
| 6 | Zapret Version Info |
| 7 | IPv6 Wizard |
| 8 | Backup / Restore |
| 9 | DPI Profile Management |
| 10 | Script Update |
| 11 | Hostlist / Autohostlist |
| 12 | IPSet Management |
| 13 | Rollback (Revert Version) |
| 14 | Network Diagnostics & System Check |
| 15 | Telegram Notifications |
| 16 | Health Monitor |
| 17 | Web Panel (GUI) |
| B | Blockcheck |
| L | Switch Language (TR/EN) |
| R | Scheduled Reboot (Cron) |
| U | Full Clean Uninstall |

---

# 🔹 Menu 1 — Install Zapret

Installs the Zapret DPI bypass engine on your router.

### What it does:

✔ Downloads Zapret components  
✔ Creates firewall rules  
✔ Prepares the NFQWS engine  
✔ Applies the default DPI profile  

👉 **This is all you need to do on first install.**

**A router reboot may be performed after installation.**

---

# 🔹 Menu 2 — Remove Zapret

Safely removes Zapret from the system.

### What gets removed:

✔ Firewall rules  
✔ NFQWS  
✔ Zapret services  
✔ NFQUEUE / ipset leftovers  

### What is kept:

✔ Manager (KZM)  
✔ Health Monitor  
✔ Telegram settings  

👉 Ideal for users who want to reinstall Zapret.

**This is not a full clean uninstall.**

### How it works:

After removal, the system is automatically verified. The NFQWS process, NFQUEUE rules, ipset sets and Zapret directory are all checked. If any leftovers are detected, a second cleanup pass runs automatically without asking the user.

If Zapret is already not installed, the system is scanned for leftovers:

- Leftovers found → you are asked whether to clean them  
- No leftovers → "System is clean, no leftovers found." message is shown

---

# 🔹 Menu 3 — Start Zapret

Activates Zapret services and brings DPI bypass rules online.

---

# 🔹 Menu 4 — Stop Zapret

Stops the Zapret service. All routing and bypass operations are paused.

---

# 🔹 Menu 5 — Restart Zapret

Restarts the Zapret service.

👉 Recommended after changing a profile or modifying settings.

---

# 🔹 Menu 6 — Zapret Version Info (Installed / GitHub)

Shows the latest Zapret version available on GitHub and the version currently installed on the device.

---

# 🔹 Menu 7 — Zapret IPv6 Support (Wizard)

Applies the required IPv6 configuration using a step-by-step wizard, for lines with IPv6 enabled.

---

# 🔹 Menu 8 — Backup / Restore

Backs up Zapret settings or restores a previous backup.

👉 Taking a backup before major changes is recommended.

---

# 🔹 Menu 9 — DPI Profile Management

Changes the DPI bypass method.

### Sub-menu:

✔ Select active profile  
✔ View current profile  
✔ Reset to default  

### Profile types:

- TTL spoof  
- Fake packet  
- Signature concealment  
- ISP-specific settings  

⚠️ An incorrect profile can cause internet issues.

👉 If unsure, stick with the default.

---

# 🔹 Menu 10 — Script Update

Updates the manager script from GitHub.

### Safety mechanism:

| Condition | Behavior |
|-----------|----------|
| Local < GitHub | Updates |
| Local = GitHub | Skips |
| Local > GitHub | Skips |

✔ Downgrades are blocked  
✔ Version loops cannot occur  

---

# 🔹 Menu 11 — Hostlist / Autohostlist (Filtering + Scope Mode)

This menu manages manual hostlist, automatic autohostlist and bypass scope together.

Determines which traffic the bypass is applied to.

---

## 🌐 Global

Applied to the entire network.

✔ Maximum compatibility  
❗ Slightly higher CPU usage  

👉 Safe for new users.

---

## 🧠 Smart Mode (Autohostlist)

Applied only to blocked hosts.

✔ Lower CPU usage  
✔ Cleaner traffic  
✔ More stable routing  

👉 Recommended mode for long-term use.

---

## Hostlist Management

Manual list of blocked domains.

### Sub-menu:

✔ Add domain  
✔ Remove domain  
✔ Add multiple domains  
✔ Clear list  
✔ View list  

👉 Used for services that autohostlist cannot detect automatically.

---

## Autohostlist

Learns blocked services automatically.

### Sub-menu:

✔ Enable / Disable  
✔ Reset list  
✔ Merge with manual list  

👉 Builds an optimized bypass list over time.

**A true set-and-forget feature.**

---

# 🔹 Menu 12 — IPSet Management

Specifies which devices bypass is applied to.

### Sub-menu:

✔ Add IP  
✔ Remove IP  
✔ View active list  
✔ Clear list  

### Use case:

Apply bypass only to specific devices such as:

- Smart TV  
- Game console  
- Apple TV  
- Android Box  

👉 Protects router CPU resources.

---

### No Zapret (Exemption) Management

IPs on this list are **exempt** from Zapret processing (e.g. IPTV boxes).

---

# 🔹 Menu 13 — Rollback (Revert Version)

Allows you to roll back to a previous version if you encounter issues after a script update.

Includes:

✔ Fetching the GitHub version list  
✔ Installing the selected version  
✔ Backing up the current file  

👉 A lifesaver after updates.

---

# 🔹 Menu 14 — Network Diagnostics & System Check

Performs a comprehensive analysis of system and network health.

### Sub-menu:

✔ Run Diagnostics  
✔ Refresh OPKG Package List  

### Checks:

**Network & DNS**  
✔ WAN connection status and IP address (IPv4/IPv6, CGNAT/NAT/Public)  
✔ DNS mode (DoH / DoT / Plain) and security level  
✔ Active DNS providers  
✔ Local DNS resolution  
✔ External DNS (8.8.8.8) access  
✔ DNS consistency  
✔ Default route  

**System**  
✔ Script path verification  
✔ Internet access (ping)  
✔ RAM usage  
✔ CPU load average  
✔ Disk usage (/opt)  
✔ Time / NTP synchronisation  

**Services**  
✔ GitHub access  
✔ OPKG package status  
✔ Zapret running state  
✔ KeenDNS status and reachability  

👉 If something isn't working, check here first.

---

# 🔹 Menu 15 — Telegram Notifications

Manages Telegram bot integration and notification settings.

### Sub-menu:

✔ Save / Update Token & Chat ID  
✔ Send Test Message  
✔ Delete Config (Reset)  
✔ Telegram Bot Management  

### One-way Notifications:

- Service restart / recovery alerts  
- Health Monitor warnings (CPU/RAM/Disk/WAN etc.)  
- Update notifications  

### Two-way Bot (Telegram Bot Management):

Commands can be sent to the router directly from Telegram.

**Bot sub-menu:**  
✔ Enable / Configure Bot (polling interval is set here)  
✔ Disable Bot  
✔ Restart Bot  

**Available actions via bot buttons:**  
✔ Status — Shows Zapret and system status  
✔ Zapret — Start / Stop / Restart / Update  
✔ System — Update KZM / Reboot Router  
✔ Logs — KZM Log / System Log  

👉 When the bot is active, it shows "ACTIVE - 2-way communication running".

⚠️ Bot Token and Chat ID must be entered correctly.

---

# 🔹 Menu 16 — Health Monitor

An automation engine running in the background.

### Monitored resources:

✔ CPU  
✔ RAM  
✔ Disk  
✔ WAN  
✔ Zapret  
✔ DNS  

### Features:

✔ Telegram notifications  
✔ Auto restart  
✔ Update checks  

👉 Keeping this enabled is **strongly recommended.**

---

# 🔹 Menu 17 — Web Panel (GUI)

A visual management panel accessible from a browser.

Default port: **8088** → `http://<router-ip>:8088`

### Sub-menu:

✔ Install Web Panel  
✔ Remove Web Panel  
✔ Update Web Panel  
✔ Web Panel Status  
✔ Enable / Disable Web Panel  

### Features:

- Zapret status and controls  
- DPI profile switching  
- Hostlist management  
- IPSet management  
- Health Monitor monitoring  
- Telegram settings  
- OPKG updates  

👉 Basic management is possible without an SSH connection to the router.

⚠️ Requires the lighttpd package. It is installed automatically during setup.

---

# 🔹 R — Scheduled Reboot (Cron)

Automatically reboots the router at a specified time or day.

### Sub-menu:

✔ Show current schedule  
✔ Add / update daily reboot (every day at HH:MM)  
✔ Add / update weekly reboot (specific day + HH:MM)  
✔ Delete schedule  

👉 Recommended for routers that run for extended periods, to free up memory.

⚠️ The crond service must be running. A warning is shown if it is not.

---

# 🔵 B — Blockcheck Test Menu

Runs DPI tests and analyses the connection state.

What it does:

- Identifies which protocol is causing issues  
- Validates profiles using DPI Health Score and test results  
- Provides quick diagnosis during troubleshooting  

---

# 🌐 L — Switch Language (TR/EN)

Switches the interface language between Turkish and English.

---

# 🔥 Menu U — Full Clean Uninstall

⚠️ This action cannot be undone.

Returns the router to the state it was in before KZM was installed.

---

## Steps

### ✔ 1. Zapret is removed  
(Full removal routine runs, including verification and automatic second cleanup pass)

### ✔ 2. Manager leftovers are cleaned

Removed items:

- Health Monitor  
- Telegram config  
- Init services  
- Log files  
- State files  
- Backup files  

---

## Safety Design

👉 The script file is **intentionally not deleted.**

Reasons:

✔ Prevents the user from being locked out  
✔ Reduces the need to re-download the script  

Users who wish to delete it can do so manually.

---

# ⭐ RECOMMENDED USAGE FLOW

## New User

1 → Install  
16 → Enable Health Monitor  

---

## Advanced User

Use Smart Mode + Autohostlist.

---

## Troubleshooting

14 → Diagnostics → Full clean uninstall → Reinstall.

---

# 🚨 CRITICAL WARNING

Do not change DPI settings randomly.

Most issues are caused by:

✔ ISP-side changes  
✔ DNS problems  
✔ Incorrect profile

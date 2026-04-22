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

### Installation Steps (automatic):

1. OPKG packages are checked; missing ones are installed (`curl`, `ipset`, `iptables`, `cron` etc.)
2. The latest Zapret release is downloaded from GitHub and installed to `/opt/zapret`
3. You are asked whether to enable **IPv6 support**
4. The **WAN interface** is selected (e.g. `ppp0`, `eth2.1`)
5. Keenetic-specific configurations are applied
6. The default DPI profile is activated: **Turk Telekom Fiber (TTL2 fake)**
7. Zapret is started
8. If Health Monitor is not yet enabled, it is activated automatically at the end of installation

👉 **This is all you need to do on first install.**

⚠️ If Zapret is already installed, the process is skipped and "Zapret already installed" is shown.

**The DPI profile can be changed later from Menu 9.**

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

Before starting, the `/tmp/.zapret_paused` flag file is cleared. While this flag is present, Zapret cannot start automatically — it is created by Menu 4.

---

# 🔹 Menu 4 — Stop Zapret

Stops the Zapret service. All routing and bypass operations are paused.

The `/tmp/.zapret_paused` flag file is created. This flag ensures that:
- Even if the netfilter hook fires, Zapret will not restart
- The init.d service cannot start it either

⚠️ Even with `HM_ZAPRET_AUTORESTART=1`, Health Monitor **does not intervene** when Zapret is stopped manually via Menu 4 or the Web Panel — the watchdog is skipped entirely while the pause flag is present. HealthMon only steps in when Zapret stops unexpectedly (crash, queue overflow etc.).

---

# 🔹 Menu 5 — Restart Zapret

Stops and restarts the Zapret service. Equivalent to Menu 4 + Menu 3 in a single step; the pause flag is cleared.

👉 Recommended after changing a profile, updating the hostlist, or modifying IPSET settings. Triggered automatically when a DPI profile is changed.

---

# 🔹 Menu 6 — Zapret Version Info (Installed / GitHub)

Compares the latest Zapret version on GitHub against the version currently installed on the device.

- **Installed version** is read from `/opt/zapret/version`
- **GitHub version** is fetched from the latest release tag of `bol-van/zapret`
- SHA256 hash verification is performed — the integrity of the installed file is checked

If a new version is available, an update option is offered.

---

# 🔹 Menu 7 — Zapret IPv6 Support (Wizard)

Sets up rules and routing on the ip6tables side for lines with IPv6 enabled.

- The current IPv6 state is detected automatically (checks for `--dpi-desync-ttl6` in the config file)
- You are asked whether to enable or disable it
- If the selection matches the current state, no action is taken
- After a change, Keenetic-specific configurations are reapplied and Zapret is restarted

⚠️ Does not work if Zapret is not installed.

---

# 🔹 Menu 8 — Backup / Restore

Backs up Zapret settings or restores a previous backup.

👉 Taking a backup before major changes is recommended.

### Sub-menu:

✔ **1. IPSET Backup** — Copies `/opt/zapret/ipset/*.txt` files to `current` and `history` folders  
✔ **2. IPSET Restore** — Select from files in the `current` folder to restore; Zapret is restarted  
✔ **3. Show IPSET Backups** — Lists the current backup and the last 5 historical ones  
✔ **4. Backup Zapret / KZM Settings** — Packages all settings files into a single `tar.gz` archive  
✔ **5. Restore Zapret / KZM Settings** — Scope-selective restore:

| Scope | Contents |
|-------|----------|
| Full backup | Everything |
| Settings only | config, wan_if, lang, dpi_profile |
| Hostlists only | hostlist / autohostlist files |
| IPSET only | ipset_clients.txt, ipset_clients_mode, ipset directory |

✔ **6. Show Settings Backups** — Lists available archives

### Backup locations:
- IPSET: `/opt/zapret_backups/current/` and `/opt/zapret_backups/history/YYYYMMDD_HHMMSS/`
- Settings archive: `/opt/zapret_backups/zapret_settings/zapret_settings_YYYYMMDD_HHMMSS.tar.gz`

---

# 🔹 Menu 9 — DPI Profile Management

Changes the DPI bypass method. When a profile is selected, Zapret **restarts automatically.**

### Profiles:

| No | Profile | Method |
|----|---------|--------|
| 1 | Turk Telekom Fiber | TTL2 fake **(Default)** |
| 2 | Turk Telekom Fiber | TTL4 fake |
| 3 | KabloNet | TTL3 fake |
| 4 | Superonline | fake + m5sig |
| 5 | Superonline Alternative | TTL3 fake + m5sig |
| 6 | Superonline Fiber | TTL5 fake + badsum |
| 7 | Turkcell Mobile | TTL1 + AutoTTL3 fake |
| 8 | Vodafone Mobile | multisplit split-pos=2 |

**Blockcheck (Auto)** mode is also shown as a profile — it becomes active when automatic detection is run from the Blockcheck menu (B).

### Profile States:

- **ACTIVE** — The profile currently running
- **Default** — Profile 1 (tt_default) always carries this label
- **Base** — The baseline profile while Blockcheck auto mode is active
- **Blockcheck (Auto)** — Parameters found by Blockcheck are active

⚠️ Selecting a manual profile while Blockcheck auto mode is active will disable auto mode; confirmation is requested.

👉 If you are unsure which profile to use, run automatic detection via Blockcheck (B).

---

# 🔹 Menu 10 — Script Update

Updates the KZM script file from GitHub.

### Safety Mechanism:

| Condition | Behaviour |
|-----------|-----------|
| Local < GitHub | Updates |
| Local = GitHub | Skips |
| Local > GitHub | Skips (downgrades blocked) |

### Update Flow:

1. The latest version is queried from the GitHub API
2. Versions are compared
3. If an update is needed, SHA256 hash verification is performed
4. The current script is automatically backed up: `.bak_vXX.XX.XX_YYYYMMDD_HHMMSS.sh`
5. The backup limit is 3 — older ones are automatically deleted
6. The new script is downloaded, syntax-checked and installed

⚠️ Local changes not pushed to GitHub will be lost during this operation.

👉 If issues arise after an update, use Menu 13 (Rollback) to revert to the previous version.

### Post-Update Automatic Actions:

When the update completes successfully, the following happen automatically:

- **Telegram bot** is restarted if active (using new code)
- **Health Monitor** is restarted if running (using new code)
- **Web Panel** is updated with the new version if installed

A prominent notification is displayed when the update completes, asking you to exit KZM and re-run it. All changes take effect upon re-entry.

---

# 🔹 Menu 11 — Hostlist / Autohostlist (Filtering + Scope Mode)

This menu manages filtering mode, scope mode, manual hostlist and autohostlist together.

---

## Filtering Mode

Determines which domains Zapret is applied to.

| Mode | Description |
|------|-------------|
| **No Filtering** | All traffic is processed; no domain distinction |
| **Listed Domains Only** | Only domains in `zapret-hosts-user.txt` and `zapret-hosts-auto.txt` are processed |
| **Auto-Learn + List** | Both hostlist and autohostlist work together |

---

## Scope Mode

Determines which devices bypass is applied to.

### 🌐 Global
Applied to the entire network.

✔ Maximum compatibility  
❗ Slightly higher CPU usage  

👉 Safe for new users.

### 🧠 Smart Mode
Applied only to blocked hosts (autohostlist-based).

✔ Lower CPU usage  
✔ Cleaner traffic  
✔ More stable routing  

👉 Recommended mode for long-term use.

---

## Hostlist Management

Manual list of blocked domains (`zapret-hosts-user.txt`).

### Sub-menu:

✔ Add domain (bulk paste supported)  
✔ Remove domain  
✔ Exclude (Domain): Add — domains you do not want processed  
✔ Exclude (Domain): Remove  
✔ Show Lists  
✔ Clear Autohostlist  
✔ Change Scope Mode (Global/Smart)  

👉 Use this to manually add services that autohostlist has not yet detected.

⚠️ After adding/removing domains and adding/removing excludes, Zapret **restarts automatically.** You do not need to go to Menu 5 for changes to take effect.

---

## Autohostlist

Learns blocked services automatically (`zapret-hosts-auto.txt`).

When a DPI-blocked connection is detected, the relevant domain is automatically added to the list. Over time, a personalised bypass list is built.

**A true set-and-forget feature.**

⚠️ To prevent autohostlist from growing indefinitely, `/opt/zapret/nfqws_autohostlist.log` is trimmed to the last 500 lines when it exceeds 1 MB (managed by Health Monitor).

---

# 🔹 Menu 12 — IPSet Management

Specifies which devices Zapret is applied to, by IP address.

⚠️ **DHCP is not supported.** Only works with **statically assigned IP** devices. Devices with DHCP-assigned IPs should not be added to the list, as their IP can change.

### Two Modes:

| Mode | Description |
|------|-------------|
| **Entire Network** | Zapret active for all LAN devices (default) |
| **Selected IPs** | Zapret active only for listed static IPs |

The active mode is shown with a colour indicator above the menu.

### Sub-menu:

✔ Add IP (single or bulk)  
✔ Remove IP  
✔ View active list (file contents + active ipset members)  
✔ Clear list  
✔ Switch mode (Entire Network ↔ Selected IPs)  
✔ No Zapret (Exemption) Management  
✔ **Add VPN Server Subnet** — automatically detects active VPN servers on Keenetic  

### Use Case:

Apply bypass only to specific devices such as:

- Smart TV  
- Game console  
- Apple TV  
- Android Box  

👉 Excluding unnecessary devices from bypass protects router CPU resources.

---

### No Zapret (Exemption) Management

IPs on this list are **exempt** from Zapret processing. Ideal for devices that should not be affected by Zapret, such as IPTV boxes.

**Two-way conflict protection:** When an IP is added to the No Zapret list, it is automatically removed from `zapret_clients`, and vice versa.

---

### Add VPN Server Subnet

Automatically detects active VPN servers on Keenetic and adds their subnets to the `ipset_clients` list.

**Supported VPN types:**
- WireGuard servers (client connections are automatically filtered out; only server interfaces are listed)
- IKEv2/IPsec server
- L2TP/IPsec server

**How It Works:**
1. Active VPN servers are scanned and listed automatically
2. Already-added subnets are marked with a green `[ADDED]` label
3. The selected subnet is added in `/24` format and Zapret is restarted

👉 Use this feature so devices connecting to your home remotely via VPN can route through Zapret.

⚠️ IPSET mode must be set to "Selected IPs" (list) mode.

---

# 🔹 Menu 13 — Rollback (Revert Version)

Allows you to roll back to a previous version if you encounter issues after a script update.

### Two Methods:

**Local Storage (Fast):**  
Select from `.bak_*` files created during Menu 10 updates. No internet required.  
Up to 3 backups are kept — older ones are automatically deleted.  
Backup file format: `keenetic_zapret_otomasyon_ipv6_ipset.sh.bak_vXX.XX.XX_YYYYMMDD_HHMMSS.sh`

**From GitHub (Any Version):**  
The last 10 release tags are listed. The selected version is downloaded from the GitHub raw URL.  
The current file is automatically backed up before the operation.

👉 The first thing to try if issues arise after an update.

⚠️ After rollback is complete, the script must be re-run.

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

An automation engine running in the background. It detects system issues, sends notifications, and in some cases intervenes automatically.

👉 Keeping this enabled is **strongly recommended.**

---

## [SETTINGS]

### Interval (HM_INTERVAL)
How often checks are performed.
- Default: `60` seconds
- Lowering it gives faster detection at a slight CPU cost

### Heartbeat (HM_HEARTBEAT_SEC)
Sends a "still alive" message to Telegram every N seconds.
- Default: `300` seconds (5 minutes)
- Prevents worry about a silent bot being dead

### Cooldown (HM_COOLDOWN_SEC)
How long to wait before resending the same alert.
- Default: `600` seconds (10 minutes)
- Without this, the same alert would arrive every 60 seconds

### Update Check (HM_UPDATECHECK_ENABLE / HM_UPDATECHECK_SEC)
Periodically checks GitHub for new versions of KZM and Zapret.
- Default interval: `21600` seconds (6 hours)

### Auto Update (HM_AUTOUPDATE_MODE)
What to do when a new version is found.

| Value | Behaviour |
|-------|-----------|
| `0` | Update checking disabled |
| `1` | Sends a Telegram notification only |
| `2` | Automatically installs the new version (default) |

⚠️ Mode 2 is recommended for advanced users. Zapret briefly pauses during automatic updates.

---

## [THRESHOLDS]

### CPU WARNING (HM_CPU_WARN / HM_CPU_WARN_DUR)
An alert is sent if CPU exceeds this percentage for this duration.
- Default: `70%` / `180` seconds
- Duration guard prevents brief spikes from triggering alerts

### CPU CRITICAL (HM_CPU_CRIT / HM_CPU_CRIT_DUR)
Emergency threshold triggered more quickly.
- Default: `90%` / `60` seconds

### Disk(/opt) WARNING (HM_DISK_WARN)
An alert is sent if `/opt` usage exceeds this threshold.
- Default: `90%`
- A full USB drive can cause Zapret to stop — early warning is critical

### RAM WARNING (HM_RAM_WARN_MB)
An alert is sent if free RAM falls below this value.
- Default: `<= 40 MB`

---

## [ZAPRET]

### Zapret Watchdog (HM_ZAPRET_WATCHDOG)
Checks on every interval whether the nfqws process is running.
- `1` = active (default), `0` = disabled
- A crashed Zapret is detected within 30 seconds

### Zapret Cooldown (HM_ZAPRET_COOLDOWN_SEC)
How long to wait before resending Zapret-related notifications.
- Default: `120` seconds

### AutoRes — Auto Restart (HM_ZAPRET_AUTORESTART)
Should HealthMon attempt to restart Zapret when it goes down?

| Value | Behaviour |
|-------|-----------|
| `0` | Sends notification only, does not restart |
| `1` | Automatically restarts after ~30 seconds **(default)** |

⚠️ **Important:** When Zapret is stopped via Menu 4 or the Web Panel, the `/tmp/.zapret_paused` flag is created. Even with `AutoRes=1`, HealthMon skips the watchdog while this flag is present — Zapret is not restarted. HealthMon only intervenes when Zapret stops unexpectedly (crash, queue overflow etc.).

### NFQUEUE Queue Watchdog (HM_QLEN_WATCHDOG / HM_QLEN_WARN_TH / HM_QLEN_CRIT_TURNS)

**This setting is critical and is often overlooked by users.**

Even when the nfqws process appears to be running, the NFQUEUE queue can fill up and overflow. When this happens:
- Packets cannot be processed and are dropped
- Internet slows down or disconnects
- `ps` continues to show nfqws as running
- Users assume "something is wrong with KZM" — when the real cause is queue congestion

HealthMon reads `/proc/net/netfilter/nfnetlink_queue` to monitor the current fill level (`qlen`) of queue 200.

| Setting | Description | Default |
|---------|-------------|---------|
| `HM_QLEN_WATCHDOG` | Enable/disable monitoring | `1` (on) |
| `HM_QLEN_WARN_TH` | Packet count at which the counter starts incrementing | `50` |
| `HM_QLEN_CRIT_TURNS` | How many consecutive high turns before a restart is triggered | `3` |

**Example flow:** Queue exceeds 50 → turn 1 → turn 2 → turn 3 → Zapret auto-restarts → issue resolved, user notices nothing.

### KeenDNS Curl Interval (HM_KEENDNS_CURL_SEC)
How often the KeenDNS reachability check runs.
- Default: `120` seconds
- Setting to `0` checks on every loop (legacy behaviour)

### Debug Mode (HM_DEBUG)
Logs the HealthMon loop's internal decisions in detail to `/tmp/healthmon_debug.log`.

- Default: `0` (off)
- Can be toggled from Menu 16 → 4 → 14
- Also accessible via the 🐛 Debug Log button in the Telegram Log menu

Logged categories: Zapret watchdog decisions, WAN monitoring, Telegram bot watchdog, update check GitHub API queries.

👉 Use for troubleshooting and behaviour analysis. Leave disabled during normal operation.

---

## Zapret Restart Log

All Zapret restart events are written to `/tmp/healthmon.log`:

| Entry | Trigger |
|-------|---------|
| `zapret_restart \| triggered` | SSH menu (Menu 3, 5, 11 etc.) |
| `zapret_restart \| triggered (web)` | Web Panel |
| `zapret_restart \| triggered (ipset)` | IPSET / No Zapret operations |
| `qlen_restart_ok` | NFQUEUE queue overflow |
| `zapret_autorestart_ok` | HealthMon watchdog |

👉 To review restart history: `tail -50 /tmp/healthmon.log | grep zapret_restart`

---

## [NOW]

Shows the current system state: CPU percentage, load average (1/5/15 min), free RAM, disk usage and Zapret status.

---

## Önerilen Yapılandırma

Telegram kurulduysa ve günlük kullanım yapılıyorsa:

<img src="/docs/images/HealthMon_EN.png" width="800">

---

# 🔹 Menu 17 — Web Panel (GUI)

A visual management panel accessible from a browser.

Default port: **8088** → `http://<router-ip>:8088`

### Sub-menu:

✔ **Install Web Panel** — lighttpd + CGI is installed, cron-based status refresh is activated, iptables rule is opened  
✔ **Remove Web Panel** — lighttpd, CGI and the cron entry are cleaned up  
✔ **Update Web Panel** — HTML and CGI files are rewritten with the current version  
✔ **Web Panel Status** — Shows whether lighttpd is running, the port, and file presence  
✔ **Enable / Disable Web Panel** — Enables or disables access (lighttpd is stopped/started)  

### Changing the Port

The port number can be changed from the web panel menu (1024–65535). The change is saved to `/opt/etc/lighttpd/kzm_custom.conf` and the iptables rule is updated automatically.

### How It Works

The web panel reads data from `/opt/var/run/kzm_status.json`. This JSON file is refreshed **every minute** by the `kzm_status_gen.sh` script via cron. The browser dashboard polls this data every 15 seconds — so the panel reflects state with up to 1 minute of delay, not in real time.

Commands (start/stop Zapret, change profile etc.) run in real time via CGI.

### Panel Sections:

| Section | Contents |
|---------|----------|
| Dashboard | Zapret status, DPI profile, CPU/RAM/Disk, HealthMon |
| Zapret | Start / Stop / Restart |
| DPI | Profile selection |
| Hostlist | Add/remove domains |
| IPSet | Add/remove IPs, switch mode |
| HealthMon | Status monitoring, configuration |
| Telegram | Bot token/chat ID settings |
| OPKG | Refresh package list |

👉 Basic management is possible without an SSH connection to the router.

⚠️ Requires the lighttpd package. Installed automatically during setup. crond must be running.

---

# 🔹 R — Scheduled Reboot (Cron)

Automatically reboots the router at a specified time or day. Triggered via `ndmc -c "system reboot"`.

### Sub-menu:

✔ **Show current schedule** — Displays the saved cron entry  
✔ **Add / update daily reboot** — Reboot every day at HH:MM  
✔ **Add / update weekly reboot** — Reboot on a specific day (Mon–Sun) at HH:MM  
✔ **Delete schedule** — Removes the cron entry  

### How It Works

The schedule is saved to crontab with the `# KZM_REBOOT` tag. This tag ensures:

- When a new schedule is added, the old one is automatically replaced — no duplicate entries
- When deleted, only the KZM-owned entry is removed; other cron jobs are untouched

The active schedule is shown in the main menu banner:
- Daily: `Sched.Reboot : 03:00`
- Weekly: `Sched.Reboot : 03:00 (Sun)`

### Recommended Use

Routers that run continuously for extended periods can accumulate temporary files in memory, degrading performance. Scheduling a reboot once or twice a week around midnight prevents this.

👉 If the Telegram bot is configured, a notification is sent before the reboot.

⚠️ The crond service must be running. A warning is shown at menu entry if it is not.

---

# 🔵 B — Blockcheck Test Menu

Runs DPI tests, analyses the connection state and automatically detects the most suitable DPI parameter.

### Sub-menu:

✔ **Full Test** — Comprehensive DPI analysis; all protocols and strategies are tried  
✔ **Summary Test (SUMMARY)** — Runs only the summary section; the lightweight test used for automatic DPI  
✔ **Clear Test Results** — Deletes `blockcheck_*.txt` and `blockcheck_summary_*.txt` files  

### DPI Health Score:

A score is calculated when the summary test completes (e.g. `8.5 / 10`):

| Check | Description |
|-------|-------------|
| ✔ DNS consistency | Is there ISP DNS manipulation? |
| ✔ TLS 1.2 status | Is HTTPS access via TLS 1.2 working? |
| ⚠ UDP 443 weak | Is QUIC/HTTP3 blocked or at risk? |

### Automatic DPI Flow:

The most suitable nfqws parameter is detected from the summary test result. A decision screen is presented:

| Option | Description |
|--------|-------------|
| **[1] Apply** | Parameter is activated as the DPI profile; Zapret is restarted |
| **[2] Inspect Parameter** | Shows the detected parameter |
| **[3] Save Only** | Saves without changing the active profile |
| **[0] Cancel** | No action taken |

⚠️ The full test does not apply automatically — only the Summary test triggers automatic DPI.

👉 If you are unsure which profile to use, or the current profile is not working, start here.

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

```
1  → Install Zapret
15 → Set up Telegram bot (optional)
16 → Enable Health Monitor
```

If internet is not working after install:

```
B → Run Summary test → Apply
```

---

## Advanced User

```
11 → Set filtering mode to "Auto-Learn + List"
11 → Set scope mode to "Smart Mode"
R  → Schedule a weekly midnight reboot
```

---

## Troubleshooting

```
14 → Run diagnostics (check DNS, WAN, Zapret, GitHub)
B  → Summary test → Apply automatic DPI parameter
9  → Switch profile and try again
14 → If still broken, refresh OPKG list
U  → Last resort: full clean uninstall → 1 → reinstall
```

---

# 🚨 CRITICAL WARNING

Do not change DPI settings randomly.

Most issues are caused by:

✔ ISP-side changes  
✔ DNS problems  
✔ Incorrect profile

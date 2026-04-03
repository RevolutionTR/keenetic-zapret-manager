# Keenetic Zapret Manager (KZM)

## 📦 Installation & Download

[![Stars](https://img.shields.io/github/stars/RevolutionTR/keenetic-zapret-manager?style=for-the-badge)](https://github.com/RevolutionTR/keenetic-zapret-manager/stargazers)
[![Latest Release](https://img.shields.io/github/v/release/RevolutionTR/keenetic-zapret-manager?style=for-the-badge)](https://github.com/RevolutionTR/keenetic-zapret-manager/releases/latest)
<br>
<br>
[![Full Setup Guide](https://img.shields.io/badge/Full%20Setup-Guide-success?style=for-the-badge)](https://github.com/RevolutionTR/keenetic-zapret-manager/blob/main/docs/sifirdan_kurulum_anlatimi.md)
[![User Guide](https://img.shields.io/badge/Usage-Menu_Guide-blue?style=for-the-badge)](https://github.com/RevolutionTR/keenetic-zapret-manager/blob/main/docs/user_guide_en.md)
[![Telegram](https://img.shields.io/badge/Telegram-Setup-2CA5E0?style=for-the-badge)](https://github.com/RevolutionTR/keenetic-zapret-manager/blob/main/docs/telegram.md)
[![Platform](https://img.shields.io/badge/Platform-Keenetic-1f6feb?style=for-the-badge)](https://keenetic.com.tr)
<br>
![Languages](https://img.shields.io/badge/Languages-TR%20%7C%20EN-orange?style=for-the-badge)
[![Open Source](https://img.shields.io/badge/Open%20Source-Yes-brightgreen?style=for-the-badge)](https://github.com/RevolutionTR/keenetic-zapret-manager)

<br>
<br>

<img src="docs/images/KZM_Main_Menu.png" width="800">

<img src="docs/images/zapret_menu2.png" width="800">

<img src="docs/images/zapret_menu4.png" width="800">

<img src="docs/images/zapret_menu5.png" width="800">

## 🚀 KZM WEB UI

<img src="docs/images/KZM_GUI1.jpg" width="800">

<img src="docs/images/KZM_GUI2.jpg" width="800">

<img src="docs/images/KZM_GUI3.jpg" width="800">


## ✅ Tested Keenetic OS Versions

This script has been tested on the following Keenetic OS versions:

- **Keenetic OS 5.0.8**
- **Keenetic OS 4.3.6.3**

> Not tested on older Keenetic OS versions.  
> On older versions, OPKG/Entware packages, iptables/ipset behaviour or binary compatibility may differ.

## ✅ Recommended Setup:
- USB storage attached to the Keenetic device
- Entware installed on USB
- Script and Zapret running under `/opt/lib/opkg`

---

## 📖 About the Project

**Zapret management and automation script for Keenetic routers/modems**

This project provides **easy installation** of Zapret on Keenetic devices, **DPI profile management**,  
**client selection via IPSET**, **menu-driven usage** and  
**version tracking via GitHub**.

### Important Note on DNS

Zapret is designed to bypass DPI (Deep Packet Inspection) based restrictions.  
**It does not resolve DNS-based blocking or ISP DNS manipulation.**

For this reason, when using Zapret on some ISPs:
- DoH (DNS over HTTPS),
- DoT (DNS over TLS),
- or a trusted third-party DNS

is **strongly recommended**.

ISP DNS servers may return incorrect IPs for blocked domains.  
In that case, even if Zapret is working, the connection may still fail.

---

## 🚀 Features

### Zapret Installation & Management
- Automatic Zapret installation and removal
- Full install / clean uninstall from a single menu
- Safe management of Zapret files on the system

### DPI Profile Management
- Turk Telekom (Fiber / Alternative)
- Superonline
- Superonline Fiber
- KabloNet
- Mobile operators (Turkcell / Vodafone)
- **Automatic Zapret restart** after profile change

### IPSET-Based Traffic Control
- Apply Zapret to the entire network (**Global mode**)
- Apply Zapret to selected IPs only (**Smart mode**)
- Client-based control via IPSET list

### Hostlist / Autohostlist System
- Automatic learning of DPI-detected domains (Autohostlist)
- Manual domain add / remove (User hostlist)
- Excluded domain list (Exclude)

### IPv6 Support
- IPv6 Zapret support (optional)
- Enable / disable IPv6 from the menu
- Colour-coded IPv6 status display on the status screen

### Backup and Restore
- Back up individual `.txt` files under IPSET
- Restore selected files
- **Automatic Zapret restart** after restore

### Version & Update Checks
- Installed Zapret version information
- Manager (script) version check (GitHub)
- Latest version notifications

### CLI Shortcuts
- `kzm`
- `KZM`
- `keenetic`
- `keenetic-zapret`
- Run the script without typing the full path

### Multi-Language Interface
- Turkish / English (TR / EN) language support
- Dictionary-based translation system

### User-Friendly Interface
- Colourful and readable menu layout
- Clear status indicators
- Protections against misconfiguration

---

## 🔍 Blockcheck → Automatic DPI Smart Flow

The most stable DPI parameter is automatically detected from the Blockcheck summary (SUMMARY) result.

A decision screen is presented to the user:

- **[1] Apply** → Parameter is activated as the DPI profile
- **[2] Inspect Parameter**
- **[3] Save Only**
- **[0] Cancel**

Automatic DPI only works from the summary test (the full test does not apply directly).

The active DPI state is clearly shown in the menu:
- Default / Manual
- Blockcheck (Automatic)

Applied parameters are also listed separately.

---

## 📊 DPI Health Score

A DPI Health Score is calculated after Blockcheck (e.g. 8.5 / 10).

Sub-checks are shown to the user in a readable format:

- ✔ DNS consistency
- ✔ TLS 1.2 status
- ⚠ UDP 443 weak / at risk

Symbols and text are formatted for terminal compatibility and readability.

---

## 🤖 Telegram Notifications

To receive instant notifications from your router:  
➡️ [Telegram Setup Guide](docs/telegram.md)

---

## 🧹 Clearing Test Results

A new option has been added to the **Blockcheck Test** menu:

**"Clear Test Results"**

The following files are safely deleted:
- `blockcheck_*.txt`
- `blockcheck_summary_*.txt`

This prevents the `/opt/zapret` directory from growing over time.

---

## 💾 Script Backup Management

A backup is taken automatically during script updates.

Backups are now saved with a `.sh` extension and can be restored:

```
keenetic_zapret_otomasyon_ipv6_ipset.sh.bak_26.1.30_YYYYMMDD_HHMMSS.sh
```

A new option has been added to the **Local Storage (Backups)** menu:

**"Clear Backups"**

Only backups belonging to this script are removed:
- `keenetic_zapret_otomasyon_ipv6_ipset.sh.bak_*`

---

## ⚠️ Prerequisites (REQUIRED)

### 1️⃣ Entware must be installed


### 2️⃣ OPKG must be installed

---

## 🧩 What Happens on First Install?

- OPKG packages are checked
- Zapret is downloaded and adapted for Keenetic
- Exit interface is requested (e.g. `ppp0`)
- Default DPI profile is applied:  
  **Turk Telekom Fiber (TTL2 fake)**
- Zapret is started automatically

> The DPI profile can be changed later from the menu.

---

## 🎛️ DPI Profile Management

- When a DPI profile is selected from the menu:
  - The profile is applied
  - **Zapret restarts automatically**
- Manual restart is not required

The active DPI profile is shown:
- In **green** in the menu
- With the **ACTIVE** label

---

## 🌐 IPSET (Client Selection)

The active mode is shown automatically above the IPSET menu:

- 🟢 **Mode: Entire network**  
  → Zapret active for all LAN clients

- 🟡 **Mode: Selected IPs**  
  → Zapret active only for the specified **static IPs**

Local networks (RFC1918, loopback, CGNAT etc.) are always technically bypassed (`nozapret`).

---

## 🔄 Version Check

- Zapret version is queried from GitHub
- Manager (script) version is compared against the GitHub Release tag

### Version Format

```
YY.MM.DD(.N)
```

Examples:
- `v26.1.24`
- `v26.1.24.2` → second release published on the same day

---

## 📜 License

This project is released under the **GNU GPLv3** license.

- You may freely use it
- Modify it
- Distribute it  

However, it must be shared under the **same license**.

---

## ⚠️ Disclaimer

This script affects:
- Network traffic
- DPI / iptables / ipset configurations

Incorrect configuration may cause connectivity issues.  
Use is entirely **at the user's own risk**.

---

## 🤝 Contributions & Feedback

- You can open an issue
- You can submit a feature request
- Pull Requests are welcome

📌 **GitHub Repo:**  
https://github.com/RevolutionTR/keenetic-zapret-manager

---
## 🔔 About Derivative Projects

Projects inspired by this project's UI design, menu architecture, or overall structure
are expected to provide proper attribution:

**Source:** [Keenetic Zapret Manager (KZM)](https://github.com/RevolutionTR/keenetic-zapret-manager) by RevolutionTR

Usage is free under the GPL-3.0 license, however providing attribution in derivative
works is an ethical requirement.
<br>
## Legal Notice
Keenetic and the Keenetic logo are registered trademarks of Keenetic Ltd.
This project has no official affiliation, partnership, or sponsorship with Keenetic Ltd.
The Keenetic logo is used solely to indicate that this tool is designed for Keenetic devices.

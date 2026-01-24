# keenetic-zapret-manager

📦 **Latest Release (recommended):**  
https://github.com/RevolutionTR/keenetic-zapret-manager/releases/latest

## ✅ Tested Keenetic OS Versions

This script has been tested on the following Keenetic OS versions:

- **Keenetic OS 5.0.4**
- **Keenetic OS 4.3.6.3**

> Older Keenetic OS versions have not been tested.  
> On older releases, OPKG/Entware packages, iptables/ipset behavior, or binary compatibility may differ.

---

**Zapret management and automation script for Keenetic routers**

This project is designed to provide **easy installation**, **DPI profile management**,  
**IPSET-based client selection**, **menu-driven usage**, and  
**GitHub-based version tracking** for Zapret on Keenetic devices.

---

## 🚀 Features

- Automatic Zapret installation / removal
- DPI profile selection (TT, Superonline, mobile operators, etc.)
- **Automatic Zapret restart** after DPI profile changes
- IPSET support:
  - Apply to the entire network
  - Apply only to selected IP addresses
- Optional IPv6 support
- Zapret version check via GitHub
- Manager (script) version check via GitHub
- TR / EN language support
- Colored, readable, and user-friendly menu interface

---

## ⚠️ Prerequisites (REQUIRED)

### 1️⃣ Entware must be installed

From the Keenetic web interface:

```
Applications → Entware
```

After installation, verify via SSH:

```sh
opkg --version
```

---

### 2️⃣ Required OPKG packages

The script automatically checks and installs missing packages.  
If you want to install them manually:

```sh
opkg update
opkg install curl wget ipset iptables
```

---

## 📦 Installation

### 1️⃣ Download the script

Download the following file from the GitHub repository or **Releases** section:

```
keenetic_zapret_otomasyon_ipv6_ipset.sh
```

---

### 2️⃣ Copy the script under `/opt`

> ⚠️ The script **must be executed from under `/opt`**.

```sh
scp keenetic_zapret_otomasyon_ipv6_ipset.sh \
root@192.168.1.1:/opt/lib/opkg/
```

---

### 3️⃣ Grant execute permission

```sh
chmod +x /opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh
```

---

### 4️⃣ Run the script

```sh
/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh
```

---

## 🧩 What Happens During First Installation?

- OPKG packages are checked
- Zapret is downloaded and adapted for Keenetic
- Outgoing interface is requested (example: `ppp0`)
- The default DPI profile is applied:  
  **Turk Telekom Fiber (TTL2 fake)**
- Zapret is started automatically

> DPI profiles can be changed later via the menu.

---

## 🎛️ DPI Profile Management

- When a DPI profile is selected from the menu:
  - The profile is applied
  - **Zapret is automatically restarted**
- No manual restart is required

The active DPI profile is:
- Displayed **in green**
- Marked with **ACTIVE** in the menu

---

## 🌐 IPSET (Client Selection)

The active mode is automatically displayed at the top of the IPSET menu:

- 🟢 **Mode: Entire network**  
  → Zapret is applied to all LAN clients

- 🟡 **Mode: Selected IPs**  
  → Zapret is applied only to specified **static IP addresses**

Local networks (RFC1918, loopback, CGNAT, etc.) are always bypassed internally via `nozapret`.

---

## 🔄 Version Checking

- Zapret version is queried from GitHub
- Manager (script) version is compared against the GitHub Release tag

### Version format

```
YY.MM.DD(.N)
```

Examples:
- `v26.1.24`
- `v26.1.24.2` → second release on the same day

---

## 📜 License

This project is licensed under **GNU GPLv3**.

You are free to:
- Use
- Modify
- Distribute

As long as the project is shared under the **same license**.

---

## ⚠️ Disclaimer

This script affects:
- Network traffic
- DPI / iptables / ipset configurations

Incorrect configuration may cause connectivity issues.  
Usage is entirely **at the user’s own responsibility**.

---

## 🤝 Contribution & Feedback

- You can open issues
- Submit feature requests
- Pull Requests are welcome

📌 GitHub Repository:  
https://github.com/RevolutionTR/keenetic-zapret-manager

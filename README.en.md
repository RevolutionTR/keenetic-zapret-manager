# keenetic-zapret-manager


📦 **Latest Release (recommended):**  
https://github.com/RevolutionTR/keenetic-zapret-manager/releases/latest


## ✅ Tested Keenetic OS Versions

This script has been tested on the following Keenetic OS versions:

- **Keenetic OS 5.0.4**
- **Keenetic OS 4.3.6.3**

> Older Keenetic OS versions have **not been tested**.  
> On older versions, OPKG/Entware packages, iptables/ipset behavior, or binary compatibility may differ.

---

## 🚀 Features

### Zapret Management
- Automatic Zapret **install / uninstall**
- Full installation and clean removal from a single menu
- Zapret files are safely managed within the system

### DPI Profile Management
- Turk Telekom (Fiber / Alternative)
- Superonline / Superonline Fiber
- KabloNet
- Mobile operators (Turkcell / Vodafone)
- **Automatic Zapret restart after profile change**

### IPSET-Based Traffic Control
- Apply Zapret to the **entire network** (Global mode)
- Apply Zapret to **selected IPs only** (Smart mode)
- Client-based control using IPSET lists

### Hostlist / Autohostlist System
- Automatic learning of DPI-detected domains (Autohostlist)
- Manual domain add / remove
- Excluded (bypass) domain list

### IPv6 Support
- Optional IPv6 Zapret support
- Enable / disable IPv6 from menu
- Colored IPv6 status display

### Backup & Restore
- Backup individual `.txt` files created under IPSET
- Restore selected files only
- **Automatic Zapret restart after restore**

### Version & Update Checks
- Installed Zapret version display
- Manager (script) version check via GitHub
- Update availability notifications

### CLI Shortcuts
- `keenetic`
- `keenetic-zapret`
- Run the script without typing the full path

### Multilingual Interface
- Turkish / English (TR / EN) language support
- Dictionary-based translation system

### User-Friendly Interface
- Colorful and readable menu
- Clear status indicators
- Safeguards against misconfiguration

---

## ⚠️ Prerequisites (REQUIRED)

### 1️⃣ Entware must be installed

From the Keenetic web interface:


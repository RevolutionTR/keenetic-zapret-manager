#!/bin/sh
#
# keenetic_zapret_otomasyon_ipv6_ipset.sh
#
# Author: RevolutionTR
# GitHub: https://github.com/RevolutionTR
#
# Copyright (C) 2026 RevolutionTR
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# -------------------------------------------------------------------


# -------------------------------------------------------------------
# Script Kimligi (Repo/Surum)
# -------------------------------------------------------------------
SCRIPT_NAME="keenetic_zapret_otomasyon_ipv6_ipset.sh"
# Version scheme: vYY.M.D[.N]  (YY=year, M=month, D=day, N=daily revision)
SCRIPT_VERSION="v26.2.2"
SCRIPT_REPO="https://github.com/RevolutionTR/keenetic-zapret-manager"
SCRIPT_AUTHOR="RevolutionTR"
# -------------------------------------------------------------------


# -------------------------------------------------------------------
# BEGIN_SESSION_GUARD_V3
# Amaç:
# - SSH / shellinabox oturumu kopunca (/dev/pts/* (deleted)) scriptin
#   arkada asılı kalmasını engellemek
# - Aynı anda birden fazla script instance'ını engellemek
# -------------------------------------------------------------------
ZKM_LOCKDIR="/tmp/keenetic_zapret_mgr.lock"
ZKM_SELF_PID="$$"

# Acquire lock (mkdir is atomic)
# NOTE: Internal daemon modes must bypass the main session lock,
# otherwise they cannot start while the UI script is open.
ZKM_SKIP_LOCK="0"
case "$1" in
    --healthmon-daemon) ZKM_SKIP_LOCK="1" ;;
esac

if [ "$ZKM_SKIP_LOCK" != "1" ]; then
    if ! mkdir "$ZKM_LOCKDIR" 2>/dev/null; then

        if [ -f "$ZKM_LOCKDIR/pid" ] && kill -0 "$(cat "$ZKM_LOCKDIR/pid" 2>/dev/null)" 2>/dev/null; then
            echo "UYARI: Betik zaten calisiyor (PID: $(cat "$ZKM_LOCKDIR/pid" 2>/dev/null))."
            echo "Lutfen mevcut oturumu kapatin veya once calisan betigi sonlandirin."
            exit 0
        fi
        # Stale lock
        rm -rf "$ZKM_LOCKDIR" 2>/dev/null
        mkdir "$ZKM_LOCKDIR" 2>/dev/null || exit 1
    fi

    echo "$ZKM_SELF_PID" > "$ZKM_LOCKDIR/pid"

    # Session guard + cleanup only for the main interactive instance
    zkm_cleanup() {
        rm -rf "$ZKM_LOCKDIR" 2>/dev/null
    }

    # Always cleanup the lock
    trap 'zkm_cleanup' EXIT

    # Extra traps: ensure Ctrl-C (INT) and disconnect signals actually EXIT
    trap 'zkm_cleanup; exit 130' INT
    trap 'zkm_cleanup; exit 143' TERM
    trap 'zkm_cleanup; exit 129' HUP
    trap 'zkm_cleanup; exit 148' TSTP
    trap 'zkm_cleanup; exit 150' TTIN
    trap 'zkm_cleanup; exit 151' TTOU

    # END_SESSION_GUARD_V3
fi


# BETIK BILGILENDIRME                                 
# Notepad++ da Duzen > Satir Sonunu Donustur > UNIX (LF)

# -------------------------------------------------------------------
# Dogru Dizin Uyarısı (keenetic / keenetic-zapret)
# -------------------------------------------------------------------
check_script_location_once() {
    local EXPECTED="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh"
    local CURRENT="$(readlink -f "$0" 2>/dev/null)"

    [ -z "$CURRENT" ] && return

    if [ "$CURRENT" != "$EXPECTED" ]; then
        echo
        printf "%b %s
" \
            "${CLR_RED}UYARI:${CLR_RESET}" \
            "$(T TXT_WARN_BAD_PATH)"

        echo
        echo "$(T TXT_WARN_MOVE)"
        echo "$(T TXT_WARN_CONTINUE)"
        echo

        read -r -p "$(T TXT_WARN_CHOICE)" sel
        case "$sel" in
            1)
                if mv "$CURRENT" "$EXPECTED" 2>/dev/null; then
                    chmod +x "$EXPECTED" 2>/dev/null
                    if [ ! -x "$EXPECTED" ]; then
                        echo
                        printf "%b
" "${CLR_RED}$(T TXT_WARN_CHMOD_FAIL)${CLR_RESET}"
                        read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")" _
                        return
                    fi
                    echo
                    printf "%b
" "${CLR_GREEN}$(T TXT_WARN_MOVED_OK)${CLR_RESET}"
                    exec "$EXPECTED"
                else
                    echo
                    printf "%b
" "${CLR_RED}$(T TXT_WARN_MOVE_FAIL)${CLR_RESET}"
                    read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                fi
                ;;
            0|"")
                return
                ;;
            *)
                return
                ;;
        esac
    fi
}
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# CLI KISAYOL (keenetic / keenetic-zapret)
# -------------------------------------------------------------------
ensure_cli_shortcut() {
    # Script her seferinde tam path ile calistirilmasin diye
    # /opt/bin altina kisa komutlar ekler (idempotent).

    local CURRENT TARGET WRAP1 WRAP2

    CURRENT="$(readlink -f "$0" 2>/dev/null)"
    TARGET="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh"

    [ -f "$TARGET" ] || TARGET="$CURRENT"

    WRAP1="/opt/bin/keenetic-zapret"
    WRAP2="/opt/bin/keenetic"

    # keenetic-zapret her zaman yarat / guncelle
    cat > "$WRAP1" <<EOF
#!/opt/bin/sh
exec /opt/bin/sh "$TARGET" "\$@"
EOF
    chmod +x "$WRAP1" 2>/dev/null

    # keenetic sadece yoksa olustur
    if [ ! -e "$WRAP2" ]; then
        ln -s "$WRAP1" "$WRAP2" 2>/dev/null || cp -a "$WRAP1" "$WRAP2"
        chmod +x "$WRAP2" 2>/dev/null
    fi

    return 0
}

# Ilk calistirmada CLI kisayolunu garanti altina al
ensure_cli_shortcut

# -------------------------------------------------------------------

# Zapret IPv6 destegi secimi (y/n). Varsayilan: n
ZAPRET_IPV6="n"

# -------------------------------------------------------------------
# Dil (TR/EN) Secimi ve Sozluk
# -------------------------------------------------------------------
LANG_FILE="/opt/zapret/lang"
LANG="tr"

# -------------------------------------------------------------------
# Renkler (ANSI) - sadece terminal (TTY) ise etkin
# -------------------------------------------------------------------
# NO_COLOR=1 -> renk kapali
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ] && [ "${NO_COLOR:-0}" != "1" ]; then
    CLR_CYAN="$(printf '\033[36m')"
    CLR_YELLOW="$(printf '\033[33m')"
    CLR_GREEN="$(printf '\033[32m')"
    CLR_RED="$(printf '\033[31m')"
    CLR_BOLD="$(printf '\033[1m')"
    CLR_DIM="$(printf '\033[2m')"
    CLR_RESET="$(printf '\033[0m')"
else
    CLR_CYAN=""
    CLR_YELLOW=""
    CLR_GREEN=""
    CLR_RED=""
    CLR_BOLD=""
    CLR_DIM=""
    CLR_RESET=""
fi



# -------------------------------------------------------------------
# UI: Dinamik cizgi (terminal genisligine gore)
#  - UI_COLS=100 ile elle zorlanabilir
#  - tput/stty yoksa 80 kolon varsayilir
# -------------------------------------------------------------------
get_term_cols() {
    # Prefer UI_COLS override
    if [ -n "${UI_COLS:-}" ]; then
        printf '%s' "${UI_COLS}"
        return 0
    fi

    # Prefer tput, fallback to stty, fallback to 80
    c="$(tput cols 2>/dev/null)"
    if [ -n "$c" ]; then
        printf '%s' "$c"
        return 0
    fi

    c="$(stty size 2>/dev/null | awk '{print $2}')"
    if [ -n "$c" ]; then
        printf '%s' "$c"
        return 0
    fi

    printf '%s' "80"
    return 0
}

print_line() {
    # Usage: print_line "="  OR  print_line "-"
    ch="${1:-=}"
    cols="$(get_term_cols)"
    [ -z "$cols" ] && cols=80
    # minimum width
    if [ "$cols" -lt 50 ] 2>/dev/null; then cols=50; fi
    # print repeated character up to terminal width
    printf "%*s\n" "$cols" "" | tr " " "$ch"
}


# Screen helper
clear_screen() {
    # Prefer 'clear' if available; otherwise reset the terminal
    if command -v clear >/dev/null 2>&1; then
        clear
    else
        printf '\033c'
    fi
}

hc_word() {
    # PASS/WARN/FAIL kelimesini renklendirir (renk kapaliysa sade basar)
    case "$1" in
        PASS) printf '%b' "${CLR_GREEN}PASS${CLR_RESET}" ;;
        WARN) printf '%b' "${CLR_YELLOW}WARN${CLR_RESET}" ;;
        INFO) printf '%b' "${CLR_CYAN}INFO${CLR_RESET}" ;;
        FAIL) printf '%b' "${CLR_RED}FAIL${CLR_RESET}" ;;
        *)    printf '%s' "$1" ;;
    esac
}
# print_status LEVEL MESSAGE
# LEVEL: PASS/WARN/INFO/FAIL (colored via hc_word)
print_status() {
    local _lvl _msg
    _lvl="$1"; shift
    _msg="$*"
    # If colors are disabled, hc_word will return plain text
    printf "%s %s\n" "$(hc_word "$_lvl")" "$_msg"
}


color_mode_name() {
    # outputs colored mode name for menu display
    case "$1" in
        autohostlist) printf '%b' "${CLR_GREEN}autohostlist${CLR_RESET}" ;;
        hostlist)     printf '%b' "${CLR_YELLOW}hostlist${CLR_RESET}" ;;
        none|"")      printf '%b' "${CLR_RED}none${CLR_RESET}" ;;
        *)            printf '%b' "$1" ;;
    esac
}



# Sozluk: TXT_*_TR / TXT_*_EN
TXT_MAIN_TITLE_TR=" [36mKeenetic icin Zapret Yonetim Scripti[0m"
TXT_MAIN_TITLE_EN=" [36mZapret Management Script for Keenetic[0m"

TXT_OPTIMIZED_TR=" Varsayilan ayarlar Turk Telekom uzerinde test edilerek optimize edilmistir"
TXT_OPTIMIZED_EN=" Default settings are optimized based on testing on Turk Telekom"

TXT_DPI_WARNING_TR=" Not: DPI profillerinin basarimi ISS, hat tipi ve bolgeye gore degisebilir"
TXT_DPI_WARNING_EN=" Note: DPI profile effectiveness may vary by ISP, line type, and region"

TXT_DEVELOPER_TR=" Gelistirici : RevolutionTR"
TXT_DEVELOPER_EN=" Developer  : RevolutionTR"

TXT_EDITOR_TR=" Duzenleyen  : RevolutionTR"
TXT_EDITOR_EN=" Maintainer : RevolutionTR"

TXT_VERSION_TR=" Surum       : ${SCRIPT_VERSION}"
TXT_VERSION_EN=" Version    : ${SCRIPT_VERSION}"

TXT_DESC1_TR="Bu betik, Keenetic cihazlari uzerinde Zapret"
TXT_DESC1_EN="This script helps you install and manage Zapret"

TXT_DESC2_TR="modulunu kolayca kurmak ve yonetmek amaciyla"
TXT_DESC2_EN="on Keenetic devices more easily."

TXT_DESC3_TR="gelistirilmistir."
TXT_DESC3_EN=""

TXT_MENU_HEADER_TR="------------------- ANA MENU --------------------------------------------------------------"
TXT_MENU_HEADER_EN="-------------------- MAIN MENU ------------------------------------------------------------"

TXT_MENU_1_TR=" 1. Zapret'i Yukle"
TXT_MENU_1_EN=" 1. Install Zapret"

TXT_MENU_2_TR=" 2. Zapret'i Kaldir"
TXT_MENU_2_EN=" 2. Uninstall Zapret"

TXT_MENU_3_TR=" 3. Zapret'i Baslat"
TXT_MENU_3_EN=" 3. Start Zapret"

TXT_MENU_4_TR=" 4. Zapret'i Durdur"
TXT_MENU_4_EN=" 4. Stop Zapret"

TXT_MENU_5_TR=" 5. Zapret'i Yeniden Baslat"
TXT_MENU_5_EN=" 5. Restart Zapret"

TXT_MENU_6_TR=" 6. Zapret Surum Bilgisi (Guncel/Kurulu - GitHub)"
TXT_MENU_6_EN=" 6. Zapret Version Info (Latest/Installed - GitHub)"

TXT_MENU_7_TR=" 7. Zapret IPv6 Destegi (Sihirbaz)"
TXT_MENU_7_EN=" 7. Zapret IPv6 support (Wizard)"

TXT_MENU_8_TR=" 8. Zapret Yedekle / Geri Yukle"
TXT_MENU_8_EN=" 8. Zapret Backup / Restore"

TXT_MENU_9_TR=" 9. DPI Profilini Degistir"
TXT_MENU_9_EN=" 9. Change DPI profile"

TXT_ACTIVE_DPI_TR=" Aktif DPI Profili"
TXT_ACTIVE_DPI_EN=" Active DPI Profile"

TXT_ACTIVE_DPI_AUTO_TR=" Blockcheck (Otomatik)"
TXT_ACTIVE_DPI_AUTO_EN=" Blockcheck (Auto)"

TXT_ACTIVE_DPI_DEFAULT_TR=" Varsayilan / Manuel"
TXT_ACTIVE_DPI_DEFAULT_EN=" Default / Manual"

TXT_ACTIVE_DPI_PARAMS_TR=" Parametreler"
TXT_ACTIVE_DPI_PARAMS_EN=" Parameters"

TXT_DPI_AUTO_NOTE_TR=" Not: Blockcheck (Otomatik) aktifken aşağıdaki 1–8 profilleri pasiftir."
TXT_DPI_AUTO_NOTE_EN=" Note: While Blockcheck (Auto) is active, profiles 1–8 below are inactive."

TXT_DPI_BASE_TR=" (Taban)"
TXT_DPI_BASE_EN=" (Base)"

TXT_DPI_BASE_PROFILE_TR=" Taban Profil"
TXT_DPI_BASE_PROFILE_EN=" Base Profile"

TXT_DPI_AUTO_DISABLE_PROMPT_TR="Blockcheck (Otomatik) aktif. Manuel profile gecmek otomatik modu kapatir. Devam edilsin mi? (e/h) [e]: "
TXT_DPI_AUTO_DISABLE_PROMPT_EN="Blockcheck (Auto) is active. Switching to a manual profile will disable auto mode. Continue? (y/n) [y]: "

TXT_BLOCKCHECK_APPLY_TR=" Bu ayarlari DPI profili olarak uygulamak ister misiniz? (e/h) [e]: "
TXT_BLOCKCHECK_APPLY_EN=" Apply these settings as DPI profile? (y/n) [y]: "

TXT_BLOCKCHECK_APPLIED_TR=" Ayarlar uygulandi ve Zapret yeniden baslatildi."
TXT_BLOCKCHECK_APPLIED_EN=" Settings applied and Zapret restarted."

TXT_BLOCKCHECK_NO_STRAT_TR=" UYARI: Uygulanabilir nfqws stratejisi bulunamadi."
TXT_BLOCKCHECK_NO_STRAT_EN=" WARNING: No applicable nfqws strategy found."

TXT_BLOCKCHECK_TPWS_WARN_TR=" UYARI: Bulunan strateji tpws. Guvenli oldugu icin otomatik uygulanmayacak. (Simdilik sadece nfqws destekleniyor.)"
TXT_BLOCKCHECK_TPWS_WARN_EN=" WARNING: Found strategy is tpws. It will NOT be applied automatically for safety. (For now only nfqws is supported.)"

TXT_MENU_10_TR="10. Betik Guncelleme Kontrolu (GitHub)"
TXT_MENU_10_EN="10. Script update check (GitHub)"

TXT_MENU_11_TR="11. Hostlist / Autohostlist (Filtreleme)"
TXT_MENU_11_EN="11. Hostlist / Autohostlist (Filtering)"

TXT_MENU_12_TR="12. IPSET (Statik IP kullanan cihazlarla calisir – DHCP desteklenmez!)"
TXT_MENU_12_EN="12. IPSET (Works with static IP devices – DHCP is not supported!)"

TXT_MENU_13_TR="13. Betik: Yedekten Geri Don (Rollback)"
TXT_MENU_13_EN="13. Script: Roll Back from Backup"

TXT_MENU_14_TR="14. Saglik Kontrolu (DNS/NTP/GitHub/OPKG/Disk/Zapret)"
TXT_MENU_14_EN="14. Health Check (DNS/NTP/GitHub/OPKG/Disk/Zapret)"

TXT_MENU_15_TR="15. Bildirimler (Telegram)"
TXT_MENU_15_EN="15. Notifications (Telegram)"

TXT_MENU_16_TR="16. Sistem Sagligi Monitoru (CPU/RAM/Disk/Load/Zapret)"
TXT_MENU_16_EN="16. System Health Monitor (CPU/RAM/Disk/Load/Zapret)"

# -------------------------------------------------------------------
# Telegram notifications
# -------------------------------------------------------------------
TXT_TG_SETTINGS_TITLE_TR="Telegram Bildirim Ayarlari"
TXT_TG_SETTINGS_TITLE_EN="Telegram Notification Settings"

TXT_TG_STATUS_ACTIVE_TR="Durum: AKTIF"
TXT_TG_STATUS_ACTIVE_EN="Status: ACTIVE"

TXT_TG_STATUS_NOT_CONFIG_TR="Durum: AYARLANMAMIS"
TXT_TG_STATUS_NOT_CONFIG_EN="Status: NOT CONFIGURED"

TXT_TG_SAVE_UPDATE_TR="Token/ChatID Kaydet-Guncelle"
TXT_TG_SAVE_UPDATE_EN="Save/Update Token & ChatID"

TXT_TG_SEND_TEST_TR="Test Mesaji Gonder"
TXT_TG_SEND_TEST_EN="Send Test Message"

TXT_TG_DELETE_RESET_TR="Ayar Dosyasini Sil (Reset)"
TXT_TG_DELETE_RESET_EN="Delete Config (Reset)"

TXT_TG_ENTER_TOKEN_TR="Bot Token girin (yapistir):"
TXT_TG_ENTER_TOKEN_EN="Enter Bot Token (paste):"

TXT_TG_ENTER_CHATID_TR="Chat ID girin (or: -100...):"
TXT_TG_ENTER_CHATID_EN="Enter Chat ID (or: -100...):"

TXT_TG_SAVED_OK_TR="Ayarlar kaydedildi."
TXT_TG_SAVED_OK_EN="Settings saved."

TXT_TG_SAVE_FAIL_TR="Kaydetme basarisiz!"
TXT_TG_SAVE_FAIL_EN="Save failed!"

TXT_TG_TEST_SENT_TR="Test mesaji gonderildi."
TXT_TG_TEST_SENT_EN="Test message sent."

TXT_TG_NOT_CONFIGURED_TR="Telegram ayari yapilmamis."
TXT_TG_NOT_CONFIGURED_EN="Telegram not configured."

TXT_TG_RESET_OK_TR="Ayarlar sifirlandi."
TXT_TG_RESET_OK_EN="Settings reset."

TXT_TG_TEST_FAIL_CONFIG_FIRST_TR="Test gonderilemedi. Once Token/ChatID ayarlayin."
TXT_TG_TEST_FAIL_CONFIG_FIRST_EN="Test failed. Configure token/chatid first."

TXT_TG_CONFIG_DELETED_TR="Ayar dosyasi silindi."
TXT_TG_CONFIG_DELETED_EN="Config deleted."

TXT_TG_TEST_SAVED_MSG_TR="✅ Telegram test: ayarlar kaydedildi"
TXT_TG_TEST_SAVED_MSG_EN="✅ Telegram test: settings saved"

TXT_TG_TEST_OK_MSG_TR="✅ Telegram test: bildirim calisiyor"
TXT_TG_TEST_OK_MSG_EN="✅ Telegram test: notifications working"


# -------------------------------------------------------------------
# Health Monitor (Mod B) notifications
# -------------------------------------------------------------------
TXT_HM_TITLE_TR="Sistem Sagligi Monitoru"
TXT_HM_TITLE_EN="System Health Monitor"

TXT_HM_STATUS_TR="Durum:"
TXT_HM_STATUS_EN="Status:"

TXT_HM_ENABLE_DISABLE_TR="Ac / Kapat"
TXT_HM_ENABLE_DISABLE_EN="Enable / Disable"

TXT_HM_SHOW_STATUS_TR="Durum Goster"
TXT_HM_SHOW_STATUS_EN="Show Status"

TXT_HM_SEND_TEST_TR="Test Bildirimi (Telegram)"
TXT_HM_SEND_TEST_EN="Send Test Notification (Telegram)"

TXT_HM_CONFIG_THRESHOLDS_TR="Esikleri Ayarla"
TXT_HM_CONFIG_THRESHOLDS_EN="Configure Thresholds"

TXT_HM_ENABLED_TR="Health Monitor acildi."
TXT_HM_ENABLED_EN="Health Monitor enabled."

TXT_HM_DISABLED_TR="Health Monitor kapatildi."
TXT_HM_DISABLED_EN="Health Monitor disabled."

TXT_HM_TEST_MSG_TR="📌 HealthMon %TS%\n✅ Health Monitor test\nCPU: %CPU%\nLoad: %LOAD%\nRAM free: %RAM% MB\nDisk(/opt): %DISK%%"
TXT_HM_TEST_MSG_EN="📌 HealthMon %TS%\n✅ Health Monitor test\nCPU: %CPU%\nLoad: %LOAD%\nRAM free: %RAM% MB\nDisk(/opt): %DISK%%"

TXT_HM_CPU_WARN_MSG_TR="📌 HealthMon %TS%\n⚠️ CPU UYARI: %CPU%%\nLoad: %LOAD%\nRAM free: %RAM% MB\nDisk(/opt): %DISK%%"
TXT_HM_CPU_WARN_MSG_EN="📌 HealthMon %TS%\n⚠️ CPU WARN: %CPU%%\nLoad: %LOAD%\nRAM free: %RAM% MB\nDisk(/opt): %DISK%%"

TXT_HM_CPU_CRIT_MSG_TR="📌 HealthMon %TS%\n🚨 CPU KRITIK: %CPU%%\nLoad: %LOAD%\nRAM free: %RAM% MB\nDisk(/opt): %DISK%%"
TXT_HM_CPU_CRIT_MSG_EN="📌 HealthMon %TS%\n🚨 CPU CRIT: %CPU%%\nLoad: %LOAD%\nRAM free: %RAM% MB\nDisk(/opt): %DISK%%"

TXT_HM_DISK_WARN_MSG_TR="📌 HealthMon %TS%\n⚠️ Disk dolu: /opt %DISK%%%\nCPU: %CPU%%\nLoad: %LOAD%\nRAM free: %RAM% MB"
TXT_HM_DISK_WARN_MSG_EN="📌 HealthMon %TS%\n⚠️ Disk high: /opt %DISK%%%\nCPU: %CPU%%\nLoad: %LOAD%\nRAM free: %RAM% MB"

TXT_HM_RAM_WARN_MSG_TR="📌 HealthMon %TS%\n⚠️ RAM dusuk: %RAM% MB\nCPU: %CPU%%\nLoad: %LOAD%\nDisk(/opt): %DISK%%"
TXT_HM_RAM_WARN_MSG_EN="📌 HealthMon %TS%\n⚠️ Low RAM: %RAM% MB\nCPU: %CPU%%\nLoad: %LOAD%\nDisk(/opt): %DISK%%"

TXT_HM_ZAPRET_DOWN_MSG_TR="📌 HealthMon %TS%\n🚨 Zapret durmus olabilir!\nCPU: %CPU%%\nLoad: %LOAD%\nRAM free: %RAM% MB\nDisk(/opt): %DISK%%"
TXT_HM_ZAPRET_DOWN_MSG_EN="📌 HealthMon %TS%\n🚨 Zapret may be down!\nCPU: %CPU%%\nLoad: %LOAD%\nRAM free: %RAM% MB\nDisk(/opt): %DISK%%"

TXT_HM_ZAPRET_UP_MSG_TR="📌 HealthMon %TS%\n✅ Zapret tekrar calisiyor.\nCPU: %CPU%%\nLoad: %LOAD%\nRAM free: %RAM% MB\nDisk(/opt): %DISK%%"
TXT_HM_ZAPRET_UP_MSG_EN="📌 HealthMon %TS%\n✅ Zapret is running again.\nCPU: %CPU%%\nLoad: %LOAD%\nRAM free: %RAM% MB\nDisk(/opt): %DISK%%"

TXT_TG_ERR_TOKEN_FORMAT_TR="Token formati hatali (:) yok)."
TXT_TG_ERR_TOKEN_FORMAT_EN="Invalid token format (missing :)."

TXT_TG_ERR_CHATID_NUM_TR="ChatID sayi olmali."
TXT_TG_ERR_CHATID_NUM_EN="ChatID must be numeric."

TXT_TG_SAVED_AND_TEST_OK_TR="Kaydedildi ve test mesaji gonderildi."
TXT_TG_SAVED_AND_TEST_OK_EN="Saved and test message sent."

TXT_TG_SAVED_BUT_TEST_FAIL_TR="Kaydedildi ama test gonderilemedi. Token/ChatID veya interneti kontrol edin."
TXT_TG_SAVED_BUT_TEST_FAIL_EN="Saved but test failed. Check token/chatid or internet."

TXT_HM_TEST_SENT_TR="Test bildirimi gonderildi."
TXT_HM_TEST_SENT_EN="Test notification sent."

TXT_HM_NEED_TG_TR="Telegram ayarlanamamis olabilir. Once menu 15 ile ayarlayin."
TXT_HM_NEED_TG_EN="Telegram may be unconfigured. Configure via menu 15."

TXT_HM_PROMPT_CPU_WARN_TR="CPU WARN esigi (%) [or: 70]:"
TXT_HM_PROMPT_CPU_WARN_EN="CPU WARN threshold (%) [e.g. 70]:"

TXT_HM_PROMPT_CPU_WARN_DUR_TR="CPU WARN sure (sn) [or: 180]:"
TXT_HM_PROMPT_CPU_WARN_DUR_EN="CPU WARN duration (sec) [e.g. 180]:"

TXT_HM_PROMPT_CPU_CRIT_TR="CPU CRIT esigi (%) [or: 90]:"
TXT_HM_PROMPT_CPU_CRIT_EN="CPU CRIT threshold (%) [e.g. 90]:"

TXT_HM_PROMPT_CPU_CRIT_DUR_TR="CPU CRIT sure (sn) [or: 60]:"
TXT_HM_PROMPT_CPU_CRIT_DUR_EN="CPU CRIT duration (sec) [e.g. 60]:"

TXT_HM_PROMPT_DISK_WARN_TR="Disk esigi (/opt, %) [or: 90]:"
TXT_HM_PROMPT_DISK_WARN_EN="Disk threshold (/opt, %) [e.g. 90]:"

TXT_HM_PROMPT_RAM_WARN_TR="RAM esigi (MB) [or: 40]:"
TXT_HM_PROMPT_RAM_WARN_EN="RAM threshold (MB) [e.g. 40]:"

TXT_HM_PROMPT_ZAPRET_WD_TR="Zapret watchdog (1=acik,0=kapali) [or: 1]:"
TXT_HM_PROMPT_ZAPRET_WD_EN="Zapret watchdog (1=on,0=off) [e.g. 1]:"

TXT_HM_PROMPT_ZAPRET_COOLDOWN_TR="Zapret cooldown (sn) [or: 120]:"
TXT_HM_PROMPT_ZAPRET_COOLDOWN_EN="Zapret cooldown (sec) [e.g. 120]:"

TXT_HM_PROMPT_ZAPRET_AUTORESTART_TR="Zapret otomatik yeniden baslatma? (0/1) [or: 0]:"
TXT_HM_PROMPT_ZAPRET_AUTORESTART_EN="Zapret auto-restart? (0/1) [e.g. 0]:"

TXT_HM_PROMPT_INTERVAL_TR="Kontrol araligi (sn) [or: 30]:"
TXT_HM_PROMPT_INTERVAL_EN="Check interval (sec) [e.g. 30]:"

TXT_HM_PROMPT_COOLDOWN_TR="Bildirim soguma (sn) [or: 600]:"
TXT_HM_PROMPT_COOLDOWN_EN="Notification cooldown (sec) [e.g. 600]:"


# Health check menu
TXT_HEALTH_TITLE_TR="Saglik Kontrolu"
TXT_HEALTH_TITLE_EN="Health Check"

TXT_HEALTH_OVERALL_TR="Genel Durum"
TXT_HEALTH_OVERALL_EN="Overall Status"

TXT_HEALTH_DNS_LOCAL_TR="DNS (Yerel resolver 127.0.0.1)"
TXT_HEALTH_DNS_LOCAL_EN="DNS (Local resolver 127.0.0.1)"

TXT_HEALTH_SCRIPT_PATH_TR="Betik Konumu (Dogru yerde mi?)"
TXT_HEALTH_SCRIPT_PATH_EN="Script location (Correct path?)"

TXT_HEALTH_DNS_PUBLIC_TR="DNS (8.8.8.8)"
TXT_HEALTH_DNS_PUBLIC_EN="DNS (8.8.8.8)"

TXT_HEALTH_TIME_TR="Saat / NTP"
TXT_HEALTH_TIME_EN="Time / NTP"

TXT_HEALTH_GITHUB_TR="GitHub erisimi (api.github.com)"
TXT_HEALTH_GITHUB_EN="GitHub access (api.github.com)"

TXT_HEALTH_OPKG_TR="OPKG durumu"
TXT_HEALTH_OPKG_EN="OPKG status"

TXT_HEALTH_DISK_TR="Disk doluluk (/opt)"
TXT_HEALTH_DISK_EN="Disk usage (/opt)"

TXT_HEALTH_ZAPRET_TR="Zapret servis durumu"
TXT_HEALTH_ZAPRET_EN="Zapret service status"

TXT_HEALTH_DNS_MATCH_TR="DNS tutarliligi"
TXT_HEALTH_DNS_MATCH_EN="DNS consistency"

TXT_HEALTH_ROUTE_TR="Varsayilan rota (default gateway)"
TXT_HEALTH_ROUTE_EN="Default route (gateway)"

TXT_HEALTH_PING_TR="Internet erisimi (ping 1.1.1.1)"
TXT_HEALTH_PING_EN="Internet connect (ping 1.1.1.1)"

TXT_HEALTH_RAM_TR="RAM durumu (MemAvailable)"
TXT_HEALTH_RAM_EN="RAM status (MemAvailable)"

TXT_HEALTH_LOAD_TR="Sistem yuk (load avg)"
TXT_HEALTH_LOAD_EN="System load (load avg)"

TXT_ROLLBACK_TITLE_TR="Betik: Yedekten Geri Don (Rollback)"
TXT_ROLLBACK_TITLE_EN="Script: Roll Back from Backup"

# -----------------------------
# Common UI
# -----------------------------
TXT_CHOICE_TR="Seçim:"
TXT_CHOICE_EN="Choice:"

TXT_INVALID_CHOICE_TR="Gecersiz secim!"
TXT_INVALID_CHOICE_EN="Invalid choice!"
# --- Added common keys (TR/EN) ---
TXT_CANCELLED_TR="Iptal edildi."
TXT_CANCELLED_EN="Cancelled."

TXT_ERROR_TR="Hata"
TXT_ERROR_EN="Error"

TXT_RESTORE_RESTART_WARN_TR="Uyari: Yeniden baslatma gerekebilir."
TXT_RESTORE_RESTART_WARN_EN="Warning: A restart may be required."

TXT_TMPDIR_CREATE_FAIL_TR="Gecici dizin olusturulamadi!"
TXT_TMPDIR_CREATE_FAIL_EN="Failed to create temporary directory!"


# -----------------------------
# Rollback / Local backups
# -----------------------------
TXT_ROLLBACK_NO_LOCAL_BACKUP_TR="Yerel yedek bulunamadı."
TXT_ROLLBACK_NO_LOCAL_BACKUP_EN="No local backup found."

TXT_ROLLBACK_CLEAN_LOCAL_BACKUPS_TR="Yedekleri Temizle"
TXT_ROLLBACK_CLEAN_LOCAL_BACKUPS_EN="Clean Backups"

TXT_ROLLBACK_CLEAN_DONE_TR="Temizlendi: %s yedek silindi."
TXT_ROLLBACK_CLEAN_DONE_EN="Cleaned: %s backup(s) deleted."

TXT_ROLLBACK_CLEAN_NONE_TR="Temizlenecek yerel yedek bulunamadı."
TXT_ROLLBACK_CLEAN_NONE_EN="No local backups to clean."

# -----------------------------
# Blockcheck reports
# -----------------------------
TXT_BLOCKCHECK_CLEAN_DONE_TR="Temizlendi: %s test sonucu silindi."
TXT_BLOCKCHECK_CLEAN_DONE_EN="Cleaned: %s test result(s) deleted."

TXT_BLOCKCHECK_CLEAN_NONE_TR="Temizlenecek test sonucu bulunamadı."
TXT_BLOCKCHECK_CLEAN_NONE_EN="No test results to clean."

TXT_BACK_TR="Geri"
TXT_BACK_EN="Back"

TXT_ROLLBACK_NO_BACKUP_TR="Yedek bulunamadi: /opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh.bak_*"
TXT_ROLLBACK_NO_BACKUP_EN="No backups found: /opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh.bak_*"

TXT_ROLLBACK_SELECT_TR="Geri donmek istediginiz yedegi secin:"
TXT_ROLLBACK_SELECT_EN="Select the backup you want to restore:"

TXT_ROLLBACK_RESTORED_TR="Geri yukleme tamamlandi. Lutfen betigi yeniden calistirin."
TXT_ROLLBACK_RESTORED_EN="Rollback completed. Please re-run the script."

TXT_ROLLBACK_CANCELLED_TR="Islem iptal edildi."
TXT_ROLLBACK_CANCELLED_EN="Cancelled."

TXT_ROLLBACK_GH_LIST_TR="GitHub'dan surum sec (Son 10)"
TXT_ROLLBACK_GH_LIST_EN="Pick version from GitHub (last 10)"

TXT_ROLLBACK_GH_TAG_TR="Sürüm etiketi yaz (Orn: v26.1.24.3)"
TXT_ROLLBACK_GH_TAG_EN="Enter a release tag (e.g. v26.1.24.3)"

TXT_ROLLBACK_GH_LOADING_TR="GitHub surum listesi aliniyor..."
TXT_ROLLBACK_GH_LOADING_EN="Fetching GitHub release list..."

TXT_ROLLBACK_LOCAL_MENU_TR="Yerel Depolama (Yedekler)"
TXT_ROLLBACK_LOCAL_MENU_EN="Local Storage (Backups)"

TXT_ROLLBACK_CLEAN_TR="Yedekleri Temizle"
TXT_ROLLBACK_CLEAN_EN="Clean Backups"

TXT_ROLLBACK_CLEAN_NONE_TR="Temizlenecek yedek yok."
TXT_ROLLBACK_CLEAN_NONE_EN="No backups to clean."

TXT_ROLLBACK_CLEAN_DONE_TR="Yedek dosyalari temizlendi."
TXT_ROLLBACK_CLEAN_DONE_EN="Backup files cleaned."

TXT_ROLLBACK_MAIN_PICK_TR="Secim: "
TXT_ROLLBACK_MAIN_PICK_EN="Choice: "

TXT_ROLLBACK_GH_NONE_TR="GitHub'dan uygun release bulunamadi."
TXT_ROLLBACK_GH_NONE_EN="No suitable releases found on GitHub."

TXT_ROLLBACK_GH_SELECT_TR="Kurmak istediginiz surumu secin"
TXT_ROLLBACK_GH_SELECT_EN="Select the version to install"

TXT_ROLLBACK_GH_TAGPROMPT_TR="Surum etiketini girin (orn: v26.1.24.3):"
TXT_ROLLBACK_GH_TAGPROMPT_EN="Enter release tag (e.g. v26.1.24.3):"

TXT_ROLLBACK_GH_DOWNLOADING_TR="Secilen surum indiriliyor..."
TXT_ROLLBACK_GH_DOWNLOADING_EN="Downloading selected version..."

TXT_ROLLBACK_GH_DONE_TR="Kurulum tamamlandi. Lutfen betigi yeniden calistirin."
TXT_ROLLBACK_GH_DONE_EN="Install completed. Please re-run the script."

TXT_BACKUP_MENU_TITLE_TR="Zapret Yedekleme / Geri Yukleme"
TXT_BACKUP_MENU_TITLE_EN="Zapret Backup / Restore"

TXT_BACKUP_BASE_PATH_TR="Yedek konumu:"
TXT_BACKUP_BASE_PATH_EN="Backup location:"

TXT_ZAPRET_SETTINGS_BACKUP_DIR_TR="Yedek konumu:"
TXT_ZAPRET_SETTINGS_BACKUP_DIR_EN="Backup location:"

TXT_YES_TR="Evet"
TXT_YES_EN="Yes"

TXT_NO_TR="Hayir"
TXT_NO_EN="No"

TXT_ZAPRET_SETTINGS_CLEAN_MENU_TR="Yedekleri Temizle"
TXT_ZAPRET_SETTINGS_CLEAN_MENU_EN="Clean Backups"

# --- Backup/Restore (Zapret Settings) ---
TXT_ZAPRET_SETTINGS_RESTORE_TITLE_TR="Zapret Ayarlari Geri Yukleme"
TXT_ZAPRET_SETTINGS_RESTORE_TITLE_EN="Restore Zapret Settings"

TXT_SELECT_BACKUP_TO_RESTORE_TR="Geri yuklemek icin yedegi secin:"
TXT_SELECT_BACKUP_TO_RESTORE_EN="Select a backup to restore:"

TXT_ZAPRET_RESTORE_SUBMENU_TITLE_TR="Zapret Yedekleme / Geri Yukleme"
TXT_ZAPRET_RESTORE_SUBMENU_TITLE_EN="Zapret Backup / Restore"

TXT_RESTORE_SCOPE_FULL_TR="Tam Yedegi Geri Yukle (Hepsi)"
TXT_RESTORE_SCOPE_FULL_EN="Restore Full Backup (All)"

TXT_RESTORE_SCOPE_DPI_TR="Sadece DPI Profili / Ayarlari Geri Yukle"
TXT_RESTORE_SCOPE_DPI_EN="Restore DPI Profile/Settings Only"

TXT_RESTORE_SCOPE_HOSTLIST_TR="Sadece Hostlist / Autohostlist Dosyalarini Geri Yukle"
TXT_RESTORE_SCOPE_HOSTLIST_EN="Restore Hostlist/Autohostlist Files Only"

TXT_RESTORE_SCOPE_IPSET_TR="Sadece IPSET Listelerini Geri Yukle"
TXT_RESTORE_SCOPE_IPSET_EN="Restore IPSET Sets Only"

TXT_RESTORE_SCOPE_NFQWS_TR="Sadece Zapret Config (nfqws) Geri Yukle"
TXT_RESTORE_SCOPE_NFQWS_EN="Restore Zapret Config (nfqws) Only"

TXT_BACKUP_NO_BACKUPS_FOUND_TR="Yedek bulunamadi."
TXT_BACKUP_NO_BACKUPS_FOUND_EN="No backups found."

TXT_BACKUP_SUB_BACKUP_TR="1. IPSET Yedekle"
TXT_BACKUP_SUB_BACKUP_EN="1. IPSET Backup"

TXT_BACKUP_SUB_RESTORE_TR="2. IPSET Geri Yukle"
TXT_BACKUP_SUB_RESTORE_EN="2. IPSET Restore"

TXT_BACKUP_SUB_SHOW_TR="3. IPSET Yedekleri Goster"
TXT_BACKUP_SUB_SHOW_EN="3. Show IPSET Backups"

TXT_BACKUP_SUB_CFG_BACKUP_TR="4. Zapret Ayarlarini Yedekle"
TXT_BACKUP_SUB_CFG_BACKUP_EN="4. Backup Zapret Settings"

TXT_BACKUP_SUB_CFG_RESTORE_TR="5. Zapret Ayarlarini Geri Yukle"
TXT_BACKUP_SUB_CFG_RESTORE_EN="5. Restore Zapret Settings"

TXT_BACKUP_SUB_CFG_SHOW_TR="6. Zapret Ayar Yedeklerini Goster"
TXT_BACKUP_SUB_CFG_SHOW_EN="6. Show Settings Backups"

TXT_BACKUP_CFG_NO_FILES_TR="Yedeklenecek Zapret ayar dosyasi bulunamadi."
TXT_BACKUP_CFG_NO_FILES_EN="No Zapret settings files found to backup."

TXT_BACKUP_CFG_BACKED_UP_TR="Zapret ayarlari yedeklendi: %s"
TXT_BACKUP_CFG_BACKED_UP_EN="Zapret settings backed up: %s"

TXT_BACKUP_CFG_NO_BACKUPS_TR="Zapret ayar yedegi bulunamadi."
TXT_BACKUP_CFG_NO_BACKUPS_EN="No Zapret settings backup found."

TXT_BACKUP_CFG_RESTORED_TR="Zapret ayarlari geri yuklendi: %s"
TXT_BACKUP_CFG_RESTORED_EN="Zapret settings restored: %s"

TXT_BACKUP_RESTORE_SUBMENU_TITLE_TR="Zapret Ayarlarini Geri Yukle"
TXT_BACKUP_RESTORE_SUBMENU_TITLE_EN="Restore Zapret Settings"

TXT_BACKUP_RESTORE_FULL_TR="Tam Yedegi Geri Yukle (Hepsi)"
TXT_BACKUP_RESTORE_FULL_EN="Restore Full Backup"

TXT_BACKUP_RESTORE_DPI_TR="Sadece DPI Profili / Ayarlari Geri Yukle"
TXT_BACKUP_RESTORE_DPI_EN="Restore DPI Settings Only"

TXT_BACKUP_RESTORE_HOSTLIST_TR="Sadece Hostlist / Autohostlist Dosyalarini Geri Yukle"
TXT_BACKUP_RESTORE_HOSTLIST_EN="Restore Hostlist / Autohostlist Only"

TXT_BACKUP_RESTORE_IPSET_TR="Sadece IPSET Listelerini Geri Yukle"
TXT_BACKUP_RESTORE_IPSET_EN="Restore IPSET Settings Only"

TXT_BACKUP_RESTORE_NFQWS_TR="Sadece Zapret Config (nfqws) Geri Yukle"
TXT_BACKUP_RESTORE_NFQWS_EN="Restore Zapret Config (nfqws) Only"

TXT_BACKUP_RESTORE_EXTRACTING_TR="Yedek aciliyor..."
TXT_BACKUP_RESTORE_EXTRACTING_EN="Extracting backup..."

TXT_BACKUP_RESTORE_FAILED_TR="Geri yukleme basarisiz!"
TXT_BACKUP_RESTORE_FAILED_EN="Restore failed!"

TXT_BACKUP_RESTORE_DONE_TR="Geri yukleme tamamlandi."
TXT_BACKUP_RESTORE_DONE_EN="Restore completed."

TXT_BACKUP_RESTORE_NOTHING_TR="Geri yuklenecek dosya bulunamadi."
TXT_BACKUP_RESTORE_NOTHING_EN="Nothing to restore."

TXT_BACKUP_RESTORE_STATS_TR="Geri yuklenen: %s | Bulunamayan/Hata: %s"
TXT_BACKUP_RESTORE_STATS_EN="Restored: %s | Missing/Error: %s"

TXT_BACKUP_RESTORE_SCOPE_TR="Geri yukleme kapsamını secin:"
TXT_BACKUP_RESTORE_SCOPE_EN="Select restore scope:"

TXT_BACKUP_SCOPE_HOSTLISTS_TR="1. Sadece host listeleri (hostlist/autohostlist)"
TXT_BACKUP_SCOPE_HOSTLISTS_EN="1. Host lists only (hostlist/autohostlist)"

TXT_BACKUP_SCOPE_CONFIG_TR="2. Sadece ayarlar (config)"
TXT_BACKUP_SCOPE_CONFIG_EN="2. Settings only (config)"

TXT_BACKUP_SCOPE_FULL_TR="3. Tam geri yukleme (ayarlar + listeler)"
TXT_BACKUP_SCOPE_FULL_EN="3. Full restore (settings + lists)"

TXT_BACKUP_SCOPE_CANCEL_TR="0. Iptal"
TXT_BACKUP_SCOPE_CANCEL_EN="0. Cancel"

TXT_BACKUP_SUB_BACK_TR="0. Geri"
TXT_BACKUP_SUB_BACK_EN="0. Back"

TXT_BACKUP_SUB_BACK_LIST_TR="0. Geri"
TXT_BACKUP_SUB_BACK_LIST_EN="0. Back"

TXT_BACKUP_NO_SRC_TR="HATA: /opt/zapret/ipset/ altinda yedeklenecek .txt dosyasi bulunamadi."
TXT_BACKUP_NO_SRC_EN="ERROR: No .txt files found under /opt/zapret/ipset/ to backup."

TXT_BACKUP_DONE_TR="Yedekleme tamamlandi."
TXT_BACKUP_DONE_EN="Backup completed."

TXT_RESTORE_DONE_TR="Geri yukleme tamamlandi."
TXT_RESTORE_DONE_EN="Restore completed."

TXT_RESTORE_RESTARTING_TR="Zapret yeniden baslatiliyor..."
TXT_RESTORE_RESTARTING_EN="Restarting Zapret..."

TXT_RESTORE_RESTART_OK_TR="Zapret yeniden baslatildi."
TXT_RESTORE_RESTART_OK_EN="Zapret restarted."

TXT_RESTORE_RESTART_FAIL_TR="UYARI: Zapret yeniden baslatilamadi."
TXT_RESTORE_RESTART_FAIL_EN="WARNING: Zapret could not be restarted."

TXT_BACKUP_NO_BACKUP_TR="HATA: Yedek bulunamadi."
TXT_BACKUP_NO_BACKUP_EN="ERROR: No backups found."

TXT_SELECT_FILE_TR="Dosya secin"
TXT_SELECT_FILE_EN="Select a file"

TXT_SELECT_ACTION_TR="Seciminizi yapin"
TXT_SELECT_ACTION_EN="Make your selection"

# --- Menu strings (TR/EN) ---
TXT_BLOCKCHECK_TEST_MENU_TR="Blockcheck Test Menüsü"
TXT_BLOCKCHECK_TEST_MENU_EN="Blockcheck Test Menu"

TXT_BACKUP_BASE_PATH_TR="Yedek konumu:"
TXT_BACKUP_BASE_PATH_EN="Backup location:"

TXT_ZAPRET_SETTINGS_BACKUP_DIR_TR="Yedek konumu:"
TXT_ZAPRET_SETTINGS_BACKUP_DIR_EN="Backup location:"

TXT_YES_TR="Evet"
TXT_YES_EN="Yes"

TXT_NO_TR="Hayir"
TXT_NO_EN="No"

TXT_ROLLBACK_NO_LOCAL_BACKUP_TR="Yerel yedek bulunamadi."
TXT_ROLLBACK_NO_LOCAL_BACKUP_EN="No local backup found."

TXT_ZAPRET_SETTINGS_CLEAN_MENU_TR="Yedekleri Temizle"
TXT_ZAPRET_SETTINGS_CLEAN_MENU_EN="Clean Backups"

TXT_ZAPRET_SETTINGS_CLEAN_CONFIRM_TR="Zapret ayar yedekleri silinsin mi? (tar.gz)"
TXT_ZAPRET_SETTINGS_CLEAN_CONFIRM_EN="Delete zapret settings backups? (tar.gz)"

TXT_ZAPRET_SETTINGS_CLEAN_NONE_TR="Silinecek zapret ayar yedegi bulunamadi."
TXT_ZAPRET_SETTINGS_CLEAN_NONE_EN="No zapret settings backups found to delete."

TXT_ZAPRET_SETTINGS_CLEAN_DONE_TR="Zapret ayar yedekleri temizlendi."
TXT_ZAPRET_SETTINGS_CLEAN_DONE_EN="Zapret settings backups have been cleaned."

TXT_ZAPRET_SETTINGS_CLEAN_FAIL_TR="Yedekler silinemedi!"
TXT_ZAPRET_SETTINGS_CLEAN_FAIL_EN="Failed to delete backups!"

# -------------------------------------------------------------------
# Hostlist / Autohostlist (Menu 11) - i18n
# -------------------------------------------------------------------
TXT_HL_TITLE_TR="Hostlist / Autohostlist Menusu"
TXT_HL_TITLE_EN="Hostlist / Autohostlist Menu"

TXT_SCOPE_MODE_TR="Kapsam Modu (Global/Akilli)"
TXT_SCOPE_MODE_EN="Scope Mode (Global/Smart)"

TXT_SCOPE_GLOBAL_DESC_TR="Tum Agda Aktif - Mevcut Davranis"
TXT_SCOPE_GLOBAL_DESC_EN="Active Across the Whole Network - Current Behavior"

TXT_SCOPE_SMART_DESC_TR="Sadece DPI Olan Hostlar - autohostlist"
TXT_SCOPE_SMART_DESC_EN="Only DPI-Affected hosts - autohostlist"

TXT_SCOPE_GLOBAL_TR="Global"
TXT_SCOPE_GLOBAL_EN="Global"

TXT_SCOPE_SMART_TR="Akilli"
TXT_SCOPE_SMART_EN="Smart"

TXT_SCOPE_BACK_TR="Geri"
TXT_SCOPE_BACK_EN="Back"

TXT_SCOPE_PROMPT_TR="Seciminiz (0-2): "
TXT_SCOPE_PROMPT_EN="Select (0-2): "

TXT_SCOPE_CHANGED_TR="Kapsam Modu Degistirildi: %s"
TXT_SCOPE_CHANGED_EN="Scope Mode Changed: %s"

TXT_SCOPE_INVALID_TR="Gecersiz Secim."
TXT_SCOPE_INVALID_EN="Invalid Choice."

TXT_HL_CURRENT_MODE_TR="Mevcut Mod: "
TXT_HL_CURRENT_MODE_EN="Current Mode: "

TXT_HL_COUNTS_TR="User/Exclude/Auto Sayilari: "
TXT_HL_COUNTS_EN="User/Exclude/Auto Counts: "

TXT_HL_OPT_1_TR="Filtreleme Modunu Degistir"
TXT_HL_OPT_1_EN="Change Filtering Mode"

TXT_HL_OPT_2_TR="User hostlist: Domain Ekle"
TXT_HL_OPT_2_EN="User hostlist: Add Domain"

TXT_HL_OPT_3_TR="User hostlist: Domain Sil"
TXT_HL_OPT_3_EN="User hostlist: Remove Domain"

TXT_HL_OPT_4_TR="Exclude (Domain): Ekle (Islenmesin)"
TXT_HL_OPT_4_EN="Exclude: Add Domain (Do not Process)"

TXT_HL_OPT_5_TR="Exclude (Domain): Sil"
TXT_HL_OPT_5_EN="Exclude: Remove (Domain)"

TXT_HL_OPT_6_TR="Listeleri Goster"
TXT_HL_OPT_6_EN="Show Lists"

TXT_HL_OPT_7_TR="Otomatik Listeyi Temizle"
TXT_HL_OPT_7_EN="Clear Auto List"

TXT_HL_WARN_AUTOCLEAR_1_TR="UYARI: Otomatik listeyi temizlemek tum ogrenilen domainleri silecek!"
TXT_HL_WARN_AUTOCLEAR_1_EN="WARNING: Clearing the auto list will delete all learned domains!"

TXT_HL_WARN_AUTOCLEAR_2_TR="Bu islem geri alinamaz."
TXT_HL_WARN_AUTOCLEAR_2_EN="This action cannot be undone."

TXT_HL_BULK_HINT_TR="Birden fazla domain girebilirsiniz (virgul/noktalivirgul/bosluk ile ayirin)."
TXT_HL_BULK_HINT_EN="You can enter multiple domains (separate with comma/semicolon/space)."

TXT_HL_BULK_HINT2_TR="Alt alta yapistirabilirsiniz. Yapistirma bittikten sonra bir kez daha ENTER'a basin (bos satir)."
TXT_HL_BULK_HINT2_EN="You can paste multiple lines. After pasting, press ENTER once more on an empty line to finish."

TXT_HL_CANCELLED_TR="Iptal edildi."
TXT_HL_CANCELLED_EN="Cancelled."

TXT_HL_OPT_8_TR="Kapsam Modunu Degistir (Global/Akilli)"
TXT_HL_OPT_8_EN="Change Scope Mode (Global/Smart)"

TXT_HL_OPT_0_TR="Geri"
TXT_HL_OPT_0_EN="Back"

# Hostlist / Autohostlist (MODE_FILTER) sub-menu
TXT_HL_MODE_TITLE_TR="Hostlist / Autohostlist (MODE_FILTER)"
TXT_HL_MODE_TITLE_EN="Hostlist / Autohostlist (MODE_FILTER)"

TXT_HL_MODE_NONE_DESC_TR="Filtre Yok"
TXT_HL_MODE_NONE_DESC_EN="No Filtering"

TXT_HL_MODE_HOSTLIST_DESC_TR="Sadece Listedeki Domainler"
TXT_HL_MODE_HOSTLIST_DESC_EN="Only Domains in List"

TXT_HL_MODE_AUTO_DESC_TR="Otomatik Ogren + Liste"
TXT_HL_MODE_AUTO_DESC_EN="Auto-Learn + List"

TXT_HL_ACTIVE_MARK_TR=" [36m(AKTIF)[0m"
TXT_HL_ACTIVE_MARK_EN=" [36m(ACTIVE)[0m"

TXT_HL_PICK_TR="Secim: "
TXT_HL_PICK_EN="Choice: "

TXT_HL_WARN_EMPTY_TR="UYARI: User hostlist bos. Hostlist modunda etki goremeyebilirsiniz."
TXT_HL_WARN_EMPTY_EN="WARNING: User hostlist is empty. Hostlist mode may have no effect."

TXT_HL_SET_OK_TR="MODE_FILTER Ayarlandi:"
TXT_HL_SET_OK_EN="MODE_FILTER Set:"

TXT_HL_SET_FAIL_TR="HATA: MODE_FILTER Ayarlanamadi"
TXT_HL_SET_FAIL_EN="ERROR: Failed to set MODE_FILTER"

TXT_HL_RESTART_TR="Zapret yeniden baslatildi."
TXT_HL_RESTART_EN="Zapret restarted."

TXT_HL_DONE_TR="Tamam."
TXT_HL_DONE_EN="Done."

TXT_HL_BAD_TR="Gecersiz secim."
TXT_HL_BAD_EN="Invalid choice."

TXT_HL_NEED_TR="Gerekli: "
TXT_HL_NEED_EN="Required: "

TXT_HL_DOMAIN_ADD_TR="Domain eklendi: "
TXT_HL_DOMAIN_ADD_EN="Domain added: "

TXT_HL_DOMAIN_DEL_TR="Domain silindi: "
TXT_HL_DOMAIN_DEL_EN="Domain removed: "

TXT_HL_CLEARED_TR="Auto list temizlendi."
TXT_HL_CLEARED_EN="Auto list cleared."

# Hostlist prompts & messages
TXT_HL_ERR_NOT_INSTALLED_TR="HATA: Zapret yuklu degil."
TXT_HL_ERR_NOT_INSTALLED_EN="ERROR: Zapret is not installed."

TXT_HL_PROMPT_ADD_TR="Eklenecek Domain (0=iptal): "
TXT_HL_PROMPT_ADD_EN="Domain to Add (0=cancel): "

TXT_HL_PROMPT_DEL_TR="Silinecek Domain (0=iptal): "
TXT_HL_PROMPT_DEL_EN="Domain to Remove (0=cancel): "

TXT_HL_INVALID_DOMAIN_TR="Gecersiz Domain."
TXT_HL_INVALID_DOMAIN_EN="Invalid Domain."

TXT_HL_MSG_ADDED_TR="Eklendi: "
TXT_HL_MSG_ADDED_EN="Added: "

TXT_HL_MSG_REMOVED_TR="Silindi: "
TXT_HL_MSG_REMOVED_EN="Removed: "

TXT_HL_WARN_EMPTY_STRICT_TR="UYARI: User hostlist bos. Bu durumda zapret, exclude haric tum hostlari isleyebilir. Devam etmek icin en az bir domain ekleyin veya exclude kullanin."
TXT_HL_WARN_EMPTY_STRICT_EN="WARNING: User hostlist is empty. In this case, zapret may process all hosts except exclude. Add at least one domain or use exclude before enabling."

TXT_MENU_B_TR=" B. Blockcheck Test (Otomatik DPI)"
TXT_MENU_B_EN=" B. Blockcheck Test (Auto DPI)"

TXT_BLOCKCHECK_TEST_TITLE_TR="Blockcheck Test Menüsü"
TXT_BLOCKCHECK_TEST_TITLE_EN="Blockcheck Test Menu"

TXT_BLOCKCHECK_FULL_TR="Tam Test"
TXT_BLOCKCHECK_FULL_EN="Full Test"

TXT_BLOCKCHECK_SUMMARY_TR="Özet (Sadece SUMMARY) (Otomatik DPI için kullanılır)"
TXT_BLOCKCHECK_SUMMARY_EN="Summary (SUMMARY only) (Used for Auto DPI)"

TXT_BLOCKCHECK_CLEAN_TR="Test Sonuçlarını Temizle"
TXT_BLOCKCHECK_CLEAN_EN="Clean Test Results"

TXT_BLOCKCHECK_CLEAN_NONE_TR="Temizlenecek test raporu yok."
TXT_BLOCKCHECK_CLEAN_NONE_EN="No test reports to clean."

TXT_BLOCKCHECK_CLEAN_DONE_TR="Test raporlari temizlendi."
TXT_BLOCKCHECK_CLEAN_DONE_EN="Test reports cleaned."


TXT_BLOCKCHECK_SUMMARY_SAVED_TR="Ozet rapor kaydedildi:"
TXT_BLOCKCHECK_SUMMARY_SAVED_EN="Summary saved:"

TXT_BLOCKCHECK_SUMMARY_NOT_FOUND_TR="UYARI: SUMMARY bolumu bulunamadi."
TXT_BLOCKCHECK_SUMMARY_NOT_FOUND_EN="WARNING: SUMMARY section not found."

# Blockcheck (Summary) - action screen (i18n)
TXT_BLOCKCHECK_FOUND_TR="Blockcheck sonucu bulundu:"
TXT_BLOCKCHECK_FOUND_EN="Blockcheck result found:"

TXT_BLOCKCHECK_MOST_STABLE_TR="Bu ISS icin en stabil parametre:"
TXT_BLOCKCHECK_MOST_STABLE_EN="Most stable parameter for this ISP:"

TXT_BLOCKCHECK_SCORE_TR="DPI Saglik Skoru:"
TXT_BLOCKCHECK_SCORE_EN="DPI Health Score:"

TXT_BLOCKCHECK_SCORE_DNS_OK_TR="DNS tutarli"
TXT_BLOCKCHECK_SCORE_DNS_OK_EN="DNS consistent"

TXT_BLOCKCHECK_SCORE_TLS12_OK_TR="TLS12 OK"
TXT_BLOCKCHECK_SCORE_TLS12_OK_EN="TLS12 OK"

TXT_BLOCKCHECK_SCORE_UDP_WEAK_TR="UDP 443 zayif"
TXT_BLOCKCHECK_SCORE_UDP_WEAK_EN="UDP 443 weak"

TXT_BLOCKCHECK_ACTION_MENU_TR="[1] Uygula
[2] Parametreyi incele
[3] Sadece kaydet
[0] Vazgec"
TXT_BLOCKCHECK_ACTION_MENU_EN="[1] Apply
[2] Inspect parameter
[3] Save only
[0] Cancel"

TXT_BLOCKCHECK_ACTION_PROMPT_TR="Secim: "
TXT_BLOCKCHECK_ACTION_PROMPT_EN="Choice: "

TXT_PROMPT_SELECTION_TR=" Secim: "
TXT_PROMPT_SELECTION_EN=" Selection: "


TXT_MENU_L_TR=" L. Dil Degistir (TR/EN)"
TXT_MENU_L_EN=" L. Switch Language (TR/EN)"

TXT_MENU_0_TR=" 0. Cikis"
TXT_MENU_0_EN=" 0. Exit"

TXT_MENU_FOOT_TR="--------------------------------------------------------------------------------------------"
TXT_MENU_FOOT_EN="--------------------------------------------------------------------------------------------"

TXT_PROMPT_MAIN_TR=" Seciminizi Yapin (0-16, L veya B): "
TXT_PROMPT_MAIN_EN=" Select an Option (0-16, L or B): "

TXT_LANG_NOW_TR="Dil: Turkce"
TXT_LANG_NOW_EN="Language: English"

# IPSET menu
TXT_IPSET_TITLE_TR=" Zapret IPSET (Istemci Secimi)"
TXT_IPSET_TITLE_EN=" Zapret IPSET (Client Selection)"

TXT_IPSET_1_TR=" 1. Tum Aga Uygula (client Filtresi Kapali)"
TXT_IPSET_1_EN=" 1. Apply to Whole Network (Client Filter Off)"

TXT_IPSET_2_TR=" 2. Secili IP'lere Uygula (IP gir)"
TXT_IPSET_2_EN=" 2. Apply to Selected IPs (enter IPs)"

TXT_IPSET_3_TR=" 3. Mevcut IP Listesini Goster"
TXT_IPSET_3_EN=" 3. Show Current IP list"

TXT_IPSET_4_TR=" 4. Listeye Tek IP Ekle"
TXT_IPSET_4_EN=" 4. Add a Single IP to list"

TXT_IPSET_5_TR=" 5. Listeden Tek IP Sil"
TXT_IPSET_5_EN=" 5. Remove a Single IP from list"

TXT_IPSET_0_TR=" 0. Ana Menuye Don"
TXT_IPSET_0_EN=" 0. Back to Main Menu"

TXT_PROMPT_IPSET_TR=" Seciminizi Yapin (0-5): "
TXT_PROMPT_IPSET_EN=" Select an Option (0-5): "

TXT_PROMPT_IPSET_BASIC_TR=" Seciminizi Yapin (0-2): "
TXT_PROMPT_IPSET_BASIC_EN=" Select an Option (0-2): "

# Ceviri secici
# --- EK DIL METINLERI (TR/EN) ---
TXT_PRESS_ENTER_TR="Devam etmek icin Enter'a basin..."
TXT_PRESS_ENTER_EN="Press Enter to continue..."

# --- Script path warning ---
TXT_WARN_BAD_PATH_TR="UYARI: Betik beklenen dizinde degil!"
TXT_WARN_BAD_PATH_EN="WARNING: Script is not in the expected directory!"

TXT_WARN_MOVE_TR="[1] Dogru yere tasi"
TXT_WARN_MOVE_EN="[1] Move to correct location"

TXT_WARN_CONTINUE_TR="[0] Devam et"
TXT_WARN_CONTINUE_EN="[0] Continue"

TXT_WARN_CHOICE_TR="Secim: "
TXT_WARN_CHOICE_EN="Choice: "

TXT_WARN_MOVED_OK_TR="Betik dogru dizine tasindi."
TXT_WARN_MOVED_OK_EN="Script moved to the correct location."

TXT_WARN_MOVE_FAIL_TR="HATA: Betik tasinamadi."
TXT_WARN_MOVE_FAIL_EN="ERROR: Failed to move the script."

TXT_WARN_CHMOD_FAIL_TR="HATA: Calistirma izni verilemedi."
TXT_WARN_CHMOD_FAIL_EN="ERROR: Could not set executable permission."

TXT_SCRIPT_INSTALLED_TR="Kurulu Betik Surumu : "
TXT_SCRIPT_INSTALLED_EN="Installed Script Ver : "

TXT_GITHUB_LATEST_SIMPLE_TR="GitHub Guncel Surum : "
TXT_GITHUB_LATEST_SIMPLE_EN="GitHub Latest Ver  : "

TXT_GITHUB_NOINFO_TR="Bilgi alinamadi"
TXT_GITHUB_NOINFO_EN="Unable to fetch info"

TXT_REPO_LABEL_TR="Repo               : "
TXT_REPO_LABEL_EN="Repo               : "

TXT_EMPTY_TR="(bos)"
TXT_EMPTY_EN="(empty)"

TXT_IPSET_MODE_LIST_TR="Mod: Secili IP"
TXT_IPSET_MODE_LIST_EN="Mode: Selected IPs"

TXT_IPSET_MODE_ALL_TR="Mod: Tum Ag"
TXT_IPSET_MODE_ALL_EN="Mode: Whole Network"

TXT_IPSET_ALL_NETWORK_TR="Zapret tum ag genelinde aktif. Secili IP listesi kullanilmiyor."
TXT_IPSET_ALL_NETWORK_EN="Zapret is active network-wide. Selected IP list is not in use."

TXT_IP_LIST_FILE_TR="IP Listesi (dosya): "
TXT_IP_LIST_FILE_EN="IP List (file): "

TXT_IPSET_MEMBERS_TR="IPSET Uyeleri (aktif): "
TXT_IPSET_MEMBERS_EN="IPSET Members (active): "

TXT_VERSION_INSTALLED_TR="Kurulu Surum: "
TXT_VERSION_INSTALLED_EN="Installed Version: "

TXT_CHECKING_GITHUB_TR="GitHub uzerinden en guncel surum sorgulaniyor..."
TXT_CHECKING_GITHUB_EN="Checking latest version on GitHub..."

TXT_GITHUB_LATEST_TR="Guncel        : "
TXT_GITHUB_LATEST_EN="Latest        : "

TXT_DEVICE_VERSION_TR="Kurulu       : "
TXT_DEVICE_VERSION_EN="Installed     : "

TXT_UPTODATE_TR="En guncel surumu kullaniyorsunuz."
TXT_UPTODATE_EN="You are using the latest version."

TXT_GITHUB_FAIL_TR="HATA: GitHub uzerinden surum bilgisi alinamadi."
TXT_GITHUB_FAIL_EN="ERROR: Could not fetch version info from GitHub."

TXT_ADD_IP_TR="Eklenecek IP (Enter=Vazgec): "
TXT_ADD_IP_EN="IP to add (Enter=Cancel): "

TXT_DEL_IP_TR="Silinecek IP (Enter=Vazgec): "
TXT_DEL_IP_EN="IP to remove (Enter=Cancel): "
T() {
    # Kullanım:
    #   T KEY                 -> sözlükten KEY_TR / KEY_EN
    #   T KEY "TR metin" "EN metin" -> verilen metinler (sözlüğe ihtiyaç yok)
    local k="$1"
    local tr="$2"
    local en="$3"
    [ -z "$k" ] && return 0

    # Eğer TR/EN parametreleri verilmişse onları kullan
    if [ -n "$tr" ] || [ -n "$en" ]; then
        if [ "$LANG" = "en" ]; then
            [ -n "$en" ] && printf '%s' "$en" || printf '%s' "${tr:-$k}"
        else
            [ -n "$tr" ] && printf '%s' "$tr" || printf '%s' "${en:-$k}"
        fi
        return 0
    fi

    # Sözlük değişkenlerinden oku
    local v=""
    if [ "$LANG" = "en" ]; then
        eval "v="\${${k}_EN}""
        [ -z "$v" ] && eval "v="\${${k}_TR}""
    else
        eval "v="\${${k}_TR}""
        [ -z "$v" ] && eval "v="\${${k}_EN}""
    fi
    [ -z "$v" ] && v="$k"
    printf '%s' "$v"
}

# Enter'a basinca devam et (TR/EN)
press_enter_to_continue() {
    # Robust pause: always read from controlling TTY so it cannot be skipped by buffered stdin.
    # We keep clear after the keypress because menus redraw anyway.
    read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")" _ </dev/tty
    clear
}



load_lang() {
    if [ -f "$LANG_FILE" ]; then
        LANG="$(cat "$LANG_FILE" 2>/dev/null | tr -d '\r\n\t ' )"
    fi
    case "$LANG" in
        en|EN) LANG="en" ;;
        *)     LANG="tr" ;;
    esac
}

toggle_lang() {
    load_lang
    if [ "$LANG" = "en" ]; then LANG="tr"; else LANG="en"; fi
    mkdir -p /opt/zapret 2>/dev/null
    echo "$LANG" > "$LANG_FILE" 2>/dev/null
}

lang_label() {
    if [ "$LANG" = "en" ]; then
        echo "$TXT_LANG_NOW_EN"
    else
        echo "$TXT_LANG_NOW_TR"
    fi
}

load_lang

# IPSET (istemci bazli) ayarlari
IPSET_CLIENT_NAME="zapret_clients"
IPSET_CLIENT_FILE="/opt/zapret/ipset_clients.txt"
IPSET_CLIENT_MODE_FILE="/opt/zapret/ipset_clients_mode"  # all | list

# WAN arayuzu (cikis) secimi / otomatik algilama
WAN_IF_FILE="/opt/zapret/wan_if"

detect_recommended_wan_if() {
    # Varsayilan route'dan arayuz algila. WireGuard/tun gibi arayuzleri mumkunse secme.
    ip route show default 2>/dev/null | awk '
        $1=="default" {
            dev=""
            for(i=1;i<=NF;i++) if($i=="dev") dev=$(i+1)
            if(dev!="") {
                if(dev !~ /^(wg|nwg|tun|tap)/) { print dev; exit }
                if(fallback=="") fallback=dev
            }
        }
        END { if(fallback!="") print fallback }
    '
}

get_wan_if() {
    local w=""
    [ -f "$WAN_IF_FILE" ] && w="$(cat "$WAN_IF_FILE" 2>/dev/null)"
    [ -z "$w" ] && w="$(detect_recommended_wan_if)"
    echo "$w"
}

# WAN arayuzu icin ifindex bilgisi (install_easy.sh arayuz secimi icin)
get_ifindex_by_iface() {
    local ifc="$1"
    [ -z "$ifc" ] && return 1
    cat "/sys/class/net/${ifc}/ifindex" 2>/dev/null
}

# Zapret config icinde IFACE_WAN degerini secilen WAN arayuzu ile esitle
sync_zapret_iface_wan_config() {
    local ifc="$(get_wan_if)"
    [ -z "$ifc" ] && return 0
    [ ! -d /opt/zapret ] && return 0
    # config dosyasi yoksa dokunma (zapret kurulu degilse)
    [ ! -f /opt/zapret/config ] && return 0
    if grep -q '^IFACE_WAN=' /opt/zapret/config 2>/dev/null; then
        sed -i "s/^IFACE_WAN=.*/IFACE_WAN=${ifc}/" /opt/zapret/config 2>/dev/null
    else
        echo "IFACE_WAN=${ifc}" >> /opt/zapret/config 2>/dev/null
    fi
}

# NFQUEUE kurallarinda eski/yanlis arayuz kalintilarini temizle (sadece secili WAN kalsin)
cleanup_nfqueue_rules_except_selected_wan() {
    local WAN="$(get_wan_if)"
    [ -z "$WAN" ] && return 0

    # yalnizca NFQUEUE iceren kurallari tara; secili WAN disindakileri sil
    iptables -t mangle -S 2>/dev/null | grep -F ' -j NFQUEUE' | while IFS= read -r line; do
        # line: -A CHAIN ...
        if echo "$line" | grep -Eq -- "(^-A (INPUT|FORWARD) -i ${WAN} )|(-A POSTROUTING -o ${WAN} )"; then
            continue
        fi
        # baska bir arayuze bagli kurali silmeyi dene
        local del
        del="$(echo "$line" | sed 's/^-A /-D /')"
        iptables -t mangle $del 2>/dev/null
    done
}


select_wan_if() {
    # Kurulumda (ve gerekirse sonradan) WAN arayuzunu belirle.
    local rec="$(detect_recommended_wan_if)"
    [ -z "$rec" ] && rec="ppp0"
    print_line "-"
printf " \033[1;33mZapret cikis arayuzu secimi\033[0m\n"
    echo " (Ornek: ppp0 = WAN, wg0/wg1 = WireGuard)"
    echo " Su Anki: $(get_wan_if)"
    echo " Onerilen: $rec"
    print_line "-"
    printf "\033[1;32mArayuz adini yazin (Enter = %s)\033[0m: " "$rec"
    read -r ans
    [ -z "$ans" ] && ans="$rec"
    # bazen kopyala-yapistir ile sonuna nokta gelebiliyor (ppp0.)
    if [ -n "$ans" ] && [ ! -d "/sys/class/net/$ans" ] && [ -d "/sys/class/net/${ans%\.}" ]; then
        ans="${ans%.}"
    fi
    [ -z "$ans" ] && return 0
    mkdir -p /opt/zapret 2>/dev/null
    echo "$ans" > "$WAN_IF_FILE" 2>/dev/null
    echo "Secildi: $(get_wan_if)"
}

enforce_wan_if_nfqueue_rules() {
    # NFQUEUE kurallarini sadece secili WAN arayuzunde etkinlestirerek WireGuard vb. arayuzlerde sorunlari azaltir.
    local WAN="$(get_wan_if)"
    [ -z "$WAN" ] && return 0

    # mangle/POSTROUTING: -o WAN ekle
    iptables -t mangle -S POSTROUTING 2>/dev/null | grep -F -- " -j NFQUEUE" | grep -F -- "--queue-num 200" | while read -r rule; do
        echo "$rule" | grep -qE ' -o [^ ]+' && continue
        del="$(echo "$rule" | sed 's/^-A /-D /')"
        iptables -t mangle $del 2>/dev/null
        add="$(echo "$rule" | sed "s/ -j NFQUEUE/ -o $WAN -j NFQUEUE/")"
        iptables -t mangle $add 2>/dev/null
    done

    # filter INPUT/FORWARD: -i WAN ekle (varsa)
    for chain in INPUT FORWARD; do
        iptables -S "$chain" 2>/dev/null | grep -F -- " -j NFQUEUE" | grep -F -- "--queue-num 200" | while read -r rule; do
            echo "$rule" | grep -qE ' -i [^ ]+' && continue
            del="$(echo "$rule" | sed 's/^-A /-D /')"
            iptables $del 2>/dev/null
            add="$(echo "$rule" | sed "s/ -j NFQUEUE/ -i $WAN -j NFQUEUE/")"
            iptables $add 2>/dev/null
        done
    done
    return 0
}


# --- Keenetic: persistently pin NFQUEUE POSTROUTING rules to real WAN (-o ppp0/wgX) ---
create_keenetic_fw_post_up_hook() {
    # Creates /opt/zapret/keenetic_fw_post_up.sh (idempotent).
    # This hook can be invoked manually and by patched zapret init script.
    local HOOK="/opt/zapret/keenetic_fw_post_up.sh"
    mkdir -p /opt/zapret >/dev/null 2>&1
    cat > "$HOOK" <<'EOF'
#!/bin/sh
# Keenetic post-up helper: pin NFQUEUE POSTROUTING rules that use zapret_clients/nozapret ipsets to the real default WAN iface.
# Works even if default route line is "default dev ppp0 ..." (Keenetic).
WAN="$(ip route 2>/dev/null | awk '/^default/ {for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
[ -z "$WAN" ] && WAN="ppp0"

# For each NFQUEUE rule in POSTROUTING that matches zapret ipsets but has no "-o", re-add it with "-o $WAN".
# Keep it safe: only touch rules that contain "match-set zapret_clients src" OR "match-set nozapret".
iptables -t mangle -S POSTROUTING 2>/dev/null | grep NFQUEUE 2>/dev/null | while IFS= read -r r; do
    echo "$r" | grep -q -- " -o " && continue
    echo "$r" | grep -Eq -- 'match-set (zapret_clients src|nozapret)' || continue

    del="${r/-A /-D }"
    add="$(echo "$r" | sed "s/ -j NFQUEUE/ -o $WAN -j NFQUEUE/")"
    iptables -t mangle $del >/dev/null 2>&1
    iptables -t mangle $add >/dev/null 2>&1
done

exit 0
EOF
    chmod +x "$HOOK" >/dev/null 2>&1
}

patch_zapret_real_to_run_post_hook() {
    # zapret upstream init script does not always support config-level hooks on Keenetic builds.
    # So we patch zapret.real to execute the post-up hook right after each zapret_apply_firewall call.
    local REAL="/opt/zapret/init.d/sysv/zapret.real"
    local HOOK="/opt/zapret/keenetic_fw_post_up.sh"
    [ -f "$REAL" ] || return 0
    [ -x "$HOOK" ] || return 0

    # Already patched?
    grep -q "keenetic_fw_post_up.sh" "$REAL" 2>/dev/null && return 0

    local BAK="${REAL}.bak_$(date +%Y%m%d_%H%M%S 2>/dev/null).sh"
    cp -a "$REAL" "$BAK" >/dev/null 2>&1 || return 0

    awk '
    {
        print $0
        # After any zapret_apply_firewall invocation (either "zapret_apply_firewall;" or "{ zapret_apply_firewall; }")
        if ($0 ~ /zapret_apply_firewall/) {
            print "        [ -x /opt/zapret/keenetic_fw_post_up.sh ] && /opt/zapret/keenetic_fw_post_up.sh >/dev/null 2>&1"
        }
    }' "$BAK" > "$REAL" 2>/dev/null || {
        cp -a "$BAK" "$REAL" >/dev/null 2>&1
        return 0
    }
    chmod +x "$REAL" >/dev/null 2>&1
}


# --- DPI PROFIL SECIMI (NFQWS_OPT) ---
DPI_PROFILE_FILE="/opt/zapret/dpi_profile"
DPI_PROFILE_ORIGIN_FILE="/opt/zapret/dpi_profile_origin"
DPI_PROFILE_PARAMS_FILE="/opt/zapret/dpi_profile_params"
BLOCKCHECK_AUTO_PARAMS_FILE="/opt/zapret/blockcheck_auto_params"

get_dpi_origin() {
    local o="manual"
    [ -f "$DPI_PROFILE_ORIGIN_FILE" ] && o="$(cat "$DPI_PROFILE_ORIGIN_FILE" 2>/dev/null)"
    case "$o" in
        auto|manual) echo "$o" ;;
        *) echo "manual" ;;
    esac
}

set_dpi_origin() {
    mkdir -p "$(dirname "$DPI_PROFILE_ORIGIN_FILE")" 2>/dev/null
    echo "$1" > "$DPI_PROFILE_ORIGIN_FILE" 2>/dev/null
}

set_dpi_params() {
    mkdir -p "$(dirname "$DPI_PROFILE_PARAMS_FILE")" 2>/dev/null
    printf "%s" "$1" > "$DPI_PROFILE_PARAMS_FILE" 2>/dev/null
}

get_dpi_params() {
    [ -f "$DPI_PROFILE_PARAMS_FILE" ] && cat "$DPI_PROFILE_PARAMS_FILE" 2>/dev/null
}


get_dpi_profile() {
    local p="tt_default"
    [ -f "$DPI_PROFILE_FILE" ] && p="$(cat "$DPI_PROFILE_FILE" 2>/dev/null)"
    case "$p" in
        tt_default|tt_fiber|tt_alt|sol|sol_alt|sol_fiber|turkcell_mob|vodafone_mob|blockcheck_auto) echo "$p" ;;
        *) echo "tt_default" ;;
    esac
}

set_dpi_profile() {
    mkdir -p "$(dirname "$DPI_PROFILE_FILE")" 2>/dev/null

    echo "$1" > "$DPI_PROFILE_FILE" 2>/dev/null
}

dpi_profile_name_tr() {
    case "$1" in
        tt_default) echo "Turk Telekom Fiber (TTL2 fake)";;
        tt_fiber)   echo "Turk Telekom Fiber (TTL4 fake)";;
        tt_alt)     echo "KabloNet (TTL3 fake)";;
        sol)        echo "Superonline (fake + m5sig)";;
        sol_alt)    echo "Superonline Alternatif (TTL3 fake + m5sig)";;
        sol_fiber) echo "Superonline Fiber (TTL5 fake + badsum)";;
        turkcell_mob) echo "Turkcell Mobil (TTL1 + AutoTTL3 fake)";;
        vodafone_mob) echo "Vodafone Mobil (multisplit split-pos=2)";;
        blockcheck_auto) echo "Blockcheck Otomatik (Auto)";;
        *) echo "$1";;
    esac
}

dpi_profile_name_en() {
    case "$1" in
        tt_default) echo "Turk Telekom Fiber (TTL2 fake)";;
        tt_fiber)   echo "Turk Telekom Fiber (TTL4 fake)";;
        tt_alt)     echo "KabloNet (TTL3 fake)";;
        sol)        echo "Superonline (fake + m5sig)";;
        sol_alt)    echo "Superonline Alternative (TTL3 fake + m5sig)";;
        sol_fiber)  echo "Superonline Fiber (TTL5 fake + badsum)";;
        turkcell_mob) echo "Turkcell Mobile (TTL1 + AutoTTL3 fake)";;
        vodafone_mob) echo "Vodafone Mobile (multisplit split-pos=2)";;
        blockcheck_auto) echo "Blockcheck Auto";;
        *) echo "$1";;
    esac
}

show_active_dpi_info() {
    local origin="$(get_dpi_origin)"
    local origin_label=""
    if [ "$origin" = "auto" ]; then
        origin_label="$(T TXT_ACTIVE_DPI_AUTO)"
    else
        origin_label="$(T TXT_ACTIVE_DPI_DEFAULT)"
    fi

    printf "%s : %s
" "$(T TXT_ACTIVE_DPI)" "$origin_label"
    if [ -s "$DPI_PROFILE_PARAMS_FILE" ]; then
        printf "%s : %s
" "$(T TXT_ACTIVE_DPI_PARAMS)" "$(cat "$DPI_PROFILE_PARAMS_FILE" 2>/dev/null)"
    fi

    # Bilgi (Auto): Blockcheck (Otomatik) aktifken listelenen 1-8 profilleri pasiftir
    # Bilgi (Auto): Blockcheck (Otomatik) aktifken listelenen 1-8 profilleri pasiftir
if [ "$origin" = "auto" ]; then
    printf "%b\n" "${CLR_YELLOW} Not: $(T TXT_DPI_AUTO_NOTE)${CLR_RESET}"
fi

}

select_dpi_profile() {
    local cur="$(get_dpi_profile)"
    local origin="$(get_dpi_origin)"
    print_line "-"
    echo " $(T dpi_title "DPI Profili Secimi" "DPI Profile Selection")"
    print_line "-"
    local _cur_label_tr=" Su Anki"
    local _cur_label_en=" Current"

    if [ "$origin" = "auto" ]; then
        # Auto: show current as Blockcheck, and show base profile separately
        printf "\033[1;32m%s: %s\033[0m\n" "$(T dpi_current "$_cur_label_tr" "$_cur_label_en")" "$(T TXT_ACTIVE_DPI_AUTO)"
        printf "%s: %s\n" "$(T TXT_DPI_BASE_PROFILE)" "$(T dpi_curp "$(dpi_profile_name_tr "$cur")" "$(dpi_profile_name_en "$cur")")"
    else
        printf "\033[1;32m%s: %s\033[0m\n" "$(T dpi_current "$_cur_label_tr" "$_cur_label_en")" "$(T dpi_curp "$(dpi_profile_name_tr "$cur")" "$(dpi_profile_name_en "$cur")")"
    fi
							 
																																	  

    print_line "-"

show_active_dpi_info
    print_line "-"
        # Menu satirlarinda:
    # - Varsayilan profil (tt_default) her zaman "Default/Varsayilan" olarak isaretlenir
    # - Kullanilan profil "ACTIVE/AKTIF" olarak isaretlenir
    for _id in tt_default tt_fiber tt_alt sol sol_alt sol_fiber turkcell_mob vodafone_mob; do
        _num=""
        case "$_id" in
            tt_default) _num="1" ;;
            tt_fiber)   _num="2" ;;
            tt_alt)     _num="3" ;;
            sol)        _num="4" ;;
            sol_alt)    _num="5" ;;
            sol_fiber)  _num="6" ;;
            turkcell_mob) _num="7" ;;
            vodafone_mob) _num="8" ;;
        esac

        _name_tr="$(dpi_profile_name_tr "$_id")"
        _name_en="$(dpi_profile_name_en "$_id")"

        _suf_tr=""
        _suf_en=""

        # varsayilan isareti
        if [ "$_id" = "tt_default" ]; then
            _suf_tr=" (Varsayilan)"
            _suf_en=" (Default)"
        fi
# aktif/taban isareti
if [ "$origin" = "auto" ]; then
    # Blockcheck otomatik modunda "AKTIF" etiketi listeye yazilmaz.
    # Bunun yerine mevcut (taban) profil "TABAN/BASE" olarak gosterilir.
    if [ "$cur" = "$_id" ]; then
        _suf_tr="${_suf_tr} (Taban)"
        _suf_en="${_suf_en} (Base)"
    fi
else
    # Manuel mod: secili profil "ACTIVE/AKTIF" olarak isaretlenir
    if [ "$cur" = "$_id" ]; then
        if [ "$origin" = "auto" ]; then
            _suf_tr="${_suf_tr} (Taban)"
            _suf_en="${_suf_en} (Base)"
        else
            _suf_tr="${_suf_tr} ${CLR_CYAN}(AKTIF)${CLR_RESET}"
            _suf_en="${_suf_en} ${CLR_CYAN}(ACTIVE)${CLR_RESET}"
        fi
    fi
fi

        echo " ${_num}. $(T dpi_prof_${_id} "${_name_tr}${_suf_tr}" "${_name_en}${_suf_en}")"
    done
    echo " 0. $(T back_main 'Ana Menuye Don' 'Back')"
    print_line "-"
    read -r -p "$(T dpi_prompt "Seciminizi yapin (0-8): " "Select an option (0-8): ")" sel
    # sanitize selection (avoid "0 applies 1" edge cases)
    sel="$(echo "$sel" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [ -z "$sel" ] || [ "$sel" = "0" ]; then
        return 1
    fi


    # If auto profile is active, switching to a numbered profile disables auto (by user's choice)
    if [ "$origin" = "auto" ] && echo "$sel" | grep -Eq '^[1-8]$'; then
        local _ans
        read -r -p "$(T TXT_DPI_AUTO_DISABLE_PROMPT)" _ans
        local _def_yes="y"
        [ "$LANG" = "tr" ] && _def_yes="e"
        _ans="${_ans:-$_def_yes}"
        case "$_ans" in
            e|E|y|Y) : ;;
            *) return 1 ;;
        esac
    fi

    case "$sel" in
        1) set_dpi_profile tt_default ;;
        2) set_dpi_profile tt_fiber ;;
        3) set_dpi_profile tt_alt ;;
        4) set_dpi_profile sol ;;
        5) set_dpi_profile sol_alt ;;
        6) set_dpi_profile sol_fiber ;;
        7) set_dpi_profile turkcell_mob ;;
        8) set_dpi_profile vodafone_mob ;;
	   
        0) return 1 ;;
        *) return 1 ;;
    esac

    set_dpi_origin "manual"
    : > "$DPI_PROFILE_PARAMS_FILE" 2>/dev/null
    rm -f "$BLOCKCHECK_AUTO_PARAMS_FILE" 2>/dev/null

    # DPI profiline gore NFQWS parametrelerini guncelle
    update_nfqws_parameters >/dev/null 2>&1

    print_line "-"
    echo "$(T dpi_restart_msg 'DPI profili uygulaniyor, Zapret yeniden baslatiliyor...' 'Applying DPI profile, restarting Zapret...')"
    /opt/etc/init.d/S90-zapret restart >/dev/null 2>&1
    _rc=$?
    if [ "$_rc" -eq 0 ]; then
        echo "$(T dpi_restart_ok 'Zapret yeniden baslatildi.' 'Zapret restarted.')"
    else
        echo "$(T dpi_restart_fail 'UYARI: Zapret yeniden baslatilamadi. Komut: /opt/etc/init.d/S90-zapret restart' 'WARNING: Could not restart Zapret. Command: /opt/etc/init.d/S90-zapret restart')"
    fi
    if type press_enter_to_continue >/dev/null 2>&1; then
        press_enter_to_continue
    else
        read -r -p "$(T press_enter "Devam etmek icin Enter'a basin..." "Press Enter to continue...")" _tmp
    fi

    return 0
}

apply_dpi_profile_now() {
    if ! is_zapret_installed; then
        echo "$(T err_not_inst "HATA: Zapret yuklu degil." "ERROR: Zapret is not installed.")"
        read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
        return 1
    fi
    update_nfqws_parameters
    restart_zapret >/dev/null 2>&1 || true
    enforce_client_mode_rules >/dev/null 2>&1 || true
    enforce_wan_if_nfqueue_rules >/dev/null 2>&1 || true
    echo "$(T dpi_applied "DPI profili uygulandi." "DPI profile applied.")"
    read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
}

get_client_mode() {
    local m="all"
    [ -f "$IPSET_CLIENT_MODE_FILE" ] && m="$(cat "$IPSET_CLIENT_MODE_FILE" 2>/dev/null)"
    [ -z "$m" ] && m="all"
    echo "$m"
}

ipset_ensure_and_load_clients() {
    command -v ipset >/dev/null 2>&1 || return 1
    ipset list "$IPSET_CLIENT_NAME" >/dev/null 2>&1 || ipset create "$IPSET_CLIENT_NAME" hash:ip >/dev/null 2>&1
    [ -f "$IPSET_CLIENT_FILE" ] || return 0
    # Bosluk/virgul/tab/... ayiricilarini destekle
    tr ' \t,;' '\n' < "$IPSET_CLIENT_FILE" | awk 'NF{print $0}' | while read -r ip; do
        ipset add "$IPSET_CLIENT_NAME" "$ip" -exist >/dev/null 2>&1
    done
    return 0
}

add_ipset_nfqueue_rules() {
    local WAN="$(get_wan_if)"
    [ -z "$WAN" ] && WAN=""
    # Sadece secili istemciler icin
    iptables -t mangle -I POSTROUTING 1 ${WAN:+-o $WAN} -p udp -m multiport --dports 443 \
        -m set --match-set "$IPSET_CLIENT_NAME" src \
        -j NFQUEUE --queue-num 200 --queue-bypass >/dev/null 2>&1
    iptables -t mangle -I POSTROUTING 1 ${WAN:+-o $WAN} -p tcp -m multiport --dports 80,443 \
        -m set --match-set "$IPSET_CLIENT_NAME" src \
        -j NFQUEUE --queue-num 200 --queue-bypass >/dev/null 2>&1

    iptables -I INPUT 1 ${WAN:+-i $WAN} -p tcp -m multiport --sports 80,443 \
        -m set --match-set "$IPSET_CLIENT_NAME" dst \
        -j NFQUEUE --queue-num 200 --queue-bypass >/dev/null 2>&1
    iptables -I FORWARD 1 ${WAN:+-i $WAN} -p tcp -m multiport --sports 80,443 \
        -m set --match-set "$IPSET_CLIENT_NAME" dst \
        -j NFQUEUE --queue-num 200 --queue-bypass >/dev/null 2>&1
}
del_ipset_nfqueue_rules() {
    local WAN="$(get_wan_if)"
    # Hem arayuzlu hem arayuzsuz varyantlari silmeyi dene
        [ -n "$WAN" ] && iptables -t mangle -D POSTROUTING -o "$WAN" -p udp -m multiport --dports 443 \
        -m set --match-set "$IPSET_CLIENT_NAME" src \
        -j NFQUEUE --queue-num 200 --queue-bypass >/dev/null 2>&1
    iptables -t mangle -D POSTROUTING -p udp -m multiport --dports 443 \
        -m set --match-set "$IPSET_CLIENT_NAME" src \
        -j NFQUEUE --queue-num 200 --queue-bypass >/dev/null 2>&1
        [ -n "$WAN" ] && iptables -t mangle -D POSTROUTING -o "$WAN" -p tcp -m multiport --dports 80,443 \
        -m set --match-set "$IPSET_CLIENT_NAME" src \
        -j NFQUEUE --queue-num 200 --queue-bypass >/dev/null 2>&1
    iptables -t mangle -D POSTROUTING -p tcp -m multiport --dports 80,443 \
        -m set --match-set "$IPSET_CLIENT_NAME" src \
        -j NFQUEUE --queue-num 200 --queue-bypass >/dev/null 2>&1
        [ -n "$WAN" ] && iptables -D INPUT -i "$WAN" -p tcp -m multiport --sports 80,443 \
        -m set --match-set "$IPSET_CLIENT_NAME" dst \
        -j NFQUEUE --queue-num 200 --queue-bypass >/dev/null 2>&1
    iptables -D INPUT -p tcp -m multiport --sports 80,443 \
        -m set --match-set "$IPSET_CLIENT_NAME" dst \
        -j NFQUEUE --queue-num 200 --queue-bypass >/dev/null 2>&1
        [ -n "$WAN" ] && iptables -D FORWARD -i "$WAN" -p tcp -m multiport --sports 80,443 \
        -m set --match-set "$IPSET_CLIENT_NAME" dst \
        -j NFQUEUE --queue-num 200 --queue-bypass >/dev/null 2>&1
    iptables -D FORWARD -p tcp -m multiport --sports 80,443 \
        -m set --match-set "$IPSET_CLIENT_NAME" dst \
        -j NFQUEUE --queue-num 200 --queue-bypass >/dev/null 2>&1
}
enforce_client_mode_rules() {
    # start-fw bazen genel (tum ag) NFQUEUE kurallarini basabiliyor.
    # MODE=list ise: tum qnum=200 NFQUEUE'leri temizle ve sadece ipset kurallarini bas.
    # MODE=all  ise: ipset'e bagli kurallari temizle (genel kalsin).
    local mode="$(get_client_mode)"
    local Q="200"

    command -v iptables >/dev/null 2>&1 || return 0

    if [ "$mode" = "list" ]; then
        flush_all_nfqueue_rules "$Q"
        ipset_ensure_and_load_clients || true
        add_ipset_nfqueue_rules "$Q"
    else
        # all modda ipset hedefli kurallari temizle
        del_ipset_nfqueue_rules >/dev/null 2>&1
    fi
}

# Cekirdek modulu yapilandirmasini gunceller
update_kernel_module_config() {
    awk '
      BEGIN { inserted=0 }
      {
        print $0
        if (!inserted && $0 == "{") {
          getline nextline
          if (prev_line == "do_start()") {
            print "    if lsmod | grep \"xt_multiport \" &> /dev/null ;  then"
            print "        echo \"xt_multiport.ko is already loaded\""
            print "    else"
            print "        if insmod /lib/modules/$(uname -r)/xt_multiport.ko &> /dev/null; then"
            print "            echo \"iptable_raw.ko loaded\""
            print "        else"
            print "            echo \"Cannot find xt_multiport.ko kernel module, aborting\""
            print "            exit 1"
            print "        fi"
            print "    fi"
            print ""
            print "    if lsmod | grep \"xt_connbytes \" &> /dev/null ;  then"
            print "        echo \"xt_connbytes.ko is already loaded\""
            print "    else"
            print "        if insmod /lib/modules/$(uname -r)/xt_connbytes.ko &> /dev/null; then"
            print "            echo \"xt_connbytes.ko loaded\""
            print "        else"
            print "            echo \"Cannot find xt_connbytes.ko kernel module, aborting\""
            print "            exit 1"
            print "        fi"
            print "    fi"
            print ""
            print "    if lsmod | grep \"xt_NFQUEUE \" &> /dev/null ;  then"
            print "        echo \"xt_NFQUEUE.ko is already loaded\""
            print "    else"
            print "        if insmod /lib/modules/$(uname -r)/xt_NFQUEUE.ko &> /dev/null; then"
            print "            echo \"xt_NFQUEUE.ko loaded\""
            print "        else"
            print "            echo \"Cannot find xt_NFQUEUE.ko kernel module, aborting\""
            print "            exit 1"
            print "        fi"
            print "    fi"
            print ""
            inserted=1
          }
          print nextline
        }
        prev_line = $0
      }
    ' /opt/zapret/init.d/sysv/zapret > /tmp/zapret_new && mv /tmp/zapret_new /opt/zapret/init.d/sysv/zapret || {
        echo "HATA: Kernel modulu yukleme dosyasina eklenemedi."
        return 1
    }

    chmod +x /opt/zapret/init.d/sysv/zapret || {
        echo "HATA: Kernel modulu yukleme dosyasina calistirma izni verilemedi."
        return 1
    }

    echo "Kernel modulu yukleme dosyasina eklendi."
    return 0
}

# NFQWS parametrelerini gunceller
update_nfqws_parameters() {
    local profile="$(get_dpi_profile)"
    local ipv6="$ZAPRET_IPV6"
    # Kapsam modu: global (tum ag) | smart (yalnizca listeler/auto)
    local scope="$(get_scope_mode)"
    local mf="$(get_mode_filter)"
    local HOST_MARKER=""
    if [ "$scope" = "smart" ]; then
        # zapret init scripts replace <HOSTLIST> depending on MODE_FILTER
        HOST_MARKER="<HOSTLIST>"
    fi


    # Profil parametreleri (varsayilanlar)
    local DESYNC="fake"
    local TTL=""
    local AUTOTTL=""
    local FOOLING=""
    local SPLITPOS=""

    # blockcheck_auto: use parameters extracted from blockcheck summary (stored as raw nfqws args)
    local AUTO_PARAMS _ttl
    AUTO_PARAMS=""
    if [ "$profile" = "blockcheck_auto" ] && [ -s "$BLOCKCHECK_AUTO_PARAMS_FILE" ]; then
        AUTO_PARAMS="$(cat "$BLOCKCHECK_AUTO_PARAMS_FILE" 2>/dev/null | tr '\n' ' ' | sed 's/^ *//; s/ *$//')"
        AUTO_PARAMS="$(echo "$AUTO_PARAMS" | sed 's/^nfqws[[:space:]]\+//')"
        # If IPv6 is enabled and ttl exists but ttl6 is missing, mirror ttl -> ttl6
        if [ "$ipv6" = "y" ] || [ "$ipv6" = "Y" ]; then
            if echo "$AUTO_PARAMS" | grep -q -- '--dpi-desync-ttl=' && ! echo "$AUTO_PARAMS" | grep -q -- '--dpi-desync-ttl6='; then
                _ttl="$(echo "$AUTO_PARAMS" | sed -n 's/.*--dpi-desync-ttl=\([^[:space:]]\+\).*/\1/p')"
                [ -n "$_ttl" ] && AUTO_PARAMS="${AUTO_PARAMS} --dpi-desync-ttl6=${_ttl}"
            fi
        fi
    fi


    case "$profile" in
        tt_default) DESYNC="fake"; TTL="2" ;;
        tt_fiber)   DESYNC="fake"; TTL="4" ;;
        tt_alt)     DESYNC="fake"; TTL="3" ;;
        sol)        DESYNC="fake"; FOOLING="m5sig" ;;
        sol_alt)    DESYNC="fake"; TTL="3"; FOOLING="m5sig" ;;
        sol_fiber)  DESYNC="fake"; TTL="5"; FOOLING="badsum" ;;
        turkcell_mob) DESYNC="fake"; TTL="1"; AUTOTTL="3" ;;
        vodafone_mob) DESYNC="multisplit"; SPLITPOS="2" ;;
        *) DESYNC="fake"; TTL="2"; profile="tt_default" ;;
    esac

    build_line() {
        # $1 proto(tcp/udp) $2 port(s) $3 extra endflag(--new or empty)
        local proto="$1" ports="$2" endflag="$3"
        local line="--filter-${proto}=${ports}"

        # Smart modda hostlist/autohostlist marker eklenir (global modda bos)
        [ -n "$HOST_MARKER" ] && line="${line} ${HOST_MARKER}"
        if [ -n "$AUTO_PARAMS" ]; then
            line="${line} ${AUTO_PARAMS}"
        else
            line="${line} --dpi-desync=${DESYNC}"
            [ -n "$FOOLING" ] && line="${line} --dpi-desync-fooling=${FOOLING}"
            [ -n "$SPLITPOS" ] && line="${line} --dpi-desync-split-pos=${SPLITPOS}"
            [ -n "$TTL" ] && line="${line} --dpi-desync-ttl=${TTL}"
            [ -n "$AUTOTTL" ] && line="${line} --dpi-desync-autottl=${AUTOTTL}"
        fi

        # IPv6 tarafinda TTL6 ekle (TTL varsa) - sadece sabit profillerde
        if [ -z "$AUTO_PARAMS" ] && { [ "$ipv6" = "y" ] || [ "$ipv6" = "Y" ]; }; then
            [ -n "$TTL" ] && line="${line} --dpi-desync-ttl6=${TTL}"
        fi

        [ -n "$endflag" ] && line="${line} ${endflag}"
        echo "$line"
    }

    # NFQWS_OPT blok satirlari
    local L1 L2 L3 L4 L5 L6
    if [ "$ipv6" = "y" ] || [ "$ipv6" = "Y" ]; then
        # IPv6 aciksa, her filtreyi iki kez yazmiyoruz; nfqws tek satirda ttl+ttl6 ile calisir.
        L1="$(build_line tcp 80 "--new")"
        L2="$(build_line tcp 443 "--new")"
        L3="$(build_line udp 443 "")"
        NFQWS_BLOCK="NFQWS_OPT=\"\\
${L1} \\
${L2} \\
${L3} \\
\""
    else
        L1="$(build_line tcp 80 "--new")"
        L2="$(build_line tcp 443 "--new")"
        L3="$(build_line udp 443 "")"
        NFQWS_BLOCK="NFQWS_OPT=\"\\
${L1} \\
${L2} \\
${L3} \\
\""
    fi

    # /opt/zapret/config icinde NFQWS_OPT bloğunu guvenli sekilde guncelle
    ensure_zapret_config >/dev/null 2>&1
    if [ ! -f /opt/zapret/config ]; then
        echo "$(T nfqws_cfg_missing "UYARI: /opt/zapret/config bulunamadi." "WARNING: /opt/zapret/config not found.")"
        return 1
    fi

    local tmp="/tmp/zapret_config.$$"
    awk -v repl="$NFQWS_BLOCK" '
        BEGIN { cleanup=0 }
        /^NFQWS_OPT="/ {
            print repl
            cleanup=1
            next
        }
        # Cleanup stray legacy multi-line NFQWS_OPT continuations (they start with --filter- and end with a lone ").
        cleanup==1 {
            if ($0 ~ /^--filter-/) next
            if ($0 ~ /^"[[:space:]]*([#;].*)?$/) { cleanup=0; next }
            cleanup=0
        }
        { print }
    ' /opt/zapret/config > "$tmp" && mv "$tmp" /opt/zapret/config

    if grep -q '^NFQWS_OPT="' /opt/zapret/config 2>/dev/null; then
        echo "$(T nfqws_updated "NFQWS parametreleri basariyla guncellendi." "NFQWS parameters updated successfully.")"
        echo "$(T dpi_active "Aktif DPI Profili" "Active DPI Profile"): $(T dpi_ap "$(dpi_profile_name_tr "$profile")" "$(dpi_profile_name_en "$profile")")"
        return 0
    else
        echo "$(T nfqws_fail "UYARI: Guncelleme basarisiz oldu, dosyayi kontrol edin." "WARNING: Update failed, please check the file.")"
        return 1
    fi
}



# Netfilter scriptini gunceller
allow_firewall() {
    # Betik icerigini dosyaya yazar
    echo '#!/bin/sh
[ "$table" != "mangle" ] && [ "$table" != "nat" ] && exit 0
/opt/zapret/init.d/sysv/zapret restart-fw
exit 0' > /opt/etc/ndm/netfilter.d/000-zapret.sh || {
        echo "HATA: Guvenlik duvari izni verilirken hata olustu."
        return 1
    }
	
    # Dosyayi calistirilabilir yapar
    chmod +x /opt/etc/ndm/netfilter.d/000-zapret.sh || {
        echo "HATA: Guvenlik duvari izni dosyasina calistirma izni verilemedi."
        return 1
    }
    
    echo "Guvenlik duvari izni verildi."
    return 0
}

# Zapret'in otomatik baslamasini ayarlar
add_auto_start_zapret() {
    ln -fs /opt/zapret/init.d/sysv/zapret /opt/etc/init.d/S90-zapret && \
    echo "Zapret'in otomatik baslatilmasi etkinlestirildi." || \
    { echo "UYARI: Zapret'in otomatik baslatilmasi etkinlestirilemedi."; return 0; }
}

# Total paket engellemeyi devre disi birakmayi ayarlar
disable_total_packet() {
    # Betik icerigini dosyaya yazar
    echo '#!/bin/sh
start() {
    sysctl -w net.netfilter.nf_conntrack_checksum=0 &> /dev/null
}
stop() {
    sysctl -w net.netfilter.nf_conntrack_checksum=1 &> /dev/null
}
case "$1" in
    '''start''')
        start
        ;;
    '''stop''')
        stop
        ;;
    *)
        stop
        start
        ;;
esac
exit 0' > /opt/etc/init.d/S00fix || {
        echo "HATA: Toplam paket kontrolu devredisi birakilirken hata olustu."
        return 1
    }

    # Dosyayi calistirilabilir yapar
    chmod +x /opt/etc/init.d/S00fix || {
        echo "HATA: Toplam paket kontrolu devre disi birakma dosyasina calistirma izni verilemedi."
        return 1
    }
    
    echo "Toplam paket kontrolu devre disi birakildi."
    return 0
}

# Keenetic uyumlulugunu etkinlestirir
keenetic_compatibility() {
    sed -i "s/^#WS_USER=nobody/WS_USER=nobody/" /opt/zapret/config.default && \
    echo "Keenetic icin uyumlu hale getirildi." || \
    { echo "HATA: Keenetic icin uyumlu hale getirilemedi."; return 1; }
}

# Keenetic UDP duzeltmesini ekler
fix_keenetic_udp() {
    cp -af /opt/zapret/init.d/custom.d.examples.linux/10-keenetic-udp-fix /opt/zapret/init.d/sysv/custom.d/10-keenetic-udp-fix && \
    echo "Keenetic UDP duzeltmesi eklendi." || \
    { echo "HATA: Keenetic UDP duzeltmesi eklenemedi."; return 1; }
}

# -------------------------------------------------------------------
# Zapret Calisma / Baslatma / Durdurma Yardimcilari
# -------------------------------------------------------------------

# (DURDUR modunda) otomatik yeniden baslamayi engellemek icin gecici bayrak.
# /tmp reboot ile temizlenir, yani router reboot edince otomatik baslatma devam eder.
ZAPRET_PAUSE_FLAG="/tmp/.zapret_paused"

zapret_pause()  { : > "$ZAPRET_PAUSE_FLAG" 2>/dev/null; }
zapret_resume() { rm -f "$ZAPRET_PAUSE_FLAG" 2>/dev/null; }

install_zapret_pause_guard() {
    # /opt/zapret/init.d/sysv/zapret wrapper'ina "pause" kontrolu ekler.
    # start/start-fw/restart/restart-fw cagrilari pause varken no-op olur.
    # stop her zaman calismaya devam eder.
    local Z="/opt/zapret/init.d/sysv/zapret"
    local R="/opt/zapret/init.d/sysv/zapret.real"
    [ -x "$Z" ] || return 0

    # Daha once wrapper yapilmadiysa yedekle
    if [ ! -f "$R" ]; then
        cp -f "$Z" "$R" 2>/dev/null || return 0
        chmod +x "$R" 2>/dev/null
    fi

    cat > "$Z" <<'EOF'
#!/opt/bin/sh
REAL="/opt/zapret/init.d/sysv/zapret.real"
PAUSE="/tmp/.zapret_paused"

if [ -f "$PAUSE" ]; then
  case "$1" in
    start|start-fw|restart|restart-fw)
      exit 0
    ;;
    esac
fi

exec "$REAL" "$@"
EOF
    chmod +x "$Z" 2>/dev/null
}

# NFQUEUE kurallarini (genel + ipset) temizlemek icin line-number tabanli guvenli temizleyici
# BusyBox ortaminda awk sorun cikarmasin diye sed/head kullaniliyor.
flush_nfqueue_by_linenum() {
    local table="$1" chain="$2" ln
    while true; do
        clear
        if [ -n "$table" ]; then
            ln="$(iptables -t "$table" -L "$chain" -n --line-numbers 2>/dev/null \
                | sed -n "/NFQUEUE/{s/^ *\\([0-9]\\+\\).*/\\1/p; q}")"
            [ -n "$ln" ] || break
            iptables -t "$table" -D "$chain" "$ln" 2>/dev/null
        else
            ln="$(iptables -L "$chain" -n --line-numbers 2>/dev/null \
                | sed -n "/NFQUEUE/{s/^ *\\([0-9]\\+\\).*/\\1/p; q}")"
            [ -n "$ln" ] || break
            iptables -D "$chain" "$ln" 2>/dev/null
        fi
    done
}

flush_all_nfqueue_rules() {
    # En saglam temizlik: iptables -S uzerinden -A -> -D cevirip sil
    command -v iptables >/dev/null 2>&1 || return 0

    # mangle: POSTROUTING/PREROUTING/OUTPUT/INPUT/FORWARD (varsa)
    for ch in POSTROUTING PREROUTING OUTPUT INPUT FORWARD; do
        iptables -t mangle -S "$ch" 2>/dev/null | grep -F -- "-j NFQUEUE" | while read -r r; do
            iptables -t mangle $(echo "$r" | sed "s/^-A /-D /") >/dev/null 2>&1
        done
    done

    # filter: INPUT/FORWARD/OUTPUT (bazi kurulumlarda burada da NFQUEUE olabiliyor)
    for ch in INPUT FORWARD OUTPUT; do
        iptables -S "$ch" 2>/dev/null | grep -F -- "-j NFQUEUE" | while read -r r; do
            iptables $(echo "$r" | sed "s/^-A /-D /") >/dev/null 2>&1
        done
    done

    # 2. tur: bazen ilk turde hepsi kalkmayabiliyor
    for ch in POSTROUTING PREROUTING OUTPUT INPUT FORWARD; do
        iptables -t mangle -S "$ch" 2>/dev/null | grep -F -- "-j NFQUEUE" | while read -r r; do
            iptables -t mangle $(echo "$r" | sed "s/^-A /-D /") >/dev/null 2>&1
        done
    done
    for ch in INPUT FORWARD OUTPUT; do
        iptables -S "$ch" 2>/dev/null | grep -F -- "-j NFQUEUE" | while read -r r; do
            iptables $(echo "$r" | sed "s/^-A /-D /") >/dev/null 2>&1
        done
    done
}

# Zapret servisinin calisip calismadigini kontrol eder (nfqws prosesine gore)
is_zapret_running() {
    pgrep -f "/opt/zapret/nfq/nfqws" >/dev/null 2>&1
}

# Zapret'in yuklu olup olmadigini kontrol eder
is_zapret_installed() {
    [ -x "/opt/zapret/init.d/sysv/zapret" ]
}

# Zapret servisini baslatir
start_zapret() {
    if ! is_zapret_installed; then
        echo "Zapret yuklu degil. Baslatma islemi yapilamiyor."
        return 1
    fi

    # Start edilecekse pause kaldir
    zapret_resume
    install_zapret_pause_guard

    if is_zapret_running; then
        echo "Zapret servisi zaten calisiyor."
        return 0
    fi

	/opt/zapret/init.d/sysv/zapret start >/dev/null 2>&1
	/opt/zapret/init.d/sysv/zapret start-fw >/dev/null 2>&1
	# start-fw, moddan bagimsiz olarak genel NFQUEUE kurallarini basabilir.
	# Burada MODE=list ise genel kurallari temizleyip sadece IPSET kurallarini birakiriz.
	enforce_client_mode_rules >/dev/null 2>&1
	enforce_wan_if_nfqueue_rules >/dev/null 2>&1

    sleep 1
    if is_zapret_running && iptables-save | grep -q "NFQUEUE"; then
        echo "Zapret servisi baslatildi."
        return 0
    fi

    echo "HATA: Zapret servisi baslatilirken hata olustu."
    return 1
}

# Zapret servisini durdurur (kalici durdurma: otomatik restart'i da engeller)
stop_zapret() {
    if ! is_zapret_installed; then
        echo "Zapret yuklu degil. Durdurma islemi yapilamiyor."
        return 1
    fi

    echo "Zapret durduruluyor (NFQWS + NFQUEUE)..."

    # Pause ON: netfilter hook/otomatik restart tetiklense bile start* no-op olur.
    zapret_pause
    install_zapret_pause_guard

    /opt/zapret/init.d/sysv/zapret stop-fw >/dev/null 2>&1
    /opt/zapret/init.d/sysv/zapret stop    >/dev/null 2>&1

    killall nfqws >/dev/null 2>&1
    killall -9 nfqws >/dev/null 2>&1

    # Her ihtimale karsi kalan NFQUEUE kurallarini da temizle
    flush_all_nfqueue_rules

    sleep 1
    if is_zapret_running; then
        echo "UYARI: nfqws hala calisiyor (otomatik yeniden baslatiliyor olabilir)."
    else
        echo "OK: NFQWS YOK"
    fi

    if iptables-save | grep -q "NFQUEUE"; then
        echo "UYARI: NFQUEUE kurali hala var (otomatik yeniden basiliyor olabilir)."
    else
        echo "OK: NFQUEUE YOK"
    fi

    echo "Zapret durduruldu."
    return 0
}

# Zapret servisini yeniden baslatir (guvenli)
restart_zapret() {
    if ! is_zapret_installed; then
        echo "Zapret yuklu degil. Yeniden baslatma islemi yapilamiyor."
        return 1
    fi
    stop_zapret
    zapret_resume
    start_zapret
}

# --- KURULU VERSIYONU GORUNTULE (6. MADDE) ---
check_zapret_version() {
    if ! is_zapret_installed; then echo "HATA: Zapret yuklu degil."; return 1; fi
    if [ -f "/opt/zapret/version" ]; then
        echo "$(T ver_installed "$TXT_VERSION_INSTALLED_TR" "$TXT_VERSION_INSTALLED_EN")$(cat /opt/zapret/version)"
    else
        echo "Surum dosyasi bulunamadi. Lutfen script ile yeniden kurulum yapin."
    fi
    read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
    clear
}

# --- YENI VERSIYON SORGULA (7. MADDE) ---
check_remote_update() {
    echo "$(T checking_github "$TXT_CHECKING_GITHUB_TR" "$TXT_CHECKING_GITHUB_EN")"
    ZAP_API_URL="https://api.github.com/repos/bol-van/zapret/releases/latest"
    REMOTE_VER=$(curl -s "$ZAP_API_URL" | grep "tag_name" | cut -d '"' -f4)
    
    if [ -z "$REMOTE_VER" ]; then
        echo "$(T github_fail "$TXT_GITHUB_FAIL_TR" "$TXT_GITHUB_FAIL_EN")"
    else
        print_line "-"
        _LBL_LATEST="$(T lbl_latest 'Guncel' 'Latest')"
        _LBL_INSTALLED="$(T lbl_installed 'Kurulu' 'Installed')"
        printf "%-12s: [1;32m%s[0m
" "$_LBL_LATEST" "$REMOTE_VER"
        if [ -f "/opt/zapret/version" ]; then
            LOCAL_VER=$(cat /opt/zapret/version)
            printf "%-12s: [1;33m%s[0m
" "$_LBL_INSTALLED" "$LOCAL_VER"
            print_line "-"
            if [ "$REMOTE_VER" = "$LOCAL_VER" ]; then
                echo "$(T uptodate "$TXT_UPTODATE_TR" "$TXT_UPTODATE_EN")"
            else
                echo "YENI SURUM MEVCUT!"
            fi
        fi
    fi
    read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
    clear
}


# --- ZAPRET IPV6 DURUM KONTROLU ---
check_zapret_ipv6_status() {
    if [ ! -f "/opt/zapret/config" ]; then
        echo "$(T ipv6_status_unknown 'Zapret IPv6 durumu: Bilinmiyor (config yok)' 'Zapret IPv6 status: Unknown (config missing)')"
        return 1
    fi

    if grep -q -- "--dpi-desync-ttl6" /opt/zapret/config 2>/dev/null; then
        echo "${CLR_BOLD}${CLR_GREEN}$(T ipv6_status_on 'Zapret IPv6 destegi: ACIK' 'Zapret IPv6 support: ON')${CLR_RESET}"
    else
        echo "${CLR_BOLD}${CLR_RED}$(T ipv6_status_off 'Zapret IPv6 destegi: KAPALI' 'Zapret IPv6 support: OFF')${CLR_RESET}"
    fi
    return 0
}

# --- ZAPRET IPV6 DESTEGI (8. MADDE) ---
# Not: Bu ayar "router'da IPv6 ac/kapat" degildir.
# Zapret'in kendi kurulum sihirbazindaki "enable ipv6 support" secenegini yonetir.
configure_zapret_ipv6_support() {
    if ! is_zapret_installed; then
        echo "HATA: Zapret yuklu degil. Once kurulum yapin."
        read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
        clear
        return 1
    fi

    echo "$(T ipv6_cfg_title 'Zapret icin IPv6 destegi ayarlanacak.' 'IPv6 support for Zapret will be configured.')"
    echo "$(T ipv6_cfg_desc 'Bu, zapretin IPv6 (ip6tables) tarafinda da kural/yonlendirme kurmasini saglar.' 'This enables Zapret to also set up rules/routing on the IPv6 (ip6tables) side.')"
    check_zapret_ipv6_status
    echo ""
    read -r -p "$(T ipv6_cfg_prompt 'IPv6 destegi etkinlestirilsin mi? (e/h) [h]: ' 'Enable IPv6 support? (y/n) [n]: ')" ans

    IPV6_ANSWER="n"
    case "$ans" in
        [eEyY]) IPV6_ANSWER="y" ;;
        *)    IPV6_ANSWER="n" ;;
    esac

    # Secimi global degiskene yaz (NFQWS_OPT ttl6/ttl icin)
    ZAPRET_IPV6="$IPV6_ANSWER"

# Mevcut IPv6 durumunu algila (config icinden)
CURRENT_IPV6="n"
if [ -f "/opt/zapret/config" ] && grep -q -- "--dpi-desync-ttl6" /opt/zapret/config 2>/dev/null; then
    CURRENT_IPV6="y"
fi

# Kullanici secimi mevcut durumla ayniysa hicbir islem yapma
if [ "$IPV6_ANSWER" = "$CURRENT_IPV6" ]; then
    echo "$(T ipv6_no_change 'Degisiklik yok (IPv6 destegi zaten bu durumda).' 'No change (IPv6 support is already in this state).')"
    read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
    clear
    return 0
fi

echo "Zapret yapilandirma sihirbazi calistiriliyor (IPv6: $IPV6_ANSWER)..."

    # install_easy.sh interaktif bir sihirbazdir. Burada mevcut otomasyon akisini koruyup
    # sadece "enable ipv6 support" sorusunu secilebilir hale getiriyoruz.
    (
        echo "y"    # Sistem uyumluluk uyarisi, dökümani okuyun uyarisi: (evet)
        echo "1"    # Güvenlik duvari tipi seçimi: 1=iptables 2=nftables
        echo "$IPV6_ANSWER"    # IPv6 destegi (hayir)
        echo "1"    # Filtreleme tipi seçimi: 1=none 2=ipset 3=hostlist 4=autohostlist
        echo "n"    # TPWS socks modu etkinlestirilsin mi? (hayir)
        echo "n"    # TPWS transparent etkinlestirilsin mi? (hayir)
        echo "y"    # NFQWS etkinlestirilsin mi? (evet)
        echo "n"    # Yapilandirma düzenlensin mi? (hayir)
        WAN_IFINDEX="$(get_ifindex_by_iface "$(get_wan_if)")"
        [ -z "$WAN_IFINDEX" ] && WAN_IFINDEX="1"
        printf "\033[1;32m[INFO] WAN IFINDEX selected: %s\033[0m\n" "$WAN_IFINDEX" >&2
        echo "WAN_IFINDEX: $WAN_IFINDEX" >&2
        echo "1"    # LAN arayüzü seçimi (1 = none)
        echo "${WAN_IFINDEX:-1}"    # WAN arayüzü seçimi (1 = none)
    ) | /opt/zapret/install_easy.sh &> /dev/null || {
        echo "HATA: Zapret yapilandirma betigi calistirilirken hata olustu."
        read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
        clear
        return 1
    }

    # Bizim Keenetic-ozel dokunuslarimizi tekrar uygula
    fix_keenetic_udp
    update_kernel_module_config
    update_nfqws_parameters
    disable_total_packet
    allow_firewall
    add_auto_start_zapret

    # Keenetic: ensure post-up hook exists and is automatically executed after firewall applies
    create_keenetic_fw_post_up_hook
    patch_zapret_real_to_run_post_hook


    # FW kurallarini ve servisi tazele
    /opt/zapret/init.d/sysv/zapret restart-fw &> /dev/null
    restart_zapret
    /opt/zapret/keenetic_fw_post_up.sh >/dev/null 2>&1
    enforce_wan_if_nfqueue_rules >/dev/null 2>&1

    echo "IPv6 destegi ayari tamamlandi."
    read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
    clear
    return 0
}

# --- ZAPRET ISTEMCI IPSET FILTRELEME (9. MADDE) ---
# Amaç: Zapret'in (NFQUEUE) kuralini sadece belirli LAN istemcilerine uygulamak.
# - "Tum ag": filtre kapali, zapret herkes icin calisir.
# - "Secili IP'ler": sadece girilen IPv4 istemci IP'leri zapret'ten gecer.
IPSET_CLIENT_NAME="zapret_clients"
IPSET_CLIENT_FILE="/opt/zapret/ipset_clients.txt"
IPSET_CLIENT_MODE_FILE="/opt/zapret/ipset_clients_mode"  # all | list
ZAPRET_CLIENT_HOOK="/opt/zapret/init.d/sysv/custom.d/90-keenetic-client-ipset"

write_client_ipset_hook() {
    # Zapret'in custom.d mekanizmasi, start-fw / restart-fw sirasinda bu betikleri calistirir.
    # Bu hook, her FW yenilemesinde iptables NFQUEUE kurallarina ipset match ekler/kaldirir.
    cat > "$ZAPRET_CLIENT_HOOK" <<'EOF'
#!/bin/sh
IPSET_NAME="zapret_clients"
IPSET_FILE="/opt/zapret/ipset_clients.txt"
MODE_FILE="/opt/zapret/ipset_clients_mode"  # all | list
QNUM="200"

command -v iptables >/dev/null 2>&1 || exit 0
command -v ipset >/dev/null 2>&1 || exit 0

MODE="all"
[ -f "$MODE_FILE" ] && MODE="$(cat "$MODE_FILE" 2>/dev/null)"
[ -z "$MODE" ] && MODE="all"

ipset_ensure_and_maybe_sync() {
    ipset list "$IPSET_NAME" >/dev/null 2>&1 || ipset create "$IPSET_NAME" hash:ip 2>/dev/null
    # Eğer dosya varsa "kaynak gerçek" dosyadır -> set'i dosyaya göre senkronla.
    if [ -f "$IPSET_FILE" ]; then
        ipset flush "$IPSET_NAME" >/dev/null 2>&1
        tr ' \t,;\r\n' '\n' < "$IPSET_FILE" | awk 'NF{print $0}' | while read -r ip; do
            ipset add "$IPSET_NAME" "$ip" -exist >/dev/null 2>&1
        done
    fi
}

# Belirli chain'de NFQUEUE kural(lar)ını güvenli biçimde sil
del_nfqueue_chain() {
    local table="$1" chain="$2" grep_pat="$3"
    if [ -n "$table" ]; then
        iptables -t "$table" -S "$chain" 2>/dev/null | grep -F "NFQUEUE" | grep -F -- "$grep_pat" | while read -r rule; do
            iptables -t "$table" $(echo "$rule" | sed 's/^-A /-D /') >/dev/null 2>&1
        done
    else
        iptables -S "$chain" 2>/dev/null | grep -F "NFQUEUE" | grep -F -- "$grep_pat" | while read -r rule; do
            iptables $(echo "$rule" | sed 's/^-A /-D /') >/dev/null 2>&1
        done
    fi
}

# İpSet'e bağlı NFQUEUE kurallarını ekle (üstten insert)
add_ipset_rules() {
    # Keenetic'te bazen default route satiri "default dev ppp0 scope link" seklinde gelir.
    # Bu yuzden arayuzu, "dev" alanini bularak cekiyoruz.
    WAN="$(ip route 2>/dev/null | awk '/^default/ {for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"

    iptables -t mangle -I POSTROUTING 1 ${WAN:+-o $WAN} -p tcp -m multiport --dports 80,443 \
        -m set --match-set "$IPSET_NAME" src \
        -j NFQUEUE --queue-num "$QNUM" --queue-bypass >/dev/null 2>&1

    iptables -t mangle -I POSTROUTING 1 ${WAN:+-o $WAN} -p udp -m multiport --dports 443 \
        -m set --match-set "$IPSET_NAME" src \
        -j NFQUEUE --queue-num "$QNUM" --queue-bypass >/dev/null 2>&1
}

# Genel NFQUEUE (qnum 200) kurallarını temizle
del_general_nfqueue_qnum200() {
    del_nfqueue_chain mangle POSTROUTING "--queue-num $QNUM"
    del_nfqueue_chain "" INPUT "--queue-num $QNUM"
    del_nfqueue_chain "" FORWARD "--queue-num $QNUM"
}

# Sadece ipset'e bağlı kuralları temizle (match-set zapret_clients)
del_ipset_nfqueue_rules() {
    del_nfqueue_chain mangle POSTROUTING "match-set $IPSET_NAME"
    del_nfqueue_chain "" INPUT "match-set $IPSET_NAME"
    del_nfqueue_chain "" FORWARD "match-set $IPSET_NAME"
}

if [ "$MODE" = "list" ]; then
    # LIST mod: tüm ağ etkilenmesin diye genel NFQUEUE'leri kaldır, sadece IPSET kurallarını bırak.
    del_general_nfqueue_qnum200
    ipset_ensure_and_maybe_sync
    add_ipset_rules
else
    # ALL mod: IPSET'e bağlı özel kurallar varsa kaldır, genel kurallar kalsın.
    del_ipset_nfqueue_rules
fi

exit 0
EOF

    chmod +x "$ZAPRET_CLIENT_HOOK" 2>/dev/null
    return 0
}

show_ipset_client_status() {
    MODE="all"
    [ -f "$IPSET_CLIENT_MODE_FILE" ] && MODE="$(cat "$IPSET_CLIENT_MODE_FILE" 2>/dev/null)"
    [ -z "$MODE" ] && MODE="all"

    if [ "$MODE" = "list" ]; then
        print_line "="
        printf '%b%s%b\n' "${CLR_CYAN}${CLR_BOLD}" "$(T ipset_mode_list "$TXT_IPSET_MODE_LIST_TR" "$TXT_IPSET_MODE_LIST_EN")" "${CLR_RESET}"
        print_line "="
        echo ""
        
        # IP Listesi Dosyası
        printf '%b%-25s:%b ' "${CLR_YELLOW}${CLR_BOLD}" "$(T ip_list_file "$TXT_IP_LIST_FILE_TR" "$TXT_IP_LIST_FILE_EN")" "${CLR_RESET}"
        if [ -f "$IPSET_CLIENT_FILE" ] && [ -s "$IPSET_CLIENT_FILE" ]; then
            local ip_count="$(wc -l < "$IPSET_CLIENT_FILE" 2>/dev/null | tr -d ' ')"
            printf '%b%d IP%b\n' "${CLR_GREEN}" "$ip_count" "${CLR_RESET}"
            echo ""
            printf '%b%s%b\n' "${CLR_DIM}" "$(T ip_list_file "$TXT_IP_LIST_FILE_TR" "$TXT_IP_LIST_FILE_EN"):" "${CLR_RESET}"
            # awk ile numaralandırma - daha güvenli
            awk -v cyan="${CLR_CYAN}" -v reset="${CLR_RESET}" '
                NF > 0 {
                    printf "  %s%2d.%s %s\n", cyan, NR, reset, $0
                }' "$IPSET_CLIENT_FILE"
        else
            printf '%b%s%b\n' "${CLR_RED}" "$(T empty "$TXT_EMPTY_TR" "$TXT_EMPTY_EN")" "${CLR_RESET}"
        fi
        
        echo ""
        print_line "-"
        
        # IPSET Üyeleri
        printf '%b%-25s:%b ' "${CLR_YELLOW}${CLR_BOLD}" "$(T ipset_members "$TXT_IPSET_MEMBERS_TR" "$TXT_IPSET_MEMBERS_EN")" "${CLR_RESET}"
        local ipset_members="$(ipset list "$IPSET_CLIENT_NAME" 2>/dev/null | sed -n '/^Members:/,$p' | tail -n +2)"
        if [ -n "$ipset_members" ]; then
            local member_count="$(echo "$ipset_members" | wc -l | tr -d ' ')"
            printf '%b%d IP%b\n' "${CLR_GREEN}" "$member_count" "${CLR_RESET}"
            echo ""
            printf '%b%s%b\n' "${CLR_DIM}" "$(T ipset_members "$TXT_IPSET_MEMBERS_TR" "$TXT_IPSET_MEMBERS_EN"):" "${CLR_RESET}"
            # awk ile numaralandırma - subshell problemi yok
            printf '%s\n' "$ipset_members" | awk -v cyan="${CLR_CYAN}" -v reset="${CLR_RESET}" '
                NF > 0 {
                    printf "  %s%2d.%s %s\n", cyan, NR, reset, $0
                }'
        else
            printf '%b%s%b\n' "${CLR_RED}" "$(T empty "$TXT_EMPTY_TR" "$TXT_EMPTY_EN")" "${CLR_RESET}"
        fi
        
        print_line "="
    else
        print_line "="
        printf '%b%s%b\n' "${CLR_CYAN}${CLR_BOLD}" "$(T ipset_mode_all "$TXT_IPSET_MODE_ALL_TR" "$TXT_IPSET_MODE_ALL_EN")" "${CLR_RESET}"
        print_line "="
        echo ""
        printf '%b%s%b\n' "${CLR_GREEN}" "$(T ipset_all_network "$TXT_IPSET_ALL_NETWORK_TR" "$TXT_IPSET_ALL_NETWORK_EN")" "${CLR_RESET}"
        print_line "="
    fi
}

apply_ipset_client_settings() {
    write_client_ipset_hook >/dev/null 2>&1

    if [ -x "/opt/zapret/init.d/sysv/zapret" ]; then
        # restart-fw yerine stop-fw + start-fw (daha deterministik)
        /opt/zapret/init.d/sysv/zapret stop-fw >/dev/null 2>&1
        /opt/zapret/init.d/sysv/zapret start-fw >/dev/null 2>&1

        # MODE all/list durumunu kesin uygula
        enforce_client_mode_rules >/dev/null 2>&1

        # nfqws yoksa daemonu da baslat
        if ! is_zapret_running; then
            /opt/zapret/init.d/sysv/zapret start >/dev/null 2>&1
        fi
    fi
    return 0
}

manage_ipset_clients() {
    if ! is_zapret_installed; then
        echo "HATA: Zapret yuklu degil. Once kurulum yapin."
        read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
        clear
        return 1
    fi

    while true; do
        print_line "-"
        echo "$(T TXT_IPSET_TITLE)"
        print_line "-"
        MODE="$(cat "$IPSET_CLIENT_MODE_FILE" 2>/dev/null)"
        [ -z "$MODE" ] && MODE="all"

        if [ "$MODE" = "list" ]; then
            printf '\033[1;33m%s\033[0m\n' "$(T ipset_mode 'Mod: Secili IP' 'Mode: Selected IPs')"
        else
            printf '\033[1;32m%s\033[0m\n' "$(T ipset_mode 'Mod: Tum ag' 'Mode: Whole network')"
        fi


        echo "$(T TXT_IPSET_1)"
        echo "$(T TXT_IPSET_2)"
        if [ "$MODE" = "list" ]; then
            echo "$(T TXT_IPSET_3)"
            echo "$(T TXT_IPSET_4)"
            echo "$(T TXT_IPSET_5)"
            echo "$(T TXT_IPSET_0)"
            print_line "-"
            printf "$(T TXT_PROMPT_IPSET)"
        else
            echo "$(T TXT_IPSET_0)"
            print_line "-"
            printf "$(T TXT_PROMPT_IPSET_BASIC)"
        fi
        read -r ipset_choice
        echo ""

        case "$ipset_choice" in
            1)
                echo "all" > "$IPSET_CLIENT_MODE_FILE"
                rm -f "$IPSET_CLIENT_FILE" 2>/dev/null
                apply_ipset_client_settings
                echo "Tamam: Zapret tum ag icin calisacak."
                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                clear
                ;;
            2)
                echo "Ornek: 192.168.1.10 192.168.1.20 (bosluk/virgul ile ayirabilirsiniz)"
                read -r -p "IP'leri girin (Enter=iptal): " ips

                if [ -z "$ips" ]; then
                    echo "$(T ipset_cancelled 'Iptal edildi. Degisiklik yapilmadi.' 'Cancelled. No changes made.')"
                else
                    tmp_ips="/tmp/ipset_clients.$$"
                    echo "$ips" | tr ',;' '  ' | tr ' ' '\n' | sed '/^$/d' > "$tmp_ips"

                    if [ ! -s "$tmp_ips" ]; then
                        rm -f "$tmp_ips" 2>/dev/null
                        echo "$(T ipset_invalid 'Gecersiz IP listesi. Degisiklik yapilmadi.' 'Invalid IP list. No changes made.')"
                    else
                        mv "$tmp_ips" "$IPSET_CLIENT_FILE" 2>/dev/null
                        echo "list" > "$IPSET_CLIENT_MODE_FILE" 2>/dev/null

                        apply_ipset_client_settings
                        echo "Tamam: Zapret sadece bu IP'lere uygulanacak."
                    fi
                fi

                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                clear
                ;;
            3)
                if [ "$MODE" = "list" ]; then
                    show_ipset_client_status
                else
                    echo "IP listesi sadece Secili IP'lere Uygula (mode=list) aktifken gosterilir."
                    show_ipset_client_status
                fi
                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                clear
                ;;

        4)
                MODE="$(cat "$IPSET_CLIENT_MODE_FILE" 2>/dev/null)"
                [ -z "$MODE" ] && MODE="all"
                if [ "$MODE" != "list" ]; then
                    echo "Bu menu sadece \"Secili IP'lere Uygula\" (mod=list) acikken kullanilabilir. Once 2'yi secin."
                else
                read -r -p "$(T add_ip_prompt "$TXT_ADD_IP_TR" "$TXT_ADD_IP_EN")" oneip
                if [ -z "$oneip" ]; then
                    echo "$(T cancelled "Islem iptal edildi." "Cancelled.")"
                    read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                    clear
                    continue
                fi
                # Basit IPv4 dogrulama
                echo "$oneip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || { echo "Gecersiz IP!"; }
                if echo "$oneip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
                    touch "$IPSET_CLIENT_FILE" 2>/dev/null
                    grep -Fqx "$oneip" "$IPSET_CLIENT_FILE" 2>/dev/null || echo "$oneip" >> "$IPSET_CLIENT_FILE"
                    apply_ipset_client_settings
                    echo "Tamam: IP eklendi."
                fi
                fi
                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                clear
                ;;

            5)
                MODE="$(cat "$IPSET_CLIENT_MODE_FILE" 2>/dev/null)"
                [ -z "$MODE" ] && MODE="all"
                if [ "$MODE" != "list" ]; then
                    echo "Bu menu sadece \"Secili IP'lere Uygula\" (mod=list) acikken kullanilabilir. Once 2'yi secin."
                else
                read -r -p "$(T del_ip_prompt "$TXT_DEL_IP_TR" "$TXT_DEL_IP_EN")" oneip
                if [ -z "$oneip" ]; then
                    echo "$(T cancelled "Islem iptal edildi." "Cancelled.")"
                    read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                    clear
                    continue
                fi
                if [ -f "$IPSET_CLIENT_FILE" ]; then
                    tmpf="/tmp/ipset_clients.$$"
                    grep -Fvx "$oneip" "$IPSET_CLIENT_FILE" > "$tmpf" 2>/dev/null && mv "$tmpf" "$IPSET_CLIENT_FILE"
                    apply_ipset_client_settings
                    echo "Tamam: IP silindi."
                else
                    echo "IP listesi dosyasi yok."
                fi
                fi
                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                clear
                ;;
            0)
                echo "Ana menuye donuluyor..."
                break
                ;;
            *)
                echo "$(T invalid_main 'Gecersiz secim! Lutfen 0 ile 11 arasinda bir sayi veya L girin.' 'Invalid choice! Please enter a number between 0 and 11 or L.')"
                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                clear
                ;;
        esac
        echo ""
    done

    return 0
}

# Kurulumdan sonra gereksiz dosyalari temizler
cleanup_files_after_extracted() {
    echo "Indirilen Zapret arsivi ve gereksiz binary dosyalari siliniyor..."

    for file in \
        /opt/zapret/binaries/mac64 \
        /opt/zapret/binaries/linux-ppc \
        /opt/zapret/binaries/linux-lexra \
        /opt/zapret/binaries/linux-x86 \
        /opt/zapret/binaries/linux-x86_64 \
        /opt/zapret/binaries/freebsd-x86_64 \
        /opt/zapret/binaries/android-arm \
        /opt/zapret/binaries/android-arm64 \
        /opt/zapret/binaries/android-x86 \
        /opt/zapret/binaries/android-x86_64 \
        /opt/zapret/binaries/windows-x86 \
        /opt/zapret/binaries/windows-x86_64 \
        /opt/tmp/zapret-*.tar.gz
    do
        [ -e "$file" ] && rm -rf "$file"
    done

    echo "Indirilen Zapret arsivi ve gereksiz binary dosyalari silindi."
}

# Kaldirma sirasinda kalan iptables/ipset kalintilarini temizler (zapret kaldirildiktan sonra bile kural kalabiliyor)
cleanup_zapret_firewall_leftovers() {
    command -v iptables >/dev/null 2>&1 || return 0
    local Q="200"

    _del_nfqueue_lines() {
        local table="$1" chain="$2" ln
        while true; do
            if [ -n "$table" ]; then
                ln="$(iptables -t "$table" -L "$chain" -n --line-numbers 2>/dev/null \
                    | grep -E "NFQUEUE" | grep -E "num $Q|queue-num $Q" | head -n 1 | awk '{print $1}')"
                [ -n "$ln" ] || break
                iptables -t "$table" -D "$chain" "$ln" 2>/dev/null
            else
                ln="$(iptables -L "$chain" -n --line-numbers 2>/dev/null \
                    | grep -E "NFQUEUE" | grep -E "num $Q|queue-num $Q" | head -n 1 | awk '{print $1}')"
                [ -n "$ln" ] || break
                iptables -D "$chain" "$ln" 2>/dev/null
            fi
        done
    }

    # mangle
    for c in PREROUTING INPUT FORWARD OUTPUT POSTROUTING; do
        _del_nfqueue_lines mangle "$c"
    done

    # filter
    for c in INPUT FORWARD OUTPUT; do
        _del_nfqueue_lines "" "$c"
    done

    # ipset kalintilari
    if command -v ipset >/dev/null 2>&1; then
        for s in zapret_clients nozapret ipban; do
            ipset list "$s" >/dev/null 2>&1 && ipset flush "$s" >/dev/null 2>&1
            ipset list "$s" >/dev/null 2>&1 && ipset destroy "$s" >/dev/null 2>&1
        done
    fi

    # netfilter hook kalintilari (disabled dosyalar dahil)
rm -f /opt/etc/ndm/netfilter.d/000-zapret.sh           /opt/etc/ndm/netfilter.d/000-zapret.sh.disabled           /opt/etc/ndm/netfilter.d/001-zapret-force-nfqueue.sh           /opt/etc/ndm/netfilter.d/001-zapret-force-nfqueue.sh.disabled           /opt/etc/ndm/netfilter.d/001-zapret-force-nfqueue.sh.disabled.disabled           /opt/etc/ndm/netfilter.d/001-zapret-ipset.sh           /opt/etc/ndm/netfilter.d/001-zapret-ipset.sh.disabled           /opt/etc/ndm/netfilter.d/001-zapret-ipset.sh.disabled.disabled 2>/dev/null

# autostart linkleri (varsa)
rm -f /opt/etc/init.d/S90-zapret /opt/etc/init.d/S00fix 2>/dev/null

rm -f /tmp/.zapret_paused 2>/dev/null
return 0
}

# Kaldirmadan sonra kalan dosyalari temizler

# --- UNINSTALL KALINTI TEMIZLIGI: NFQUEUE (qnum 200) ---
remove_nfqueue_rules_200() {
    command -v iptables >/dev/null 2>&1 || return 0

    # mangle
    for c in PREROUTING INPUT FORWARD OUTPUT POSTROUTING; do
        while true; do
            ln="$(iptables -t mangle -L "$c" -n --line-numbers 2>/dev/null | sed -n "s/^ *\\([0-9]\\+\\) .*NFQUEUE num 200 .*/\\1/p" | head -n 1)"
            [ -n "$ln" ] || break
            iptables -t mangle -D "$c" "$ln" 2>/dev/null
        done
    done

    # filter
    for c in INPUT FORWARD OUTPUT; do
        while true; do
            ln="$(iptables -L "$c" -n --line-numbers 2>/dev/null | sed -n "s/^ *\\([0-9]\\+\\) .*NFQUEUE num 200 .*/\\1/p" | head -n 1)"
            [ -n "$ln" ] || break
            iptables -D "$c" "$ln" 2>/dev/null
        done
    done
}

cleanup_files_after_uninstall() {
    cleanup_zapret_firewall_leftovers
    rm -rf /opt/zapret \
           /opt/etc/init.d/S00fix \
           /opt/etc/init.d/S90-zapret \
           /opt/etc/ndm/netfilter.d/000-zapret.sh &>/dev/null  
    return 0
}


# Zapret kurulu olmasa bile (kaldirmadan sonra) NFQUEUE/IPSET kalintilarini temizler
cleanup_only_leftovers() {
    print_line "-"
    echo " Kalinti Temizligi (Zapret olmasa da calisir)"
    print_line "-"
    echo "Bu islem, NFQUEUE (qnum 200) iptables kurallarini ve zapret'e ait ipset/netfilter kalintilarini temizler."
    read -r -p "Devam edilsin mi? (e/h): " _c
    echo "$_c" | grep -qi '^e' || { echo "Iptal edildi."; return 0; }

    cleanup_zapret_firewall_leftovers
    remove_nfqueue_rules_200

    # ipset mod dosyalari (opsiyonel)
    rm -f /opt/zapret/ipset_clients_mode /opt/zapret/ipset_clients.txt /opt/zapret/wan_if 2>/dev/null

    echo "Kalinti temizligi tamamlandi."
    read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
    clear
    return 0
}


# Zapret'i kaldirir
uninstall_zapret() {

if ! is_zapret_installed; then
        echo "Zapret yuklu degil. Kaldirma islemi yapilamaz."
        echo ""
        echo "Ama NFQUEUE/IPSET gibi kalintilar kalmis olabilir."
        read -r -p "Kalintilari temizlemek ister misiniz? (e/h): " _cc
        if echo "$_cc" | grep -qi '^e'; then
            cleanup_zapret_firewall_leftovers
            remove_nfqueue_rules_200
            echo "Kalintilar temizlendi."
        else
            echo "Iptal edildi."
        fi
        read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
        clear
        return 0
    fi

    read -r -p "Zapret'i kaldirmak istediginizden emin misiniz? (e/h): " uninstall_confirmation
    [[ ! "$uninstall_confirmation" =~ ^[eE]$ ]] && { echo "Zapret'i kaldirma islemi iptal edildi."; return 0; }

    is_zapret_running && stop_zapret

    cleanup_zapret_firewall_leftovers

    echo "Zapret kaldiriliyor..."

    if ! echo "y" | /opt/zapret/uninstall_easy.sh &> /dev/null; then
        read -r -p "Zapret kaldirma betigi bulunamadi veya calistirilamadi.
Kendi aracimiz tarafindan kaldirilmasini ister misiniz? (e/h): " manual_cleanup_confirmation
        
        if [[ "$manual_cleanup_confirmation" =~ ^[eE]$ ]]; then
            echo "Kendi kaldirma aracimiz calistiriliyor..."
            cleanup_files_after_uninstall
            return 0 
        else
            echo "Zapret'i kaldirma islemi iptal edildi."
            return 1 
        fi
    fi

    cleanup_files_after_uninstall

    echo "Zapret basariyla kaldirildi."
	read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
	clear 
    return 0
}

# Zapret'i kurar
install_zapret() {
    is_zapret_installed && echo "Zapret zaten yuklu." && return 1

    echo "OPKG paketleri denetleniyor, eksik olan varsa indirilip kurulacaktir..."
    opkg update >/dev/null 2>&1
    opkg install coreutils-sort curl grep gzip ipset iptables kmod_ndms xtables-addons_legacy >/dev/null 2>&1 || \
    { echo "HATA: Gerekli paketler yuklenemedi veya guncellenemedi."; return 1; }
    
    echo "Zapret yukleniyor..."

    ZAPRET_API_URL="https://api.github.com/repos/bol-van/zapret/releases/latest"
    ZAP_DATA=$(curl -s "$ZAPRET_API_URL")
    ZAPRET_ARCHIVE_URL=$(echo "$ZAP_DATA" | grep "browser_download_url.*tar.gz" | head -n1 | cut -d '"' -f4)
    ZAPRET_VER=$(echo "$ZAP_DATA" | grep "tag_name" | cut -d '"' -f4)
    ZAPRET_ARCHIVE_NAME=$(basename "$ZAPRET_ARCHIVE_URL")
    ARCHIVE="/opt/tmp/$ZAPRET_ARCHIVE_NAME"
    DIR="/opt/zapret"

    if [ -z "$ZAPRET_ARCHIVE_URL" ]; then
        echo "HATA: Zapret'in en guncel surumu alinamadi."
        return 1
    fi

    curl -L -o "$ARCHIVE" "$ZAPRET_ARCHIVE_URL" >/dev/null 2>&1 || { echo "HATA: Arsiv indirilemedi."; return 1; }
    rm -rf "$DIR"
    mkdir -p /opt/tmp
    tar -xzf "$ARCHIVE" -C /opt/tmp >/dev/null 2>&1 || { echo "HATA: Arsiv acilamadi."; return 1; }
    EXTRACTED_DIR=$(tar -tzf "$ARCHIVE" | head -1 | cut -f1 -d"/")
    mv "/opt/tmp/$EXTRACTED_DIR" "$DIR" || { echo "HATA: Dosya tasinamadi."; return 1; }

    # Surum bilgisini kaydet
    echo "$ZAPRET_VER" > /opt/zapret/version

    echo "Zapret basariyla yuklendi."

    cleanup_files_after_extracted

    keenetic_compatibility || echo "UYARI: Keenetic uyumlulugu ayarlanirken bir sorun olustu."

printf "\033[1;32mZapret icin IPv6 destegi etkinlestirilsin mi? (e/h):\033[0m "
read -r ipv6_ans
    if echo "$ipv6_ans" | grep -qi "^e"; then
        ZAPRET_IPV6="y"
    else
        ZAPRET_IPV6="n"
    fi

    echo "Zapret yapilandirma betigi calistiriliyor..."

    IPV6_ANSWER="$ZAPRET_IPV6"


    # WAN arayuzunu belirle (WireGuard sorunlarini azaltmak icin)
    select_wan_if
    (
        echo "y"    # Sistem uyumluluk uyarisi, dökümani okuyun uyarisi: (evet)
        echo "1"    # Güvenlik duvari tipi seçimi: 1=iptables 2=nftables
        echo "$IPV6_ANSWER"    # IPv6 destegi (hayir)
        echo "1"    # Filtreleme tipi seçimi: 1=none 2=ipset 3=hostlist 4=autohostlist
        echo "n"    # TPWS socks modu etkinlestirilsin mi? (hayir)
        echo "n"    # TPWS transparent etkinlestirilsin mi? (hayir)
        echo "y"    # NFQWS etkinlestirilsin mi? (evet)
        echo "n"    # Yapilandirma düzenlensin mi? (hayir)
        WAN_IFINDEX="$(get_ifindex_by_iface "$(get_wan_if)")"
        [ -z "$WAN_IFINDEX" ] && WAN_IFINDEX="1"
        printf "\033[1;32m[INFO] WAN IFINDEX selected: %s\033[0m\n" "$WAN_IFINDEX" >&2
        echo "WAN_IFINDEX: $WAN_IFINDEX" >&2
        echo "1"    # LAN arayüzü seçimi (1 = none)
        echo "${WAN_IFINDEX:-1}"    # WAN arayüzü seçimi (1 = none)   
    ) | /opt/zapret/install_easy.sh &> /dev/null || \
    { echo "HATA: Zapret yapilandirma betigi calistirilirken hata olustu."; return 1; }
    
    echo "Zapret'in Keenetic cihazlarda calisabilmesi icin gerekli yapilandirmalar yapiliyor..."

    fix_keenetic_udp
    update_kernel_module_config
    update_nfqws_parameters
    disable_total_packet
    allow_firewall
    add_auto_start_zapret

    echo "Zapret basariyla kuruldu ve yapilandirildi."

    sync_zapret_iface_wan_config
    restart_zapret
    cleanup_nfqueue_rules_except_selected_wan
    read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
	clear 
    return 0 
}


# --- Betik (Manager) Surum Kontrolu (GitHub Releases) ---
get_manager_latest_version() {
    # GitHub API: releases/latest -> tag_name
    # curl yoksa wget denenir
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "https://api.github.com/repos/RevolutionTR/keenetic-zapret-manager/releases/latest" 2>/dev/null \
        | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        | head -n 1
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "https://api.github.com/repos/RevolutionTR/keenetic-zapret-manager/releases/latest" 2>/dev/null \
        | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        | head -n 1
    else
        echo ""
    fi
}


# --- Version compare helper (returns 0 if $1 > $2) ---
ver_is_newer() {
    # usage: ver_is_newer "v26.1.24.2" "v26.1.24"
    _va="${1#v}"; _vb="${2#v}"
    # replace non-digit/dot just in case
    _va="$(echo "$_va" | tr -cd '0-9.')"
    _vb="$(echo "$_vb" | tr -cd '0-9.')"
    set -- $(echo "$_va" | tr '.' ' ')
    _a1=${1:-0}; _a2=${2:-0}; _a3=${3:-0}; _a4=${4:-0}
    set -- $(echo "$_vb" | tr '.' ' ')
    _b1=${1:-0}; _b2=${2:-0}; _b3=${3:-0}; _b4=${4:-0}
    [ "$_a1" -gt "$_b1" ] && return 0
    [ "$_a1" -lt "$_b1" ] && return 1
    [ "$_a2" -gt "$_b2" ] && return 0
    [ "$_a2" -lt "$_b2" ] && return 1
    [ "$_a3" -gt "$_b3" ] && return 0
    [ "$_a3" -lt "$_b3" ] && return 1
    [ "$_a4" -gt "$_b4" ] && return 0
    return 1
}

download_file() {
    # usage: download_file URL OUTFILE
    _url="$1"; _out="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -L -s -o "$_out" "$_url" && [ -s "$_out" ] && return 0
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$_out" "$_url" && [ -s "$_out" ] && return 0
    fi
    return 1
}

update_manager_script() {
    TARGET_SCRIPT="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh"
    DL_URL="https://github.com/RevolutionTR/keenetic-zapret-manager/releases/latest/download/keenetic_zapret_otomasyon_ipv6_ipset.sh"
    TMP_FILE="/tmp/keenetic_zapret_manager_update.$$"
    BACKUP_FILE="${TARGET_SCRIPT}.bak_${SCRIPT_VERSION#v}_$(date +%Y%m%d_%H%M%S 2>/dev/null).sh"

    echo "$(T mgr_update_start 'Betik indiriliyor (GitHub)...' 'Downloading script (GitHub)...')"
    if ! download_file "$DL_URL" "$TMP_FILE"; then
        echo "$(T mgr_update_dl_fail 'Indirme basarisiz (curl/wget/SSL kontrol edin).' 'Download failed (check curl/wget/SSL).')"
        rm -f "$TMP_FILE" 2>/dev/null
        return 1
    fi

    # Basic sanity: should look like a shell script and include expected markers
    if ! grep -q "SCRIPT_VERSION" "$TMP_FILE" 2>/dev/null; then
        echo "$(T mgr_update_bad 'Indirilen dosya beklenen formatta degil, iptal edildi.' 'Downloaded file is not in expected format, aborting.')"
        rm -f "$TMP_FILE" 2>/dev/null
        return 1
    fi

    # Syntax check (best-effort)
    if sh -n "$TMP_FILE" >/dev/null 2>&1; then
        :
    else
        echo "$(T mgr_update_syntax 'Indirilen dosyada syntax hatasi var, iptal edildi.' 'Downloaded file has syntax errors, aborting.')"
        rm -f "$TMP_FILE" 2>/dev/null
        return 1
    fi

    # Backup current script if present
    if [ -f "$TARGET_SCRIPT" ]; then
        cp -f "$TARGET_SCRIPT" "$BACKUP_FILE" 2>/dev/null
        echo "$(T mgr_update_backup 'Yedek alindi:' 'Backup created:') $BACKUP_FILE"
    fi

    # Replace
    cp -f "$TMP_FILE" "$TARGET_SCRIPT" 2>/dev/null && chmod +x "$TARGET_SCRIPT" 2>/dev/null
    rm -f "$TMP_FILE" 2>/dev/null

    echo "$(T mgr_update_done 'Guncelleme tamamlandi. Lutfen betigi yeniden calistirin.' 'Update completed. Please re-run the script.')"
    return 0
}


check_manager_update() {
    echo "$(T checking_github "$TXT_CHECKING_GITHUB_TR" "$TXT_CHECKING_GITHUB_EN")"
    MANAGER_API_URL="https://api.github.com/repos/RevolutionTR/keenetic-zapret-manager/releases/latest"

    # Yerel (kurulu) betik surumu + GitHub tag_name cek
    REMOTE_VER=$(curl -s "$MANAGER_API_URL" | grep "tag_name" | cut -d '"' -f4)

    print_line "-"
    _LBL_SCRIPT="$(T lbl_script_ver 'Kurulu Betik Surumu' 'Installed Script Version')"
    _LBL_GH="$(T lbl_gh_ver 'GitHub Guncel Surum' 'GitHub Latest Version')"
    _LBL_REPO="$(T lbl_repo 'Repo' 'Repository')"

    # Kurulu betik surumu (sari)
    printf "%-26s: \033[1;33m%s\033[0m\n" "$_LBL_SCRIPT" "$SCRIPT_VERSION"

    if [ -z "$REMOTE_VER" ]; then
        # Bilgi alinamadi (kirmizi)
        printf "%-26s: \033[1;31m%s\033[0m\n" "$_LBL_GH" "$(T github_noinfo 'Bilgi alinamadi' 'Unable to fetch info')"
    else
        # GitHub surumu (yesil)
        printf "%-26s: \033[1;32m%s\033[0m\n" "$_LBL_GH" "$REMOTE_VER"
    fi

    # Repo (renksiz)
    printf "%-26s: %s\n" "$_LBL_REPO" "$SCRIPT_REPO"
    print_line "-"

    if [ -n "$REMOTE_VER" ]; then
        if [ "${SCRIPT_VERSION#v}" = "${REMOTE_VER#v}" ]; then
            echo "$(T uptodate "$TXT_UPTODATE_TR" "$TXT_UPTODATE_EN")"
        else
            if ver_is_newer "$REMOTE_VER" "$SCRIPT_VERSION"; then
                echo "$(T new_version 'YENI SURUM MEVCUT!' 'NEW VERSION AVAILABLE!')"
                _ASK_UPD="$(T mgr_ask 'Guncellemek ister misiniz? (e/h): ' 'Update now? (y/n): ')"
                read -r -p "$_ASK_UPD" _ans
                case "$_ans" in
                    e|E|y|Y)
                        update_manager_script
                        ;;
                    *) ;;
                esac
            else
                # Local is newer or different; treat as up-to-date
                echo "$(T uptodate "$TXT_UPTODATE_TR" "$TXT_UPTODATE_EN")"
            fi
        fi
    fi

    if type press_enter_to_continue >/dev/null 2>&1; then
        press_enter_to_continue
    else
        read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")" _tmp
    fi
    clear
}



# --- Ana Menu Fonksiyonu ---
# -------------------------------------------------------------------
# Hostlist / Autohostlist (MODE_FILTER) Yonetimi
# -------------------------------------------------------------------
HOSTLIST_DIR="/opt/zapret/ipset"
HOSTLIST_USER="${HOSTLIST_DIR}/zapret-hosts-user.txt"
HOSTLIST_EXCLUDE_DOM="${HOSTLIST_DIR}/zapret-hosts-user-exclude.txt"
HOSTLIST_EXCLUDE_IP="${HOSTLIST_DIR}/zapret-hosts-localnets.txt"
HOSTLIST_AUTO="${HOSTLIST_DIR}/zapret-hosts-auto.txt"
HOSTLIST_MODE_FILE="/opt/zapret/hostlist_mode"
HOSTLIST_AUTO_DEBUG="/opt/zapret/nfqws_autohostlist.log"
SCOPE_MODE_FILE="/opt/zapret/scope_mode"

ensure_hostlist_files() {
    [ -d "$HOSTLIST_DIR" ] || mkdir -p "$HOSTLIST_DIR" >/dev/null 2>&1
    [ -f "$HOSTLIST_USER" ] || : > "$HOSTLIST_USER"
        # IP/localnets exclude (legacy/compat)
    if [ ! -f "$HOSTLIST_EXCLUDE_IP" ]; then
        cat > "$HOSTLIST_EXCLUDE_IP" <<'EOF'
127.0.0.0/8
10.0.0.0/8
172.16.0.0/12
192.168.0.0/16
169.254.0.0/16
100.64.0.0/10
::1
fc00::/7
fe80::/10
EOF
    fi
    # Domain exclude (our menu manages this)
    [ -f "$HOSTLIST_EXCLUDE_DOM" ] || : > "$HOSTLIST_EXCLUDE_DOM"
    # AUTO dosyasi zapret tarafindan doldurulur; yoksa gosterebilmek icin olusturuyoruz
    [ -f "$HOSTLIST_AUTO" ] || : > "$HOSTLIST_AUTO"
}


ensure_zapret_config() {
    # zapret upstream expects /opt/zapret/config (optional). If missing, try to create it.
    if [ -f /opt/zapret/config ]; then
        return 0
    fi
    if [ -f /opt/zapret/config.default ]; then
        cp -f /opt/zapret/config.default /opt/zapret/config >/dev/null 2>&1 && return 0
    fi
    # minimal safe config (only what we touch)
    cat > /opt/zapret/config <<'EOF'
# this file is included from init scripts
# change values here

# filtering mode : none|ipset|hostlist|autohostlist
MODE_FILTER=none

# use <HOSTLIST> and <HOSTLIST_NOAUTO> placeholders to engage standard hostlists and autohostlist in ipset dir
# hostlist markers are replaced to empty string if MODE_FILTER does not satisfy
# <HOSTLIST_NOAUTO> appends ipset/zapret-hosts-auto.txt as normal list

# nfqws options (filled/updated by management script)
NFQWS_OPT=""
EOF
    [ -f /opt/zapret/config ]
}

get_scope_mode() {
    # global|smart (default: global)
    if [ -f "$SCOPE_MODE_FILE" ]; then
        sm="$(head -n1 "$SCOPE_MODE_FILE" 2>/dev/null | tr -d '\r\n' | tr 'A-Z' 'a-z')"
        case "$sm" in
            global|smart) echo "$sm"; return 0 ;;
        esac
    fi
    echo "global"
}

pretty_scope_mode() {
    # UI helper: keep stored values (global/smart) but show localized label
    case "$(get_scope_mode)" in
        global) echo "$(T TXT_SCOPE_GLOBAL)" ;;
        smart)  echo "$(T TXT_SCOPE_SMART)" ;;
        *)      echo "$(get_scope_mode)" ;;
    esac
}


set_scope_mode() {
    # $1: global|smart
    [ -z "$1" ] && return 1
    case "$1" in
        global|smart) ;;
        *) return 1 ;;
    esac
    echo "$1" > "$SCOPE_MODE_FILE" 2>/dev/null || return 1
    return 0
}

get_mode_filter() {
    # priority: state file -> zapret config -> default none
    if [ -f "$HOSTLIST_MODE_FILE" ]; then
        mf="$(head -n1 "$HOSTLIST_MODE_FILE" 2>/dev/null | tr -d '\r\n' | tr 'A-Z' 'a-z')"
        case "$mf" in
            none|hostlist|autohostlist|ipset) echo "$mf"; return 0 ;;
        esac
    fi
    if [ -f /opt/zapret/config ]; then
        mf="$(sed -n 's/^MODE_FILTER=\(.*\)$/\1/p' /opt/zapret/config 2>/dev/null | head -n1)"
        [ -n "$mf" ] && { echo "$mf"; return 0; }
    fi
    echo "none"
}


set_mode_filter() {
    # $1: none|hostlist|autohostlist|ipset
    [ -z "$1" ] && return 1
    ensure_hostlist_files

    # persist for this script (works even if /opt/zapret/config is absent)
    echo "$1" > "$HOSTLIST_MODE_FILE" 2>/dev/null || return 1

    # best-effort: also write to zapret config if present/creatable (for compatibility)
    ensure_zapret_config >/dev/null 2>&1
    if [ -f /opt/zapret/config ]; then
        if grep -q '^MODE_FILTER=' /opt/zapret/config 2>/dev/null; then
            sed -i "s/^MODE_FILTER=.*/MODE_FILTER=$1/" /opt/zapret/config 2>/dev/null
        else
            echo "MODE_FILTER=$1" >> /opt/zapret/config
        fi
    fi
    return 0
}


normalize_domain() {
    # stdin or $1; output normalized domain or empty
    d="$1"
    [ -z "$d" ] && read -r d
    d="$(echo "$d" | tr -d '\r' | tr 'A-Z' 'a-z' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    d="$(echo "$d" | sed 's#^[a-z]\+://##')"
    d="$(echo "$d" | sed 's#/.*$##')"
    d="$(echo "$d" | sed 's/^\.*//')"
    # basic allow: letters digits dot hyphen, must contain a dot or be wildcard like *.domain.tld (we store without *)
    d="$(echo "$d" | sed 's/^\*\.\(.*\)$/\1/')"
    echo "$d" | grep -Eq '^[a-z0-9][a-z0-9.-]*[a-z0-9]$' || { echo ""; return 1; }
    echo "$d"
}

file_has_line() {
    # $1 file $2 line exact
    [ -f "$1" ] || return 1
    grep -Fxq -- "$2" "$1" 2>/dev/null
}

add_line_unique() {
    # $1 file $2 line
    [ -f "$1" ] || : > "$1"
    if ! file_has_line "$1" "$2"; then
        printf "%s\n" "$2" >> "$1"
    fi
}

remove_line_exact() {
    # $1 file $2 line
    [ -f "$1" ] || return 0
    tmp="/tmp/hostlist.$$"
    grep -Fvx -- "$2" "$1" 2>/dev/null > "$tmp" && mv "$tmp" "$1"
}

hostlist_stats() {
    # $1 file
    [ -f "$1" ] || { echo "0"; return; }
    awk 'NF && $0 !~ /^[[:space:]]*#/' "$1" 2>/dev/null | wc -l | tr -d ' '
}

show_hostlist_tail() {
    # $1 file $2 title
    f="$1"; t="$2"
    c="$(hostlist_stats "$f")"
    print_line "-"
    echo "$t (count: $c)"
    print_line "-"
    if [ "$c" -eq 0 ]; then
        echo "(empty)"
    else
        awk 'NF && $0 !~ /^[[:space:]]*#/' "$f" 2>/dev/null | tail -n 30
        if [ "$c" -gt 30 ]; then
            echo "..."
        fi
    fi
}

choose_mode_filter_interactive() {
    cur="$(get_mode_filter)"

    # NOTE:
    # This function is used inside command substitution:
    #   mode="$(choose_mode_filter_interactive)"
    # If we print the menu to STDOUT, the caller will capture it and the UI will look "frozen".
    # Therefore, ALL menu/UI output goes to STDERR. Only the final selected mode is echoed to STDOUT.
    {
        print_line "-"
        echo "$(T TXT_HL_MODE_TITLE)"
        print_line "-"
        printf '%b\n' "$(T TXT_HL_CURRENT_MODE)$(color_mode_name "$cur")"
        echo ""
        _a1=""; _a2=""; _a3=""
[ "$cur" = "none" ] && _a1="$(T TXT_HL_ACTIVE_MARK)"
[ "$cur" = "hostlist" ] && _a2="$(T TXT_HL_ACTIVE_MARK)"
[ "$cur" = "autohostlist" ] && _a3="$(T TXT_HL_ACTIVE_MARK)"

echo " 1. none     ($(T TXT_HL_MODE_NONE_DESC))${_a1}"
echo " 2. hostlist ($(T TXT_HL_MODE_HOSTLIST_DESC))${_a2}"
echo " 3. autohostlist ($(T TXT_HL_MODE_AUTO_DESC))${_a3}"
echo " 0. $(T TXT_SCOPE_BACK)"
        echo ""
        printf "%s" "$(T TXT_HL_PICK)"
    } >&2

    # Prefer reading from TTY (works reliably even in $(...)). Fallback to normal stdin.
    if [ -r /dev/tty ]; then
        read -r msel </dev/tty
    else
        read -r msel
    fi

    case "$msel" in
        1) echo "none" ;;
        2) echo "hostlist" ;;
        3) echo "autohostlist" ;;
        0) echo "" ;;
        *) echo "__invalid__" ;;
    esac
}


apply_mode_filter() {
    # $1 mode
    mode="$1"
    [ -z "$mode" ] && return 0
    ensure_hostlist_files

    # hostlist/autohostlist modunda, listeler BOS ise zapret "include yok" gibi davranabilir (exclude hariç herseyi isler).
    # Bu sebeple kullaniciyi uyar.
    if [ "$mode" = "hostlist" ] || [ "$mode" = "autohostlist" ]; then
        ucnt="$(hostlist_stats "$HOSTLIST_USER")"
        if [ "$ucnt" -eq 0 ]; then
            echo "$(T TXT_HL_WARN_EMPTY_STRICT)"
            read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")" _tmp
        fi
    fi

    if set_mode_filter "$mode"; then
        echo "$(T TXT_HL_SET_OK) $mode"
        restart_zapret >/dev/null 2>&1
        echo "$(T TXT_HL_RESTART)"
    else
        echo "$(T TXT_HL_SET_FAIL)"
    fi
}

apply_scope_mode() {
    # $1 scope: global|smart
    scope="$1"
    [ -z "$scope" ] && return 0
    ensure_hostlist_files

    if ! set_scope_mode "$scope"; then
        echo "$(T TXT_HL_SET_FAIL)"
        return 1
    fi

    case "$scope" in
        global)
            # Global mod: her seye uygula (mevcut davranis). MODE_FILTER anlamsiz kalmasin diye none yap.
            set_mode_filter none >/dev/null 2>&1
            ;;
        smart)
            # Smart modun amaci: sadece gerekli hostlarda calis (otomatik ogrenme icin autohostlist)
            set_mode_filter autohostlist >/dev/null 2>&1
            ;;
    esac

    # NFQWS_OPT satirlarini kapsam moduna gore yeniden yaz
    update_nfqws_parameters >/dev/null 2>&1
    restart_zapret >/dev/null 2>&1
    echo "$(T TXT_HL_RESTART)"
    return 0
}


manage_hostlist_menu() {
    if ! is_zapret_installed; then
        echo "$(T TXT_HL_ERR_NOT_INSTALLED)"
        read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")" _tmp
        clear
        return 1
    fi

    ensure_hostlist_files

    while true; do
        clear
        cur="$(get_mode_filter)"
        ucnt="$(hostlist_stats "$HOSTLIST_USER")"
        ecnt="$(hostlist_stats "$HOSTLIST_EXCLUDE_DOM")"
        acnt="$(hostlist_stats "$HOSTLIST_AUTO")"
        print_line "=" 
        echo "$(T TXT_HL_TITLE)"
        print_line "=" 
        printf '%b\n' "$(T TXT_HL_CURRENT_MODE)$(color_mode_name "$cur")"
        echo "$(T TXT_HL_COUNTS)${ucnt}/${ecnt}/${acnt}"
        print_line "-"
        echo " 1. $(T TXT_HL_OPT_1)"
        echo " 2. $(T TXT_HL_OPT_2)"
        echo " 3. $(T TXT_HL_OPT_3)"
        echo " 4. $(T TXT_HL_OPT_4)"
        echo " 5. $(T TXT_HL_OPT_5)"
        echo " 6. $(T TXT_HL_OPT_6)"
        echo " 7. $(T TXT_HL_OPT_7)"
        echo " 8. $(T TXT_HL_OPT_8)"
        echo " 0. $(T TXT_HL_OPT_0)"
        print_line "-"
        printf "%s" "$(T TXT_HL_PICK)"
        read -r sel

        case "$sel" in
            1)
                mode="$(choose_mode_filter_interactive)"
                [ "$mode" = "__invalid__" ] && { echo "$(T invalid_main 'Gecersiz secim!' 'Invalid choice!')"; continue; }
                [ -n "$mode" ] && apply_mode_filter "$mode"
                if type press_enter_to_continue >/dev/null 2>&1; then
                    press_enter_to_continue
                else
                    read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")" _tmp
                fi
                clear
                ;;

            2)
echo "$(T TXT_HL_BULK_HINT)"
echo "$(T TXT_HL_BULK_HINT2)"
added=0
already=0
invalid=0
cancelled=0

# Prompt only once so multi-line paste doesn't spam the screen.
# Read until an empty line. "0" cancels.
printf "%s" "$(T TXT_HL_PROMPT_ADD)"
while :; do
    IFS= read -r d || break

    # Normalize input (CRLF terminals + trim)
    d="$(printf '%s' "$d" | tr -d '
' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    # Cancel (0 / 00 / 000 ...) and return to menu immediately
    if [ -n "$d" ]; then
        case "$d" in
            *[!0]*) : ;;   # not all zeros
            *)
                cancelled=1
                echo "$(T TXT_HL_CANCELLED)"
                break
                ;;
        esac
    fi

    [ -z "$d" ] && break

    # Split current line by comma/semicolon/whitespace
    for one in $(echo "$d" | tr ',;	' '   '); do
        nd="$(normalize_domain "$one")"
        # Reject entries without a dot (prevents accidentally adding "0", "00", etc.)
        case "$nd" in
            *.*) : ;;
            *) nd="";;
        esac
        if [ -z "$nd" ]; then
            invalid=$((invalid+1))
            continue
        fi
        [ -f "$HOSTLIST_USER" ] || : > "$HOSTLIST_USER"
        if grep -Fqx "$nd" "$HOSTLIST_USER" 2>/dev/null; then
            already=$((already+1))
            continue
        fi
        echo "$nd" >> "$HOSTLIST_USER"
        echo "$(T TXT_HL_MSG_ADDED)$nd"
        added=$((added+1))
    done
done

if [ "$cancelled" -eq 1 ]; then
    # Cancel should return to menu immediately (no extra prompt)
    sleep 1
    clear
    continue
fi

echo "$(T X 'Ozet:' 'Summary:') $(T X 'Eklendi' 'Added')=$added, $(T X 'Zaten vardi' 'Already existed')=$already, $(T X 'Gecersiz' 'Invalid')=$invalid"
if type press_enter_to_continue >/dev/null 2>&1; then
    press_enter_to_continue
else
    read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")" _tmp
fi
clear

    ;;
            3)
                read -r -p "$(T TXT_HL_PROMPT_DEL)" d
                [ "$d" = "0" ] && continue
                nd="$(normalize_domain "$d")"
                [ -z "$nd" ] && { echo "$(T TXT_HL_INVALID_DOMAIN)"; continue; }
                remove_line_exact "$HOSTLIST_USER" "$nd"
                echo "$(T TXT_HL_MSG_REMOVED)$nd"
                ;;

            4)
echo "$(T TXT_HL_BULK_HINT)"
echo "$(T TXT_HL_BULK_HINT2)"
added=0
already=0
invalid=0
cancelled=0

# Prompt only once so multi-line paste doesn't spam the screen.
# Read until an empty line. "0" cancels.
printf "%s" "$(T TXT_HL_PROMPT_ADD)"
while :; do
    IFS= read -r d || break

    # Normalize input (CRLF terminals + trim)
    d="$(printf '%s' "$d" | tr -d '
' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    # Cancel (0 / 00 / 000 ...) and return to menu immediately
    if [ -n "$d" ]; then
        case "$d" in
            *[!0]*) : ;;   # not all zeros
            *)
                cancelled=1
                echo "$(T TXT_HL_CANCELLED)"
                break
                ;;
        esac
    fi

    [ -z "$d" ] && break

    # Split current line by comma/semicolon/whitespace
    for one in $(echo "$d" | tr ',;	' '   '); do
        nd="$(normalize_domain "$one")"
        # Reject entries without a dot (prevents accidentally adding "0", "00", etc.)
        case "$nd" in
            *.*) : ;;
            *) nd="";;
        esac
        if [ -z "$nd" ]; then
            invalid=$((invalid+1))
            continue
        fi
        [ -f "$HOSTLIST_EXCLUDE_DOM" ] || : > "$HOSTLIST_EXCLUDE_DOM"
        if grep -Fqx "$nd" "$HOSTLIST_EXCLUDE_DOM" 2>/dev/null; then
            already=$((already+1))
            continue
        fi
        echo "$nd" >> "$HOSTLIST_EXCLUDE_DOM"
        echo "$(T TXT_HL_MSG_ADDED)$nd"
        added=$((added+1))
    done
done

if [ "$cancelled" -eq 1 ]; then
    # Cancel should return to menu immediately (no extra prompt)
    sleep 1
    clear
    continue
fi

echo "$(T X 'Ozet:' 'Summary:') $(T X 'Eklendi' 'Added')=$added, $(T X 'Zaten vardi' 'Already existed')=$already, $(T X 'Gecersiz' 'Invalid')=$invalid"
if type press_enter_to_continue >/dev/null 2>&1; then
    press_enter_to_continue
else
    read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")" _tmp
fi
clear

    ;;
            5)
                read -r -p "$(T TXT_HL_PROMPT_DEL)" d
                [ "$d" = "0" ] && continue
                nd="$(normalize_domain "$d")"
                [ -z "$nd" ] && { echo "$(T TXT_HL_INVALID_DOMAIN)"; continue; }
                remove_line_exact "$HOSTLIST_EXCLUDE_DOM" "$nd"
                echo "$(T TXT_HL_MSG_REMOVED)$nd"
                ;;
            6)
                show_hostlist_tail "$HOSTLIST_USER"    "/opt/zapret/ipset/zapret-hosts-user.txt"
                echo ""
                show_hostlist_tail "$HOSTLIST_EXCLUDE_DOM" "/opt/zapret/ipset/zapret-hosts-user-exclude.txt"
                echo ""
                show_hostlist_tail "$HOSTLIST_EXCLUDE_IP"  "/opt/zapret/ipset/zapret-hosts-localnets.txt"
                echo ""
                show_hostlist_tail "$HOSTLIST_AUTO"    "/opt/zapret/ipset/zapret-hosts-auto.txt"
                if type press_enter_to_continue >/dev/null 2>&1; then
                    press_enter_to_continue
                else
                    read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")" _tmp
                fi
                clear
                ;;
            7)
                print_line "-"
                printf '%b
' "${CLR_BOLD}${CLR_RED}$(T TXT_HL_WARN_AUTOCLEAR_1)${CLR_RESET}"
                printf '%b
' "${CLR_BOLD}${CLR_RED}$(T TXT_HL_WARN_AUTOCLEAR_2)${CLR_RESET}"
                print_line "-"
                printf "%s" "$(T confirm_autolist_q 'Onayliyor musunuz? (e=Evet, h=Hayir, 0=Geri): ' 'Confirm? (y=Yes, n=No, 0=Back): ')"
                read -r ans
                case "$ans" in
                    0) ;;
                    e|E|y|Y)
                        : > "$HOSTLIST_AUTO"
                        echo "$(T TXT_HL_CLEARED)"
                        ;;
                    *)
                        echo "$(T cancelled 'Islem iptal edildi.' 'Cancelled.')"
                        ;;
                esac
                if type press_enter_to_continue >/dev/null 2>&1; then
                    press_enter_to_continue
                else
                    read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")" _tmp
                fi
                clear
                ;;

            8)
                print_line "-"
                printf '%b
' "${CLR_BOLD}${CLR_CYAN}$(T TXT_SCOPE_MODE): $(pretty_scope_mode)${CLR_RESET}"
                print_line "-"
                echo ""
                gdesc="$(T TXT_SCOPE_GLOBAL_DESC)"
            sdesc="$(T TXT_SCOPE_SMART_DESC)"
echo " 1. $(T TXT_SCOPE_GLOBAL) (${gdesc})"
echo " 2. $(T TXT_SCOPE_SMART)  (${sdesc})"
                echo " 0. $(T TXT_SCOPE_BACK)"
                echo ""
                printf "%s" "$(T TXT_HL_PICK)"

                if [ -r /dev/tty ]; then
                    read -r ssel </dev/tty
                else
                    read -r ssel
                fi

case "$ssel" in
                    1) apply_scope_mode global ;;
                    2) apply_scope_mode smart ;;
                    0) : ;;
                    *) echo "$(T invalid_main 'Gecersiz secim!' 'Invalid choice!')" ;;
                esac

                if type press_enter_to_continue >/dev/null 2>&1; then
                    press_enter_to_continue
                else
                    read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")" _tmp
                fi
                clear
                ;;

            0)
                clear
                return 0
                ;;
            *)
                echo "$(T invalid_main 'Gecersiz secim!' 'Invalid choice!')"
                ;;
        esac
        echo ""
    done
}

# --- Betik: Yedekten Geri Don (Rollback) ---

github_fetch_release_kv_last10() {
    # outputs lines: tag|url  (tag list; not release assets)
    local API
    API="https://api.github.com/repos/RevolutionTR/keenetic-zapret-manager/tags?per_page=10"
    {
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL -H "User-Agent: keenetic-zapret-manager" "$API"
        elif command -v wget >/dev/null 2>&1; then
            wget -qO- "$API"
        else
            return 1
        fi
    } | tr '\r\n' ' ' | sed 's/\"name\":/\n\"name\":/g' | awk -F'\"' '
        $0 ~ /"name":/ {
            tag=$4
            if (tag != "") {
                print tag "|" "https://raw.githubusercontent.com/RevolutionTR/keenetic-zapret-manager/" tag "/keenetic_zapret_otomasyon_ipv6_ipset.sh"
            }
        }
    '
}

github_fetch_release_url_by_tag() {
    # $1 = tag => prints raw url (may 404 if tag does not exist)
    local TAG
    TAG="$1"
    [ -n "$TAG" ] || return 1
    echo "https://raw.githubusercontent.com/RevolutionTR/keenetic-zapret-manager/$TAG/keenetic_zapret_otomasyon_ipv6_ipset.sh"
}

github_install_script_from_url() {
    # $1=tag (for backup name), $2=url
    local TAG URL TARGET TS BAK TMP
    TAG="$1"
    URL="$2"
    TARGET="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh"
    [ -f "$TARGET" ] || TARGET="$(readlink -f "$0" 2>/dev/null)"
    [ -n "$URL" ] || return 1

    TS="$(date +%Y%m%d_%H%M%S 2>/dev/null)"
    [ -z "$TS" ] && TS="$(date +%Y%m%d%H%M%S 2>/dev/null)"
    BAK="${TARGET}.bak_${TAG}_${TS}.sh"
    TMP="/tmp/keenetic_zapret_manager_dl.$$"

    echo "$(T TXT_ROLLBACK_GH_DOWNLOADING)"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$URL" -o "$TMP" || { rm -f "$TMP"; return 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$TMP" "$URL" || { rm -f "$TMP"; return 1; }
    else
        return 1
    fi

    head -n 1 "$TMP" 2>/dev/null | grep -q "^#!" || { rm -f "$TMP"; return 1; }

    if [ -f "$TARGET" ]; then
        cp -f "$TARGET" "$BAK" 2>/dev/null
        chmod +x "$BAK" 2>/dev/null
    fi

    cp -f "$TMP" "$TARGET" 2>/dev/null && chmod +x "$TARGET" 2>/dev/null
    rm -f "$TMP" 2>/dev/null

    echo "$(T TXT_ROLLBACK_GH_DONE)"
    press_enter_to_continue
    return 0
}

github_install_from_releases_last10() {
    local LIST TMP i sel line tag url
    echo "$(T TXT_ROLLBACK_GH_LOADING)"
    LIST="$(github_fetch_release_kv_last10 2>/dev/null)"
    if [ -z "$LIST" ]; then
        echo "$(T TXT_ROLLBACK_GH_NONE)"
        press_enter_to_continue
        return 0
    fi

    TMP="/tmp/keenetic_zapret_releases.$$"
    printf "%s\n" "$LIST" > "$TMP" 2>/dev/null

    print_line "-"
    i=1
    while IFS= read -r line; do
        tag="${line%%|*}"
        echo " $i. $tag"
        i=$((i+1))
    done < "$TMP"

    echo " 0. $(T TXT_BACK)"
    print_line "-"
    printf "%s: " "$(T TXT_ROLLBACK_GH_SELECT)"
    read sel

    if [ "$sel" = "0" ] || [ -z "$sel" ]; then
        rm -f "$TMP" 2>/dev/null
        echo "$(T TXT_ROLLBACK_CANCELLED)"
        press_enter_to_continue
        return 0
    fi

    case "$sel" in
        *[!0-9]*)
            rm -f "$TMP" 2>/dev/null
            echo "$(T TXT_INVALID_CHOICE)"
            press_enter_to_continue
            return 0
            ;;
    esac

    i=1
    while IFS= read -r line; do
        if [ "$i" = "$sel" ]; then
            tag="${line%%|*}"
            url="${line#*|}"
            rm -f "$TMP" 2>/dev/null
            github_install_script_from_url "$tag" "$url"
            if [ $? -ne 0 ]; then
                echo "$(T TXT_GITHUB_FAIL)"
                press_enter_to_continue
                return 0
            fi
            echo "$(T TXT_ROLLBACK_GH_DONE)"
            press_enter_to_continue
            return 0
        fi
        i=$((i+1))
    done < "$TMP"

    rm -f "$TMP" 2>/dev/null
    echo "$(T TXT_INVALID_CHOICE)"
    press_enter_to_continue
    return 0
}

github_install_from_tag_prompt() {
    local TAG URL
    printf "%s " "$(T TXT_ROLLBACK_GH_TAGPROMPT)"
    read TAG
    if [ "$TAG" = "0" ]; then
        echo "$(T TXT_ROLLBACK_CANCELLED)"
        press_enter_to_continue
        return 0
    fi
    if [ -z "$TAG" ]; then
        echo "$(T TXT_ROLLBACK_CANCELLED)"
        press_enter_to_continue
        return 0
    fi

    URL="$(github_fetch_release_url_by_tag "$TAG" 2>/dev/null)"
    if [ -z "$URL" ]; then
        echo "$(T TXT_ROLLBACK_GH_NONE)"
        press_enter_to_continue
        return 0
    fi

    github_install_script_from_url "$TAG" "$URL"
    if [ $? -ne 0 ]; then
        echo "$(T TXT_GITHUB_FAIL)"
        press_enter_to_continue
        return 0
    fi
    echo "$(T TXT_ROLLBACK_GH_DONE)"
    press_enter_to_continue
    return 0
}



clean_backup_files() {
    local dir="/opt/lib/opkg"
    local pattern="keenetic_zapret_otomasyon_ipv6_ipset.sh.bak*"
    local count
    count="$(find "$dir" -maxdepth 1 -type f -name "$pattern" 2>/dev/null | wc -l | tr -d ' ')"
    if [ "${count:-0}" = "0" ]; then
        echo "$(T TXT_ROLLBACK_CLEAN_NONE)"
        return 0
    fi
    find "$dir" -maxdepth 1 -type f -name "$pattern" -delete 2>/dev/null
    echo "$(T TXT_ROLLBACK_CLEAN_DONE) (${count})"
}

clean_blockcheck_reports() {
    local dir="/opt/zapret"
    local pattern="blockcheck_*.txt"
    local count
    count="$(find "$dir" -maxdepth 1 -type f -name "$pattern" 2>/dev/null | wc -l | tr -d ' ')"
    if [ "${count:-0}" = "0" ]; then
        echo "$(T TXT_BLOCKCHECK_CLEAN_NONE)"
        return 0
    fi
    find "$dir" -maxdepth 1 -type f -name "$pattern" -delete 2>/dev/null
    echo "$(T TXT_BLOCKCHECK_CLEAN_DONE) (${count})"
}

rollback_local_storage_menu() {
    local TARGET="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh"
    local BACKUP_PATTERN="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh.bak_*"

    while true; do
        clear
        print_line
        echo "$(T TXT_ROLLBACK_LOCAL_MENU)"
        print_line

        BACKUP_FILES="$(ls -1t $BACKUP_PATTERN 2>/dev/null)"

        if [ -z "$BACKUP_FILES" ]; then
            echo "$(T TXT_ROLLBACK_NO_LOCAL_BACKUP)"
        else
            local i=1
            for file in $BACKUP_FILES; do
                echo " $i. $(basename "$file")"
                i=$((i+1))
            done
        fi

        print_line
        echo " c) $(T TXT_ROLLBACK_CLEAN)"
        echo " 0) $(T TXT_BACK)"
        print_line

        read -r -p "$(T TXT_ROLLBACK_MAIN_PICK) " sel
        sel=$(echo "$sel" | tr -d '[:space:]')

        case "$sel" in
            c|C)
                clean_backup_files
                press_enter_to_continue
                return
            ;;

            0|"")
                echo "$(T TXT_ROLLBACK_CANCELLED)"
                press_enter_to_continue
                return
            ;;
        esac

        if [ -z "$BACKUP_FILES" ]; then
            echo "$(T TXT_INVALID_CHOICE)"
            press_enter_to_continue
            continue
        fi

        local found=0
        local idx=1
        for file in $BACKUP_FILES; do
            if [ "$idx" = "$sel" ]; then
                found=1
                cp -f "$file" "$TARGET" 2>/dev/null && chmod +x "$TARGET" 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo "$(T TXT_ROLLBACK_RESTORED)"
                else
                    echo "$(T TXT_ERROR)"
                fi
                press_enter_to_continue
                return
            fi
            idx=$((idx+1))
        done

        if [ "$found" -eq 0 ]; then
            echo "$(T TXT_INVALID_CHOICE)"
            press_enter_to_continue
        fi
    done
}

script_rollback_menu() {
    local sel

    while :; do
        clear
        print_line "=" 
        echo "$(T TXT_ROLLBACK_TITLE)"
        print_line "=" 
        echo " 1. $(T TXT_ROLLBACK_LOCAL_MENU)"
        echo " 2. $(T TXT_ROLLBACK_GH_LIST)"
        echo " 3. $(T TXT_ROLLBACK_GH_TAG)"
        echo " 0. $(T TXT_BACK)"
        print_line "-"
        printf "%s" "$(T TXT_ROLLBACK_MAIN_PICK)"
        read sel

        case "$sel" in
            0|"")
                echo "$(T TXT_ROLLBACK_CANCELLED)"
                press_enter_to_continue
                return 0
                ;;
            1)
                rollback_local_storage_menu
                continue
                ;;
            2|G|g)
                github_install_from_releases_last10
                continue
                ;;
            3|T|t)
                github_install_from_tag_prompt
                continue
                ;;
            *)
                echo "$(T TXT_INVALID_CHOICE)"
                press_enter_to_continue
                ;;
        esac
    done
}


display_menu() {
    print_line "=" 
    echo "$(T TXT_MAIN_TITLE)"
    echo "$(T TXT_OPTIMIZED)"
    _dpi_warn="$(T dpi_warn "$TXT_DPI_WARNING_TR" "$TXT_DPI_WARNING_EN")"
    echo "$_dpi_warn"
    printf '%b\n' "${CLR_BOLD}${CLR_CYAN}$(T TXT_DEVELOPER)${CLR_RESET}"
    printf '%b\n' "${CLR_BOLD}${CLR_CYAN}$(T TXT_EDITOR)${CLR_RESET}"
    printf '%b\n' "${CLR_YELLOW}$(T TXT_VERSION)${CLR_RESET}"
    print_line "=" 
	echo
    echo " $(T TXT_DESC1)"
    echo " $(T TXT_DESC2)"
    echo " $(T TXT_DESC3)"
    echo
    print_line "-"
    echo "$(T TXT_MENU_1)"
    echo "$(T TXT_MENU_2)"
    echo "$(T TXT_MENU_3)"
    echo "$(T TXT_MENU_4)"
    echo "$(T TXT_MENU_5)"
    echo "$(T TXT_MENU_6)"
    echo "$(T TXT_MENU_7)"
    echo "$(T TXT_MENU_8)"
    echo "$(T TXT_MENU_9)"
    echo "$(T TXT_MENU_10)"
    echo "$(T TXT_MENU_11)"
    echo "$(T TXT_MENU_12)"
    echo "$(T TXT_MENU_13)"
    echo "$(T TXT_MENU_14)"
    echo "$(T TXT_MENU_15)"
    echo "$(T TXT_MENU_16)"
    echo "$(T TXT_MENU_B)"
    echo "$(T TXT_MENU_L)  ($(lang_label))"
    echo "$(T TXT_MENU_0)"
    print_line "-"
    echo
    printf "$(T TXT_PROMPT_MAIN)"

}


# --- SAGLIK KONTROLU (HEALTH CHECK) ---
run_health_check() {
    pass_n=0
    info_n=0
    warn_n=0
    fail_n=0
    total_n=0

    HC_TMP="/tmp/healthcheck.$$"
    : >"$HC_TMP" 2>/dev/null || {
        HC_TMP="/opt/tmp/healthcheck.$$"
        mkdir -p /opt/tmp 2>/dev/null
        : >"$HC_TMP" 2>/dev/null || HC_TMP=""
    }

    add_line() {
        # $1=label, $2=msg (already colored), $3=status PASS|WARN|FAIL
        label="$1"
        msg="$2"
        st="$3"
        total_n=$((total_n+1))
        case "$st" in
            PASS) pass_n=$((pass_n+1)) ;;
            INFO) info_n=$((info_n+1)) ;;
            WARN) warn_n=$((warn_n+1)) ;;
            FAIL) fail_n=$((fail_n+1)) ;;
        esac
        if [ -n "$HC_TMP" ]; then
            printf "%-35s : %b\n" "$label" "$msg" >>"$HC_TMP"
        else
            # Fallback: print directly (no summary at top in this rare case)
            printf "%-35s : %b\n" "$label" "$msg"
        fi
    }

    # ---- Checks (append to temp) ----

    # DNS (local resolver)
    if nslookup github.com 127.0.0.1 >/dev/null 2>&1; then
        add_line "$(T TXT_HEALTH_DNS_LOCAL)" "$(hc_word PASS)" "PASS"
    else
        add_line "$(T TXT_HEALTH_DNS_LOCAL)" "$(hc_word FAIL)" "FAIL"
    fi

    # DNS (public)
    if nslookup github.com 8.8.8.8 >/dev/null 2>&1; then
        add_line "$(T TXT_HEALTH_DNS_PUBLIC)" "$(hc_word PASS)" "PASS"
    else
        add_line "$(T TXT_HEALTH_DNS_PUBLIC)" "$(hc_word FAIL)" "FAIL"
    fi

    # DNS consistency (compare first A/Address line for github.com between local and 8.8.8.8)
    dns_local_ip="$(nslookup github.com 127.0.0.1 2>/dev/null | awk '/^Address [0-9]+:/{print $3; exit}')"
    dns_pub_ip="$(nslookup github.com 8.8.8.8 2>/dev/null | awk '/^Address [0-9]+:/{print $3; exit}')"
    if [ -n "$dns_local_ip" ] && [ -n "$dns_pub_ip" ]; then
        if [ "$dns_local_ip" = "$dns_pub_ip" ]; then
            add_line "$(T TXT_HEALTH_DNS_MATCH)" "$(hc_word PASS)  (${dns_local_ip})" "PASS"
        else
            add_line "$(T TXT_HEALTH_DNS_MATCH)" "$(hc_word INFO)  (ISS farkli IP donduruyor olabilir)" "INFO"
        fi
    else
        add_line "$(T TXT_HEALTH_DNS_MATCH)" "$(hc_word INFO)  (ISS farkli IP donduruyor olabilir)" "INFO"
    fi

    # Default route
    if ip route 2>/dev/null | grep -q '^default '; then
        add_line "$(T TXT_HEALTH_ROUTE)" "$(hc_word PASS)" "PASS"

    # Betik konumu kontrolu (dogru dizinden mi calisiyor?)
    expected_script="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh"
    actual_script="$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")"
    if [ "$actual_script" = "$expected_script" ]; then
        add_line "$(T TXT_HEALTH_SCRIPT_PATH)" "$(hc_word PASS)  ($actual_script)" "PASS"
    else
        add_line "$(T TXT_HEALTH_SCRIPT_PATH)" "$(hc_word WARN)  (Beklenen: $expected_script | Su an: $actual_script)" "WARN"
    fi
    else
        # Some systems lack 'ip'; try route
        if route -n 2>/dev/null | awk '$1=="0.0.0.0"{found=1} END{exit !found}'; then
            add_line "$(T TXT_HEALTH_ROUTE)" "$(hc_word PASS)" "PASS"
        else
            add_line "$(T TXT_HEALTH_ROUTE)" "$(hc_word WARN)" "WARN"
        fi
    fi

    # Internet ping
    if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
        add_line "$(T TXT_HEALTH_PING)" "$(hc_word PASS)" "PASS"
    else
        add_line "$(T TXT_HEALTH_PING)" "$(hc_word WARN)" "WARN"
    fi

    # RAM (MemAvailable)
    mem_av_kb="$(awk '/MemAvailable:/{print $2; exit}' /proc/meminfo 2>/dev/null)"
    if [ -n "$mem_av_kb" ]; then
        mem_av_mb="$(awk -v k="$mem_av_kb" 'BEGIN{printf "%d", (k/1024)}' 2>/dev/null)"
        [ -z "$mem_av_mb" ] && mem_av_mb="N/A"
        add_line "$(T TXT_HEALTH_RAM)" "$(hc_word PASS)  (~${mem_av_mb}MB)" "PASS"
    else
        add_line "$(T TXT_HEALTH_RAM)" "$(hc_word WARN)  (N/A)" "WARN"
    fi

    # Load avg
    load_avg="$(awk '{print $1}' /proc/loadavg 2>/dev/null)"
    [ -z "$load_avg" ] && load_avg="N/A"
    add_line "$(T TXT_HEALTH_LOAD)" "$(hc_word PASS)  (${load_avg})" "PASS"

    # Time / NTP (human-readable)
    now_epoch="$(date +%s 2>/dev/null)"
    now_human="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
    if [ -n "$now_epoch" ] && [ "$now_epoch" -gt 1609459200 ] 2>/dev/null; then
        add_line "$(T TXT_HEALTH_TIME)" "$(hc_word PASS)  (${now_human})" "PASS"
    else
        add_line "$(T TXT_HEALTH_TIME)" "$(hc_word WARN)  (${now_human})" "WARN"
    fi

    # GitHub access
    code="$(curl -I -m 8 -s -o /dev/null -w "%{http_code}" https://api.github.com/ 2>/dev/null)"
    case "$code" in
        2*|3*) add_line "$(T TXT_HEALTH_GITHUB)" "$(hc_word PASS)  (HTTP ${code})" "PASS" ;;
        403|429) add_line "$(T TXT_HEALTH_GITHUB)" "$(hc_word WARN)  (HTTP ${code})" "WARN" ;;
        *) [ -z "$code" ] && code="N/A"
           add_line "$(T TXT_HEALTH_GITHUB)" "$(hc_word FAIL)  (HTTP ${code})" "FAIL" ;;
    esac

    # opkg status
    if command -v opkg >/dev/null 2>&1; then
        if opkg --version >/dev/null 2>&1; then
            add_line "$(T TXT_HEALTH_OPKG)" "$(hc_word PASS)" "PASS"
        else
            add_line "$(T TXT_HEALTH_OPKG)" "$(hc_word WARN)  (opkg)" "WARN"
        fi
    else
        add_line "$(T TXT_HEALTH_OPKG)" "$(hc_word FAIL)  (opkg yok)" "FAIL"
    fi

    # Disk usage (/opt)
    df_line="$(df -P /opt 2>/dev/null | awk 'NR==2{print $2" "$3" "$4}')"
    if [ -n "$df_line" ]; then
        size_k="$(printf "%s" "$df_line" | awk '{print $1}')"
        used_k="$(printf "%s" "$df_line" | awk '{print $2}')"
        avail_k="$(printf "%s" "$df_line" | awk '{print $3}')"
        avail_mb="$(printf "%s" "$avail_k" | awk '{printf "%d", ($1/1024)}' 2>/dev/null)"
        [ -z "$avail_mb" ] && avail_mb="N/A"
        pct_dec="$(awk -v u="$used_k" -v s="$size_k" 'BEGIN{ if (s>0) printf "%.2f", (u/s)*100; }' 2>/dev/null)"
        if [ -n "$pct_dec" ]; then
            # PASS <90, WARN 90-95, FAIL >=95
            if awk -v p="$pct_dec" 'BEGIN{exit !(p<90)}'; then
                add_line "$(T TXT_HEALTH_DISK)" "$(hc_word PASS)  (${pct_dec}%, free ~${avail_mb}MB)" "PASS"
            elif awk -v p="$pct_dec" 'BEGIN{exit !((p>=90)&&(p<95))}'; then
                add_line "$(T TXT_HEALTH_DISK)" "$(hc_word WARN)  (${pct_dec}%, free ~${avail_mb}MB)" "WARN"
            else
                add_line "$(T TXT_HEALTH_DISK)" "$(hc_word FAIL)  (${pct_dec}%, free ~${avail_mb}MB)" "FAIL"
            fi
        else
            add_line "$(T TXT_HEALTH_DISK)" "$(hc_word WARN)  (N/A)" "WARN"
        fi
    else
        add_line "$(T TXT_HEALTH_DISK)" "$(hc_word WARN)  (df N/A)" "WARN"
    fi

    # Zapret service status
    if is_zapret_installed; then
        if is_zapret_running; then
            add_line "$(T TXT_HEALTH_ZAPRET)" "$(hc_word PASS)" "PASS"
        else
            add_line "$(T TXT_HEALTH_ZAPRET)" "$(hc_word WARN)  (kurulu ama calismiyor)" "WARN"
        fi
    else
        add_line "$(T TXT_HEALTH_ZAPRET)" "$(hc_word FAIL)  (kurulu degil)" "FAIL"
    fi

    # ---- Print (summary at top) ----
    if [ "$fail_n" -gt 0 ] 2>/dev/null; then
        overall_st="FAIL"
    elif [ "$warn_n" -gt 0 ] 2>/dev/null; then
        overall_st="WARN"
    else
        overall_st="PASS"
    fi

    ok_n=$((pass_n+info_n))

    overall_msg="$(hc_word "$overall_st")  (${ok_n}/${total_n} OK"
    if [ "$warn_n" -gt 0 ] 2>/dev/null; then
        overall_msg="${overall_msg}, ${warn_n} WARN"
    fi
    if [ "$fail_n" -gt 0 ] 2>/dev/null; then
        overall_msg="${overall_msg}, ${fail_n} FAIL"
    fi
    overall_msg="${overall_msg})"

    clear
    print_line "=" 
    echo "$(T TXT_HEALTH_TITLE)"
    print_line "=" 
    printf "%-35s : %b\n" "$(T TXT_HEALTH_OVERALL)" "$overall_msg"
    print_line "-"
    if [ -n "$HC_TMP" ] && [ -f "$HC_TMP" ]; then
        cat "$HC_TMP"
        rm -f "$HC_TMP" 2>/dev/null
    fi
    print_line "-"

    if type press_enter_to_continue >/dev/null 2>&1; then
        press_enter_to_continue
    else
        read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")" _tmp
    fi
    clear
}




# --- BLOCKCHECK (DPI TEST) ---
run_blockcheck() {
    local BLOCKCHECK="/opt/zapret/blockcheck.sh"
    local DEF_DOMAIN="pastebin.com"
    local domains report today was_running stop_ans do_stop stopped_by_us

    print_line "-"
    echo "$(T blk_title 'Blockcheck (DPI Test Raporu)' 'Blockcheck (DPI Test Report)')"
    print_line "-"

    if [ ! -x "$BLOCKCHECK" ]; then
        echo "$(T blk_missing 'HATA: /opt/zapret/blockcheck.sh bulunamadi veya calistirilabilir degil.' 'ERROR: /opt/zapret/blockcheck.sh not found or not executable.')"
        read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")" _tmp
        clear
        return 1
    fi

    # Domain(ler)
    read -r -p "$(T blk_domain 'Test edilecek domain(ler) (Enter=pastebin.com, 0=Iptal): ' 'Domain(s) to test (Enter=pastebin.com, 0=Cancel): ')" domains
    if [ "$domains" = "0" ]; then
        clear
        return 0
    fi
    [ -z "$domains" ] && domains="$DEF_DOMAIN"

	now="$(date +%Y%m%d%H%M 2>/dev/null)"
	[ -z "$now" ] && now="000000000000"
	report="/opt/zapret/blockcheck_${now}.txt"


	LAST_BLOCKCHECK_REPORT="$report"
    # Zapret calisiyorsa blockcheck genelde "bypass kapali olmali" diye uyarir.
    was_running=0
    do_stop=0
    stopped_by_us=0
    if is_zapret_running; then
        was_running=1
        echo "$(T blk_running 'Not: Zapret su anda calisiyor. Blockcheck testi icin gecici olarak durdurulmesi onerilir.' 'Note: Zapret is currently running. It is recommended to stop it temporarily for blockcheck.')"
        read -r -p "$(T blk_stopq 'Zapret gecici olarak durdurulsun mu? (e/h) [e]: ' 'Stop Zapret temporarily? (y/n) [y]: ')" stop_ans
        case "$stop_ans" in
            [hHnN]) do_stop=0 ;;
            *) do_stop=1 ;;
        esac
        if [ "$do_stop" -eq 1 ]; then
            stop_zapret >/dev/null 2>&1
            stopped_by_us=1
        fi
    fi

    echo
    echo "$(T blk_running2 "Calistiriliyor... (Rapor: ${report})" "Running... (Report: ${report})")"
    print_line "-"

    # blockcheck kendi icinde domain prompt'u aciyor; stdin'e domainleri basarak takilmasini engelliyoruz.
    # stdout+stderr rapora yazilsin diye tee kullan.
    # (tee yoksa sadece > ile yazar)
    if command -v tee >/dev/null 2>&1; then
        printf "%s\n" "$domains" | sh "$BLOCKCHECK" 2>&1 | tee "$report"
    else
        printf "%s\n" "$domains" | sh "$BLOCKCHECK" >"$report" 2>&1
        cat "$report" 2>/dev/null
    fi

    print_line "-"
    echo "$(T blk_done "Bitti. Rapor dosyasi: ${report}" "Done. Report file: ${report}")"

    # Daha once calisiyorduysa ve biz durdurduysak geri ac
    if [ "$was_running" -eq 1 ] && [ "$stopped_by_us" -eq 1 ]; then
        echo "$(T blk_restarting 'Zapret tekrar baslatiliyor...' 'Starting Zapret again...')"
        start_zapret >/dev/null 2>&1
        if is_zapret_running; then
            echo "$(T blk_started 'Zapret tekrar baslatildi.' 'Zapret started again.')"
        else
            echo "$(T blk_startfail 'UYARI: Zapret tekrar baslatilamadi. Elle baslatmaniz gerekebilir.' 'WARNING: Could not restart Zapret. You may need to start it manually.')"
        fi
    fi

    read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")" _tmp
    clear
    return 0
}


run_blockcheck_save_summary() {
    # Run the full interactive test exactly like "Tam Test", then save only * SUMMARY * to a separate file.
    run_blockcheck

    local src_report ts summary_file
    src_report="${LAST_BLOCKCHECK_REPORT}"
    if [ -z "$src_report" ] || [ ! -f "$src_report" ]; then
        src_report="$(ls -1t /opt/zapret/blockcheck_[0-9]*.txt 2>/dev/null | head -n 1)"

    # Guard: avoid using an already-summarized file as the source report
    case "$src_report" in
        */blockcheck_summary_*.txt)
            src_report="$(ls -1t /opt/zapret/blockcheck_[0-9]*.txt 2>/dev/null | head -n 1)"
        ;;
    esac

    fi
    if [ -z "$src_report" ] || [ ! -f "$src_report" ]; then
        echo "$(T TXT_BLOCKCHECK_SUMMARY_NOT_FOUND)"
        press_enter_to_continue
        return 1
    fi

    ts="$(date +%Y%m%d%H%M%S 2>/dev/null)"
    [ -z "$ts" ] && ts="$(date +%Y%m%d%H%M%S)"
    summary_file="/opt/zapret/blockcheck_summary_${ts}.txt"

# Build a compact summary file:
# 1) Keep the last "working strategy found ..." line (if any)
# 2) Append the * SUMMARY section (if present)
: > "$summary_file" 2>/dev/null || true

# Find the LAST "working strategy found" line (prefer the one before "clearing nfqws redirection" when possible)
clear_ln="$(grep -ni 'clearing nfqws redirection' "$src_report" 2>/dev/null | tail -n 1 | cut -d: -f1)"
ws_ln="0"
if [ -n "$clear_ln" ] && [ "$clear_ln" -gt 1 ] 2>/dev/null; then
    ws_ln="$(sed -n "1,$((clear_ln-1))p" "$src_report" 2>/dev/null | grep -ni 'working strategy found' | tail -n 1 | cut -d: -f1)"
else
    ws_ln="$(grep -ni 'working strategy found' "$src_report" 2>/dev/null | tail -n 1 | cut -d: -f1)"
fi

if [ -n "$ws_ln" ] && [ "$ws_ln" -gt 0 ] 2>/dev/null; then
    ws_line="$(sed -n "${ws_ln}p" "$src_report" 2>/dev/null)"
    [ -n "$ws_line" ] && printf "%s
" "$ws_line" >> "$summary_file"
fi

sum_ln="$(grep -ni '^\* SUMMARY' "$src_report" 2>/dev/null | tail -n 1 | cut -d: -f1)"
if [ -n "$sum_ln" ] && [ "$sum_ln" -gt 0 ] 2>/dev/null; then
    sed -n "${sum_ln},\$p" "$src_report" 2>/dev/null >> "$summary_file"
fi

if [ ! -s "$summary_file" ]; then
    echo "$(T TXT_BLOCKCHECK_SUMMARY_NOT_FOUND)" > "$summary_file"
fi
    # Optional: extract nfqws parameters from the summary and apply as special DPI profile "blockcheck_auto"
    local chosen_line raw_params params_filtered ans

    chosen_line=""
    # Prefer the "working strategy found ..." line if it contains nfqws/tpws
    chosen_line="$(grep -i 'working strategy found' "$summary_file" 2>/dev/null | tail -n 1)"

    if [ -z "$chosen_line" ]; then
        # Fall back to * SUMMARY block candidates (prefer https_tls12, then tls13, then http)
        chosen_line="$(grep -i 'curl_test_https_tls12' "$summary_file" 2>/dev/null | grep -i ' nfqws ' | grep -i -- '--dpi-desync=' | tail -n 1)"
        [ -z "$chosen_line" ] && chosen_line="$(grep -i 'curl_test_https_tls13' "$summary_file" 2>/dev/null | grep -i ' nfqws ' | grep -i -- '--dpi-desync=' | tail -n 1)"
        [ -z "$chosen_line" ] && chosen_line="$(grep -i 'curl_test_http' "$summary_file" 2>/dev/null | grep -i ' nfqws ' | grep -i -- '--dpi-desync=' | tail -n 1)"
    fi

    if echo "$chosen_line" | grep -qi ': *tpws '; then
        # For safety, we do not auto-apply tpws yet.
        echo "$(T blockcheck_tpws_warn "$TXT_BLOCKCHECK_TPWS_WARN_TR" "$TXT_BLOCKCHECK_TPWS_WARN_EN")"
    elif echo "$chosen_line" | grep -qi ': *nfqws '; then
        raw_params="$(echo "$chosen_line" | sed -n 's/^.*:[[:space:]]*nfqws[[:space:]]*//p' | sed 's/!//g; s/[[:space:]]\+$//')"

        # Keep only safe nfqws flags we support writing (avoid accidental config corruption)
        params_filtered=""
        for tok in $raw_params; do
            case "$tok" in
                --dpi-desync=*|--dpi-desync-ttl=*|--dpi-desync-fooling=*|--dpi-desync-autottl=*|--dpi-desync-split-pos=*|--disorder)
                    params_filtered="${params_filtered} ${tok}"
                ;;
            esac
        done
        params_filtered="$(echo "$params_filtered" | sed 's/^ *//; s/ *$//')"

        
if [ -z "$params_filtered" ]; then
    echo "$(T TXT_BLOCKCHECK_NO_STRAT)"
else
    # Build quick stability stats from SUMMARY section (best-effort)
    local _sum_start total_tests success_tests tls12_ok dns_ok udp_weak score
    _sum_start="$(grep -n "^\* SUMMARY" "$REPORT" 2>/dev/null | head -n1 | cut -d: -f1)"
    total_tests=0
    success_tests=0
    if [ -n "$_sum_start" ]; then
        total_tests="$(sed -n "${_sum_start},\$p" "$REPORT" 2>/dev/null | awk '/^curl_test_/ {print $1}' | sort -u | wc -l 2>/dev/null)"
        success_tests="$(sed -n "${_sum_start},\$p" "$REPORT" 2>/dev/null | awk -v p="$params_filtered" '$0 ~ /^curl_test_/ && index($0,p)>0 {print $1}' | sort -u | wc -l 2>/dev/null)"
        tls12_ok=0
        sed -n "${_sum_start},\$p" "$REPORT" 2>/dev/null | grep -q '^curl_test_https_tls12 ' && tls12_ok=1
        udp_weak=1
        sed -n "${_sum_start},\$p" "$REPORT" 2>/dev/null | grep -qi 'udp' && udp_weak=0
    fi
    [ -n "$total_tests" ] || total_tests=0
    [ -n "$success_tests" ] || success_tests=0
    [ "$total_tests" -gt 0 ] || total_tests=1

    dns_ok=1
    grep -qi "POSSIBLE DNS HIJACK" "$REPORT" 2>/dev/null && dns_ok=0

    # Simple score (0-10) - informative only
    score=10
    [ "$dns_ok" = "0" ] && score=$((score-2))
    [ "${tls12_ok:-0}" = "0" ] && score=$((score-1))
    [ "$score" -lt 0 ] && score=0
    [ "$score" -gt 10 ] && score=10

    echo
    echo "$(T TXT_BLOCKCHECK_FOUND)"
    echo " $params_filtered"
    echo
    echo "$(T TXT_BLOCKCHECK_MOST_STABLE)"
    echo " $params_filtered (${success_tests}/${total_tests})"
    echo
    echo "$(T TXT_BLOCKCHECK_SCORE) ${score} / 10"
    # UI symbols: prefer Unicode on UTF-8 terminals, fallback to ASCII for PuTTY/non-UTF8
    local _sym_ok="✔" _sym_warn="⚠"
    case "${LC_ALL:-}${LANG:-}" in
    *UTF-8*|*utf8*|*Utf8*) : ;;
    *) _sym_ok="[OK]"; _sym_warn="[!]" ;;
    esac
    [ "$dns_ok" = "1" ] && printf "  %s %s\n" "$_sym_ok" "$(T TXT_BLOCKCHECK_SCORE_DNS_OK)" || printf "  %s DNS\n" "$_sym_warn"
    [ "${tls12_ok:-0}" = "1" ] && printf "  %s %s\n" "$_sym_ok" "$(T TXT_BLOCKCHECK_SCORE_TLS12_OK)" || printf "  %s TLS12\n" "$_sym_warn"
    [ "${udp_weak:-1}" = "1" ] && printf "  %s %s\n" "$_sym_warn" "$(T TXT_BLOCKCHECK_SCORE_UDP_WEAK)"
    echo

    while :; do
        echo "$(T TXT_BLOCKCHECK_ACTION_MENU)"
        read -r -p "$(T TXT_BLOCKCHECK_ACTION_PROMPT) " ans
        ans="$(echo "$ans" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        case "$ans" in
            1)
                set_dpi_profile "blockcheck_auto"
                set_dpi_origin "auto"
                printf "%s\n" "$params_filtered" > "$BLOCKCHECK_AUTO_PARAMS_FILE" 2>/dev/null
                printf "%s\n" "$params_filtered" > "$DPI_PROFILE_PARAMS_FILE" 2>/dev/null
                update_nfqws_parameters >/dev/null 2>&1
                restart_zapret >/dev/null 2>&1 || /opt/etc/init.d/S90-zapret start >/dev/null 2>&1
                echo "$(T TXT_BLOCKCHECK_APPLIED)"
                break
            ;;
            2)
                echo
                echo "$params_filtered"
                echo
                press_enter
            ;;
            3)
                # Save only (do not switch current profile / restart)
                printf "%s\n" "$params_filtered" > "$BLOCKCHECK_AUTO_PARAMS_FILE" 2>/dev/null
                printf "%s\n" "$params_filtered" > "$DPI_PROFILE_PARAMS_FILE" 2>/dev/null
                echo "$(T TXT_BLOCKCHECK_SUMMARY_SAVED) $SUMMARY_FILE"
                break
            ;;
            0|"")
                break
            ;;
            *)
                :
            ;;
        esac
    done
fi

    fi

    # Summary mode: keep only the summary file (avoid creating an extra large report file) (avoid creating an extra large report file)
    if [ -n "$src_report" ] && [ -f "$src_report" ]; then
        rm -f "$src_report" >/dev/null 2>&1
    fi

    echo "$(T TXT_BLOCKCHECK_SUMMARY_SAVED) $summary_file"
    press_enter_to_continue
}

blockcheck_test_menu() {
    while true; do
        clear
        print_line
        echo "$(T TXT_BLOCKCHECK_TEST_TITLE)"
        print_line
        echo " 1. $(T TXT_BLOCKCHECK_FULL)"
        echo " 2. $(T TXT_BLOCKCHECK_SUMMARY)"
        echo " 3. $(T TXT_BLOCKCHECK_CLEAN)"
        echo " 0. $(T TXT_BACK)"
        print_line
        read -r -p "$(T TXT_CHOICE) " ch
        case "$ch" in
            1) run_blockcheck_full ;;
            2) run_blockcheck_save_summary ;;
            3) clean_blockcheck_reports; press_enter_to_continue ;;
            0) return ;;
            *) echo "$(T TXT_INVALID_CHOICE)"; press_enter_to_continue ;;
        esac
    done
}



# --------------------------------------------------
# Zapret backup/restore (.txt) - /opt/zapret/ipset -> /opt/zapret_backups
# --------------------------------------------------
backup_restore_menu() {
    local BACKUP_BASE SRC_DIR CUR_DIR HIST_DIR TS
    BACKUP_BASE="/opt/zapret_backups"
    SRC_DIR="/opt/zapret/ipset"
    CUR_DIR="${BACKUP_BASE}/current"
    HIST_DIR="${BACKUP_BASE}/history"

    mkdir -p "$CUR_DIR" "$HIST_DIR" 2>/dev/null

    while true; do
        clear
print_line "="
        echo "$(T TXT_BACKUP_MENU_TITLE)"
        print_line "-"
        printf "%s %s
" "$(T TXT_BACKUP_BASE_PATH)" "$BACKUP_BASE"
        printf "%s %s
" "$(T TXT_ZAPRET_SETTINGS_BACKUP_DIR)" "$BACKUP_BASE/zapret_settings"
print_line "="
        echo "  $(T TXT_BACKUP_SUB_BACKUP)"
        echo "  $(T TXT_BACKUP_SUB_RESTORE)"
        echo "  $(T TXT_BACKUP_SUB_SHOW)"
        echo "  $(T TXT_BACKUP_SUB_CFG_BACKUP)"
        echo "  $(T TXT_BACKUP_SUB_CFG_RESTORE)"
        echo "  $(T TXT_BACKUP_SUB_CFG_SHOW)"
        echo "  $(T TXT_BACKUP_SUB_BACK)"
        print_line "-"
        printf "%s: " "$(T TXT_SELECT_ACTION)"
        read -r CH

        case "$CH" in
            1)
                # Backup: copy all existing .txt files to current + history timestamp
                if [ ! -d "$SRC_DIR" ] || ! ls "$SRC_DIR"/*.txt >/dev/null 2>&1; then
                    echo "$(T TXT_BACKUP_NO_SRC)"
                    read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                    continue
                fi
                TS="$(date +%Y%m%d_%H%M%S)"
                mkdir -p "$HIST_DIR/$TS" 2>/dev/null
                for f in "$SRC_DIR"/*.txt; do
                    [ -f "$f" ] || continue
                    cp -a "$f" "$CUR_DIR/$(basename "$f")" 2>/dev/null
                    cp -a "$f" "$HIST_DIR/$TS/$(basename "$f")" 2>/dev/null
                done
                echo "$(T TXT_BACKUP_DONE)"
                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                ;;
            2)
                # Restore: let user pick a file from current backups
                if [ ! -d "$CUR_DIR" ] || ! ls "$CUR_DIR"/*.txt >/dev/null 2>&1; then
                    echo "$(T TXT_BACKUP_NO_BACKUP)"
                    read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                    continue
                fi
                restore_single_from_current "$CUR_DIR" "$SRC_DIR"
                ;;
            3)
                clear
print_line "="
                echo "$(T TXT_BACKUP_MENU_TITLE)"
        printf "%s %s\n" "$(T TXT_BACKUP_BASE_PATH)" "$BACKUP_BASE"
print_line "="
                echo
                echo "[current]"
                ls -la "$CUR_DIR" 2>/dev/null | sed -n '1,200p'
                echo
                echo "[history - last 5]"
                ls -1 "$HIST_DIR" 2>/dev/null | tail -n 5
                print_line "-"
                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                ;;
            4)
                backup_zapret_settings "$BACKUP_BASE"
                ;;
            5) zapret_restore_menu "$BACKUP_BASE" ;;
            6)
                show_zapret_settings_backups "$BACKUP_BASE"
                ;;
            0)
                return 0
                ;;
            *)
                ;;
        esac
    done
}

restore_single_from_current() {
    # $1: current backup dir, $2: src dir
    local CUR_DIR SRC_DIR i f files sel
    CUR_DIR="$1"
    SRC_DIR="$2"
    mkdir -p "$SRC_DIR" 2>/dev/null

    # build file list
    files=""
    for f in "$CUR_DIR"/*.txt; do
        [ -f "$f" ] || continue
        files="${files}${f}
"
    done

    if [ -z "$files" ]; then
        echo "$(T TXT_BACKUP_NO_BACKUP)"
        read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
        return 0
    fi

    while true; do
        clear
print_line "="
        echo "$(T TXT_BACKUP_MENU_TITLE)"
print_line "="
        echo "$(T TXT_SELECT_FILE):"
        print_line "-"
        i=1
        for f in $files; do
            [ -f "$f" ] || continue
            echo " $i. $(basename "$f")"
            i=$((i+1))
        done
        echo " $(T TXT_BACKUP_SUB_BACK_LIST)"
        print_line "-"
        printf "%s: " "$(T TXT_SELECT_ACTION)"
        read -r sel
        [ "$sel" = "0" ] && return 0

        i=1
        for f in $files; do
            [ -f "$f" ] || continue
            if [ "$sel" = "$i" ]; then
                cp -a "$f" "$SRC_DIR/$(basename "$f")" 2>/dev/null
                echo "$(T TXT_RESTORE_DONE)"
                # Restore sonrasi zapret'i yeniden baslat (kurallar tekrar uygulansin)
                if is_zapret_installed; then
        echo "$(T TXT_RESTORE_RESTARTING)"
        # Menu 5 ile ayni akisi kullan: stop/resume/start + WAN pin kontrolleri
        if restart_zapret; then
            echo "$(T TXT_RESTORE_RESTART_OK)"
        else
            echo "$(T TXT_RESTORE_RESTART_FAIL)"
        fi
    fi
                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                return 0
            fi
            i=$((i+1))
        done
    done
}
backup_zapret_settings() {
    # Back up Zapret settings (config + key state files) into a tar.gz under BACKUP_BASE/zapret_settings
    BACKUP_BASE="${1:-/opt/zapret_backups}"
    DEST_DIR="$BACKUP_BASE/zapret_settings"
    mkdir -p "$DEST_DIR" 2>/dev/null

    TS="$(date +%Y%m%d_%H%M%S)"
    ARCHIVE="$DEST_DIR/zapret_settings_${TS}.tar.gz"

    # Build relative path list safely (only include existing files/dirs)
    RELS=""
    add_rel() {
        _p="$1"
        [ -e "$_p" ] || return 0
        RELS="$RELS ${_p#/}"
        return 0
    }

    add_rel "/opt/zapret/config"
    add_rel "/opt/zapret/wan_if"
    add_rel "/opt/zapret/lang"
    add_rel "/opt/zapret/hostlist_mode"
    add_rel "/opt/zapret/ipset_clients.txt"
    add_rel "/opt/zapret/ipset_clients_mode"

    # include host lists if present (user/auto)
    for f in /opt/zapret/ipset/zapret-hosts-*.txt; do
        [ -e "$f" ] || break
        add_rel "$f"
    done

    # nothing to back up?
    if [ -z "$(echo "$RELS" | tr -d ' ')" ]; then
        print_status WARN "$(T TXT_BACKUP_CFG_NO_FILES)"
        read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
        return 0
    fi

    # create archive (busybox tar is usually available)
    tar -C / -czf "$ARCHIVE" $RELS 2>/dev/null
    if [ $? -ne 0 ] || [ ! -s "$ARCHIVE" ]; then
        rm -f "$ARCHIVE" 2>/dev/null
        print_status FAIL "$(T backup_tar_fail 'Yedekleme basarisiz.' 'Backup failed.')"
        read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
        return 1
    fi

    print_status PASS "$(printf "$(T TXT_BACKUP_CFG_BACKED_UP)" "$ARCHIVE")"
    read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
    return 0
}


clean_zapret_settings_backups() {
    BACKUP_BASE="${1:-$BACKUP_BASE}"

    # Backward compatible:
    # - Newer builds:   $BACKUP_BASE/zapret_settings/zapret_settings_*.tar.gz
    # - Older builds:   $BACKUP_BASE/zapret_settings_*.tar.gz
    local DIR_NEW="$BACKUP_BASE/zapret_settings"
    local DIR_OLD="$BACKUP_BASE"

    # Screen
    command -v clear >/dev/null 2>&1 && clear || true
    echo "==========================================================="
    echo "$(T TXT_ZAPRET_SETTINGS_CLEAN_MENU)"
    echo "==========================================================="
    echo "$(T TXT_ZAPRET_SETTINGS_BACKUP_DIR) $BACKUP_BASE/zapret_settings"
    echo "==========================================================="
    echo "$(T TXT_ZAPRET_SETTINGS_CLEAN_CONFIRM)"
    print_line

    echo " 1) $(T TXT_YES)"
    echo " 0) $(T TXT_NO)"
    print_line
    printf "%s " "$(T TXT_CHOICE)"

    local ans
    read -r ans

    case "$ans" in
        1|y|Y|e|E)
            local removed=0

            # Delete in both possible locations.
            # shellcheck disable=SC2039
            if [ -d "$DIR_NEW" ]; then
                # If there are matches, delete them.
                if ls "$DIR_NEW"/zapret_settings_*.tar.gz >/dev/null 2>&1; then
                    rm -f "$DIR_NEW"/zapret_settings_*.tar.gz 2>/dev/null && removed=1
                fi
            fi

            if ls "$DIR_OLD"/zapret_settings_*.tar.gz >/dev/null 2>&1; then
                rm -f "$DIR_OLD"/zapret_settings_*.tar.gz 2>/dev/null && removed=1
            fi

            if [ "$removed" -eq 1 ]; then
                print_status PASS "$(T TXT_ZAPRET_SETTINGS_CLEAN_DONE)"
            else
                print_status WARN "$(T TXT_ZAPRET_SETTINGS_CLEAN_NONE)"
            fi
            ;;
        *)
            print_status INFO "$(T TXT_CANCELLED)"
            ;;
    esac

    pause
}




list_zapret_settings_backups() {
    BACKUP_BASE="${1:-/opt/zapret_backups}"
    DIR="$BACKUP_BASE/zapret_settings"
    [ -d "$DIR" ] || return 1
    ls -1 "$DIR"/zapret_settings_*.tar.gz 2>/dev/null | sort -r
}

show_zapret_settings_backups() {
    BACKUP_BASE="${1:-/opt/zapret_backups}"
    DIR="$BACKUP_BASE/zapret_settings"
    if [ ! -d "$DIR" ] || ! ls "$DIR"/zapret_settings_*.tar.gz >/dev/null 2>&1; then
        print_status WARN "$(T TXT_BACKUP_CFG_NO_BACKUPS)"
        read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
        return 0
    fi
    clear
print_line "="
    echo "$(T TXT_BACKUP_MENU_TITLE)"
print_line "="
    echo
    ls -la "$DIR" 2>/dev/null | sed -n '1,200p'
    print_line "-"
    read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
    return 0
}

restore_zapret_settings() {
    # $1 = BACKUP_BASE (root folder that contains zapret_settings/)
    local BACKUP_BASE="${1:-$(get_backup_base_path 2>/dev/null)}"
    local SETTINGS_DIR="${BACKUP_BASE%/}/zapret_settings"

    clear_screen
    print_line "="
    printf "%s\n" "$(T TXT_ZAPRET_SETTINGS_RESTORE_TITLE)"
    print_line "="
    printf "%s\n" "$(T TXT_BACKUP_BASE_PATH) ${BACKUP_BASE}"
    print_line "-"
    printf "\n"

    if [ ! -d "$SETTINGS_DIR" ]; then
        print_status WARN "$(T TXT_BACKUP_NO_BACKUPS_FOUND)"
        pause_anykey
        return 1
    fi

    # List backups (newest first). Expected: zapret_settings_YYYYmmdd_HHMMSS.tar.gz
    local backups
    backups="$(ls -1t "$SETTINGS_DIR"/zapret_settings_*.tar.gz 2>/dev/null)"
    if [ -z "$backups" ]; then
        print_status WARN "$(T TXT_BACKUP_NO_BACKUPS_FOUND)"
        pause_anykey
        return 1
    fi

    printf "%s\n" "$(T TXT_SELECT_BACKUP_TO_RESTORE)"
    print_line "-"

    local i=0 b
    for b in $backups; do
        i=$((i+1))
        printf " %2d) %s\n" "$i" "$(basename "$b")"
        [ "$i" -ge 15 ] && break
    done
    printf "  c) %s
" "$(T TXT_ZAPRET_SETTINGS_CLEAN_MENU)"
    printf "  0) %s
" "$(T TXT_BACK)"
    print_line "-"
    printf "%s" "$(T TXT_CHOICE)"
    read -r sel
    [ -z "$sel" ] && return 0
    if echo "$sel" | grep -Eq "^[cC]$"; then
        clean_zapret_settings_backups
        restore_zapret_settings
        return 0
    fi
    if [ "$sel" = "0" ]; then
        return 0
    fi
    if ! echo "$sel" | grep -Eq '^[0-9]+$'; then
        print_status WARN "$(T TXT_INVALID_CHOICE)"
        pause_anykey
        return 1
    fi

    local chosen=""
    i=0
    for b in $backups; do
        i=$((i+1))
        if [ "$i" -eq "$sel" ]; then
            chosen="$b"
            break
        fi
        [ "$i" -ge 15 ] && break
    done
    if [ -z "$chosen" ] || [ ! -f "$chosen" ]; then
        print_status WARN "$(T TXT_INVALID_CHOICE)"
        pause_anykey
        return 1
    fi

    clear_screen
    printf "%s\n" "$(T TXT_ZAPRET_RESTORE_SUBMENU_TITLE)"
    print_line "-"
    printf " 1. %s\n" "$(T TXT_RESTORE_SCOPE_FULL)"
    printf " 2. %s\n" "$(T TXT_RESTORE_SCOPE_DPI)"
    printf " 3. %s\n" "$(T TXT_RESTORE_SCOPE_HOSTLIST)"
    printf " 4. %s\n" "$(T TXT_RESTORE_SCOPE_IPSET)"
    printf " 5. %s\n" "$(T TXT_RESTORE_SCOPE_NFQWS)"
    print_line "-"
    printf " 0. %s\n" "$(T TXT_BACK)"
    print_line "-"
    printf "%s" "$(T TXT_CHOICE)"
    read -r scope
    [ -z "$scope" ] && return 0
    if [ "$scope" = "0" ]; then
        return 0
    fi

    local tmp="/tmp/zapret_settings_restore.$$"
    rm -rf "$tmp" 2>/dev/null
    mkdir -p "$tmp" || { print_status FAIL "$(T TXT_BACKUP_RESTORE_FAILED)"; pause_anykey; return 1; }

    # Extract to temp first (safer), then copy selected paths
    if ! tar -xzf "$chosen" -C "$tmp" >/dev/null 2>&1; then
        rm -rf "$tmp" 2>/dev/null
        print_status FAIL "$(T TXT_BACKUP_RESTORE_FAILED)"
        pause_anykey
        return 1
    fi

    local src="$tmp"
    # Some archives may include leading ./ or an extra top folder. Normalize:
    if [ -d "$tmp/opt" ]; then
        src="$tmp"
    else
        # pick first directory that contains opt/
        local d
        for d in "$tmp"/*; do
            if [ -d "$d/opt" ]; then src="$d"; break; fi
        done
    fi

    # Helper: copy a path if present (dir -> merge contents; file -> overwrite)
    _copy_if_exists() {
        local p="$1"
        local src_path="$src/$p"
        local dst_path="/$p"

        if [ -d "$src_path" ]; then
            mkdir -p "$dst_path" 2>/dev/null
            # Copy directory contents to avoid nested dir like /opt/zapret/ipset/ipset
            cp -a "$src_path/." "$dst_path/" 2>/dev/null || return 1
            return 0
        fi

        if [ -e "$src_path" ]; then
            mkdir -p "/$(dirname "$p")" 2>/dev/null
            cp -a "$src_path" "$dst_path" 2>/dev/null || return 1
            return 0
        fi

        return 1
    }

    # Varsayılan: işlem başarılı kabul edilir. Zorunlu parçalar yoksa/başarısızsa ok=1 yapılır.
    local ok=0
    case "$scope" in
        1) # full restore
            cp -a "$src/"* / 2>/dev/null || ok=1
            ;;
        2) # DPI settings
            _copy_if_exists "opt/zapret/config" || ok=1
            _copy_if_exists "opt/zapret/lang" || ok=1
            _copy_if_exists "opt/zapret/wan_if" || ok=1
            _copy_if_exists "opt/zapret/dpi_profile" || true
            ;;
        3) # hostlist / autohostlist
            _copy_if_exists "opt/zapret/hostlist_mode" || ok=1
            _copy_if_exists "opt/zapret/hostlist" || true
            _copy_if_exists "opt/zapret/autohostlist" || true
            _copy_if_exists "opt/zapret/hostlists" || true
            ;;
        4) # ipset settings
            _copy_if_exists "opt/zapret/ipset_clients.txt" || true
            _copy_if_exists "opt/zapret/ipset" || true
            _copy_if_exists "opt/zapret/ipset_mode" || true
            ;;
        5) # nfqws config only
            _copy_if_exists "opt/zapret/config" || ok=1
            ;;
        *)
            rm -rf "$tmp" 2>/dev/null
            print_status WARN "$(T TXT_INVALID_CHOICE)"
            pause_anykey
            return 1
            ;;
    esac

    rm -rf "$tmp" 2>/dev/null

    if [ "$ok" -eq 0 ]; then
        print_status PASS "$(T TXT_BACKUP_RESTORE_DONE)"
		# Restore sonrasi zapret'i yeniden baslat (kurallar tekrar uygulansin)
		if is_zapret_installed; then
			echo "$(T TXT_RESTORE_RESTARTING)"
			if restart_zapret; then
				print_status PASS "$(T TXT_RESTORE_RESTART_OK)"
			else
				print_status WARN "$(T TXT_RESTORE_RESTART_WARN)"
			fi
		fi
    else
        print_status FAIL "$(T TXT_BACKUP_RESTORE_FAILED)"
    fi
    pause_anykey
}

zapret_restore_menu() {
    local BACKUP_BASE="$1"
    restore_zapret_settings "$BACKUP_BASE"
}




# -------------------------------------------------------------------
# TELEGRAM NOTIFICATIONS (CONFIG + TEST)
# -------------------------------------------------------------------
TG_CONF_FILE="/opt/etc/telegram.conf"

telegram_load_config() {
    TG_BOT_TOKEN=""
    TG_CHAT_ID=""
    [ -f "$TG_CONF_FILE" ] && . "$TG_CONF_FILE" 2>/dev/null
    # validate minimal
    [ -n "$TG_BOT_TOKEN" ] && [ -n "$TG_CHAT_ID" ] || return 1
    return 0
}

telegram_mask_token() {
    # prints masked token (first 6 ... last 4)
    local t="$1"
    [ -z "$t" ] && { echo "-"; return; }
    local l="${#t}"
    if [ "$l" -le 12 ]; then
        echo "***"
    else
        echo "$(echo "$t" | cut -c1-6)....$(echo "$t" | rev | cut -c1-4 | rev)"
    fi
}

telegram_send() {
    # $1 message
    local msg="$1"
    telegram_load_config || return 1
    # Use data-urlencode so newlines and special chars render correctly in Telegram.
    msg="$(printf '%b' "$msg")"
    curl -sS -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT_ID}" \
        --data-urlencode "text=${msg}" \
        --data-urlencode "disable_web_page_preview=1" >/dev/null 2>&1
}
tpl_render() {
    # Usage: tpl_render "template" KEY1 "val1" KEY2 "val2" ...
    # Replaces %KEY% in template with the given values (busybox ash compatible)
    local tpl="$1"
    # Built-in timestamp placeholder
    local ts="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
    tpl="${tpl//%TS%/${ts}}"
    shift
    while [ $# -ge 2 ]; do
        local k="$1"
        local v="$2"
        tpl="${tpl//%${k}%/${v}}"
        shift 2
    done
    printf "%b" "$tpl"
}

telegram_write_config() {
    # $1 token, $2 chatid
    local token="$1"
    local chatid="$2"

    mkdir -p /opt/etc 2>/dev/null
    umask 077
    cat >"$TG_CONF_FILE" <<EOF
TG_BOT_TOKEN="$token"
TG_CHAT_ID="$chatid"
EOF
    chmod 600 "$TG_CONF_FILE" 2>/dev/null
}

telegram_notifications_menu() {
    while true; do
        clear
        print_line "="
        echo "$(T TXT_TG_SETTINGS_TITLE)"
        print_line "="
        echo
        if telegram_load_config; then
            print_line "-"
            printf "%b\n" "${CLR_BOLD}${CLR_GREEN}$(T TXT_TG_STATUS_ACTIVE)${CLR_RESET}"
            print_line "-"
            echo "  Token : $(telegram_mask_token "$TG_BOT_TOKEN")"
            echo "  ChatID: $TG_CHAT_ID"
        else
            print_line "-"
            printf "%b\n" "${CLR_BOLD}${CLR_YELLOW}$(T TXT_TG_STATUS_NOT_CONFIG)${CLR_RESET}"
            print_line "-"
            echo "  $TG_CONF_FILE"
        fi
        echo
        print_line "-"
        echo " 1) $(T TXT_TG_SAVE_UPDATE)"
        echo " 2) $(T TXT_TG_SEND_TEST)"
        echo " 3) $(T TXT_TG_DELETE_RESET)"
        echo " 0) $(T TXT_BACK)"
        print_line "-"
        printf "%s" "$(T TXT_CHOICE) "
        read -r c
        clear
        case "$c" in
            1)
                echo "$(T TXT_TG_ENTER_TOKEN)"
                read -r token
                echo "$(T TXT_TG_ENTER_CHATID)"
                read -r chatid

                # simple validation
                case "$token" in
                    *:*) : ;;
                    *) print_status FAIL "$(T TXT_TG_ERR_TOKEN_FORMAT)" ; press_enter_to_continue ; continue ;;
                esac
                case "$chatid" in
                    -[0-9]*|[0-9]*) : ;;
                    *) print_status FAIL "$(T TXT_TG_ERR_CHATID_NUM)" ; press_enter_to_continue ; continue ;;
                esac

                telegram_write_config "$token" "$chatid"
                if telegram_send "$(T TXT_TG_TEST_SAVED_MSG)"; then
                    print_status PASS "$(T TXT_TG_SAVED_AND_TEST_OK)"
                else
                    print_status WARN "$(T TXT_TG_SAVED_BUT_TEST_FAIL)"
                fi
                press_enter_to_continue
                ;;
            2)
                if telegram_send "$(T TXT_TG_TEST_OK_MSG)"; then
                    print_status PASS "$(T TXT_TG_TEST_SENT)"
                else
                    print_status FAIL "$(T TXT_TG_TEST_FAIL_CONFIG_FIRST)"
                fi
                press_enter_to_continue
                ;;
            3)
                rm -f "$TG_CONF_FILE" 2>/dev/null
                print_status PASS "$(T TXT_TG_CONFIG_DELETED)"
                press_enter_to_continue
                ;;
            0) return 0 ;;
            *) echo "$(T TXT_INVALID_CHOICE)" ; sleep 1 ;;
        esac
    done
}

# -------------------------------------------------------------------
# SYSTEM HEALTH MONITOR (MOD B): CPU/RAM/DISK/LOAD + ZAPRET WATCHDOG
# -------------------------------------------------------------------
HM_CONF_FILE="/opt/etc/healthmon.conf"
HM_PID_FILE="/tmp/healthmon.pid"
HM_LOCKDIR="/tmp/healthmon.lock"
HM_LOG_FILE="/tmp/healthmon.log"

HM_AUTOSTART_FILE="/opt/etc/init.d/S99zkm_healthmon"
# defaults (used if config missing)
HM_ENABLE="0"
HM_INTERVAL="30"
HM_CPU_WARN="70"
HM_CPU_WARN_DUR="180"
HM_CPU_CRIT="90"
HM_CPU_CRIT_DUR="60"
HM_DISK_WARN="90"          # percent used on /opt
HM_RAM_WARN_MB="40"        # free+buffers+cached approximation in MB
HM_ZAPRET_WATCHDOG="1"
HM_ZAPRET_COOLDOWN_SEC="120"
HM_ZAPRET_AUTORESTART="0"
HM_HEARTBEAT_SEC="300"
HM_COOLDOWN_SEC="600"
HM_ZAPRET_COOLDOWN_SEC="120"

healthmon_load_config() {
    HM_ENABLE="0"
    HM_INTERVAL="30"
    HM_CPU_WARN="70"
    HM_CPU_WARN_DUR="180"
    HM_CPU_CRIT="90"
    HM_CPU_CRIT_DUR="60"
    HM_DISK_WARN="90"
    HM_RAM_WARN_MB="40"
    HM_ZAPRET_WATCHDOG="1"
    HM_COOLDOWN_SEC="600"
    HM_ZAPRET_COOLDOWN_SEC="120"

    [ -f "$HM_CONF_FILE" ] && . "$HM_CONF_FILE" 2>/dev/null
}

healthmon_write_config() {
    mkdir -p /opt/etc 2>/dev/null
    umask 077
    cat >"$HM_CONF_FILE" <<EOF
HM_ENABLE="$HM_ENABLE"
HM_INTERVAL="$HM_INTERVAL"
HM_CPU_WARN="$HM_CPU_WARN"
HM_CPU_WARN_DUR="$HM_CPU_WARN_DUR"
HM_CPU_CRIT="$HM_CPU_CRIT"
HM_CPU_CRIT_DUR="$HM_CPU_CRIT_DUR"
HM_DISK_WARN="$HM_DISK_WARN"
HM_RAM_WARN_MB="$HM_RAM_WARN_MB"
HM_ZAPRET_WATCHDOG="$HM_ZAPRET_WATCHDOG"
HM_COOLDOWN_SEC="$HM_COOLDOWN_SEC"
HM_ZAPRET_COOLDOWN_SEC="$HM_ZAPRET_COOLDOWN_SEC"
HM_ZAPRET_AUTORESTART="$HM_ZAPRET_AUTORESTART"
HM_HEARTBEAT_SEC="$HM_HEARTBEAT_SEC"
EOF
    chmod 600 "$HM_CONF_FILE" 2>/dev/null
}

healthmon_cpu_pct() {
    # busybox-safe CPU usage from /proc/stat
    # prints integer 0-100
    local a b c idle rest
    read cpu a b c idle rest < /proc/stat
    local t1=$((a+b+c+idle))
    local i1=$idle
    sleep 1
    read cpu a b c idle rest < /proc/stat
    local t2=$((a+b+c+idle))
    local i2=$idle
    local dt=$((t2-t1))
    local di=$((i2-i1))
    [ "$dt" -le 0 ] && { echo 0; return; }
    echo $(( (100*(dt-di))/dt ))
}

healthmon_loadavg() {
    # returns "1m 5m 15m"
    uptime 2>/dev/null | awk -F'load average: ' '{print $2}' | tr -d '\r'
}

healthmon_disk_used_pct() {
    # $1 mountpoint
    df -P "$1" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}'
}

healthmon_mem_free_mb() {
    # approximated available = MemFree+Buffers+Cached (kB) -> MB
    awk '
        /^MemFree:/ {mf=$2}
        /^Buffers:/ {b=$2}
        /^Cached:/ {c=$2}
        END { printf "%d\n", (mf+b+c)/1024 }
    ' /proc/meminfo 2>/dev/null
}

healthmon_now() { date +%s; }


healthmon_log() {
    # $1 line
    [ -n "$HM_LOG_FILE" ] || return 0
    # best-effort append
    echo "$1" >>"$HM_LOG_FILE" 2>/dev/null
}
healthmon_should_alert() {
    # $1 key (file suffix), $2 cooldown
    local key="$1"
    local cooldown="$2"
    local f="/tmp/healthmon_last_${key}.ts"
    local now
    now=$(healthmon_now)
    local last=0
    [ -f "$f" ] && last=$(cat "$f" 2>/dev/null)
    [ -z "$last" ] && last=0
    [ $((now-last)) -ge "$cooldown" ] || return 1
    echo "$now" >"$f" 2>/dev/null
    return 0
}

healthmon_loop() {
    trap '' HUP 2>/dev/null
    # single-instance guard
    if ! mkdir "$HM_LOCKDIR" 2>/dev/null; then
        # already running
        exit 0
    fi
    echo "$$" >"$HM_PID_FILE" 2>/dev/null
    : >"$HM_LOG_FILE" 2>/dev/null
    echo "$(date +%s) | started" >>"$HM_LOG_FILE" 2>/dev/null

    # state files for duration tracking
    local cpu_warn_start="/tmp/healthmon_cpu_warn.start"
    local cpu_crit_start="/tmp/healthmon_cpu_crit.start"
    local disk_start="/tmp/healthmon_disk.start"
    local ram_start="/tmp/healthmon_ram.start"
    local zapret_start="/tmp/healthmon_zapret_down.start"
    local zapret_flag="/tmp/healthmon_zapret_down.flag"
    local zapret_restart_flag="/tmp/healthmon_zapret_restart.tried"
    local hb_ts="/tmp/healthmon_heartbeat.ts"

    while true; do
        healthmon_load_config
        [ "$HM_ENABLE" = "1" ] || break

        local now cpu load disk ram
        now=$(healthmon_now)
        cpu=$(healthmon_cpu_pct)
        load=$(healthmon_loadavg)
        disk=$(healthmon_disk_used_pct /opt)
        ram=$(healthmon_mem_free_mb)

        # ---- CPU WARN ----
        if [ "$cpu" -ge "$HM_CPU_WARN" ]; then
            [ -f "$cpu_warn_start" ] || echo "$now" >"$cpu_warn_start"
            local st=$(cat "$cpu_warn_start" 2>/dev/null)
            local el=$((now-st))
            if [ "$el" -ge "$HM_CPU_WARN_DUR" ]; then
                if healthmon_should_alert "cpu_warn" "$HM_COOLDOWN_SEC"; then
                    telegram_send "$(tpl_render "$(T TXT_HM_CPU_WARN_MSG)" CPU "$cpu" LOAD "$load" RAM "$ram" DISK "$disk")"
                        healthmon_log "$now | cpu_warn | cpu=$cpu load=$load ram=${ram}MB disk=${disk}%"
                fi
                rm -f "$cpu_warn_start" 2>/dev/null
            fi
        else
            rm -f "$cpu_warn_start" 2>/dev/null
        fi

        # ---- CPU CRIT ----
        if [ "$cpu" -ge "$HM_CPU_CRIT" ]; then
            [ -f "$cpu_crit_start" ] || echo "$now" >"$cpu_crit_start"
            local stc=$(cat "$cpu_crit_start" 2>/dev/null)
            local elc=$((now-stc))
            if [ "$elc" -ge "$HM_CPU_CRIT_DUR" ]; then
                if healthmon_should_alert "cpu_crit" "$HM_COOLDOWN_SEC"; then
                    telegram_send "$(tpl_render "$(T TXT_HM_CPU_CRIT_MSG)" CPU "$cpu" LOAD "$load" RAM "$ram" DISK "$disk")"
                        healthmon_log "$now | cpu_crit | cpu=$cpu load=$load ram=${ram}MB disk=${disk}%"
                fi
                rm -f "$cpu_crit_start" 2>/dev/null
            fi
        else
            rm -f "$cpu_crit_start" 2>/dev/null
        fi

        # ---- DISK ----
        if [ -n "$disk" ] && [ "$disk" -ge "$HM_DISK_WARN" ]; then
            [ -f "$disk_start" ] || echo "$now" >"$disk_start"
            local sd=$(cat "$disk_start" 2>/dev/null)
            local eld=$((now-sd))
            if [ "$eld" -ge 60 ]; then
                if healthmon_should_alert "disk" "$HM_COOLDOWN_SEC"; then
                    telegram_send "$(tpl_render "$(T TXT_HM_DISK_WARN_MSG)" CPU "$cpu" LOAD "$load" RAM "$ram" DISK "$disk")"
                        healthmon_log "$now | disk_warn | cpu=$cpu load=$load ram=${ram}MB disk=${disk}%"
                fi
                rm -f "$disk_start" 2>/dev/null
            fi
        else
            rm -f "$disk_start" 2>/dev/null
        fi

        # ---- RAM ----
        if [ -n "$ram" ] && [ "$ram" -le "$HM_RAM_WARN_MB" ]; then
            [ -f "$ram_start" ] || echo "$now" >"$ram_start"
            local sr=$(cat "$ram_start" 2>/dev/null)
            local elr=$((now-sr))
            if [ "$elr" -ge 60 ]; then
                if healthmon_should_alert "ram" "$HM_COOLDOWN_SEC"; then
                    telegram_send "$(tpl_render "$(T TXT_HM_RAM_WARN_MSG)" CPU "$cpu" LOAD "$load" RAM "$ram" DISK "$disk")"
                        healthmon_log "$now | ram_warn | cpu=$cpu load=$load ram=${ram}MB disk=${disk}%"
                fi
                rm -f "$ram_start" 2>/dev/null
            fi
        else
            rm -f "$ram_start" 2>/dev/null
        fi

        # ---- Zapret watchdog ----
        if [ "$HM_ZAPRET_WATCHDOG" = "1" ]; then
            if is_zapret_installed && ! is_zapret_running; then
                [ -f "$zapret_start" ] || echo "$now" >"$zapret_start"
                local sz=$(cat "$zapret_start" 2>/dev/null)
                local elz=$((now-sz))
                if [ "$elz" -ge 30 ]; then
                    # optional auto-restart: try once per down event, and only notify if restart fails
                    local restart_ok="0"
                    if [ "$HM_ZAPRET_AUTORESTART" = "1" ] && [ ! -f "$zapret_restart_flag" ]; then
                        echo "1" >"$zapret_restart_flag" 2>/dev/null
                        start_zapret >/dev/null 2>&1
                        sleep 1
                        if is_zapret_running; then
                            restart_ok="1"
                            # Notify "UP" immediately to reduce panic
                            if healthmon_should_alert "zapret_up" "$HM_ZAPRET_COOLDOWN_SEC"; then
                                telegram_send "$(tpl_render "$(T TXT_HM_ZAPRET_UP_MSG)" CPU "$cpu" LOAD "$load" RAM "$ram" DISK "$disk")"
                                healthmon_log "$now | zapret_autorestart_ok | cpu=$cpu load=$load ram=${ram}MB disk=${disk}%"
                            fi
                            # clear state to allow future down events to re-attempt restart
                            rm -f "$zapret_flag" 2>/dev/null
                            rm -f "$zapret_restart_flag" 2>/dev/null
                            rm -f "$zapret_start" 2>/dev/null
                            continue
                        fi
                    fi

                    # If still down here, notify only when cooldown allows
                    if [ "$restart_ok" != "1" ]; then
                        if healthmon_should_alert "zapret_down" "$HM_ZAPRET_COOLDOWN_SEC"; then
                            telegram_send "$(tpl_render "$(T TXT_HM_ZAPRET_DOWN_MSG)" CPU "$cpu" LOAD "$load" RAM "$ram" DISK "$disk")"
                            healthmon_log "$now | zapret_down | cpu=$cpu load=$load ram=${ram}MB disk=${disk}%"
                            echo "1" >"$zapret_flag" 2>/dev/null
                        fi
                        rm -f "$zapret_start" 2>/dev/null
                    fi
                fi
            else
                # recovered
                if [ -f "$zapret_flag" ] && is_zapret_installed && is_zapret_running; then
                    if healthmon_should_alert "zapret_up" "$HM_ZAPRET_COOLDOWN_SEC"; then
                        telegram_send "$(tpl_render "$(T TXT_HM_ZAPRET_UP_MSG)" CPU "$cpu" LOAD "$load" RAM "$ram" DISK "$disk")"
                        healthmon_log "$now | zapret_up | cpu=$cpu load=$load ram=${ram}MB disk=${disk}%"
                    fi
                    rm -f "$zapret_flag" 2>/dev/null
                    rm -f "$zapret_restart_flag" 2>/dev/null
                fi
                rm -f "$zapret_start" 2>/dev/null
            fi
        fi


        # ---- Heartbeat log (no Telegram) ----
        if [ -n "$HM_HEARTBEAT_SEC" ] && [ "$HM_HEARTBEAT_SEC" -gt 0 ] 2>/dev/null; then
            local last_hb=$(cat "$hb_ts" 2>/dev/null)
            [ -z "$last_hb" ] && last_hb=0
            if [ $((now-last_hb)) -ge "$HM_HEARTBEAT_SEC" ]; then
                local zst="n/a"
                if is_zapret_installed; then
                    is_zapret_running && zst="up" || zst="down"
                else
                    zst="not_installed"
                fi
                # Heartbeat: log at most once per HM_HEARTBEAT_SEC
                if [ "${HM_HEARTBEAT_SEC:-0}" -gt 0 ]; then
                    last_hb="$(cat "$hb_ts" 2>/dev/null)"
                    case "$last_hb" in
                        ''|*[!0-9]*) last_hb=0 ;;
                    esac
                    if [ $((now - last_hb)) -ge "$HM_HEARTBEAT_SEC" ]; then
                        echo "$now" > "$hb_ts" 2>/dev/null
                        chmod 600 "$hb_ts" 2>/dev/null
                        healthmon_log "$now | heartbeat | cpu=$cpu load=$load ram=${ram}MB disk=${disk}% zapret=$zst"
                    fi
                fi
                echo "$now" >"$hb_ts" 2>/dev/null
            fi
        fi

        sleep "$HM_INTERVAL"
    done

    rm -f "$HM_PID_FILE" 2>/dev/null
    rmdir "$HM_LOCKDIR" 2>/dev/null
}

healthmon_is_running() {
  [ -f /tmp/healthmon.pid ] || return 1
  PID="$(cat /tmp/healthmon.pid 2>/dev/null)"
  [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null
}


healthmon_autostart_install() {
    # Ensure HealthMon starts after reboot when enabled
    mkdir -p /opt/etc/init.d 2>/dev/null
    cat > "$HM_AUTOSTART_FILE" <<'EOF'
#!/opt/bin/sh
# Auto-start for ZKM Health Monitor (Entware init.d)
SCRIPT="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh"
CONF="/opt/etc/healthmon.conf"
PIDFILE="/tmp/healthmon.pid"
LOCKDIR="/tmp/healthmon.lock"

start() {
  # Start only if enabled
  if [ -f "$CONF" ] && grep -q '^HM_ENABLE="1"' "$CONF" 2>/dev/null; then
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
      return 0
    fi
    "$SCRIPT" --healthmon-daemon </dev/null >/tmp/healthmon.log 2>&1 &
  fi
}

stop() {
  if [ -f "$PIDFILE" ]; then
    kill "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null
    rm -f "$PIDFILE" 2>/dev/null
  fi
  rm -rf "$LOCKDIR" 2>/dev/null
}

case "$1" in
  start) start ;;
  stop) stop ;;
  restart) stop; start ;;
  *) start ;;
esac
exit 0
EOF
    chmod 755 "$HM_AUTOSTART_FILE" 2>/dev/null
}

healthmon_autostart_remove() {
    rm -f "$HM_AUTOSTART_FILE" 2>/dev/null
}

healthmon_start() {
    # already running? don't spawn a 2nd daemon
    healthmon_is_running && return 0

    healthmon_load_config
    HM_ENABLE="1"
    healthmon_write_config


    healthmon_autostart_install
    # If already running, do nothing
    if healthmon_is_running; then
        return 0
    fi

    # Clear stale state (safe)
    rm -f "$HM_PID_FILE" /tmp/healthmon.log 2>/dev/null
    rm -rf "$HM_LOCKDIR" 2>/dev/null

    # Start as a detached daemon by re-invoking this script
    if command -v nohup >/dev/null 2>&1; then
        nohup "$0" --healthmon-daemon </dev/null >/tmp/healthmon.log 2>&1 &
    else
        "$0" --healthmon-daemon </dev/null >/tmp/healthmon.log 2>&1 &
    fi

    # Wait up to 5s for PID to appear and process to be alive (BusyBox-safe)
    local i pid
    for i in 1 2 3 4 5; do
        pid="$(cat "$HM_PID_FILE" 2>/dev/null)"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        sleep 1
    done

    # Failed to start: cleanup any stale state
    rm -f "$HM_PID_FILE" 2>/dev/null
    rm -rf "$HM_LOCKDIR" 2>/dev/null
    return 1
}


healthmon_stop() {
    HM_ENABLE="0"
    healthmon_write_config

    healthmon_autostart_remove
    if [ -f "$HM_PID_FILE" ]; then
        kill "$(cat "$HM_PID_FILE" 2>/dev/null)" 2>/dev/null
        rm -f "$HM_PID_FILE" 2>/dev/null
    fi
    rmdir "$HM_LOCKDIR" 2>/dev/null
}

healthmon_status() {
    healthmon_load_config
    local run="OFF"
    healthmon_is_running && run="ON"
    local cpu load disk ram
    cpu=$(healthmon_cpu_pct)
    load=$(healthmon_loadavg)
    disk=$(healthmon_disk_used_pct /opt)
    ram=$(healthmon_mem_free_mb)

    local pid=""
    [ -f "$HM_PID_FILE" ] && pid="$(cat "$HM_PID_FILE" 2>/dev/null)"
    echo "$(T _ 'Calisiyor:' 'Running:') $run (enable=${HM_ENABLE}${pid:+, pid=$pid})"
    echo "  Interval : ${HM_INTERVAL}s"
    echo "  CPU WARN : %${HM_CPU_WARN} / ${HM_CPU_WARN_DUR}s"
    echo "  CPU CRIT : %${HM_CPU_CRIT} / ${HM_CPU_CRIT_DUR}s"
    echo "  Disk(/opt) WARN : ${HM_DISK_WARN}%"
    echo "  RAM WARN : <= ${HM_RAM_WARN_MB} MB"
    echo "  Zapret watchdog : ${HM_ZAPRET_WATCHDOG}"
    echo "  Zapret cooldown : ${HM_ZAPRET_COOLDOWN_SEC}s"
    echo "  Cooldown : ${HM_COOLDOWN_SEC}s"
    echo
    echo "  Now -> CPU: %${cpu} | Load: ${load} | RAM free: ${ram} MB | Disk(/opt): ${disk}%"
}

healthmon_test() {
    local cpu load disk ram
    cpu=$(healthmon_cpu_pct)
    load=$(healthmon_loadavg)
    disk=$(healthmon_disk_used_pct /opt)
    ram=$(healthmon_mem_free_mb)
    telegram_send "$(tpl_render "$(T TXT_HM_TEST_MSG)" CPU "$cpu" LOAD "$load" RAM "$ram" DISK "$disk")"
}

health_monitor_menu() {
    while true; do
        clear
        print_line "="
        echo "$(T TXT_HM_TITLE)"
        print_line "="
        echo
        healthmon_load_config
        local run="OFF"
        healthmon_is_running && run="ON"
        print_line "-"
        if [ "$run" = "ON" ]; then
            printf "%b\n" "${CLR_BOLD}${CLR_GREEN}$(T TXT_HM_STATUS) ON (enable=${HM_ENABLE})${CLR_RESET}"
        else
            printf "%b\n" "${CLR_BOLD}${CLR_RED}$(T TXT_HM_STATUS) OFF (enable=${HM_ENABLE})${CLR_RESET}"
        fi
        print_line "-"
        echo "CPU WARN %${HM_CPU_WARN}/${HM_CPU_WARN_DUR}s  |  CPU CRIT %${HM_CPU_CRIT}/${HM_CPU_CRIT_DUR}s"
        echo "Disk(/opt) >= ${HM_DISK_WARN}%  |  RAM <= ${HM_RAM_WARN_MB} MB  |  Load via uptime"
        echo "Zapret watchdog: ${HM_ZAPRET_WATCHDOG}  |  Interval: ${HM_INTERVAL}s"
        echo
        print_line "-"
        echo " 1) $(T TXT_HM_ENABLE_DISABLE)"
        echo " 2) $(T TXT_HM_SHOW_STATUS)"
        echo " 3) $(T TXT_HM_SEND_TEST)"
        echo " 4) $(T TXT_HM_CONFIG_THRESHOLDS)"
        echo " 0) $(T TXT_BACK)"
        print_line "-"
        printf "%s" "$(T TXT_CHOICE) "
        read -r c
        clear
        case "$c" in
1)
    # Toggle based on *actual* daemon state (not only HM_ENABLE flag)
    # This prevents "OFF (enable=1)" showing, then option 1 trying to stop a non-running daemon.
    if healthmon_is_running; then
        healthmon_stop
        print_status PASS "$(T TXT_HM_DISABLED)"
    else
        healthmon_start
        print_status PASS "$(T TXT_HM_ENABLED)"
    fi
    press_enter_to_continue
    ;;
            2)
                healthmon_status
                press_enter_to_continue
                ;;
            3)
                if healthmon_test; then
                    print_status PASS "$(T TXT_HM_TEST_SENT)"
                else
                    print_status WARN "$(T TXT_HM_NEED_TG)"
                fi
                press_enter_to_continue
                ;;
            4)
                healthmon_load_config
                echo "$(T TXT_HM_PROMPT_CPU_WARN)"
                read -r v; [ -n "$v" ] && HM_CPU_WARN="$v"
                echo "$(T TXT_HM_PROMPT_CPU_WARN_DUR)"
                read -r v; [ -n "$v" ] && HM_CPU_WARN_DUR="$v"

                echo "$(T TXT_HM_PROMPT_CPU_CRIT)"
                read -r v; [ -n "$v" ] && HM_CPU_CRIT="$v"
                echo "$(T TXT_HM_PROMPT_CPU_CRIT_DUR)"
                read -r v; [ -n "$v" ] && HM_CPU_CRIT_DUR="$v"

                echo "$(T TXT_HM_PROMPT_DISK_WARN)"
                read -r v; [ -n "$v" ] && HM_DISK_WARN="$v"

                echo "$(T TXT_HM_PROMPT_RAM_WARN)"
                read -r v; [ -n "$v" ] && HM_RAM_WARN_MB="$v"

                echo "$(T TXT_HM_PROMPT_ZAPRET_WD)"
                read -r v; [ -n "$v" ] && HM_ZAPRET_WATCHDOG="$v"

                echo "$(T TXT_HM_PROMPT_ZAPRET_COOLDOWN)"
                read -r v; [ -n "$v" ] && HM_ZAPRET_COOLDOWN_SEC="$v"

                echo "$(T TXT_HM_PROMPT_ZAPRET_AUTORESTART)"
                read -r v; [ -n "$v" ] && HM_ZAPRET_AUTORESTART="$v"

                echo "$(T _ 'Interval (sn) [or: 30]:' 'Interval (sec) [e.g. 30]:' )"
                read -r v; [ -n "$v" ] && HM_INTERVAL="$v"

                echo "$(T _ 'Cooldown (sn) [or: 600]:' 'Cooldown (sec) [e.g. 600]:' )"
                read -r v; [ -n "$v" ] && HM_COOLDOWN_SEC="$v"

                # sanitize numeric (best-effort)
                for k in HM_CPU_WARN HM_CPU_WARN_DUR HM_CPU_CRIT HM_CPU_CRIT_DUR HM_DISK_WARN HM_RAM_WARN_MB HM_INTERVAL HM_COOLDOWN_SEC HM_ZAPRET_WATCHDOG HM_ZAPRET_COOLDOWN_SEC HM_ZAPRET_AUTORESTART HM_HEARTBEAT_SEC; do
                    eval val=\$$k
                    case "$val" in
                        ''|*[!0-9-]*) : ;; # keep as-is; user responsibility
                    esac
                done

                healthmon_write_config

                # restart loop if running
                if healthmon_is_running; then
                    healthmon_stop
                    healthmon_start
                fi

                print_status PASS "$(T _ 'Ayarlar kaydedildi.' 'Settings saved.')"
                press_enter_to_continue
                ;;
            0) return 0 ;;
            *) echo "$(T TXT_INVALID_CHOICE)" ; sleep 1 ;;
        esac
    done
}

check_script_location_once
main_menu_loop() {
    while true; do
    clear  # clear_on_start_main_loop
        display_menu
        read -r choice
    clear  # clear_after_choice_main
        echo ""
        case "$choice" in
        c|C)
            clean_zapret_settings_backups
            restore_zapret_settings
            return 0
            ;;
            1) install_zapret; press_enter_to_continue ;;
            2) uninstall_zapret ;;
            3) start_zapret; press_enter_to_continue ;;
            4) stop_zapret; press_enter_to_continue ;;
            5) restart_zapret; press_enter_to_continue ;;
            6) check_remote_update ;;
        10) check_manager_update ;;
        7) configure_zapret_ipv6_support ;;
        8) backup_restore_menu ;;
        9)
            while true; do
                if select_dpi_profile; then
                    apply_dpi_profile_now
                else
                    break
                fi
            done
            ;;
        11) manage_hostlist_menu ;;
            12) manage_ipset_clients ;;
        13) script_rollback_menu ;;
        14) run_health_check ;;
        15) telegram_notifications_menu ;;
        16) health_monitor_menu ;;
B|b) blockcheck_test_menu ;;
L|l) toggle_lang ;; 
            0) echo "Cikis yapiliyor..."; break ;;
            *) echo "Gecersiz secim! Lutfen 0 ile 16 arasinda bir sayi girin." ;;
        esac
        echo ""
    done
}


# Internal: run health monitor loop as a detached daemon
if [ "$1" = "--healthmon-daemon" ]; then
    # ignore hangup when parent shell exits
    trap '' HUP 2>/dev/null
    healthmon_loop
    exit 0
fi

# --- Betigin Baslangic Noktasi ---
# Kullanım: ./script.sh cleanup  -> Zapret kurulu olmasa bile kalıntıları temizler
if [ "$1" = "cleanup" ]; then
    cleanup_only_leftovers
    exit 0
fi

main_menu_loop

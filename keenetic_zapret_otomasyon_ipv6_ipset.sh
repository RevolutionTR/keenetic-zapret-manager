#!/bin/sh
#
# keenetic_zapret_otomasyon_ipv6_ipset.sh
#
# Author: RevolutionTR
# GitHub: https://github.com/RevolutionTR
#
# Copyright (C) 2027 RevolutionTR
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

# BETIK BILGILENDIRME                                 
# Notepad++ da Duzen > Satir Sonunu Donustur > UNIX (LF)

# -------------------------------------------------------------------
# Script Kimligi (Repo/Surum)
# -------------------------------------------------------------------
SCRIPT_NAME="keenetic_zapret_otomasyon_ipv6_ipset.sh"
# Version scheme: vYY.M.D[.N]  (YY=year, M=month, D=day, N=daily revision)
SCRIPT_VERSION="v26.2.23"
SCRIPT_REPO="https://github.com/RevolutionTR/keenetic-zapret-manager"
ZKM_SCRIPT_PATH="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh"
SCRIPT_AUTHOR="RevolutionTR"

# Daemon icin +x gerekli; "sh script.sh" ile calisinca izin olmasa da menu acilir
# ama healthmon baslatilamaz. Script her calistiginda otomatik duzelt.
[ -x "$ZKM_SCRIPT_PATH" ] || chmod +x "$ZKM_SCRIPT_PATH" 2>/dev/null
# -------------------------------------------------------------------


# -------------------------------------------------------------------
# BEGIN_SESSION_GUARD_V3
# Amac:
# - SSH / shellinabox oturumu kopunca (/dev/pts/* (deleted)) scriptin
#   arkada asili kalmasini engellemek
# - Ayni anda birden fazla script instance'ini engellemek
# -------------------------------------------------------------------
ZKM_LOCKDIR="/tmp/keenetic_zapret_mgr.lock"
ZKM_SELF_PID="$$"

# Acquire lock (mkdir is atomic)
# NOTE: Internal daemon modes must bypass the main session lock,
# otherwise they cannot start while the UI script is open.
ZKM_SKIP_LOCK="0"
case "$1" in
    --healthmon-daemon) ZKM_SKIP_LOCK="1" ;;
    --self-test)        ZKM_SKIP_LOCK="1" ; ZKM_SELF_TEST="1" ;;
    --dev|--developer)  ZKM_DEV_CHECK="1" ;;
esac


# Developer / Self-test flags
ZKM_SELF_TEST="${ZKM_SELF_TEST:-0}"
ZKM_DEV_CHECK="${ZKM_DEV_CHECK:-0}"

zkm_self_test() {
    local f="$0"
    local fail=0 warn=0
    _pass() { echo "PASS $*"; }
    _warn() { echo "WARN $*"; warn=$((warn+1)); }
    _fail() { echo "FAIL $*"; fail=$((fail+1)); }

    echo "=== ZKM Self-Test ==="
    echo "File: $f"

    # 1) Syntax
    if sh -n "$f" 2>/tmp/zkm_selftest_syntax.err; then
        _pass "syntax: sh -n OK"
    else
        _fail "syntax: sh -n FAILED (see /tmp/zkm_selftest_syntax.err)"
    fi

    # 2) Turkish letters (byte-level)
    local found_tr=0 pat
    for pat in \
      $'\xC5\x9E' $'\xC5\x9F' \
      $'\xC4\x9E' $'\xC4\x9F' \
      $'\xC4\xB0' $'\xC4\xB1' \
      $'\xC3\x96' $'\xC3\xB6' \
      $'\xC3\x87' $'\xC3\xA7' \
      $'\xC3\x9C' $'\xC3\xBC'
    do
      if grep -oba "$pat" "$f" >/dev/null 2>&1; then
        found_tr=1
        break
      fi
    done
    if [ "$found_tr" -eq 1 ]; then
        _fail "TR letters detected - keep ASCII for menus"
    else
        _pass "TR letters: none (byte-verified)"
    fi

    # 3) Translation coverage: used TXT_* keys must have _TR and _EN
    local miss="/tmp/zkm_selftest_missing.txt"
    : > "$miss"
    grep -oE '(^|[^A-Z0-9_])T[[:space:]]+TXT_[A-Z0-9_]+' "$f" 2>/dev/null \
      | sed -E 's/^.*T[[:space:]]+(TXT_[A-Z0-9_]+).*$/\1/' \
      | sort -u \
      | while IFS= read -r k; do
            grep -qE "^${k}_TR=" "$f" 2>/dev/null || echo "${k}_TR" >> "$miss"
            grep -qE "^${k}_EN=" "$f" 2>/dev/null || echo "${k}_EN" >> "$miss"
        done

    if [ -s "$miss" ]; then
        _fail "missing translations found (see $miss)"
        head -n 30 "$miss" | sed 's/^/  - /'
        local cnt
        cnt="$(wc -l < "$miss" 2>/dev/null)"
        [ -n "$cnt" ] && [ "$cnt" -gt 30 ] && echo "  ... (+$((cnt-30)) more)"
    else
        _pass "translations: all used TXT_* have TR+EN"
        rm -f "$miss" 2>/dev/null
    fi

    # 4) Telegram config (optional)
    if [ -f /opt/etc/telegram.conf ]; then
        . /opt/etc/telegram.conf 2>/dev/null
        if [ -n "$TG_BOT_TOKEN" ] && [ -n "$TG_CHAT_ID" ]; then
            _pass "telegram: config present"
        else
            _warn "telegram: config exists but token/chat_id missing"
        fi
    else
        _warn "telegram: /opt/etc/telegram.conf not found (optional)"
    fi

    # 5) HealthMon auto-start (optional)
    if [ -f /opt/etc/healthmon.conf ]; then
        . /opt/etc/healthmon.conf 2>/dev/null
        if [ "${HM_ENABLE:-0}" = "1" ]; then
            local pid
            pid="$(cat /tmp/healthmon.pid 2>/dev/null)"
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                _pass "healthmon: enabled and running (pid=$pid)"
            else
                _warn "healthmon: enabled but not running"
            fi
        else
            _pass "healthmon: disabled"
        fi
    else
        _warn "healthmon: /opt/etc/healthmon.conf not found (optional)"
    fi

    echo "=== Summary: FAIL=$fail WARN=$warn ==="
    [ "$fail" -eq 0 ]
}

# Run self-test and exit
if [ "$ZKM_SELF_TEST" = "1" ]; then
    zkm_self_test
    exit $?
fi

# Optional developer check (silent). No dependency for users.
if [ "$ZKM_DEV_CHECK" = "1" ] && [ -x /opt/etc/zkm_guard.sh ]; then
    /opt/bin/sh /opt/etc/zkm_guard.sh "$0" >/dev/null 2>&1
fi


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

    # Forceful exit helper: in BusyBox ash, "exit" inside a trap handler may fail
    # to terminate the shell when deep in nested function calls (e.g., during
    # healthmon_start's sleep loop). kill -KILL $$ guarantees termination.
    _zkm_force_exit() {
        zkm_cleanup
        trap - EXIT INT TERM HUP 2>/dev/null
        kill -KILL $$ 2>/dev/null
        exit "$1" 2>/dev/null
    }

    # Always cleanup the lock
    trap 'zkm_cleanup' EXIT

    # Extra traps: ensure Ctrl-C (INT) and disconnect signals actually EXIT
    trap '_zkm_force_exit 130' INT
    trap '_zkm_force_exit 143' TERM
    trap '_zkm_force_exit 129' HUP
    trap '_zkm_force_exit 148' TSTP
    trap '_zkm_force_exit 150' TTIN
    trap '_zkm_force_exit 151' TTOU

    # END_SESSION_GUARD_V3
fi

# -------------------------------------------------------------------
# Dogru Dizin Uyarisi (keenetic / keenetic-zapret)
# -------------------------------------------------------------------

#------ Komple Kaldirma ---------------------------------------------------------------
# KZM + Zapret tam temiz kaldirma (UNSAFE / irreversible)
# Not: "Zapret’i Kaldir" (mevcut) rutini aynen calisir, sonra KZM kalintilari temizlenir.
# TR/EN Dictionary (Komple Kaldirma)
TXT_ZKM_FULL_UNINSTALL_TITLE_TR="KZM + Zapret Kaldirma (Tam Temiz)"
TXT_ZKM_FULL_UNINSTALL_TITLE_EN="KZM + Zapret Uninstall (Full Clean)"

TXT_ZKM_FULL_UNINSTALL_WARN1_TR="Bu islem Zapret'i kaldirir ve KZM'nin HealthMon/Telegram ayarlarini, init dosyalarini ve log/state dosyalarini temizler."
TXT_ZKM_FULL_UNINSTALL_WARN1_EN="This will uninstall Zapret and clean KZM HealthMon/Telegram configs, init files, and log/state files."

TXT_ZKM_FULL_UNINSTALL_WARN2_TR="Islem geri alinamaz. Devam etmeden once yedek aldiginizdan emin olun."
TXT_ZKM_FULL_UNINSTALL_WARN2_EN="This action is irreversible. Make sure you have a backup before continuing."

TXT_ZKM_FULL_UNINSTALL_PROMPT1_TR="Devam etmek icin BUYUK HARFLE 'EVET' yazin (iptal icin Enter): "
TXT_ZKM_FULL_UNINSTALL_PROMPT1_EN="Type 'YES' (uppercase) to continue (press Enter to cancel): "

TXT_ZKM_FULL_UNINSTALL_PROMPT2_TR="Son onay: BUYUK HARFLE 'KALDIR' yazin (iptal icin Enter): "
TXT_ZKM_FULL_UNINSTALL_PROMPT2_EN="Final confirm: type 'REMOVE' (uppercase) (press Enter to cancel): "

TXT_ZKM_FULL_UNINSTALL_CANCEL_TR="Iptal edildi."
TXT_ZKM_FULL_UNINSTALL_CANCEL_EN="Cancelled."

TXT_ZKM_FULL_UNINSTALL_HINT_TR="Iptal icin ENTER'a basin."
TXT_ZKM_FULL_UNINSTALL_HINT_EN="Press ENTER to cancel."

TXT_ZKM_FULL_UNINSTALL_PHASE1_TR="1/2: Zapret kaldiriliyor..."
TXT_ZKM_FULL_UNINSTALL_PHASE1_EN="1/2: Uninstalling Zapret..."

TXT_ZKM_FULL_UNINSTALL_PHASE2_TR="2/2: KZM kalintilari temizleniyor..."
TXT_ZKM_FULL_UNINSTALL_PHASE2_EN="2/2: Cleaning KZM leftovers..."

TXT_ZKM_FULL_UNINSTALL_STEP1_TR="1/2: Zapret kaldiriliyor (mevcut kaldirma rutini)..."
TXT_ZKM_FULL_UNINSTALL_STEP1_EN="1/2: Removing Zapret (existing uninstall routine)..."

TXT_ZKM_FULL_UNINSTALL_STEP2_TR="2/2: KZM kalintilari temizleniyor..."
TXT_ZKM_FULL_UNINSTALL_STEP2_EN="2/2: Cleaning KZM leftovers..."

TXT_ZKM_FULL_UNINSTALL_DONE_TR="Tam temiz kaldirma tamamlandi."
TXT_ZKM_FULL_UNINSTALL_DONE_EN="Full clean uninstall completed."

TXT_ZKM_FULL_UNINSTALL_NOTE_TR="Not: Bu islemin ardindan betik artik calismayacaktir."
TXT_ZKM_FULL_UNINSTALL_NOTE_EN="Note: After this, the script will no longer be available."

TXT_ZKM_FULL_UNINSTALL_SCRIPT_NOTE_TR="Betik dosyasi guvenlik nedeniyle silinmedi. Isterseniz manuel olarak silebilirsiniz."
TXT_ZKM_FULL_UNINSTALL_SCRIPT_NOTE_EN="Script file was not removed for safety. You may delete it manually if desired."
zkm_full_uninstall() {
	    clear
	    print_line "=" 120
	    echo "$(T TXT_ZKM_FULL_UNINSTALL_TITLE)"
	    print_line "=" 120
	    echo ""
    print_status WARN "$(T TXT_ZKM_FULL_UNINSTALL_WARN1)"
    print_status WARN "$(T TXT_ZKM_FULL_UNINSTALL_WARN2)"
    echo ""
    print_status INFO "$(T TXT_ZKM_FULL_UNINSTALL_HINT)"
    echo ""

	    printf "%s" "$(T TXT_ZKM_FULL_UNINSTALL_PROMPT1)"
	    read -r _ans1
	    if [ -z "$_ans1" ] || ( [ "$_ans1" != "EVET" ] && [ "$_ans1" != "YES" ] ); then
        print_status INFO "$(T TXT_ZKM_FULL_UNINSTALL_CANCEL)"
        press_enter_to_continue
        return 0
    fi

	    printf "%s" "$(T TXT_ZKM_FULL_UNINSTALL_PROMPT2)"
	    read -r _ans2
	    if [ -z "$_ans2" ] || ( [ "$_ans2" != "KALDIR" ] && [ "$_ans2" != "REMOVE" ] ); then
        print_status INFO "$(T TXT_ZKM_FULL_UNINSTALL_CANCEL)"
        press_enter_to_continue
        return 0
    fi

    echo ""
    print_status INFO "$(T TXT_ZKM_FULL_UNINSTALL_STEP1)"
    uninstall_zapret

    echo ""
    print_status INFO "$(T TXT_ZKM_FULL_UNINSTALL_STEP2)"

    # Stop HealthMon daemon if running
    if [ -f /tmp/healthmon.pid ]; then
        _pid="$(cat /tmp/healthmon.pid 2>/dev/null)"
        [ -n "$_pid" ] && kill "$_pid" 2>/dev/null
        rm -f /tmp/healthmon.pid 2>/dev/null
    fi
    rm -rf /tmp/healthmon.lock 2>/dev/null

    # Remove HealthMon / Telegram configs (KZM-owned)
    rm -f /opt/etc/healthmon.conf /opt/etc/healthmon.conf.bak 2>/dev/null
    rm -f /opt/etc/telegram.conf 2>/dev/null

    # Remove init autostart (if created by KZM)
    rm -f /opt/etc/init.d/S99zkm_healthmon 2>/dev/null

    # Remove state/log files (KZM/HealthMon/WANMon)
    rm -f /opt/etc/healthmon_update.state 2>/dev/null
    rm -f /tmp/zkm_autoupdate.log 2>/dev/null
    rm -f /tmp/healthmon.log 2>/dev/null
    rm -f /tmp/healthmon_* /tmp/wanmon.* 2>/dev/null

    # Remove helper/wrapper commands created by this script
    rm -f /opt/bin/keenetic /opt/bin/keenetic-zapret /opt/bin/kzm /opt/bin/KZM 2>/dev/null

    # Remove KZM backup files (script backups)
    rm -f /opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh.bak_* 2>/dev/null
    # Script file is NOT removed (safety)

    echo ""
    print_status OK "$(T TXT_ZKM_FULL_UNINSTALL_DONE)"
    print_status INFO "$(T TXT_ZKM_FULL_UNINSTALL_SCRIPT_NOTE)"
    press_enter_to_continue
    exit 0
}

# -------------------------------------------------------------------
# Dogru Dizin Uyarisi (keenetic / keenetic-zapret)
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
    WRAP3="/opt/bin/kzm"
    WRAP4="/opt/bin/KZM"

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

    # kzm sadece yoksa olustur
    if [ ! -e "$WRAP3" ]; then
        ln -s "$WRAP1" "$WRAP3" 2>/dev/null || cp -a "$WRAP1" "$WRAP3"
        chmod +x "$WRAP3" 2>/dev/null
    fi

    # KZM (buyuk harf) sadece yoksa olustur
    if [ ! -e "$WRAP4" ]; then
        ln -s "$WRAP1" "$WRAP4" 2>/dev/null || cp -a "$WRAP1" "$WRAP4"
        chmod +x "$WRAP4" 2>/dev/null
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
    CLR_ORANGE="$(printf '\033[38;5;214m')"
    CLR_BOLD="$(printf '\033[1m')"
    CLR_DIM="$(printf '\033[2m')"
    CLR_RESET="$(printf '\033[0m')"
else
    CLR_CYAN=""
    CLR_YELLOW=""
    CLR_GREEN=""
    CLR_RED=""
    CLR_ORANGE=""
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

# --- Health helpers (used by Health Score layout) ---
check_dns_local() {
    nslookup github.com 127.0.0.1 >/dev/null 2>&1
}

check_dns_external() {
    nslookup github.com 8.8.8.8 >/dev/null 2>&1
}

check_dns_consistency() {
    local dns_local_ip dns_pub_ip
    dns_local_ip="$(nslookup github.com 127.0.0.1 2>/dev/null | awk '/^Address [0-9]+:/{print $3; exit}')"
    dns_pub_ip="$(nslookup github.com 8.8.8.8 2>/dev/null | awk '/^Address [0-9]+:/{print $3; exit}')"
    [ -n "$dns_local_ip" ] && [ -n "$dns_pub_ip" ] && [ "$dns_local_ip" = "$dns_pub_ip" ]
}

check_ntp() {
    local now_epoch
    now_epoch="$(date +%s 2>/dev/null)"
    [ -n "$now_epoch" ] && [ "$now_epoch" -gt 1609459200 ] 2>/dev/null
}

check_github() {
    local code
    code="$(curl -I -m 8 -s -o /dev/null -w '%{http_code}' https://api.github.com/ 2>/dev/null)"
    case "$code" in
        2*|3*) return 0 ;;
        *) return 1 ;;
    esac
}

check_opkg() {
    command -v opkg >/dev/null 2>&1 && opkg --version >/dev/null 2>&1
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

# Zapret installed version (from file). Safe if not installed.
ZAPRET_VERSION_FILE="/opt/zapret/version"

zkm_get_zapret_version() {
    local v
    # Default fallback comes from TR/EN dictionary variables (no hardcoded literals here)
    v="$(T TXT_UNKNOWN "$TXT_UNKNOWN_TR" "$TXT_UNKNOWN_EN")"
    if [ -r "$ZAPRET_VERSION_FILE" ]; then
        v="$(head -n 1 "$ZAPRET_VERSION_FILE" 2>/dev/null | tr -d '
')"
        [ -n "$v" ] || v="$(T TXT_UNKNOWN "$TXT_UNKNOWN_TR" "$TXT_UNKNOWN_EN")"
    fi
    printf "%s" "$v"
}

# ---- Main banner live status helpers (safe, minimal) ----
zkm_banner_ndmc_ok() {
    command -v ndmc >/dev/null 2>&1 || return 1
    ndmc -c 'show version' >/dev/null 2>&1
}

zkm_banner_get_ndmc_field() {
    # $1: field name (e.g., "model:")
    [ -n "$1" ] || return 1
    ndmc -c 'show version' 2>/dev/null | tr -d '\r' | awk -v f="$1" '$1==f{ $1=""; sub(/^[ \t]+/,""); print; exit }'
}

# KN numarasindan cihaz adi dondurur
_zkm_kn_to_name() {
    case "$1" in
        KN-1010) echo "Keenetic Giga (KN-1010)"           ;;
        KN-1011) echo "Keenetic Giga (KN-1011)"           ;;
        KN-1012) echo "Keenetic Giga (KN-1012)"           ;;
        KN-1110) echo "Keenetic Start (KN-1110)"          ;;
        KN-1111) echo "Keenetic Start (KN-1111)"          ;;
        KN-1112) echo "Keenetic Start (KN-1112)"          ;;
        KN-1121) echo "Keenetic Starter (KN-1121)"        ;;
        KN-1210) echo "Keenetic 4G (KN-1210)"             ;;
        KN-1211) echo "Keenetic 4G (KN-1211)"             ;;
        KN-1212) echo "Keenetic 4G (KN-1212)"             ;;
        KN-1213) echo "Keenetic 4G (KN-1213)"             ;;
        KN-1221) echo "Keenetic Launcher (KN-1221)"       ;;
        KN-1310) echo "Keenetic Lite (KN-1310)"           ;;
        KN-1311) echo "Keenetic Lite (KN-1311)"           ;;
        KN-1410) echo "Keenetic Omni (KN-1410)"           ;;
        KN-1510) echo "Keenetic City (KN-1510)"           ;;
        KN-1511) echo "Keenetic City (KN-1511)"           ;;
        KN-1610) echo "Keenetic Air (KN-1610)"            ;;
        KN-1611) echo "Keenetic Air (KN-1611)"            ;;
        KN-1613) echo "Keenetic Air (KN-1613)"            ;;
        KN-1621) echo "Keenetic Explorer (KN-1621)"       ;;
        KN-1710) echo "Keenetic Extra (KN-1710)"          ;;
        KN-1711) echo "Keenetic Extra (KN-1711)"          ;;
        KN-1713) echo "Keenetic Extra (KN-1713)"          ;;
        KN-1714) echo "Keenetic Extra (KN-1714)"          ;;
        KN-1721) echo "Keenetic Carrier (KN-1721)"        ;;
        KN-1810) echo "Keenetic Ultra (KN-1810)"          ;;
        KN-1811) echo "Keenetic Ultra (KN-1811)"          ;;
        KN-1812) echo "Keenetic Titan (KN-1812)"          ;;
        KN-1910) echo "Keenetic Viva (KN-1910)"           ;;
        KN-1912) echo "Keenetic Viva (KN-1912)"           ;;
        KN-1913) echo "Keenetic Viva (KN-1913)"           ;;
        KN-2010) echo "Keenetic DSL (KN-2010)"            ;;
        KN-2012) echo "Keenetic Launcher DSL (KN-2012)"   ;;
        KN-2110) echo "Keenetic Duo (KN-2110)"            ;;
        KN-2112) echo "Keenetic Extra DSL / Skipper DSL (KN-2112)" ;;
        KN-2113) echo "Keenetic Speedster DSL (KN-2113)"  ;;
        KN-2210) echo "Keenetic Runner 4G (KN-2210)"      ;;
        KN-2211) echo "Keenetic Runner 4G (KN-2211)"      ;;
        KN-2212) echo "Keenetic Runner 4G (KN-2212)"      ;;
        KN-2310) echo "Keenetic Hero 4G (KN-2310)"        ;;
        KN-2311) echo "Keenetic Hero 4G+ (KN-2311)"       ;;
        KN-2312) echo "Keenetic Hopper 4G+ (KN-2312)"     ;;
        KN-2410) echo "Keenetic Giga SE (KN-2410)"        ;;
        KN-2510) echo "Keenetic Ultra SE (KN-2510)"       ;;
        KN-2610) echo "Keenetic Giant (KN-2610)"          ;;
        KN-2710) echo "Keenetic Peak (KN-2710)"           ;;
        KN-2810) echo "Keenetic Orbiter Pro (KN-2810)"    ;;
        KN-2910) echo "Keenetic Skipper 4G (KN-2910)"     ;;
        KN-2911) echo "Keenetic Speedster 4G+ (KN-2911)"  ;;
        KN-3010) echo "Keenetic Speedster (KN-3010)"      ;;
        KN-3012) echo "Keenetic Speedster (KN-3012)"      ;;
        KN-3013) echo "Keenetic Speedster (KN-3013)"      ;;
        KN-3210) echo "Keenetic Buddy 4 (KN-3210)"        ;;
        KN-3211) echo "Keenetic Buddy 4 (KN-3211)"        ;;
        KN-3310) echo "Keenetic Buddy 5 (KN-3310)"        ;;
        KN-3311) echo "Keenetic Buddy 5 (KN-3311)"        ;;
        KN-3410) echo "Keenetic Buddy 5S (KN-3410)"       ;;
        KN-3411) echo "Keenetic Buddy 6 (KN-3411)"        ;;
        KN-3510) echo "Keenetic Voyager Pro (KN-3510)"    ;;
        KN-3610) echo "Keenetic Hopper DSL (KN-3610)"     ;;
        KN-3611) echo "Keenetic Hopper DSL (KN-3611)"     ;;
        KN-3710) echo "Keenetic Sprinter (KN-3710)"       ;;
        KN-3711) echo "Keenetic Sprinter (KN-3711)"       ;;
        KN-3712) echo "Keenetic Sprinter SE (KN-3712)"    ;;
        KN-3810) echo "Keenetic Hopper (KN-3810)"         ;;
        KN-3811) echo "Keenetic Hopper (KN-3811)"         ;;
        KN-3812) echo "Keenetic Hopper SE (KN-3812)"      ;;
        KN-3910) echo "Keenetic Challenger (KN-3910)"     ;;
        KN-3911) echo "Keenetic Challenger SE (KN-3911)"  ;;
        KN-4010) echo "Keenetic Racer (KN-4010)"          ;;
        KN-4110) echo "Keenetic Hero 5G (KN-4110)"        ;;
        KN-4210) echo "Keenetic Titan SE (KN-4210)"       ;;
        KN-4310) echo "Keenetic Atlas SE (KN-4310)"       ;;
        KN-4410) echo "Keenetic Buddy 6 SE (KN-4410)"     ;;
        KN-4910) echo "Keenetic Explorer 4G (KN-4910)"    ;;
        *)        echo "Keenetic $1"                       ;;
    esac
}

zkm_banner_get_system() {
    local m="" _ver="" _sys="" _kn=""

    # 1) ndmc show version
    _ver="$(ndmc -c show version 2>/dev/null | tr -d '\r')"
    if [ -n "$_ver" ]; then
        m="$(printf '%s\n' "$_ver" | awk -F': ' '
            /model:|description:|product:|device:|hardware:|board:/ {
                gsub(/^[ \t]+|[ \t]+$/, "", $2);
                if ($2 != "") { print $2; exit }
            }')"
        if [ -n "$m" ]; then
            case "$m" in
                KN-[0-9]*) _zkm_kn_to_name "$m"; return 0 ;;
                Keenetic*) echo "$m"; return 0 ;;
                *) echo "Keenetic $m"; return 0 ;;
            esac
        fi
        _kn="$(printf '%s\n' "$_ver" | grep -Eo 'KN-[0-9]{3,5}' | head -1)"
        [ -n "$_kn" ] && { _zkm_kn_to_name "$_kn"; return 0; }
    fi

    # 2) ndmc show system
    _sys="$(ndmc -c show system 2>/dev/null | tr -d '\r')"
    if [ -n "$_sys" ]; then
        m="$(printf '%s\n' "$_sys" | awk -F': ' '
            /model:|description:|product:|device:|hardware:|board:/ {
                gsub(/^[ \t]+|[ \t]+$/, "", $2);
                if ($2 != "") { print $2; exit }
            }')"
        if [ -n "$m" ]; then
            case "$m" in
                KN-[0-9]*) _zkm_kn_to_name "$m"; return 0 ;;
                Keenetic*) echo "$m"; return 0 ;;
                *) echo "Keenetic $m"; return 0 ;;
            esac
        fi
        _kn="$(printf '%s\n' "$_sys" | grep -Eo 'KN-[0-9]{3,5}' | head -1)"
        [ -n "$_kn" ] && { _zkm_kn_to_name "$_kn"; return 0; }
    fi

    # 3) /proc/device-tree/model veya /sys/firmware/devicetree/base/model
    for _f in /proc/device-tree/model /sys/firmware/devicetree/base/model; do
        [ -r "$_f" ] || continue
        m="$(tr -d '\000' <"$_f" 2>/dev/null)"
        [ -z "$m" ] && continue
        _kn="$(echo "$m" | grep -Eo 'KN-[0-9]{3,5}' | head -1)"
        [ -n "$_kn" ] && { _zkm_kn_to_name "$_kn"; return 0; }
        echo "$m"; return 0
    done

    # 4) /etc/components.xml — model="KN-XXXX"
    if [ -r /etc/components.xml ]; then
        _kn="$(grep -o 'model="KN-[0-9]*"' /etc/components.xml 2>/dev/null | head -1 | grep -o 'KN-[0-9]*')"
        [ -n "$_kn" ] && { _zkm_kn_to_name "$_kn"; return 0; }
    fi

    # 5) MTD U-Config partition — ndmhwid=KN-XXXX
    # /proc/mtd'den "U-Config" adli bolumu bul, sadece ilk 64KB oku
    if [ -r /proc/mtd ]; then
        local _mtddev
        _mtddev="$(awk -F'[: "]+' '/U-Config/{print "/dev/"$1"ro"; exit}' /proc/mtd 2>/dev/null)"
        if [ -n "$_mtddev" ] && [ -r "$_mtddev" ]; then
            _kn="$(dd if="$_mtddev" bs=1024 count=64 2>/dev/null | strings | grep -o 'KN-[0-9]*' | head -1)"
            [ -n "$_kn" ] && { _zkm_kn_to_name "$_kn"; return 0; }
        fi
    fi

    echo "Keenetic"
}



zkm_banner_get_firmware() {
    # /etc/components.xml'den firmware versiyonu ve kanal bilgisini okur
    # Cikti: "5.0.6 (Onizleme)" gibi
    local _xml _version _sandbox _channel_tr

    [ -r /etc/components.xml ] || return 1
    _xml="$(cat /etc/components.xml 2>/dev/null)" || return 1

    # Kisa versiyon: <title>5.0.6</title>
    _version="$(printf '%s' "$_xml" | grep -o '<title>[^<]*</title>' | head -1 | sed 's/<title>//;s/<\/title>//')"
    [ -z "$_version" ] && _version="$(printf '%s' "$_xml" | grep -o 'version="[^"]*"' | head -1 | sed 's/version="//;s/"//')"
    [ -z "$_version" ] && return 1

    # Kanal: sandbox="stable|preview|alpha"
    _sandbox="$(printf '%s' "$_xml" | grep -o 'sandbox="[^"]*"' | head -1 | sed 's/sandbox="//;s/"//')"

    # Kanal adini yerellestir
    case "$_sandbox" in
        stable)  _channel_tr="$(T _ 'Kararli'     'Stable')"     ;;
        preview) _channel_tr="$(T _ 'Onizleme'    'Preview')"    ;;
        alpha)   _channel_tr="$(T _ 'Gelistirici' 'Developer')"  ;;
        *)       _channel_tr="$_sandbox"                          ;;
    esac

    if [ -n "$_channel_tr" ]; then
        printf '%s (%s)' "$_version" "$_channel_tr"
    else
        printf '%s' "$_version"
    fi
}

zkm_banner_get_wan_dev() {
    local dev=""

    # Prefer existing WAN detection helpers (used elsewhere in the script)
    dev="$(get_wan_if 2>/dev/null)"
    [ -z "$dev" ] && dev="$(healthmon_detect_wan_iface_ndm 2>/dev/null)"

    # Fallback: parse default route robustly (avoid returning 'link')
    if [ -z "$dev" ]; then
        dev="$(ip route 2>/dev/null | awk '$1=="default"{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
    fi

    printf "%s" "$dev"
}

zkm_banner_get_wan_state() {
    local dev="$1"
    local up

    [ -n "$dev" ] || { echo "DOWN"; return 0; }

    up="$(ip link show "$dev" 2>/dev/null | head -n 1)"
    echo "$up" | grep -q 'LOWER_UP' && { echo "UP"; return 0; }
    echo "$up" | grep -q '<.*UP' && { echo "UP"; return 0; }

    echo "DOWN"
}

zkm_banner_get_zapret_state() {
    if is_zapret_running; then
        echo "RUNNING"
    else
        echo "STOPPED"
    fi
}

zkm_banner_fmt_wan_state() {
    # $1: UP|DOWN
    case "$1" in
        UP)   printf '%b' "${CLR_GREEN}$(T TXT_MAIN_UP)${CLR_RESET}" ;;
        *)    printf '%b' "${CLR_RED}$(T TXT_MAIN_DOWN)${CLR_RESET}" ;;
    esac
}

zkm_banner_fmt_zapret_state() {
    # $1: RUNNING|STOPPED
    case "$1" in
        RUNNING) printf '%b' "${CLR_GREEN}$(T TXT_MAIN_RUNNING)${CLR_RESET}" ;;
        *)       printf '%b' "${CLR_RED}$(T TXT_MAIN_STOPPED)${CLR_RESET}" ;;
    esac
}

zkm_banner_fmt_keendns_state() {
    # $1: direct|cloud|unknown/empty
    case "$1" in
        direct) printf '%b' "${CLR_GREEN}$(T TXT_KEENDNS_DIRECT)${CLR_RESET}" ;;
        cloud)  printf '%b' "${CLR_YELLOW}$(T TXT_KEENDNS_CLOUD)${CLR_RESET}" ;;
        *)      printf '%b' "${CLR_RED}$(T TXT_KEENDNS_UNKNOWN)${CLR_RESET}" ;;
    esac
}




# Sozluk: TXT_*_TR / TXT_*_EN
TXT_MAIN_TITLE_TR="KEENETIC ZAPRET YONETIM ARACI (KZM)"
TXT_MAIN_TITLE_EN="KEENETIC ZAPRET MANAGEMENT TOOL (KZM)"

TXT_OPTIMIZED_TR=" Varsayilan ayarlar TT altyapisinda test edilerek optimize edilmistir."
TXT_OPTIMIZED_EN=" Default settings are tested and optimized for TT infrastructure."

TXT_DPI_WARNING_TR=" DPI profil basarimi; ISS, hat tipine gore degiskenlik gosterebilir."
TXT_DPI_WARNING_EN=" DPI profile effectiveness may vary by ISP, line type."

TXT_DEVELOPER_TR=" Gelistirici : RevolutionTR"
TXT_DEVELOPER_EN=" Developer  : RevolutionTR"

TXT_GITHUB_TR=" GitHub      : github.com/RevolutionTR/keenetic-zapret-manager"
TXT_GITHUB_EN=" GitHub     : github.com/RevolutionTR/keenetic-zapret-manager"

# TXT_EDITOR_TR=" Duzenleyen  : RevolutionTR"
# TXT_EDITOR_EN=" Maintainer : RevolutionTR"

TXT_VERSION_TR=" KZM Surum   : ${SCRIPT_VERSION}"
TXT_VERSION_EN=" KZM Version: ${SCRIPT_VERSION}"

TXT_ZAPRET_VERSION_PREFIX_TR=" Zapret Surum: "
TXT_ZAPRET_VERSION_PREFIX_EN=" Zapret Ver : "

TXT_UNKNOWN_TR="Kurulu Degil"
TXT_UNKNOWN_EN="Not Installed"

TXT_MAIN_SYS_LABEL_TR="Sistem"
TXT_MAIN_SYS_LABEL_EN="System"

TXT_MAIN_WAN_LABEL_TR="WAN"
TXT_MAIN_WAN_LABEL_EN="WAN"

TXT_MAIN_ZAPRET_LABEL_TR="Zapret"
TXT_MAIN_ZAPRET_LABEL_EN="Zapret"

TXT_MAIN_UP_TR="ACIK"
TXT_MAIN_UP_EN="UP"

TXT_MAIN_DOWN_TR="KAPALI"
TXT_MAIN_DOWN_EN="DOWN"

TXT_MAIN_RUNNING_TR="CALISIYOR"
TXT_MAIN_RUNNING_EN="RUNNING"

TXT_MAIN_STOPPED_TR="DURDU"
TXT_MAIN_STOPPED_EN="STOPPED"

TXT_DESC1_TR="Bu arac, Keenetic cihazlarinda Zapret kurulumunu,"
TXT_DESC1_EN="This tool unifies Zapret installation,"

TXT_DESC2_TR="yonetimini ve sistem izlemeyi tek noktada toplayan"
TXT_DESC2_EN="management, and system monitoring"

TXT_DESC3_TR="gelismis bir yonetim cozumudur."
TXT_DESC3_EN="into a centralized solution for Keenetic devices."

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

TXT_MENU_8_TR=" 8. Zapret / KZM Yedekle / Geri Yukle"
TXT_MENU_8_EN=" 8. Zapret / KZM Backup / Restore"

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

TXT_DPI_AUTO_NOTE_TR=" Not: Blockcheck (Otomatik) aktifken asagidaki 1-8 profilleri pasiftir."
TXT_DPI_AUTO_NOTE_EN=" Note: While Blockcheck (Auto) is active, profiles 1-8 below are inactive."

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

TXT_MENU_10_TR="10. Betik Guncelleme Kontrolu (Guncel/Kurulu - GitHub)"
TXT_MENU_10_EN="10. Script update check (Latest/Installed - GitHub)"

TXT_MENU_11_TR="11. Hostlist / Autohostlist (Filtreleme)"
TXT_MENU_11_EN="11. Hostlist / Autohostlist (Filtering)"

TXT_MENU_12_TR="12. IPSET (Statik IP kullanan cihazlarla calisir - DHCP desteklenmez!)"
TXT_MENU_12_EN="12. IPSET (Works with static IP devices - DHCP is not supported!)"

TXT_MENU_13_TR="13. Betik: Yedekten Geri Don (Rollback)"
TXT_MENU_13_EN="13. Script: Roll Back from Backup"

TXT_MENU_14_TR="14. Ag Tanilama ve Sistem Kontrolu (DNS/NTP/GitHub/OPKG/Disk/Zapret)"
TXT_MENU_14_EN="14. Network Diagnostics & System Check (DNS/NTP/GitHub/OPKG/Disk/Zapret)"

TXT_MENU_15_TR="15. Bildirimler (Telegram)"
TXT_MENU_15_EN="15. Notifications (Telegram)"

TXT_MENU_16_TR="16. Sistem Izleme (CPU/RAM/Disk/Load/Zapret)"
TXT_MENU_16_EN="16. System Monitoring (CPU/RAM/Disk/Load/Zapret)"

# -------------------------------------------------------------------
# Telegram notifications
# -------------------------------------------------------------------
TXT_TG_SETTINGS_TITLE_TR="Telegram Bildirim Ayarlari"
TXT_TG_SETTINGS_TITLE_EN="Telegram Notification Settings"

TXT_TG_TIME_LABEL_TR="Zaman "
TXT_TG_TIME_LABEL_EN="Time  "

TXT_TG_MODEL_LABEL_TR="Model "
TXT_TG_MODEL_LABEL_EN="Model "

TXT_TG_WAN_LABEL_TR="WAN IP"
TXT_TG_WAN_LABEL_EN="WAN IP"

TXT_TG_LAN_LABEL_TR="LAN IP"
TXT_TG_LAN_LABEL_EN="LAN IP"

TXT_TG_DEVICE_LABEL_TR="Cihaz"
TXT_TG_DEVICE_LABEL_EN="Router"

TXT_TG_EVENT_LABEL_TR="Olay"
TXT_TG_EVENT_LABEL_EN="Event"

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
TXT_TG_TEST_FAIL_CONFIG_FIRST_EN="Test failed. Configure Token/ChatID first."

TXT_TG_CONFIG_DELETED_TR="Ayar dosyasi silindi."
TXT_TG_CONFIG_DELETED_EN="Config deleted."

TXT_TG_TEST_SAVED_MSG_TR="✅ Telegram Test: Ayarlar kaydedildi"
TXT_TG_TEST_SAVED_MSG_EN="✅ Telegram Test: Settings saved"

TXT_TG_TEST_OK_MSG_TR="✅ Telegram Test: Bildirim calisiyor"
TXT_TG_TEST_OK_MSG_EN="✅ Telegram Test: Notifications working"


# -------------------------------------------------------------------
# Health Monitor (Mod B) notifications
# -------------------------------------------------------------------
TXT_HM_TITLE_TR="Sistem Sagligi Monitoru"
TXT_HM_TITLE_EN="System Health Monitor"

TXT_HM_BANNER_LABEL_TR="Saglik Mon."
TXT_HM_BANNER_LABEL_EN="Health Mon."
TXT_SCHED_BANNER_LABEL_TR="Tekrar Baslat"
TXT_SCHED_BANNER_LABEL_EN="Sched.Reboot"

TXT_HM_MENU_LINE2_TR="Disk(/opt) >= %DISK%%%  |  RAM <= %RAM% MB  |  Load (uptime)"
TXT_HM_MENU_LINE2_EN="Disk(/opt) >= %DISK%%%  |  RAM <= %RAM% MB  |  Load via uptime"

TXT_HM_MENU_LINE3_TR="Zapret watchdog: %WD%  |  Aralik: %INT%s"
TXT_HM_MENU_LINE3_EN="Zapret watchdog: %WD%  |  Interval: %INT%s"

TXT_HM_CFG_TITLE_TR="Saglik Ayarlari"
TXT_HM_CFG_TITLE_EN="Health Settings"

TXT_HM_CFG_ITEM5_TR="Zapret (watchdog)"
TXT_HM_CFG_ITEM5_EN="Zapret (watchdog)"

TXT_HM_CFG_ITEM6_TR="Guncelleme kontrolu"
TXT_HM_CFG_ITEM6_EN="Update check"

TXT_HM_CFG_ITEM7_TR="Oto guncelleme modu"
TXT_HM_CFG_ITEM7_EN="Auto update mode"

TXT_HM_CFG_ITEM8_TR="Aralik (sn)"
TXT_HM_CFG_ITEM8_EN="Interval (sec)"

TXT_HM_CFG_ITEM9_TR="Cooldown (sn)"
TXT_HM_CFG_ITEM9_EN="Cooldown (sec)"

TXT_HM_CFG_ITEM10_TR="Heartbeat (sn)"
TXT_HM_CFG_ITEM10_EN="Heartbeat (sec)"


TXT_HM_CFG_ITEM11_TR="WAN izleme"
TXT_HM_CFG_ITEM11_EN="WAN monitor"

TXT_HM_PROMPT_WANMON_ENABLE_TR="WAN izleme aktif mi?"
TXT_HM_PROMPT_WANMON_ENABLE_EN="Enable WAN monitoring?"
TXT_HM_PROMPT_WANMON_FAIL_TH_TR="DOWN algilama esigi (adet)"
TXT_HM_PROMPT_WANMON_FAIL_TH_EN="DOWN detect threshold (count)"
TXT_HM_PROMPT_WANMON_OK_TH_TR="UP dogrulama esigi (adet)"
TXT_HM_PROMPT_WANMON_OK_TH_EN="UP confirm threshold (count)"

TXT_HM_WAN_DOWN_MSG_TR="🚫 WAN KAPALI (%IF%)"
TXT_HM_WAN_DOWN_MSG_EN="🚫 WAN DOWN (%IF%)"
TXT_HM_WAN_UP_MSG_TR="✅ WAN UP (%IF%)\nKesinti: %DUR%"
TXT_HM_WAN_UP_MSG_EN="✅ WAN UP (%IF%)\nOutage: %DUR%"

# WAN monitor - rich UP notification (Down/Up/Duration labels)
TXT_HM_WAN_UP_TITLE_TR="✅ WAN ACIK (%IF%)"
TXT_HM_WAN_UP_TITLE_EN="✅ WAN UP (%IF%)"
TXT_HM_WAN_DOWN_TIME_LABEL_TR="Kapali"
TXT_HM_WAN_DOWN_TIME_LABEL_EN="Down"
TXT_HM_WAN_UP_TIME_LABEL_TR="Acik"
TXT_HM_WAN_UP_TIME_LABEL_EN="Up"
TXT_HM_WAN_DUR_LABEL_TR="Sure"
TXT_HM_WAN_DUR_LABEL_EN="Duration"

TXT_HM_STATUS_DISK_OPT_TR="Disk(/opt)"
TXT_HM_STATUS_DISK_OPT_EN="Disk(/opt)"

TXT_HM_STATUS_TITLE_TR="Sistem Sagligi Monitoru Durumu"
TXT_HM_STATUS_TITLE_EN="System Health Monitor Status"

TXT_HM_STATUS_SEC_SETTINGS_TR="[AYARLAR]"
TXT_HM_STATUS_SEC_SETTINGS_EN="[SETTINGS]"

TXT_HM_STATUS_SEC_THRESH_TR="[ESIKLER]"
TXT_HM_STATUS_SEC_THRESH_EN="[THRESHOLDS]"

TXT_HM_STATUS_SEC_ZAPRET_TR="[ZAPRET]"
TXT_HM_STATUS_SEC_ZAPRET_EN="[ZAPRET]"

TXT_HM_STATUS_SEC_NOW_TR="[SIMDI]"
TXT_HM_STATUS_SEC_NOW_EN="[NOW]"

TXT_HM_STATUS_ZAPRET_AR_TR="AutoRes"
TXT_HM_STATUS_ZAPRET_AR_EN="AutoRes"

TXT_HM_STATUS_CPU_TR="CPU"
TXT_HM_STATUS_CPU_EN="CPU"

TXT_HM_STATUS_ZAPRET_TR="Zapret"
TXT_HM_STATUS_ZAPRET_EN="Zapret"

TXT_HM_ZAPRET_UP_SHORT_TR="acik"
TXT_HM_ZAPRET_UP_SHORT_EN="up"

TXT_HM_ZAPRET_DOWN_SHORT_TR="kapali"
TXT_HM_ZAPRET_DOWN_SHORT_EN="down"

TXT_HM_ZAPRET_NA_SHORT_TR="n/a"
TXT_HM_ZAPRET_NA_SHORT_EN="n/a"

TXT_HM_STATUS_SECTION_CFG_TR="Ayarlar"
TXT_HM_STATUS_SECTION_CFG_EN="Settings"

TXT_HM_STATUS_SECTION_NOW_TR="Anlik Durum"
TXT_HM_STATUS_SECTION_NOW_EN="Live Status"

TXT_HM_STATUS_UPDATECHECK_TR="Guncelleme kontrolu"
TXT_HM_STATUS_UPDATECHECK_EN="Update check"

TXT_HM_STATUS_AUTOUPDATE_TR="Oto guncelleme"
TXT_HM_STATUS_AUTOUPDATE_EN="Auto update"

TXT_HM_WORD_ON_TR="ACIK"
TXT_HM_WORD_ON_EN="ON"

TXT_HM_WORD_OFF_TR="KAPALI"
TXT_HM_WORD_OFF_EN="OFF"

TXT_HM_MODE0_TR="KAPALI"
TXT_HM_MODE0_EN="OFF"

TXT_HM_MODE1_TR="BILDIR"
TXT_HM_MODE1_EN="Notify"

TXT_HM_MODE2_TR="OTO KUR"
TXT_HM_MODE2_EN="Auto install"

TXT_HM_FLAG_EVERY_TR="her"
TXT_HM_FLAG_EVERY_EN="every"

TXT_HM_FLAG_MODE_TR="mod"
TXT_HM_FLAG_MODE_EN="mode"

TXT_HM_FLAG_ENABLED_TR="acik"
TXT_HM_FLAG_ENABLED_EN="en"

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

TXT_HM_ENABLED_TR="Sistem Sagligi Monitoru acildi."
TXT_HM_ENABLED_EN="Health Monitor enabled."

TXT_HM_DISABLED_TR="Sistem Sagligi Monitoru kapatildi."
TXT_HM_DISABLED_EN="Health Monitor disabled."

TXT_HM_TEST_MSG_TR="📌 HealthMon %TS%\n✅ Saglik Izleme testi\n🧠 CPU: %CPU%%\n📊 Yuk: %LOAD%\n🧮 RAM bos: %RAM% MB\n💾 Disk(/opt): %DISK%%"
TXT_HM_TEST_MSG_EN="📌 HealthMon %TS%\n✅ Health Monitor test\n🧠 CPU: %CPU%%\n📊 Load: %LOAD%\n🧮 RAM free: %RAM% MB\n💾 Disk(/opt): %DISK%%"

TXT_HM_CPU_WARN_MSG_TR="📌 HealthMon %TS%\n⚠️ CPU UYARI: %CPU%%\n🧠 CPU: %CPU%%\n📊 Yuk: %LOAD%\n🧮 RAM bos: %RAM% MB\n💾 Disk(/opt): %DISK%%"
TXT_HM_CPU_WARN_MSG_EN="📌 HealthMon %TS%\n⚠️ CPU WARN: %CPU%%\n🧠 CPU: %CPU%%\n📊 Load: %LOAD%\n🧮 RAM free: %RAM% MB\n💾 Disk(/opt): %DISK%%"

TXT_HM_CPU_CRIT_MSG_TR="📌 HealthMon %TS%\n🚨 CPU KRITIK: %CPU%%\n🧠 CPU: %CPU%%\n📊 Yuk: %LOAD%\n🧮 RAM bos: %RAM% MB\n💾 Disk(/opt): %DISK%%"
TXT_HM_CPU_CRIT_MSG_EN="📌 HealthMon %TS%\n🚨 CPU CRIT: %CPU%%\n🧠 CPU: %CPU%%\n📊 Load: %LOAD%\n🧮 RAM free: %RAM% MB\n💾 Disk(/opt): %DISK%%"

TXT_HM_DISK_WARN_MSG_TR="📌 HealthMon %TS%\n⚠️ Disk dolu: /opt %DISK%%%\n🧠 CPU: %CPU%%\n📊 Yuk: %LOAD%\n🧮 RAM bos: %RAM% MB"
TXT_HM_DISK_WARN_MSG_EN="📌 HealthMon %TS%\n⚠️ Disk high: /opt %DISK%%%\n🧠 CPU: %CPU%%\n📊 Load: %LOAD%\n🧮 RAM free: %RAM% MB"

TXT_HM_RAM_WARN_MSG_TR="📌 HealthMon %TS%\n⚠️ RAM dusuk: %RAM% MB\n🧠 CPU: %CPU%%\n📊 Yuk: %LOAD%\n💾 Disk(/opt): %DISK%%"
TXT_HM_RAM_WARN_MSG_EN="📌 HealthMon %TS%\n⚠️ Low RAM: %RAM% MB\n🧠 CPU: %CPU%%\n📊 Load: %LOAD%\n💾 Disk(/opt): %DISK%%"

TXT_HM_ZAPRET_DOWN_MSG_TR="📌 HealthMon %TS%\n🚨 Zapret durmus olabilir!\n🧠 CPU: %CPU%%\n📊 Yuk: %LOAD%\n🧮 RAM bos: %RAM% MB\n💾 Disk(/opt): %DISK%%"
TXT_HM_ZAPRET_DOWN_MSG_EN="📌 HealthMon %TS%\n🚨 Zapret may be down!\n🧠 CPU: %CPU%%\n📊 Load: %LOAD%\n🧮 RAM free: %RAM% MB\n💾 Disk(/opt): %DISK%%"

TXT_HM_ZAPRET_UP_MSG_TR="📌 HealthMon %TS%\n✅ Zapret tekrar calisiyor.\n🧠 CPU: %CPU%%\n📊 Yuk: %LOAD%\n🧮 RAM bos: %RAM% MB\n💾 Disk(/opt): %DISK%%"
TXT_HM_ZAPRET_UP_MSG_EN="📌 HealthMon %TS%\n✅ Zapret is running again.\n🧠 CPU: %CPU%%\n📊 Load: %LOAD%\n🧮 RAM free: %RAM% MB\n💾 Disk(/opt): %DISK%%"

TXT_HM_STATUS_RUNNING_TR="Calisiyor:"
TXT_HM_STATUS_RUNNING_EN="Running:"

TXT_HM_RUN_ON_TR="AKTIF"
TXT_HM_RUN_ON_EN="ON"

TXT_HM_RUN_OFF_TR="KAPALI"
TXT_HM_RUN_OFF_EN="OFF"

TXT_HM_ENABLE_LABEL_TR="etkin"
TXT_HM_ENABLE_LABEL_EN="enable"

TXT_HM_STATUS_INTERVAL_TR="Aralik"
TXT_HM_STATUS_INTERVAL_EN="Interval"

TXT_HM_STATUS_CPU_WARN_TR="CPU UYARI"
TXT_HM_STATUS_CPU_WARN_EN="CPU WARN"

TXT_HM_STATUS_CPU_CRIT_TR="CPU KRITIK"
TXT_HM_STATUS_CPU_CRIT_EN="CPU CRIT"

TXT_HM_STATUS_DISK_WARN_TR="Disk(/opt) UYARI"
TXT_HM_STATUS_DISK_WARN_EN="Disk(/opt) WARN"

TXT_HM_STATUS_RAM_WARN_TR="RAM UYARI"
TXT_HM_STATUS_RAM_WARN_EN="RAM WARN"

TXT_HM_STATUS_ZAPRET_WD_TR="Zapret izleme"
TXT_HM_STATUS_ZAPRET_WD_EN="Zapret watchdog"

TXT_HM_STATUS_ZAPRET_CD_TR="Zapret bekleme"
TXT_HM_STATUS_ZAPRET_CD_EN="Zapret cooldown"

TXT_HM_STATUS_COOLDOWN_TR="Bekleme"
TXT_HM_STATUS_COOLDOWN_EN="Cooldown"

TXT_HM_STATUS_NOW_TR="Simdi ->"
TXT_HM_STATUS_NOW_EN="Now ->"

TXT_HM_STATUS_LOAD_TR="Yuk"
TXT_HM_STATUS_LOAD_EN="Load"

TXT_HM_STATUS_RAM_FREE_TR="RAM bos"
TXT_HM_STATUS_RAM_FREE_EN="RAM free"

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

TXT_HM_PROMPT_UPDATECHECK_ENABLE_TR="Guncelleme kontrolu (1=acik,0=kapali) [or: 1]:"
TXT_HM_PROMPT_UPDATECHECK_ENABLE_EN="Update check (1=on,0=off) [e.g. 1]:"

TXT_HM_PROMPT_UPDATECHECK_SEC_TR="Update check araligi (sn) [or: 21600]:"
TXT_HM_PROMPT_UPDATECHECK_SEC_EN="Update check interval (sec) [e.g. 21600]:"

TXT_UPD_ZKM_NEW_TR="[Guncelleme]
📦 Paket  : KZM
🔖 Mevcut : %CUR%
🆕 Yeni   : %NEW%
🔗 Link   : %URL%

Simdi kur? (menu 10)"
TXT_UPD_ZKM_NEW_EN="[Update]
📦 Package : KZM
🔖 Current : %CUR%
🆕 Latest  : %NEW%
🔗 Link    : %URL%

Install now? (menu 10)"
TXT_UPD_ZAPRET_NEW_TR="[Guncelleme]
📦 Paket  : zapret
🔖 Kurulu : %CUR%
🆕 Yeni   : %NEW%
🔗 Link   : %URL%"
TXT_UPD_ZAPRET_NEW_EN="[Update]
📦 Package  : zapret
🔖 Installed: %CUR%
🆕 Latest   : %NEW%
🔗 Link     : %URL%"
TXT_UPD_ZKM_AUTO_OK_TR="[OtoGuncelleme]\nKZM otomatik kurulum basarili.\nBetigi yeniden calistirin.\n\nMevcut : %CUR%\nYeni   : %NEW%\nLink   : %URL%"
TXT_UPD_ZKM_AUTO_OK_EN="[AutoUpdate]\nKZM auto install OK.\nPlease re-run the script.\n\nCurrent : %CUR%\nLatest  : %NEW%\nLink    : %URL%"

TXT_UPD_ZKM_UP_TO_DATE_TR="[Guncelleme]
📦 Paket : KZM
🔄 Durum : Guncel ✅
🔖 Surum : %CUR%"
TXT_UPD_ZKM_UP_TO_DATE_EN="[Update]
📦 Package : KZM
🔄 Status  : Up to date ✅
🔖 Version : %CUR%"

TXT_UPD_ZKM_AUTO_FAIL_TR="[OtoGuncelleme]\nKZM otomatik kurulum BASARISIZ.\nLutfen elle guncelleyin (menu 10).\n\nMevcut : %CUR%\nYeni   : %NEW%\nLink   : %URL%"
TXT_UPD_ZKM_AUTO_FAIL_EN="[AutoUpdate]\nKZM auto install FAILED.\nPlease update manually (menu 10).\n\nCurrent : %CUR%\nLatest  : %NEW%\nLink    : %URL%"

TXT_HM_PROMPT_AUTOUPDATE_MODE_TR="Otomatik guncelleme modu (0=KAPALI,1=BILDIR,2=OTO KUR) [or: 2]:"
TXT_HM_PROMPT_AUTOUPDATE_MODE_EN="Auto update mode (0=OFF,1=Notify,2=Auto install) [e.g. 2]:"

TXT_HM_AUTOUPDATE_MODE_HINT_TR="0=KAPALI,1=BILDIR,2=OTO KUR"
TXT_HM_AUTOUPDATE_MODE_HINT_EN="0=OFF,1=Notify,2=Auto install"

TXT_HM_AUTOUPDATE_WARN_TITLE_TR="UYARI:"
TXT_HM_AUTOUPDATE_WARN_TITLE_EN="WARNING:"

TXT_HM_AUTOUPDATE_WARN_L1_TR="Auto install modu betigi otomatik gunceller."
TXT_HM_AUTOUPDATE_WARN_L1_EN="Auto install will update the script automatically."

TXT_HM_AUTOUPDATE_WARN_L2_TR="Ileri seviye kullanicilar icin onerilir."
TXT_HM_AUTOUPDATE_WARN_L2_EN="Recommended for advanced users."

TXT_HM_AUTOUPDATE_WARN_L3_TR="Devam? (e/h): "
TXT_HM_AUTOUPDATE_WARN_L3_EN="Continue? (y/n): "

TXT_HM_AUTOUPDATE_SET_MSG_TR="Otomatik guncelleme modu ayarlandi: %MODE%"
TXT_HM_AUTOUPDATE_SET_MSG_EN="Auto update mode set: %MODE%"

TXT_HM_PROMPT_COOLDOWN_TR="Bildirim soguma (sn) [or: 600]:"
TXT_HM_PROMPT_COOLDOWN_EN="Notification cooldown (sec) [e.g. 600]:"


# Health check menu
TXT_HEALTH_TITLE_TR="Saglik Kontrolu"
TXT_HEALTH_TITLE_EN="Health Check"

TXT_HEALTH_OVERALL_TR="Genel Durum"
TXT_HEALTH_OVERALL_EN="Overall Status"
TXT_HEALTH_SCORE_TR="Saglik Skoru (Health Score)"
TXT_HEALTH_SCORE_EN="Health Score"

TXT_HEALTH_RATING_EXCELLENT_TR="Mukemmel"
TXT_HEALTH_RATING_EXCELLENT_EN="Excellent"
TXT_HEALTH_RATING_GREAT_TR="Cok iyi"
TXT_HEALTH_RATING_GREAT_EN="Great"
TXT_HEALTH_RATING_GOOD_TR="Iyi"
TXT_HEALTH_RATING_GOOD_EN="Good"
TXT_HEALTH_RATING_OK_TR="Orta"
TXT_HEALTH_RATING_OK_EN="OK"
TXT_HEALTH_RATING_BAD_TR="Zayif"
TXT_HEALTH_RATING_BAD_EN="Poor"

TXT_HEALTH_SECTION_SUMMARY_TR="Durum Ozeti"
TXT_HEALTH_SECTION_SUMMARY_EN="Status Summary"
TXT_HEALTH_SECTION_NETDNS_TR="Ag & DNS"
TXT_HEALTH_SECTION_NETDNS_EN="Network & DNS"
TXT_HEALTH_SECTION_SYSTEM_TR="Sistem"
TXT_HEALTH_SECTION_SYSTEM_EN="System"
TXT_HEALTH_SECTION_SERVICES_TR="Servisler"
TXT_HEALTH_SECTION_SERVICES_EN="Services"

TXT_HEALTH_WAN_STATUS_TR="WAN durumu"
TXT_HEALTH_WAN_STATUS_EN="WAN status"
TXT_HEALTH_DNS_MODE_TR="DNS Modu"
TXT_HEALTH_DNS_MODE_EN="DNS Mode"
TXT_HEALTH_DNS_SEC_TR="DNS Guvenlik Seviyesi"
TXT_HEALTH_DNS_SEC_EN="DNS Security Level"
TXT_HEALTH_DNS_PROVIDERS_TR="DNS Saglayicilar"
TXT_HEALTH_DNS_PROVIDERS_EN="DNS Providers"

TXT_DNS_MODE_DOH_TR="DoH"
TXT_DNS_MODE_DOH_EN="DoH"
TXT_DNS_MODE_DOT_TR="DoT"
TXT_DNS_MODE_DOT_EN="DoT"
TXT_DNS_MODE_PLAIN_TR="Plain"
TXT_DNS_MODE_PLAIN_EN="Plain"
TXT_DNS_MODE_MIXED_TR="DoH+DoT"
TXT_DNS_MODE_MIXED_EN="DoH+DoT"

TXT_DNS_SEC_HIGH_TR="YUKSEK"
TXT_DNS_SEC_HIGH_EN="HIGH"
TXT_DNS_SEC_LOW_TR="DUSUK"
TXT_DNS_SEC_LOW_EN="LOW"

TXT_TG_DOWN_LABEL_TR="Kapali"
TXT_TG_DOWN_LABEL_EN="Down"
TXT_TG_UP_LABEL_TR="Acik"
TXT_TG_UP_LABEL_EN="Up"
TXT_TG_DURATION_LABEL_TR="Sure"
TXT_TG_DURATION_LABEL_EN="Duration"

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

TXT_HEALTH_DNS_MATCH_NOTE_TR="Farkli IP'ler normal olabilir"
TXT_HEALTH_DNS_MATCH_NOTE_EN="Different IPs can be normal"


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
TXT_CHOICE_TR="Secim:"
TXT_CHOICE_EN="Choice:"

TXT_INVALID_CHOICE_TR="Gecersiz secim!"
TXT_INVALID_CHOICE_EN="Invalid choice!"

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
TXT_ROLLBACK_NO_LOCAL_BACKUP_TR="Yerel yedek bulunamadi."
TXT_ROLLBACK_NO_LOCAL_BACKUP_EN="No local backup found."

TXT_ROLLBACK_CLEAN_LOCAL_BACKUPS_TR="Yedekleri Temizle"
TXT_ROLLBACK_CLEAN_LOCAL_BACKUPS_EN="Clean Backups"

TXT_ROLLBACK_CLEAN_DONE_TR="Temizlendi: %s yedek silindi."
TXT_ROLLBACK_CLEAN_DONE_EN="Cleaned: %s backup(s) deleted."

TXT_ROLLBACK_CLEAN_NONE_TR="Temizlenecek yerel yedek bulunamadi."
TXT_ROLLBACK_CLEAN_NONE_EN="No local backups to clean."

# -----------------------------
# Blockcheck reports
# -----------------------------
TXT_BLOCKCHECK_CLEAN_DONE_TR="Temizlendi: %s test sonucu silindi."
TXT_BLOCKCHECK_CLEAN_DONE_EN="Cleaned: %s test result(s) deleted."

TXT_BLOCKCHECK_CLEAN_NONE_TR="Temizlenecek test sonucu bulunamadi."
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

TXT_ROLLBACK_GH_TAG_TR="Surum etiketi yaz (Orn: v26.1.24.3)"
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

TXT_RESTORE_SCOPE_KZM_TR="KZM Ayarlarini Geri Yukle (HealthMon + Telegram)"
TXT_RESTORE_SCOPE_KZM_EN="Restore KZM Settings (HealthMon + Telegram)"

TXT_BACKUP_NO_BACKUPS_FOUND_TR="Yedek bulunamadi."
TXT_BACKUP_NO_BACKUPS_FOUND_EN="No backups found."

TXT_BACKUP_SUB_BACKUP_TR="1. IPSET Yedekle"
TXT_BACKUP_SUB_BACKUP_EN="1. IPSET Backup"

TXT_BACKUP_SUB_RESTORE_TR="2. IPSET Geri Yukle"
TXT_BACKUP_SUB_RESTORE_EN="2. IPSET Restore"

TXT_BACKUP_SUB_SHOW_TR="3. IPSET Yedekleri Goster"
TXT_BACKUP_SUB_SHOW_EN="3. Show IPSET Backups"

TXT_BACKUP_SUB_CFG_BACKUP_TR="4. Zapret / KZM Ayarlarini Yedekle"
TXT_BACKUP_SUB_CFG_BACKUP_EN="4. Backup Zapret / KZM Settings"

TXT_BACKUP_SUB_CFG_RESTORE_TR="5. Zapret / KZM Ayarlarini Geri Yukle"
TXT_BACKUP_SUB_CFG_RESTORE_EN="5. Restore Zapret / KZM Settings"

TXT_BACKUP_SUB_CFG_SHOW_TR="6. Zapret Ayar Yedeklerini Goster"
TXT_BACKUP_SUB_CFG_SHOW_EN="6. Show Settings Backups"

TXT_BACKUP_CFG_NO_FILES_TR="Yedeklenecek Zapret/KZM ayar dosyasi bulunamadi."
TXT_BACKUP_CFG_NO_FILES_EN="No Zapret/KZM settings files found to backup."

TXT_BACKUP_CFG_BACKED_UP_TR="Zapret/KZM ayarlari yedeklendi: %s"
TXT_BACKUP_CFG_BACKED_UP_EN="Zapret/KZM settings backed up: %s"

TXT_BACKUP_CFG_NO_BACKUPS_TR="Zapret/KZM ayar yedegi bulunamadi."
TXT_BACKUP_CFG_NO_BACKUPS_EN="No Zapret/KZM settings backup found."

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

TXT_BACKUP_RESTORE_SCOPE_TR="Geri yukleme kapsamini secin:"
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
TXT_BLOCKCHECK_TEST_MENU_TR="Blockcheck Test Menusu"
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

TXT_BLOCKCHECK_TEST_TITLE_TR="Blockcheck Test Menusu"
TXT_BLOCKCHECK_TEST_TITLE_EN="Blockcheck Test Menu"

TXT_BLOCKCHECK_FULL_TR="Tam Test"
TXT_BLOCKCHECK_FULL_EN="Full Test"

TXT_BLOCKCHECK_SUMMARY_TR="Ozet (Sadece SUMMARY) (Otomatik DPI icin kullanilir)"
TXT_BLOCKCHECK_SUMMARY_EN="Summary (SUMMARY only) (Used for Auto DPI)"

TXT_BLOCKCHECK_CLEAN_TR="Test Sonuclarini Temizle"
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

TXT_MENU_R_TR=" R. Zamanli Yeniden Baslat (Cron)"
TXT_MENU_R_EN=" R. Scheduled Reboot (Cron)"

TXT_MENU_U_TR=" U. KZM + Zapret Kaldir (Tam Temiz)"
TXT_MENU_U_EN=" U. KZM + Zapret Uninstall (Full Clean)"


TXT_MENU_0_TR=" 0. Cikis"
TXT_MENU_0_EN=" 0. Exit"

TXT_MENU_FOOT_TR="--------------------------------------------------------------------------------------------"
TXT_MENU_FOOT_EN="--------------------------------------------------------------------------------------------"

TXT_PROMPT_MAIN_TR=" Seciminizi Yapin (0-16, B, L, R, U): "
TXT_PROMPT_MAIN_EN=" Select an Option (0-16, B, L, R, U): "

TXT_LANG_NOW_TR="Dil: Turkce"
TXT_LANG_NOW_EN="Language: English"

# IPSET menu
TXT_IPSET_TITLE_TR=" Zapret IPSET (Istemci Secimi)"
TXT_IPSET_TITLE_EN=" Zapret IPSET (Client Selection)"

TXT_IPSET_1_TR=" 1. Mevcut IP Listesini Goster"
TXT_IPSET_1_EN=" 1. Show Current IP List"

TXT_IPSET_2_TR=" 2. Tum Aga Uygula (client Filtresi Kapali)"
TXT_IPSET_2_EN=" 2. Apply to Whole Network (Client Filter Off)"

TXT_IPSET_3_TR=" 3. Secili IP'lere Uygula (IP gir)"
TXT_IPSET_3_EN=" 3. Apply to Selected IPs (enter IPs)"

TXT_IPSET_4_TR=" 4. Listeye Tek IP Ekle"
TXT_IPSET_4_EN=" 4. Add a Single IP to list"

TXT_IPSET_5_TR=" 5. Listeden Tek IP Sil"
TXT_IPSET_5_EN=" 5. Remove a Single IP from list"

TXT_IPSET_6_TR=" 6. No Zapret (Muafiyet) Yonetimi"
TXT_IPSET_6_EN=" 6. No Zapret (Exemption) Management"

TXT_IPSET_0_TR=" 0. Ana Menuye Don"
TXT_IPSET_0_EN=" 0. Back to Main Menu"

TXT_PROMPT_IPSET_TR=" Seciminizi Yapin (0-6): "
TXT_PROMPT_IPSET_EN=" Select an Option (0-6): "

TXT_PROMPT_IPSET_BASIC_TR=" Seciminizi Yapin (0-3, 6): "
TXT_PROMPT_IPSET_BASIC_EN=" Select an Option (0-3, 6): "

TXT_NOZAPRET_TITLE_TR="No Zapret (Muafiyet) Yonetimi"
TXT_NOZAPRET_TITLE_EN="No Zapret (Exemption) Management"
TXT_NOZAPRET_DESC_TR="Bu listedeki IP'ler Zapret isleminden MUAF tutulur (ornegin IPTV kutulari)"
TXT_NOZAPRET_DESC_EN="IPs in this list are EXEMPT from Zapret processing (e.g. IPTV boxes)"
TXT_NOZAPRET_1_TR=" 1. Muafiyet Listesini Goster"
TXT_NOZAPRET_1_EN=" 1. Show Exemption List"
TXT_NOZAPRET_2_TR=" 2. IP Ekle (Zapret'ten Muaf Tut)"
TXT_NOZAPRET_2_EN=" 2. Add IP (Exempt from Zapret)"
TXT_NOZAPRET_3_TR=" 3. IP Sil"
TXT_NOZAPRET_3_EN=" 3. Remove IP"
TXT_NOZAPRET_4_TR=" 4. Listeyi Temizle"
TXT_NOZAPRET_4_EN=" 4. Clear List"
TXT_NOZAPRET_0_TR=" 0. Geri"
TXT_NOZAPRET_0_EN=" 0. Back"
TXT_NOZAPRET_PROMPT_TR=" Seciminizi Yapin (0-4): "
TXT_NOZAPRET_PROMPT_EN=" Select an Option (0-4): "
TXT_NOZAPRET_ADD_TR="Muaf tutulacak IP'i girin (Enter=iptal): "
TXT_NOZAPRET_ADD_EN="Enter IP to exempt (Enter=cancel): "
TXT_NOZAPRET_DEL_TR="Silmek istediginiz IP'i girin (Enter=iptal): "
TXT_NOZAPRET_DEL_EN="Enter IP to remove (Enter=cancel): "
TXT_NOZAPRET_EMPTY_TR="Muafiyet listesi bos."
TXT_NOZAPRET_EMPTY_EN="Exemption list is empty."
TXT_NOZAPRET_ADDED_TR="Tamam: IP muafiyet listesine eklendi."
TXT_NOZAPRET_ADDED_EN="OK: IP added to exemption list."
TXT_NOZAPRET_EXISTS_TR="Bu IP zaten listede."
TXT_NOZAPRET_EXISTS_EN="This IP is already in the list."
TXT_NOZAPRET_REMOVED_TR="Tamam: IP muafiyet listesinden silindi."
TXT_NOZAPRET_REMOVED_EN="OK: IP removed from exemption list."
TXT_NOZAPRET_NOTFOUND_TR="IP listede bulunamadi."
TXT_NOZAPRET_NOTFOUND_EN="IP not found in list."
TXT_NOZAPRET_CLEARED_TR="Tamam: Muafiyet listesi temizlendi."
TXT_NOZAPRET_CLEARED_EN="OK: Exemption list cleared."
TXT_NOZAPRET_CONFIRM_CLEAR_TR="Tum muafiyet listesini silmek istiyor musunuz? (e/h): "
TXT_NOZAPRET_CONFIRM_CLEAR_EN="Delete entire exemption list? (y/n): "
TXT_NOZAPRET_INVALID_IP_TR="Gecersiz IP adresi!"
TXT_NOZAPRET_INVALID_IP_EN="Invalid IP address!"
TXT_NOZAPRET_IPSET_ACTIVE_TR="  IPSET Aktif Uyeler:"
TXT_NOZAPRET_IPSET_ACTIVE_EN="  IPSET Active Members:"
TXT_NOZAPRET_IPSET_EMPTY_TR="  (IPSET bos veya tanimsiz)"
TXT_NOZAPRET_IPSET_EMPTY_EN="  (IPSET empty or undefined)"

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

# --- KeenDNS Izleme ---
TXT_KEENDNS_BANNER_LABEL_TR="KeenDNS"
TXT_KEENDNS_BANNER_LABEL_EN="KeenDNS"
TXT_KEENDNS_DIRECT_TR="Dogrudan Erisim"
TXT_KEENDNS_DIRECT_EN="Direct Access"
TXT_KEENDNS_CLOUD_TR="Yalnizca Cloud"
TXT_KEENDNS_CLOUD_EN="Cloud Only"
TXT_KEENDNS_NONE_TR="KeenDNS kaydi yok"
TXT_KEENDNS_NONE_EN="No KeenDNS record"
TXT_KEENDNS_UNKNOWN_TR="Bilinmiyor"
TXT_KEENDNS_UNKNOWN_EN="Unknown"
TXT_KEENDNS_LOST_TR="⚠️ KeenDNS Uyari\n%s\nDogrudan erisim kesildi, yalnizca cloud aktif."
TXT_KEENDNS_CGN_LOST_TR="⚠️ KeenDNS Uyari\n%s\nCloud erisimi kesildi (CGN/direkt erisim yok)."
TXT_KEENDNS_CGN_LOST_EN="⚠️ KeenDNS Alert\n%s\nCloud access lost (CGN / no direct access)."
TXT_KEENDNS_CGN_BACK_TR="✅ KeenDNS Geri Geldi\n%s\nCloud erisimi yeniden aktif."
TXT_KEENDNS_CGN_BACK_EN="✅ KeenDNS Restored\n%s\nCloud access is active again."
TXT_KEENDNS_LOST_EN="⚠️ KeenDNS Alert\n%s\nDirect access lost, cloud only."
TXT_KEENDNS_BACK_TR="✅ KeenDNS Geri Geldi\n%s\nDogrudan erisim yeniden aktif."
TXT_KEENDNS_BACK_EN="✅ KeenDNS Restored\n%s\nDirect access is active again."
TXT_KEENDNS_FAIL_TR="❌ KeenDNS Erisim Yok\n%s\nDomain disaridan erisilebilir degil."
TXT_KEENDNS_FAIL_EN="❌ KeenDNS Unreachable\n%s\nDomain is not accessible from outside."
TXT_KEENDNS_REACH_TR="✅ KeenDNS Erisim Geri Geldi\n%s\nDomain tekrar disaridan erisilebilir."
TXT_KEENDNS_REACH_EN="✅ KeenDNS Reachable Again\n%s\nDomain is accessible from outside again."


# Component Check translations
TXT_COMP_CHECK_TITLE_TR="=== Keenetic Bilesenler Kontrolu ==="
TXT_COMP_CHECK_TITLE_EN="=== Keenetic Components Check ==="

TXT_COMP_OPKG_TR="OPKG (Entware)"
TXT_COMP_OPKG_EN="OPKG (Entware)"
TXT_COMP_OPKG_REQ_TR="OPKG (Entware) - ZORUNLU!"
TXT_COMP_OPKG_REQ_EN="OPKG (Entware) - REQUIRED!"

TXT_COMP_IPV6_TR="IPv6 destegi (ip6tables)"
TXT_COMP_IPV6_EN="IPv6 support (ip6tables)"
TXT_COMP_IPV6_REQ_TR="IPv6 destegi - ZORUNLU!"
TXT_COMP_IPV6_REQ_EN="IPv6 support - REQUIRED!"
TXT_COMP_IPV6_SHORT_TR="IPv6 destegi"
TXT_COMP_IPV6_SHORT_EN="IPv6 support"

TXT_COMP_IPTABLES_TR="iptables"
TXT_COMP_IPTABLES_EN="iptables"
TXT_COMP_IPTABLES_REQ_TR="iptables - ZORUNLU!"
TXT_COMP_IPTABLES_REQ_EN="iptables - REQUIRED!"

TXT_COMP_NFQUEUE_TR="Netfilter Queue modulleri"
TXT_COMP_NFQUEUE_EN="Netfilter Queue modules"
TXT_COMP_NFQUEUE_WARN_TR="Netfilter kernel modulleri yuklu degil - Zapret servisi baslamaz!"
TXT_COMP_NFQUEUE_WARN_EN="Netfilter kernel modules not installed - Zapret service will not start!"

TXT_COMP_CURL_TR="curl (guncelleme icin)"
TXT_COMP_CURL_EN="curl (for updates)"
TXT_COMP_WGET_TR="wget (guncelleme icin)"
TXT_COMP_WGET_EN="wget (for updates)"
TXT_COMP_CURL_REQ_TR="curl veya wget - ZORUNLU!"
TXT_COMP_CURL_REQ_EN="curl or wget - REQUIRED!"
TXT_COMP_OR_TR="veya"
TXT_COMP_OR_EN="or"

TXT_COMP_IPSET_TR="ipset"
TXT_COMP_IPSET_EN="ipset"
TXT_COMP_IPSET_REQ_TR="ipset - ZORUNLU!"
TXT_COMP_IPSET_REQ_EN="ipset - REQUIRED!"

TXT_COMP_STORAGE_USB_TR="Harici depolama - USB (/opt bagli)"
TXT_COMP_STORAGE_USB_EN="External storage - USB (/opt mounted)"
TXT_COMP_STORAGE_INTERNAL_TR="Dahili depolama - eMMC/SD (/opt bagli)"
TXT_COMP_STORAGE_INTERNAL_EN="Internal storage - eMMC/SD (/opt mounted)"
TXT_COMP_STORAGE_EMMC_HINT_TR="      (Not: USB kullanimi onerilir - eMMC yipranma riski)"
TXT_COMP_STORAGE_EMMC_HINT_EN="      (Note: USB recommended - eMMC wear risk)"
TXT_COMP_STORAGE_GENERIC_TR="Depolama (/opt bagli)"
TXT_COMP_STORAGE_GENERIC_EN="Storage (/opt mounted)"
TXT_COMP_STORAGE_TMPFS_TR="/opt tmpfs - yeniden baslatmada kayip"
TXT_COMP_STORAGE_TMPFS_EN="/opt on tmpfs - lost on reboot"
TXT_COMP_STORAGE_REC_TR="Depolama - onerilir (USB/eMMC)"
TXT_COMP_STORAGE_REC_EN="Storage - recommended (USB/eMMC)"
TXT_COMP_STORAGE_INTERNAL_SD_TR="Dahili depolama - eMMC/NAND (/opt bagli)"
TXT_COMP_STORAGE_INTERNAL_SD_EN="Internal storage - eMMC/NAND (/opt mounted)"
TXT_COMP_STORAGE_INTERNAL_HINT_TR="      (Not: Dahili bellegin omru kisalabilir. Harici USB kullanimi onerilir.)"
TXT_COMP_STORAGE_INTERNAL_HINT_EN="      (Note: Internal storage wear may occur. External USB is recommended.)"

TXT_COMP_CRIT_FAIL_TR="KRITIK bilesenler eksik. Zapret calismayacak!"
TXT_COMP_CRIT_FAIL_EN="CRITICAL components missing. Zapret will NOT work!"
TXT_COMP_MISSING_TR="Eksik bilesenler:"
TXT_COMP_MISSING_EN="Missing components:"
TXT_COMP_INSTALL_FROM_TR="Bu bilesenler Keenetic Web UI uzerinden yuklenmelidir:"
TXT_COMP_INSTALL_FROM_EN="These components must be installed from Keenetic Web UI:"
TXT_COMP_INSTALL_PATH_TR="Keenetic Web UI > Yonetim > Genel Sistem Ayarlari > Bilesen Secenekleri > Guncelle"
TXT_COMP_INSTALL_PATH_EN="Keenetic Web UI > Management > General System Settings > Component Options > Update"
TXT_COMP_REBOOT_WARN_TR="UYARI: Bilesenler yuklendikten sonra cihaz yeniden baslatilir!"
TXT_COMP_REBOOT_WARN_EN="WARNING: Device will restart after installing components!"
TXT_COMP_REQUIRED_TR="Gerekli bilesenler:"
TXT_COMP_REQUIRED_EN="Required components:"

TXT_COMP_OPT_WARN_TR="Bazi OPSIYONEL bilesenler eksik. Zapret calisir ama tam fonksiyonel olmayabilir."
TXT_COMP_OPT_WARN_EN="Some OPTIONAL components missing. Zapret will work but may not be fully functional."
TXT_COMP_ALL_OK_TR="Tum gerekli bilesenler mevcut!"
TXT_COMP_ALL_OK_EN="All required components present!"
TXT_COMP_XTABLES_TR="Netfilter Xtables-addons genisletme paketleri"
TXT_COMP_XTABLES_EN="Netfilter Xtables-addons extension packages"
TXT_COMP_XTABLES_WARN_TR="Xtables-addons yuklu degil - Zapret servisi baslamaz!"
TXT_COMP_XTABLES_WARN_EN="Xtables-addons not installed - Zapret service will not start!"
TXT_COMP_TC_TR="Trafik Kontrol (tc) kernel modulleri"
TXT_COMP_TC_EN="Traffic Control (tc) kernel modules"
TXT_COMP_TC_WARN_TR="Trafik Kontrol modulleri yuklu degil - Zapret servisi baslamaz!"
TXT_COMP_TC_WARN_EN="Traffic Control modules not installed - Zapret service will not start!"
TXT_COMP_PRESS_ENTER_TR="Devam etmek icin Enter..."
TXT_COMP_PRESS_ENTER_EN="Press Enter to continue..."


T() {
    # Kullanim:
    #   T KEY                 -> sozlukten KEY_TR / KEY_EN
    #   T KEY "TR metin" "EN metin" -> verilen metinler (sozluge ihtiyac yok)
    local k="$1"
    local tr="$2"
    local en="$3"
    [ -z "$k" ] && return 0

    # Eger TR/EN parametreleri verilmisse onlari kullan
    if [ -n "$tr" ] || [ -n "$en" ]; then
        if [ "$LANG" = "en" ]; then
            [ -n "$en" ] && printf '%s' "$en" || printf '%s' "${tr:-$k}"
        else
            [ -n "$tr" ] && printf '%s' "$tr" || printf '%s' "${en:-$k}"
        fi
        return 0
    fi

    # Sozluk degiskenlerinden oku
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
    # EOF guard: if terminal is gone (SSH/Telnet disconnect), exit cleanly.
    read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")" _ </dev/tty || exit 0
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

# No Zapret (muafiyet) ayarlari
NOZAPRET_IPSET_NAME="nozapret"
NOZAPRET_FILE="/opt/zapret/ipset/nozapret.txt"

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
    printf " ${CLR_ORANGE}%s${CLR_RESET}\n" "$(T TXT_WAN_SEL_TITLE)"
    echo "$(T TXT_WAN_SEL_EXAMPLE)"
    echo "$(T TXT_WAN_SEL_CURRENT) $(get_wan_if)"
    echo "$(T TXT_WAN_SEL_RECOMMENDED) $rec"
    print_line "-"
    printf "${CLR_GREEN}%s${CLR_RESET}" "$(tpl_render "$(T TXT_WAN_SEL_PROMPT)" REC "$rec")"
    read -r ans
    [ -z "$ans" ] && ans="$rec"
    # bazen kopyala-yapistir ile sonuna nokta gelebiliyor (ppp0.)
    if [ -n "$ans" ] && [ ! -d "/sys/class/net/$ans" ] && [ -d "/sys/class/net/${ans%\.}" ]; then
        ans="${ans%.}"
    fi
    [ -z "$ans" ] && return 0
    mkdir -p /opt/zapret 2>/dev/null
    echo "$ans" > "$WAN_IF_FILE" 2>/dev/null
    echo "$(T TXT_WAN_SEL_SELECTED) $(get_wan_if)"
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
    printf "%b\n" "${CLR_ORANGE}$(T TXT_DPI_AUTO_NOTE)${CLR_RESET}"
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
    read -r -p "$(T dpi_prompt "Seciminizi yapin (0-8): " "Select an option (0-8): ")" sel || return 1
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
# TR/EN Dictionary (WAN Interface Selection & Cleanup)
TXT_WAN_SEL_TITLE_TR="Zapret cikis arayuzu secimi"
TXT_WAN_SEL_TITLE_EN="Zapret output interface selection"
TXT_WAN_SEL_EXAMPLE_TR=" (Ornek: ppp0 = WAN, wg0/wg1 = WireGuard)"
TXT_WAN_SEL_EXAMPLE_EN=" (Example: ppp0 = WAN, wg0/wg1 = WireGuard)"
TXT_WAN_SEL_CURRENT_TR=" Su Anki:"
TXT_WAN_SEL_CURRENT_EN=" Current:"
TXT_WAN_SEL_RECOMMENDED_TR=" Onerilen:"
TXT_WAN_SEL_RECOMMENDED_EN=" Recommended:"
TXT_WAN_SEL_PROMPT_TR="Arayuz adini yazin (Enter = %REC%): "
TXT_WAN_SEL_PROMPT_EN="Enter interface name (Enter = %REC%): "
TXT_WAN_SEL_SELECTED_TR="Secildi:"
TXT_WAN_SEL_SELECTED_EN="Selected:"
TXT_CLEANUP_REMOVING_TR="Indirilen Zapret arsivi ve gereksiz binary dosyalari siliniyor..."
TXT_CLEANUP_REMOVING_EN="Removing downloaded Zapret archive and unnecessary binary files..."
TXT_CLEANUP_REMOVED_TR="Indirilen Zapret arsivi ve gereksiz binary dosyalari silindi."
TXT_CLEANUP_REMOVED_EN="Downloaded Zapret archive and unnecessary binary files removed."

# TR/EN Dictionary (Kernel & Firewall & Zapret Service)
TXT_KERN_MOD_ADD_FAIL_TR="HATA: Kernel modulu yukleme dosyasina eklenemedi."
TXT_KERN_MOD_ADD_FAIL_EN="ERROR: Failed to write to kernel module load file."
TXT_KERN_MOD_CHMOD_FAIL_TR="HATA: Kernel modulu yukleme dosyasina calistirma izni verilemedi."
TXT_KERN_MOD_CHMOD_FAIL_EN="ERROR: Failed to set execute permission on kernel module load file."
TXT_KERN_MOD_OK_TR="Kernel modulu yukleme dosyasina eklendi."
TXT_KERN_MOD_OK_EN="Kernel module load file updated."
TXT_FW_WRITE_FAIL_TR="HATA: Guvenlik duvari izni verilirken hata olustu."
TXT_FW_WRITE_FAIL_EN="ERROR: Failed to write firewall permission file."
TXT_FW_CHMOD_FAIL_TR="HATA: Guvenlik duvari izni dosyasina calistirma izni verilemedi."
TXT_FW_CHMOD_FAIL_EN="ERROR: Failed to set execute permission on firewall file."
TXT_FW_OK_TR="Guvenlik duvari izni verildi."
TXT_FW_OK_EN="Firewall permission granted."
TXT_AUTOSTART_OK_TR="Zapret otomatik baslatma etkinlestirildi."
TXT_AUTOSTART_OK_EN="Zapret autostart enabled."
TXT_AUTOSTART_FAIL_TR="UYARI: Zapret otomatik baslatma etkinlestirilemedi."
TXT_AUTOSTART_FAIL_EN="WARNING: Failed to enable Zapret autostart."
TXT_TOTAL_PKT_FAIL_TR="HATA: Toplam paket kontrolu devre disi birakilirken hata olustu."
TXT_TOTAL_PKT_FAIL_EN="ERROR: Failed to disable total packet check."
TXT_TOTAL_PKT_CHMOD_FAIL_TR="HATA: Toplam paket kontrolu devre disi birakma dosyasina calistirma izni verilemedi."
TXT_TOTAL_PKT_CHMOD_FAIL_EN="ERROR: Failed to set execute permission on total packet disable file."
TXT_COMPAT_FAIL_TR="HATA: Keenetic icin uyumlu hale getirilemedi."
TXT_COMPAT_FAIL_EN="ERROR: Failed to apply Keenetic compatibility settings."
TXT_UDP_FIX_FAIL_TR="HATA: Keenetic UDP duzeltmesi eklenemedi."
TXT_UDP_FIX_FAIL_EN="ERROR: Failed to apply Keenetic UDP fix."
TXT_START_NOT_INSTALLED_TR="Zapret yuklu degil. Baslatma islemi yapilamiyor."
TXT_START_NOT_INSTALLED_EN="Zapret is not installed. Cannot start."
TXT_START_ALREADY_TR="Zapret servisi zaten calisiyor."
TXT_START_ALREADY_EN="Zapret service is already running."
TXT_START_OK_TR="Zapret servisi baslatildi."
TXT_START_OK_EN="Zapret service started."
TXT_START_FAIL_TR="HATA: Zapret servisi baslatilirken hata olustu."
TXT_START_FAIL_EN="ERROR: Failed to start Zapret service."
TXT_STOP_NOT_INSTALLED_TR="Zapret yuklu degil. Durdurma islemi yapilamiyor."
TXT_STOP_NOT_INSTALLED_EN="Zapret is not installed. Cannot stop."
TXT_STOP_STOPPING_TR="Zapret durduruluyor (NFQWS + NFQUEUE)..."
TXT_STOP_STOPPING_EN="Stopping Zapret (NFQWS + NFQUEUE)..."
TXT_STOP_NFQWS_WARN_TR="UYARI: nfqws hala calisiyor (otomatik yeniden baslatiliyor olabilir)."
TXT_STOP_NFQWS_WARN_EN="WARNING: nfqws is still running (may be auto-restarting)."
TXT_STOP_NFQUEUE_WARN_TR="UYARI: NFQUEUE kurali hala var (otomatik yeniden basiliyor olabilir)."
TXT_STOP_NFQUEUE_WARN_EN="WARNING: NFQUEUE rule still exists (may be auto-restarting)."
TXT_STOP_OK_TR="Zapret durduruldu."
TXT_STOP_OK_EN="Zapret stopped."
TXT_RESTART_NOT_INSTALLED_TR="Zapret yuklu degil. Yeniden baslatma islemi yapilamiyor."
TXT_RESTART_NOT_INSTALLED_EN="Zapret is not installed. Cannot restart."
TXT_ZAPRET_NOT_INSTALLED_TR="HATA: Zapret yuklu degil."
TXT_ZAPRET_NOT_INSTALLED_EN="ERROR: Zapret is not installed."
TXT_IPV6_NOT_INSTALLED_TR="HATA: Zapret yuklu degil. Once kurulum yapin."
TXT_IPV6_NOT_INSTALLED_EN="ERROR: Zapret is not installed. Please install first."
TXT_IPV6_WIZARD_START_TR="Zapret yapilandirma sihirbazi calistiriliyor (IPv6: %VAL%)..."
TXT_IPV6_WIZARD_START_EN="Running Zapret configuration wizard (IPv6: %VAL%)..."
TXT_IPV6_CFG_FAIL_TR="HATA: Zapret yapilandirma betigi calistirilirken hata olustu."
TXT_IPV6_CFG_FAIL_EN="ERROR: Failed to run Zapret configuration script."
TXT_UNINSTALL_NOT_INSTALLED_TR="Zapret yuklu degil. Kaldirma islemi yapilamaz."
TXT_UNINSTALL_NOT_INSTALLED_EN="Zapret is not installed. Nothing to remove."
TXT_UNINSTALL_REMOVING_TR="Zapret kaldiriliyor..."
TXT_UNINSTALL_REMOVING_EN="Removing Zapret..."
TXT_UNINSTALL_OK_TR="Zapret basariyla kaldirildi."
TXT_UNINSTALL_OK_EN="Zapret removed successfully."
TXT_INSTALL_ALREADY_TR="Zapret zaten yuklu."
TXT_INSTALL_ALREADY_EN="Zapret is already installed."
TXT_INSTALL_INSTALLING_TR="Zapret yukleniyor..."
TXT_INSTALL_INSTALLING_EN="Installing Zapret..."
TXT_INSTALL_OK_TR="Zapret basariyla yuklendi."
TXT_INSTALL_OK_EN="Zapret installed successfully."
TXT_INSTALL_DONE_TR="Zapret basariyla kuruldu ve yapilandirildi."
TXT_INSTALL_DONE_EN="Zapret successfully installed and configured."
TXT_INSTALL_PKG_FAIL_TR="HATA: Gerekli paketler yuklenemedi veya guncellenemedi."
TXT_INSTALL_PKG_FAIL_EN="ERROR: Failed to install or update required packages."
TXT_INSTALL_CFG_FAIL_TR="HATA: Zapret yapilandirma betigi calistirilirken hata olustu."
TXT_INSTALL_CFG_FAIL_EN="ERROR: Failed to run Zapret configuration script."
TXT_INSTALL_COMPAT_WARN_TR="UYARI: Keenetic uyumlulugu ayarlanirken bir sorun olustu."
TXT_INSTALL_COMPAT_WARN_EN="WARNING: An issue occurred while applying Keenetic compatibility settings."
TXT_INSTALL_CFG_RUNNING_TR="Zapret yapilandirma betigi calistiriliyor..."
TXT_INSTALL_CFG_RUNNING_EN="Running Zapret configuration script..."
TXT_INSTALL_KEENETIC_CFG_TR="Zapret'in Keenetic cihazlarda calisabilmesi icin gerekli yapilandirmalar yapiliyor..."
TXT_INSTALL_KEENETIC_CFG_EN="Applying required configurations for Zapret to run on Keenetic devices..."

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
        echo "$(T TXT_KERN_MOD_ADD_FAIL)"
        return 1
    }

    chmod +x /opt/zapret/init.d/sysv/zapret || {
        echo "$(T TXT_KERN_MOD_CHMOD_FAIL)"
        return 1
    }

    echo "$(T TXT_KERN_MOD_OK)"
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

    # /opt/zapret/config icinde NFQWS_OPT blogunu guvenli sekilde guncelle
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
        echo "$(T TXT_FW_WRITE_FAIL)"
        return 1
    }

    # Dosyayi calistirilabilir yapar
    chmod +x /opt/etc/ndm/netfilter.d/000-zapret.sh || {
        echo "$(T TXT_FW_CHMOD_FAIL)"
        return 1
    }
    
    echo "$(T TXT_FW_OK)"
    return 0
}

# Check Keenetic components required for Zapret
check_keenetic_components() {
    local missing_critical=0
    local missing_optional=0
    local all_components=""
    
    echo ""
    echo "$(T TXT_COMP_CHECK_TITLE)"
    print_line "-"
    
    # 1. OPKG (Entware) - CRITICAL
    if check_opkg; then
        print_status PASS "$(T TXT_COMP_OPKG)"
    else
        print_status FAIL "$(T TXT_COMP_OPKG_REQ)"
        missing_critical=1
        all_components="${all_components}  - OPKG (Entware)\n"
    fi
    
    # 2. IPv6 Support - CRITICAL
    if command -v ip6tables >/dev/null 2>&1 && ip6tables --version >/dev/null 2>&1; then
        print_status PASS "$(T TXT_COMP_IPV6)"
    else
        print_status FAIL "$(T TXT_COMP_IPV6_REQ)"
        missing_critical=1
        all_components="${all_components}  - $(T TXT_COMP_IPV6_SHORT)\n"
    fi
    
    # 3. iptables - CRITICAL
    if command -v iptables >/dev/null 2>&1 && iptables --version >/dev/null 2>&1; then
        print_status PASS "$(T TXT_COMP_IPTABLES)"
    else
        print_status FAIL "$(T TXT_COMP_IPTABLES_REQ)"
        missing_critical=1
        all_components="${all_components}  - iptables\n"
    fi
    
    # 4. Netfilter kernel modules - CRITICAL
    # Zapret'in zorunlu tuttugu modul: xt_multiport
    # Tespit sirasi: lsmod > modinfo > /lib/modules *.ko dosyasi
    _nfmod_ok=0
    if lsmod 2>/dev/null | grep -qE "^xt_multiport"; then
        _nfmod_ok=1
    elif modinfo xt_multiport >/dev/null 2>&1; then
        _nfmod_ok=1
    elif find /lib/modules -name "xt_multiport.ko" 2>/dev/null | grep -q .; then
        _nfmod_ok=1
    fi
    if [ "$_nfmod_ok" -eq 1 ]; then
        print_status PASS "$(T TXT_COMP_NFQUEUE)"
    else
        print_status FAIL "$(T TXT_COMP_NFQUEUE_WARN)"
        missing_critical=1
        all_components="${all_components}  - $(T TXT_COMP_NFQUEUE)\n"
    fi
    
    # 5. curl or wget - CRITICAL
    if command -v curl >/dev/null 2>&1; then
        print_status PASS "$(T TXT_COMP_CURL)"
    elif command -v wget >/dev/null 2>&1; then
        print_status PASS "$(T TXT_COMP_WGET)"
    else
        print_status FAIL "$(T TXT_COMP_CURL_REQ)"
        missing_critical=1
        all_components="${all_components}  - curl $(T TXT_COMP_OR) wget\n"
    fi
    
    # 6. ipset - CRITICAL
    if command -v ipset >/dev/null 2>&1 && ipset --version >/dev/null 2>&1; then
        print_status PASS "$(T TXT_COMP_IPSET)"
    else
        print_status FAIL "$(T TXT_COMP_IPSET_REQ)"
        missing_critical=1
        all_components="${all_components}  - ipset\n"
    fi
    
    # 7. Xtables-addons - CRITICAL (Keenetic OPKG bileseni)
    # Eksik olursa zapret servisi baslatma hatasi verir
    # Tespit sirasi: opkg kaydi > /lib/modules *.ko > lsmod > xtables .so
    _xtables_ok=0
    if opkg list-installed 2>/dev/null | grep -q "^kmod-ipt-xtables-extra\|^xtables-addons"; then
        _xtables_ok=1
    elif find /lib/modules -name "xt_condition.ko" -o -name "xt_ipp2p.ko" \
         -o -name "xt_iface.ko" -o -name "xt_fuzzy.ko" 2>/dev/null | grep -q .; then
        _xtables_ok=1
    elif lsmod 2>/dev/null | grep -qE "^xt_condition|^xt_fuzzy|^xt_iface|^xt_ipp2p"; then
        _xtables_ok=1
    elif ls /lib/xtables/libxt_condition.so \
            /usr/lib/xtables/libxt_condition.so \
            /usr/lib/iptables/libxt_condition.so 2>/dev/null | grep -q .; then
        _xtables_ok=1
    fi
    if [ "$_xtables_ok" -eq 1 ]; then
        print_status PASS "$(T TXT_COMP_XTABLES)"
    else
        print_status FAIL "$(T TXT_COMP_XTABLES_WARN)"
        missing_critical=1
        all_components="${all_components}  - $(T TXT_COMP_XTABLES)\n"
    fi

    # 8. Traffic Control kernel modules - CRITICAL (Keenetic OPKG bileseni)
    # Eksik olursa zapret servisi baslatma hatasi verir
    # Tespit sirasi: opkg kaydi > /lib/modules *.ko > lsmod > tc komutu
    _tc_ok=0
    if opkg list-installed 2>/dev/null | grep -q "^kmod-sched\|^kmod-tc\|^kmod-trafik"; then
        _tc_ok=1
    elif find /lib/modules -name "sch_ingress.ko" -o -name "sch_htb.ko" \
         -o -name "sch_hfsc.ko" -o -name "cls_u32.ko" 2>/dev/null | grep -q .; then
        _tc_ok=1
    elif lsmod 2>/dev/null | grep -qE "^sch_ingress|^sch_htb|^sch_hfsc|^cls_fw|^cls_u32"; then
        _tc_ok=1
    elif command -v tc >/dev/null 2>&1; then
        _tc_ok=1
    fi
    if [ "$_tc_ok" -eq 1 ]; then
        print_status PASS "$(T TXT_COMP_TC)"
    else
        print_status FAIL "$(T TXT_COMP_TC_WARN)"
        missing_critical=1
        all_components="${all_components}  - $(T TXT_COMP_TC)\n"
    fi

    # 9. Storage - OPTIONAL (for persistence)
    # Adim 1: /proc/mounts'ta /opt icin ayri bir mount satiri ara
    local _opt_line=""
    _opt_line=$(awk '$2=="/opt"{print; exit}' /proc/mounts 2>/dev/null)
    local opt_dev=""
    local opt_fstype=""
    if [ -n "$_opt_line" ]; then
        opt_dev=$(printf '%s' "$_opt_line" | awk '{print $1}')
        opt_fstype=$(printf '%s' "$_opt_line" | awk '{print $3}')
    fi

    # /dev/sdX icin removable flag kontrol: 1=USB(cikabilir), 0=dahili
    _is_usb_removable() {
        local _bdev
        _bdev=$(basename "$1" | sed 's/[0-9]*$//')
        local _removable=0
        if [ -f "/sys/block/${_bdev}/removable" ]; then
            _removable=$(cat "/sys/block/${_bdev}/removable" 2>/dev/null)
        fi
        [ "$_removable" = "1" ]
    }

    if [ -n "$opt_dev" ]; then
        # /opt ayri mount edilmis - device tipine gore karar ver
        if echo "$opt_dev" | grep -q "^/dev/sd"; then
            if _is_usb_removable "$opt_dev"; then
                print_status PASS "$(T TXT_COMP_STORAGE_USB)"
            else
                # Dahili /dev/sdX (bazi modellerde eMMC USB controller'a bagli)
                print_status WARN "$(T TXT_COMP_STORAGE_INTERNAL_SD)"
                echo "$(T TXT_COMP_STORAGE_INTERNAL_HINT)"
                missing_optional=1
            fi
        elif echo "$opt_dev" | grep -q "^/dev/mmcblk"; then
            print_status WARN "$(T TXT_COMP_STORAGE_INTERNAL)"
            echo "$(T TXT_COMP_STORAGE_EMMC_HINT)"
            missing_optional=1
        elif echo "$opt_dev" | grep -q "^/dev/nvme"; then
            print_status WARN "$(T TXT_COMP_STORAGE_INTERNAL)"
            missing_optional=1
        elif echo "$opt_fstype" | grep -qE "^tmpfs$"; then
            print_status INFO "$(T TXT_COMP_STORAGE_TMPFS)"
        elif echo "$opt_fstype" | grep -qE "^(overlay|overlayfs|ubifs)$" || \
             echo "$opt_dev" | grep -qE "^(overlay|ubi[0-9])"; then
            print_status WARN "$(T TXT_COMP_STORAGE_INTERNAL_SD)"
            echo "$(T TXT_COMP_STORAGE_INTERNAL_HINT)"
            missing_optional=1
        else
            print_status PASS "$(T TXT_COMP_STORAGE_GENERIC)"
        fi
    else
        # Adim 2: /opt ayri mount degil - df ile rootfs mount noktasini kontrol et
        # df son sutunu (Mounted on): "/" ise /opt rootfs'in parcasi = dahili flash
        local _opt_mounton=""
        _opt_mounton=$(df /opt 2>/dev/null | awk 'NR==2{print $NF}')
        if [ "$_opt_mounton" = "/" ]; then
            # /opt, kok dizinin altinda bir klasor = Keenetic dahili flash
            print_status WARN "$(T TXT_COMP_STORAGE_INTERNAL_SD)"
            echo "$(T TXT_COMP_STORAGE_INTERNAL_HINT)"
            missing_optional=1
        elif [ -n "$_opt_mounton" ]; then
            # Mount var ama /proc/mounts'ta gorunmedi (edge case)
            print_status PASS "$(T TXT_COMP_STORAGE_GENERIC)"
        else
            # /opt mevcut degil veya tespit edilemedi
            print_status WARN "$(T TXT_COMP_STORAGE_REC)"
            missing_optional=1
        fi
    fi
    
    print_line "-"
    
    if [ "$missing_critical" -eq 1 ]; then
        echo ""
        print_status FAIL "$(T TXT_COMP_CRIT_FAIL)"
        echo ""
        echo "$(T TXT_COMP_MISSING)"
        printf "$all_components"
        echo ""
        echo "$(T TXT_COMP_INSTALL_FROM)"
        echo "  $(T TXT_COMP_INSTALL_PATH)"
        echo ""
        echo "$(T TXT_COMP_REBOOT_WARN)"
        echo ""
        echo "$(T TXT_COMP_REQUIRED)"
        echo "  - OPKG"
        echo "  - $(T TXT_COMP_IPV6_SHORT)"
        echo "  - iptables"
        echo "  - ipset"
        echo "  - curl"
        echo "  - $(T TXT_COMP_XTABLES)"
        echo "  - $(T TXT_COMP_TC)"
        echo ""
        return 1
    elif [ "$missing_optional" -eq 1 ]; then
        echo ""
        print_status WARN "$(T TXT_COMP_OPT_WARN)"
        echo ""
        return 0
    else
        echo ""
        print_status PASS "$(T TXT_COMP_ALL_OK)"
        echo ""
        return 0
    fi
}



# Zapret'in otomatik baslamasini ayarlar
add_auto_start_zapret() {
    ln -fs /opt/zapret/init.d/sysv/zapret /opt/etc/init.d/S90-zapret && \
    echo "$(T TXT_AUTOSTART_OK)" || \
    { echo "$(T TXT_AUTOSTART_FAIL)"; return 0; }
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
        echo "$(T TXT_TOTAL_PKT_FAIL)"
        return 1
    }

    # Dosyayi calistirilabilir yapar
    chmod +x /opt/etc/init.d/S00fix || {
        echo "$(T TXT_TOTAL_PKT_CHMOD_FAIL)"
        return 1
    }
    
    echo "$(T _ 'Toplam paket kontrolu devre disi birakildi.' 'Total packet check disabled.')"
    return 0
}

# Keenetic uyumlulugunu etkinlestirir
keenetic_compatibility() {
    sed -i "s/^#WS_USER=nobody/WS_USER=nobody/" /opt/zapret/config.default && \
    echo "$(T _ 'Keenetic icin uyumlu hale getirildi.' 'Keenetic compatibility applied.')" || \
    { echo "$(T TXT_COMPAT_FAIL)"; return 1; }
}

# Keenetic UDP duzeltmesini ekler
fix_keenetic_udp() {
    cp -af /opt/zapret/init.d/custom.d.examples.linux/10-keenetic-udp-fix /opt/zapret/init.d/sysv/custom.d/10-keenetic-udp-fix && \
    echo "$(T _ 'Keenetic UDP duzeltmesi eklendi.' 'Keenetic UDP fix applied.')" || \
    { echo "$(T TXT_UDP_FIX_FAIL)"; return 1; }
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
    # Component check before starting
    if ! check_keenetic_components; then
        return 1
    fi
    
    if ! is_zapret_installed; then
        echo "$(T TXT_START_NOT_INSTALLED)"
        return 1
    fi

    # Start edilecekse pause kaldir
    zapret_resume
    install_zapret_pause_guard

    if is_zapret_running; then
        echo "$(T TXT_START_ALREADY)"
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
        echo "$(T TXT_START_OK)"
        return 0
    fi

    echo "$(T TXT_START_FAIL)"
    return 1
}

# Zapret servisini durdurur (kalici durdurma: otomatik restart'i da engeller)
stop_zapret() {
    if ! is_zapret_installed; then
        echo "$(T TXT_STOP_NOT_INSTALLED)"
        return 1
    fi

    echo "$(T TXT_STOP_STOPPING)"

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
        echo "$(T TXT_STOP_NFQWS_WARN)"
    else
        echo "OK: NFQWS YOK"
    fi

    if iptables-save | grep -q "NFQUEUE"; then
        echo "$(T TXT_STOP_NFQUEUE_WARN)"
    else
        echo "OK: NFQUEUE YOK"
    fi

    echo "$(T TXT_STOP_OK)"
    return 0
}

# Zapret servisini yeniden baslatir (guvenli)
restart_zapret() {
    if ! is_zapret_installed; then
        echo "$(T TXT_RESTART_NOT_INSTALLED)"
        return 1
    fi
    stop_zapret
    zapret_resume
    start_zapret
}

# --- KURULU VERSIYONU GORUNTULE (6. MADDE) ---
check_zapret_version() {
    if ! is_zapret_installed; then echo "$(T TXT_ZAPRET_NOT_INSTALLED)"; return 1; fi
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
        echo "$(T TXT_IPV6_NOT_INSTALLED)"
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

echo "$(tpl_render "$(T TXT_IPV6_WIZARD_START)" VAL "$IPV6_ANSWER")"

    # install_easy.sh interaktif bir sihirbazdir. Burada mevcut otomasyon akisini koruyup
    # sadece "enable ipv6 support" sorusunu secilebilir hale getiriyoruz.
    (
        echo "y"    # Sistem uyumluluk uyarisi, dokumani okuyun uyarisi: (evet)
        echo "1"    # Guvenlik duvari tipi secimi: 1=iptables 2=nftables
        echo "$IPV6_ANSWER"    # IPv6 destegi (hayir)
        echo "1"    # Filtreleme tipi secimi: 1=none 2=ipset 3=hostlist 4=autohostlist
        echo "n"    # TPWS socks modu etkinlestirilsin mi? (hayir)
        echo "n"    # TPWS transparent etkinlestirilsin mi? (hayir)
        echo "y"    # NFQWS etkinlestirilsin mi? (evet)
        echo "n"    # Yapilandirma duzenlensin mi? (hayir)
        WAN_IFINDEX="$(get_ifindex_by_iface "$(get_wan_if)")"
        [ -z "$WAN_IFINDEX" ] && WAN_IFINDEX="1"
        printf "\033[1;32m[INFO] WAN IFINDEX selected: %s\033[0m\n" "$WAN_IFINDEX" >&2
        echo "WAN_IFINDEX: $WAN_IFINDEX" >&2
        echo "1"    # LAN arayuzu secimi (1 = none)
        echo "${WAN_IFINDEX:-1}"    # WAN arayuzu secimi (1 = none)
    ) | /opt/zapret/install_easy.sh >/dev/null 2>&1 || {
        echo "$(T TXT_IPV6_CFG_FAIL)"
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
# Amac: Zapret'in (NFQUEUE) kuralini sadece belirli LAN istemcilerine uygulamak.
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
    # Eger dosya varsa "kaynak gercek" dosyadir -> set'i dosyaya gore senkronla.
    if [ -f "$IPSET_FILE" ]; then
        ipset flush "$IPSET_NAME" >/dev/null 2>&1
        tr ' \t,;\r\n' '\n' < "$IPSET_FILE" | awk 'NF{print $0}' | while read -r ip; do
            ipset add "$IPSET_NAME" "$ip" -exist >/dev/null 2>&1
        done
    fi
}

# Belirli chain'de NFQUEUE kural(lar)ini guvenli bicimde sil
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

# IpSet'e bagli NFQUEUE kurallarini ekle (ustten insert)
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

# Genel NFQUEUE (qnum 200) kurallarini temizle
del_general_nfqueue_qnum200() {
    del_nfqueue_chain mangle POSTROUTING "--queue-num $QNUM"
    del_nfqueue_chain "" INPUT "--queue-num $QNUM"
    del_nfqueue_chain "" FORWARD "--queue-num $QNUM"
}

# Sadece ipset'e bagli kurallari temizle (match-set zapret_clients)
del_ipset_nfqueue_rules() {
    del_nfqueue_chain mangle POSTROUTING "match-set $IPSET_NAME"
    del_nfqueue_chain "" INPUT "match-set $IPSET_NAME"
    del_nfqueue_chain "" FORWARD "match-set $IPSET_NAME"
}

if [ "$MODE" = "list" ]; then
    # LIST mod: tum ag etkilenmesin diye genel NFQUEUE'leri kaldir, sadece IPSET kurallarini birak.
    del_general_nfqueue_qnum200
    ipset_ensure_and_maybe_sync
    add_ipset_rules
else
    # ALL mod: IPSET'e bagli ozel kurallar varsa kaldir, genel kurallar kalsin.
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
        
        # IP Listesi Dosyasi
        printf '%b%-25s:%b ' "${CLR_ORANGE}${CLR_BOLD}" "$(T ip_list_file "$TXT_IP_LIST_FILE_TR" "$TXT_IP_LIST_FILE_EN")" "${CLR_RESET}"
        if [ -f "$IPSET_CLIENT_FILE" ] && [ -s "$IPSET_CLIENT_FILE" ]; then
            local ip_count="$(wc -l < "$IPSET_CLIENT_FILE" 2>/dev/null | tr -d ' ')"
            printf '%b%d IP%b\n' "${CLR_GREEN}" "$ip_count" "${CLR_RESET}"
            echo ""
            # awk ile numaralandirma - daha guvenli
            awk -v cyan="${CLR_CYAN}" -v reset="${CLR_RESET}" '
                NF > 0 {
                    printf "  %s%2d.%s %s\n", cyan, NR, reset, $0
                }' "$IPSET_CLIENT_FILE"
        else
            printf '%b%s%b\n' "${CLR_RED}" "$(T empty "$TXT_EMPTY_TR" "$TXT_EMPTY_EN")" "${CLR_RESET}"
        fi
        
        echo ""
        print_line "-"
        
        # IPSET Uyeleri
        printf '%b%-25s:%b ' "${CLR_ORANGE}${CLR_BOLD}" "$(T ipset_members "$TXT_IPSET_MEMBERS_TR" "$TXT_IPSET_MEMBERS_EN")" "${CLR_RESET}"
        local ipset_members="$(ipset list "$IPSET_CLIENT_NAME" 2>/dev/null | sed -n '/^Members:/,$p' | tail -n +2)"
        if [ -n "$ipset_members" ]; then
            local member_count="$(echo "$ipset_members" | wc -l | tr -d ' ')"
            printf '%b%d IP%b\n' "${CLR_GREEN}" "$member_count" "${CLR_RESET}"
            echo ""
            # awk ile numaralandirma - subshell problemi yok
            printf '%s\n' "$ipset_members" | awk -v cyan="${CLR_CYAN}" -v reset="${CLR_RESET}" '
                NF > 0 {
                    printf "  %s%2d.%s %s\n", cyan, NR, reset, $0
                }'
        else
            printf '%b%s%b\n' "${CLR_RED}" "$(T empty "$TXT_EMPTY_TR" "$TXT_EMPTY_EN")" "${CLR_RESET}"
        fi
        
        print_line "-"

        # No Zapret (Muafiyet) Uyeleri
        printf '%b%-25s:%b ' "${CLR_ORANGE}${CLR_BOLD}" "$(T nozapret_members 'No Zapret (Muafiyet)' 'No Zapret (Exempt)')" "${CLR_RESET}"
        local noz_members="$(ipset list "$NOZAPRET_IPSET_NAME" 2>/dev/null | sed -n '/^Members:/,$p' | tail -n +2)"
        if [ -f "$NOZAPRET_FILE" ] && [ -s "$NOZAPRET_FILE" ]; then
            local noz_count="$(grep -c '[0-9]' "$NOZAPRET_FILE" 2>/dev/null | tr -d ' ')"
            printf '%b%d IP%b\n' "${CLR_GREEN}" "$noz_count" "${CLR_RESET}"
            echo ""
            awk -v cyan="${CLR_CYAN}" -v reset="${CLR_RESET}" '
                NF > 0 {
                    printf "  %s%2d.%s %s\n", cyan, NR, reset, $0
                }' "$NOZAPRET_FILE"
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

        print_line "-"

        # No Zapret (Muafiyet) Uyeleri - Tum Ag modunda da goster
        printf '%b%-25s:%b ' "${CLR_ORANGE}${CLR_BOLD}" "$(T nozapret_members 'No Zapret (Muafiyet)' 'No Zapret (Exempt)')" "${CLR_RESET}"
        if [ -f "$NOZAPRET_FILE" ] && [ -s "$NOZAPRET_FILE" ]; then
            local noz_count2="$(grep -c '[0-9]' "$NOZAPRET_FILE" 2>/dev/null | tr -d ' ')"
            printf '%b%d IP%b\n' "${CLR_GREEN}" "$noz_count2" "${CLR_RESET}"
            echo ""
            awk -v cyan="${CLR_CYAN}" -v reset="${CLR_RESET}" '
                NF > 0 {
                    printf "  %s%2d.%s %s\n", cyan, NR, reset, $0
                }' "$NOZAPRET_FILE"
        else
            printf '%b%s%b\n' "${CLR_RED}" "$(T empty "$TXT_EMPTY_TR" "$TXT_EMPTY_EN")" "${CLR_RESET}"
        fi

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
        echo "$(T TXT_IPV6_NOT_INSTALLED)"
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
        echo ""


        echo "$(T TXT_IPSET_1)"
        echo "$(T TXT_IPSET_2)"
        echo "$(T TXT_IPSET_3)"
        if [ "$MODE" = "list" ]; then
            echo "$(T TXT_IPSET_4)"
            echo "$(T TXT_IPSET_5)"
            echo "$(T TXT_IPSET_6)"
            echo "$(T TXT_IPSET_0)"
            print_line "-"
            printf "$(T TXT_PROMPT_IPSET)"
        else
            echo "$(T TXT_IPSET_6)"
            echo "$(T TXT_IPSET_0)"
            print_line "-"
            printf "$(T TXT_PROMPT_IPSET_BASIC)"
        fi
        read -r ipset_choice || return 0
        echo ""

        case "$ipset_choice" in
            2)
                echo "all" > "$IPSET_CLIENT_MODE_FILE"
                rm -f "$IPSET_CLIENT_FILE" 2>/dev/null
                apply_ipset_client_settings
                echo "Tamam: Zapret tum ag icin calisacak."
                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                clear
                ;;
            3)
                # Mevcut listeyi goster
                if [ -f "$IPSET_CLIENT_FILE" ] && [ -s "$IPSET_CLIENT_FILE" ]; then
                    echo "$(T ipset_current_list 'Mevcut liste (bu islem listeyi KOMPLE degistirecek):' 'Current list (this will REPLACE the entire list):')"
                    awk '{printf "  %d. %s\n", NR, $0}' "$IPSET_CLIENT_FILE"
                    echo ""
                fi
                echo "$(T ipset_bulk_hint 'Not: Tek IP eklemek icin menu 4u kullanin.' 'Note: To add a single IP, use option 4.')"
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
                        # Gecersiz formattaki satirlari filtrele (sadece IPv4 kabul et)
                        tmp_ips_valid="/tmp/ipset_clients_valid.$$"
                        invalid_count=0
                        while IFS= read -r _line; do
                            [ -z "$_line" ] && continue
                            if echo "$_line" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
                                echo "$_line" >> "$tmp_ips_valid"
                            else
                                invalid_count=$((invalid_count + 1))
                            fi
                        done < "$tmp_ips"
                        rm -f "$tmp_ips"
                        tmp_ips="$tmp_ips_valid"
                        [ "$invalid_count" -gt 0 ] && echo "$(T _ "$invalid_count gecersiz satir atildi." "$invalid_count invalid line(s) skipped.")"

                        if [ ! -s "$tmp_ips" ]; then
                            rm -f "$tmp_ips" 2>/dev/null
                            echo "$(T ipset_invalid 'Gecersiz IP listesi. Degisiklik yapilmadi.' 'Invalid IP list. No changes made.')"
                        else
                        # No Zapret listesinde olan IP'leri filtrele (catisma onleme)
                        if [ -f "$NOZAPRET_FILE" ] && [ -s "$NOZAPRET_FILE" ]; then
                            filtered="/tmp/ipset_clients_filtered.$$"
                            clash_list=""
                            while IFS= read -r ip; do
                                [ -z "$ip" ] && continue
                                if grep -Fqx "$ip" "$NOZAPRET_FILE" 2>/dev/null; then
                                    clash_list="${clash_list} $ip"
                                else
                                    echo "$ip" >> "$filtered"
                                fi
                            done < "$tmp_ips"
                            rm -f "$tmp_ips"
                            if [ -n "$clash_list" ]; then
                                echo "$(T ipset_clash_warn 'Uyari: Su IP(ler) No Zapret listesinde oldugu icin eklenmedi:' 'Warning: The following IP(s) are in No Zapret list and were skipped:')$clash_list"
                            fi
                            tmp_ips="$filtered"
                        fi
                        if [ -s "$tmp_ips" ]; then
                            mv "$tmp_ips" "$IPSET_CLIENT_FILE" 2>/dev/null
                            echo "list" > "$IPSET_CLIENT_MODE_FILE" 2>/dev/null
                            apply_ipset_client_settings
                            echo "Tamam: Zapret sadece bu IP'lere uygulanacak."
                        else
                            rm -f "$tmp_ips" 2>/dev/null
                            echo "$(T ipset_invalid 'Gecersiz IP listesi. Degisiklik yapilmadi.' 'Invalid IP list. No changes made.')"
                        fi
                        fi  # gecersiz IP filtresi sonrasi bos kontrol
                    fi
                fi

                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                clear
                ;;
            1)
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
                    echo "Bu menu sadece \"Secili IP'lere Uygula\" (mod=list) acikken kullanilabilir. Once 3'u secin."
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
                    # Ayni IP nozapret listesinde varsa cikar (catisma onleme)
                    if [ -f "$NOZAPRET_FILE" ] && grep -Fqx "$oneip" "$NOZAPRET_FILE" 2>/dev/null; then
                        tmpf="/tmp/nozapret_clash.$$"
                        grep -Fvx "$oneip" "$NOZAPRET_FILE" > "$tmpf" 2>/dev/null
                        cp "$tmpf" "$NOZAPRET_FILE" 2>/dev/null
                        rm -f "$tmpf"
                        ipset del "$NOZAPRET_IPSET_NAME" "$oneip" 2>/dev/null
                        nozapret_apply_rules
                        echo "Tamam: IP eklendi. Not: IP, No Zapret listesinden de cikarildi."
                    else
                        echo "Tamam: IP eklendi."
                    fi
                fi
                fi
                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                clear
                ;;

            5)
                MODE="$(cat "$IPSET_CLIENT_MODE_FILE" 2>/dev/null)"
                [ -z "$MODE" ] && MODE="all"
                if [ "$MODE" != "list" ]; then
                    echo "Bu menu sadece \"Secili IP'lere Uygula\" (mod=list) acikken kullanilabilir. Once 3'u secin."
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
                    grep -Fvx "$oneip" "$IPSET_CLIENT_FILE" > "$tmpf" 2>/dev/null
                    cp "$tmpf" "$IPSET_CLIENT_FILE" 2>/dev/null; rm -f "$tmpf"
                    apply_ipset_client_settings
                    echo "Tamam: IP silindi."
                else
                    echo "IP listesi dosyasi yok."
                fi
                fi
                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                clear
                ;;
            6)
                manage_nozapret_menu
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

# -------------------------------------------------------------------
# nozapret (Muafiyet) Alt-Menusu
# -------------------------------------------------------------------

# ipset'i olusturur (yoksa) ve dosyadan yukler
nozapret_ensure_and_load() {
    ipset list "$NOZAPRET_IPSET_NAME" >/dev/null 2>&1 || \
        ipset create "$NOZAPRET_IPSET_NAME" hash:ip 2>/dev/null
    if [ -f "$NOZAPRET_FILE" ]; then
        while IFS= read -r line; do
            line="${line%%#*}"
            line="$(echo "$line" | tr -d '[:space:]')"
            [ -z "$line" ] && continue
            ipset -exist add "$NOZAPRET_IPSET_NAME" "$line" 2>/dev/null
        done < "$NOZAPRET_FILE"
    fi
}

# iptables RETURN kurali ekler (nozapret listesindeki IP'ler Zapret'ten muaf)
nozapret_apply_rules() {
    local wan_if
    wan_if="$(get_wan_if 2>/dev/null)"
    # Eski kurallari temizle
    nozapret_remove_rules
    # ipset'i yukle
    nozapret_ensure_and_load
    # RETURN kurali: nozapret listesindeki kaynak IP'ler NFQUEUE'ya gitmez
    if [ -n "$wan_if" ]; then
        iptables -t mangle -I POSTROUTING -o "$wan_if" \
            -m set --match-set "$NOZAPRET_IPSET_NAME" src \
            -j RETURN 2>/dev/null
    else
        iptables -t mangle -I POSTROUTING \
            -m set --match-set "$NOZAPRET_IPSET_NAME" src \
            -j RETURN 2>/dev/null
    fi
}

# iptables kurallarini temizler
nozapret_remove_rules() {
    while iptables -t mangle -D POSTROUTING \
        -m set --match-set "$NOZAPRET_IPSET_NAME" src \
        -j RETURN 2>/dev/null; do :; done
}

# Mevcut muafiyet listesini gosterir
nozapret_show_status() {
    print_line "-"
    printf '\033[1;36m %s\033[0m\n' "$(T TXT_NOZAPRET_TITLE)"
    print_line "-"
    if [ ! -f "$NOZAPRET_FILE" ] || [ ! -s "$NOZAPRET_FILE" ]; then
        echo "  $(T TXT_NOZAPRET_EMPTY)"
    else
        local i=0
        while IFS= read -r line; do
            line="${line%%#*}"
            line="$(echo "$line" | tr -d '[:space:]')"
            [ -z "$line" ] && continue
            i=$((i+1))
            printf '  \033[1;33m%2d.\033[0m %s\n' "$i" "$line"
        done < "$NOZAPRET_FILE"
        if [ "$i" -eq 0 ]; then
            echo "  $(T TXT_NOZAPRET_EMPTY)"
        fi
    fi
    echo ""
    printf '\033[1;32m%s\033[0m\n' "$(T TXT_NOZAPRET_IPSET_ACTIVE)"
    ipset list "$NOZAPRET_IPSET_NAME" 2>/dev/null | grep -E '^[0-9]' | \
        while read -r ip; do printf '    %s\n' "$ip"; done || \
        echo "$(T TXT_NOZAPRET_IPSET_EMPTY)"
    print_line "-"
}

# nozapret alt-menusu
manage_nozapret_menu() {
    while true; do
        clear
        print_line "="
        printf '\033[1;36m  %s\033[0m\n' "$(T TXT_NOZAPRET_TITLE)"
        echo ""
        printf '  %s\n' "$(T TXT_NOZAPRET_DESC)"
        print_line "="
        echo "$(T TXT_NOZAPRET_1)"
        echo "$(T TXT_NOZAPRET_2)"
        echo "$(T TXT_NOZAPRET_3)"
        echo "$(T TXT_NOZAPRET_4)"
        echo "$(T TXT_NOZAPRET_0)"
        print_line "-"
        printf "$(T TXT_NOZAPRET_PROMPT)"
        read -r noz_choice || return 0
        echo ""

        case "$noz_choice" in
            1)
                nozapret_show_status
                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                ;;
            2)
                printf "$(T TXT_NOZAPRET_ADD)"
                read -r noz_ip
                if [ -z "$noz_ip" ]; then
                    echo "$(T cancelled 'Iptal edildi.' 'Cancelled.')"
                elif echo "$noz_ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
                    mkdir -p "$(dirname "$NOZAPRET_FILE")"
                    touch "$NOZAPRET_FILE"
                    if grep -Fqx "$noz_ip" "$NOZAPRET_FILE" 2>/dev/null; then
                        echo "$(T TXT_NOZAPRET_EXISTS)"
                    else
                        echo "$noz_ip" >> "$NOZAPRET_FILE"
                        nozapret_apply_rules
                        # Ayni IP zapret_clients listesinde varsa cikar (catisma onleme)
                        if [ -f "$IPSET_CLIENT_FILE" ] && grep -Fqx "$noz_ip" "$IPSET_CLIENT_FILE" 2>/dev/null; then
                            tmpf="/tmp/ipset_clients_clash.$$"
                            grep -Fvx "$noz_ip" "$IPSET_CLIENT_FILE" > "$tmpf" 2>/dev/null
                            cp "$tmpf" "$IPSET_CLIENT_FILE" 2>/dev/null; rm -f "$tmpf"
                            apply_ipset_client_settings
                            echo "$(T TXT_NOZAPRET_ADDED) $(T ipset_clash_removed 'Not: IP, Secili IP listesinden de cikarildi.' 'Note: IP also removed from Selected IPs list.')"
                        else
                            echo "$(T TXT_NOZAPRET_ADDED)"
                        fi
                    fi
                else
                    echo "$(T TXT_NOZAPRET_INVALID_IP)"
                fi
                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                ;;
            3)
                printf "$(T TXT_NOZAPRET_DEL)"
                read -r noz_ip
                if [ -z "$noz_ip" ]; then
                    echo "$(T cancelled 'Iptal edildi.' 'Cancelled.')"
                elif [ -f "$NOZAPRET_FILE" ] && grep -Fqx "$noz_ip" "$NOZAPRET_FILE" 2>/dev/null; then
                    tmpf="/tmp/nozapret_del.$$"
                    grep -Fvx "$noz_ip" "$NOZAPRET_FILE" > "$tmpf" 2>/dev/null
                    cp "$tmpf" "$NOZAPRET_FILE" 2>/dev/null; rm -f "$tmpf"
                    ipset del "$NOZAPRET_IPSET_NAME" "$noz_ip" 2>/dev/null
                    nozapret_apply_rules
                    echo "$(T TXT_NOZAPRET_REMOVED)"
                else
                    echo "$(T TXT_NOZAPRET_NOTFOUND)"
                fi
                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                ;;
            4)
                printf "$(T TXT_NOZAPRET_CONFIRM_CLEAR)"
                read -r confirm
                case "$confirm" in
                    e|E|y|Y)
                        rm -f "$NOZAPRET_FILE"
                        ipset flush "$NOZAPRET_IPSET_NAME" 2>/dev/null
                        nozapret_remove_rules
                        echo "$(T TXT_NOZAPRET_CLEARED)"
                        ;;
                    *)
                        echo "$(T cancelled 'Iptal edildi.' 'Cancelled.')"
                        ;;
                esac
                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                ;;
            0)
                break
                ;;
            *)
                echo "$(T invalid_main 'Gecersiz secim!' 'Invalid choice!')"
                read -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"
                ;;
        esac
    done
}

# Kurulumdan sonra gereksiz dosyalari temizler
cleanup_files_after_extracted() {
    echo "$(T TXT_CLEANUP_REMOVING)"

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

    echo "$(T TXT_CLEANUP_REMOVED)"
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
        echo "$(T TXT_UNINSTALL_NOT_INSTALLED)"
        echo ""
        echo "$(T _ 'Ama NFQUEUE/IPSET gibi kalintilar kalmis olabilir.' 'But NFQUEUE/IPSET leftovers may still exist.')"
        printf "%s" "$(T _ 'Kalintilari temizlemek ister misiniz? (e/h): ' 'Clean up leftovers? (y/n): ')"; read -r _cc
        if echo "$_cc" | grep -qi '^[ey]'; then
            cleanup_zapret_firewall_leftovers
            remove_nfqueue_rules_200
            echo "$(T _ 'Kalintilar temizlendi.' 'Leftovers cleaned.')"
        else
            echo "$(T _ 'Iptal edildi.' 'Cancelled.')"
        fi
        press_enter_to_continue
        clear
        return 0
    fi

    printf "%s" "$(T _ 'Zapret kaldirilsin mi? (e/h): ' 'Remove Zapret? (y/n): ')"; read -r uninstall_confirmation
    case "$uninstall_confirmation" in
        e|E|y|Y) ;;
        *) echo "$(T _ 'Iptal edildi.' 'Cancelled.')"; return 0 ;;
    esac

    is_zapret_running && stop_zapret

    cleanup_zapret_firewall_leftovers

    echo "$(T TXT_UNINSTALL_REMOVING)"

    if ! echo "y" | /opt/zapret/uninstall_easy.sh >/dev/null 2>&1; then
        printf "%s" "$(T _ 'Zapret kaldirma betigi bulunamadi. Kendi aracimizla kaldirilsin mi? (e/h): ' 'Zapret uninstall script not found. Use built-in cleanup? (y/n): ')"; read -r manual_cleanup_confirmation
        
        if echo "$manual_cleanup_confirmation" | grep -qi '^[ey]'; then
            echo "$(T _ 'Kendi kaldirma aracimiz calistiriliyor...' 'Running built-in cleanup...')"
            cleanup_files_after_uninstall
            return 0 
        else
            echo "$(T _ 'Iptal edildi.' 'Cancelled.')"
            return 1 
        fi
    fi

    cleanup_files_after_uninstall

    echo "$(T TXT_UNINSTALL_OK)"
	press_enter_to_continue
	clear 
    return 0
}

# Zapret'i kurar
install_zapret() {
    # Component check before installation
    if ! check_keenetic_components; then
        return 1
    fi
    
    if is_zapret_installed; then
        echo "$(T TXT_INSTALL_ALREADY)"
        return 1
    fi

    echo "$(T _ 'OPKG paketleri denetleniyor, eksik olan varsa indirilip kurulacaktir...' 'Checking OPKG packages, missing ones will be downloaded and installed...')"
    opkg update >/dev/null 2>&1
    opkg install coreutils-sort curl grep gzip ipset iptables kmod_ndms xtables-addons_legacy >/dev/null 2>&1 || \
    { echo "$(T TXT_INSTALL_PKG_FAIL)"; return 1; }
    
    echo "$(T TXT_INSTALL_INSTALLING)"

    ZAPRET_API_URL="https://api.github.com/repos/bol-van/zapret/releases/latest"
    ZAP_DATA=$(curl -s "$ZAPRET_API_URL")
    ZAPRET_ARCHIVE_URL=$(echo "$ZAP_DATA" | grep "browser_download_url.*tar.gz" | head -n1 | cut -d '"' -f4)
    ZAPRET_VER=$(echo "$ZAP_DATA" | grep "tag_name" | cut -d '"' -f4)
    ZAPRET_ARCHIVE_NAME=$(basename "$ZAPRET_ARCHIVE_URL")
    ARCHIVE="/opt/tmp/$ZAPRET_ARCHIVE_NAME"
    DIR="/opt/zapret"

    if [ -z "$ZAPRET_ARCHIVE_URL" ]; then
        echo "$(T _ 'HATA: Zapret en guncel surumu alinamadi.' 'ERROR: Could not fetch latest Zapret version.')"
        return 1
    fi

    curl -L -o "$ARCHIVE" "$ZAPRET_ARCHIVE_URL" >/dev/null 2>&1 || { echo "$(T _ 'HATA: Arsiv indirilemedi.' 'ERROR: Failed to download archive.')"; return 1; }
    rm -rf "$DIR"
    mkdir -p /opt/tmp
    tar -xzf "$ARCHIVE" -C /opt/tmp >/dev/null 2>&1 || { echo "$(T _ 'HATA: Arsiv acilamadi.' 'ERROR: Failed to extract archive.')"; return 1; }
    EXTRACTED_DIR=$(tar -tzf "$ARCHIVE" | head -1 | cut -f1 -d"/")
    mv "/opt/tmp/$EXTRACTED_DIR" "$DIR" || { echo "$(T _ 'HATA: Dosya tasinamadi.' 'ERROR: Failed to move files.')"; return 1; }

    # Surum bilgisini kaydet
    echo "$ZAPRET_VER" > /opt/zapret/version

    echo "$(T TXT_INSTALL_OK)"

    cleanup_files_after_extracted

    keenetic_compatibility || echo "$(T TXT_INSTALL_COMPAT_WARN)"

    printf "%s " "$(T _ 'Zapret icin IPv6 destegi etkinlestirilsin mi? (e/h):' 'Enable IPv6 support for Zapret? (y/n):')"; read -r ipv6_ans
    if echo "$ipv6_ans" | grep -qi "^[ey]"; then
        ZAPRET_IPV6="y"
    else
        ZAPRET_IPV6="n"
    fi

    echo "$(T TXT_INSTALL_CFG_RUNNING)"

    IPV6_ANSWER="$ZAPRET_IPV6"


    # WAN arayuzunu belirle (WireGuard sorunlarini azaltmak icin)
    select_wan_if
    (
        echo "y"    # Sistem uyumluluk uyarisi, dokumani okuyun uyarisi: (evet)
        echo "1"    # Guvenlik duvari tipi secimi: 1=iptables 2=nftables
        echo "$IPV6_ANSWER"    # IPv6 destegi (hayir)
        echo "1"    # Filtreleme tipi secimi: 1=none 2=ipset 3=hostlist 4=autohostlist
        echo "n"    # TPWS socks modu etkinlestirilsin mi? (hayir)
        echo "n"    # TPWS transparent etkinlestirilsin mi? (hayir)
        echo "y"    # NFQWS etkinlestirilsin mi? (evet)
        echo "n"    # Yapilandirma duzenlensin mi? (hayir)
        WAN_IFINDEX="$(get_ifindex_by_iface "$(get_wan_if)")"
        [ -z "$WAN_IFINDEX" ] && WAN_IFINDEX="1"
        printf "\033[1;32m[INFO] WAN IFINDEX selected: %s\033[0m\n" "$WAN_IFINDEX" >&2
        echo "WAN_IFINDEX: $WAN_IFINDEX" >&2
        echo "1"    # LAN arayuzu secimi (1 = none)
        echo "${WAN_IFINDEX:-1}"    # WAN arayuzu secimi (1 = none)   
    ) | /opt/zapret/install_easy.sh >/dev/null 2>&1 || \
    { echo "$(T TXT_INSTALL_CFG_FAIL)"; return 1; }
    
    echo "$(T TXT_INSTALL_KEENETIC_CFG)"

    fix_keenetic_udp
    update_kernel_module_config
    update_nfqws_parameters
    disable_total_packet
    allow_firewall
    add_auto_start_zapret

    echo "$(T TXT_INSTALL_DONE)"

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


# Read current installed script version from disk (daemon-safe; handles manual edits)
zkm_get_installed_script_version() {
    local v=""
    v="$(grep -m1 '^SCRIPT_VERSION=' "$ZKM_SCRIPT_PATH" 2>/dev/null | cut -d'"' -f2)"
    [ -z "$v" ] && v="$SCRIPT_VERSION"
    echo "$v"
}


update_manager_script() {
    TARGET_SCRIPT="$ZKM_SCRIPT_PATH"
    DL_URL="https://github.com/RevolutionTR/keenetic-zapret-manager/releases/latest/download/keenetic_zapret_otomasyon_ipv6_ipset.sh"
    TMP_FILE="/tmp/keenetic_zapret_manager_update.$$"
    LOCAL_VER="$(zkm_get_installed_script_version)"
    [ -z "$LOCAL_VER" ] && LOCAL_VER="$SCRIPT_VERSION"
    BACKUP_FILE="${TARGET_SCRIPT}.bak_${LOCAL_VER#v}_$(date +%Y%m%d_%H%M%S 2>/dev/null).sh"

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


# Version guard: never auto-downgrade.
REMOTE_FILE_VER="$(grep -m1 '^SCRIPT_VERSION=' "$TMP_FILE" 2>/dev/null | cut -d'"' -f2)"
if [ -z "$REMOTE_FILE_VER" ]; then
    echo "$(T mgr_update_bad 'Indirilen dosyada surum bilgisi okunamadi, iptal edildi.' 'Unable to read version from downloaded file, aborting.')"
    rm -f "$TMP_FILE" 2>/dev/null
    return 1
fi

# Allow only if remote is newer than local.
if ! ver_is_newer "$REMOTE_FILE_VER" "$LOCAL_VER"; then
    echo "$(T mgr_update_skip 'Guncelleme atlandi (downgrade engellendi).' 'Update skipped (downgrade blocked).') $(T _ 'Kurulu:' 'Local:') $LOCAL_VER, $(T _ 'GitHub:' 'Remote:') $REMOTE_FILE_VER"
    rm -f "$TMP_FILE" 2>/dev/null
    return 0
fi

    # Backup current script if present
    if [ -f "$TARGET_SCRIPT" ]; then
        # Backup limit: keep max 3, remove oldest if exceeded
        _bak_dir="$(dirname "$TARGET_SCRIPT")"
        _bak_pattern="keenetic_zapret_otomasyon_ipv6_ipset.sh.bak_*"
        _bak_count=$(find "$_bak_dir" -maxdepth 1 -type f -name "$_bak_pattern" 2>/dev/null | wc -l | tr -d ' ')
        if [ "${_bak_count:-0}" -ge 3 ] 2>/dev/null; then
            find "$_bak_dir" -maxdepth 1 -type f -name "$_bak_pattern" 2>/dev/null | \
                sort | head -n $((_bak_count - 2)) | while IFS= read -r _f; do
                    rm -f "$_f" 2>/dev/null
                done
        fi
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
        read -r msel </dev/tty || msel=""
    else
        read -r msel || msel=""
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

    # hostlist/autohostlist modunda, listeler BOS ise zapret "include yok" gibi davranabilir (exclude haric herseyi isler).
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
        read -r sel || return 0
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
                    read -r ssel </dev/tty || ssel=""
                else
                    read -r ssel || ssel=""
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

        read -r -p "$(T TXT_ROLLBACK_MAIN_PICK) " sel || return 0
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
    echo
    echo

    # ---- Baslik (versiyon YOK - altta zaten var) ----
    printf "  %b%s%b\n" "${CLR_BOLD}${CLR_CYAN}" "$(T TXT_MAIN_TITLE)" "${CLR_RESET}"
    print_line "-"

    # ---- Bilgi satirlari ----
    local _sys _wan_dev _wan_state _zap_state
    _sys="$(zkm_banner_get_system)"
    _wan_dev="$(zkm_banner_get_wan_dev)"
    [ -z "$_wan_dev" ] && _wan_dev="-"
    _wan_state="$(zkm_banner_get_wan_state "$_wan_dev")"
    _zap_state="$(zkm_banner_get_zapret_state)"

    # Etiket genisligi: EN'de 'Zapret Version' = 14 karakter
    local _lw=14

    printf "  %b%-*s%b : %b%s%b\n"      "${CLR_BOLD}" "$_lw" "$(T TXT_MAIN_SYS_LABEL)"                        "${CLR_RESET}" "${CLR_ORANGE}" "$_sys"                                           "${CLR_RESET}"
    _fw="$(zkm_banner_get_firmware 2>/dev/null)"
    [ -n "$_fw" ] && printf "  %b%-*s%b : %b%b%s%b\n" "${CLR_BOLD}" "$_lw" "$(T _ 'Firmware' 'Firmware')" "${CLR_RESET}" "${CLR_BOLD}" "${CLR_CYAN}" "$_fw" "${CLR_RESET}"
    printf "  %b%-*s%b : %b%s | %b\n"   "${CLR_BOLD}" "$_lw" "$(T TXT_MAIN_WAN_LABEL)"                        "${CLR_RESET}" "${CLR_RESET}"  "$_wan_dev" "$(zkm_banner_fmt_wan_state "$_wan_state")"
    local _kdns_raw _kdns_access
    _kdns_raw="$(LD_LIBRARY_PATH= ndmc -c 'show ndns' 2>/dev/null)"
    _kdns_access="$(printf '%s\n' "$_kdns_raw" | awk '/^[[:space:]]*access:/ {print $2; exit}')"
    if [ -n "$_kdns_access" ]; then
        local _kdns_name _kdns_domain
        _kdns_name="$(printf '%s\n' "$_kdns_raw"   | awk '/^[[:space:]]*name:/   {print $2; exit}')"
        _kdns_domain="$(printf '%s\n' "$_kdns_raw" | awk '/^[[:space:]]*domain:/ {print $2; exit}')"
        printf "  %b%-*s%b : %s | %b\n" "${CLR_BOLD}" "$_lw" "$(T TXT_KEENDNS_BANNER_LABEL)"             "${CLR_RESET}" "${_kdns_name}.${_kdns_domain}" "$(zkm_banner_fmt_keendns_state "$_kdns_access")"
    fi
    # Zamanli reboot varsa goster
    local _sched_cur
    _sched_cur="$(crontab -l 2>/dev/null | grep '# KZM_REBOOT' | head -n 1)"
    if [ -n "$_sched_cur" ]; then
        local _sm _sh _sd _shh _smm _sname
        _sm="$(printf '%s\n' "$_sched_cur" | awk '{print $1}')"
        _sh="$(printf '%s\n' "$_sched_cur" | awk '{print $2}')"
        _sd="$(printf '%s\n' "$_sched_cur" | awk '{print $5}')"
        _shh="$(printf '%02d' "$_sh" 2>/dev/null)"
        _smm="$(printf '%02d' "$_sm" 2>/dev/null)"
        if [ "$_sd" = "*" ]; then
            printf "  %b%-*s%b : %b%b%s%b\n" \
                "${CLR_BOLD}" "$_lw" "$(T TXT_SCHED_BANNER_LABEL)" "${CLR_RESET}" \
                "${CLR_ORANGE}" "${CLR_BOLD}" "${_shh}:${_smm}" "${CLR_RESET}"
        else
            if [ "$LANG" = "en" ]; then
                case "$_sd" in
                    0|7) _sname="Sun" ;; 1) _sname="Mon" ;; 2) _sname="Tue" ;;
                    3) _sname="Wed" ;; 4) _sname="Thu" ;; 5) _sname="Fri" ;; 6) _sname="Sat" ;;
                    *) _sname="$_sd" ;;
                esac
            else
                case "$_sd" in
                    0|7) _sname="Paz" ;; 1) _sname="Pzt" ;; 2) _sname="Sal" ;;
                    3) _sname="Car" ;; 4) _sname="Per" ;; 5) _sname="Cum" ;; 6) _sname="Cmt" ;;
                    *) _sname="$_sd" ;;
                esac
            fi
            printf "  %b%-*s%b : %b%b%s%b (%s)\n" \
                "${CLR_BOLD}" "$_lw" "$(T TXT_SCHED_BANNER_LABEL)" "${CLR_RESET}" \
                "${CLR_ORANGE}" "${CLR_BOLD}" "${_shh}:${_smm}" "${CLR_RESET}" "$_sname"
        fi
    fi
    printf "  %b%-*s%b : %b%b\n"        "${CLR_BOLD}" "$_lw" "$(T TXT_MAIN_ZAPRET_LABEL)"                     "${CLR_RESET}" "${CLR_RESET}"  "$(zkm_banner_fmt_zapret_state "$_zap_state")"
    healthmon_load_config 2>/dev/null
    if healthmon_is_running 2>/dev/null; then
        printf "  %b%-*s%b : %b%s%b\n"  "${CLR_BOLD}" "$_lw" "$(T TXT_HM_BANNER_LABEL)" \
            "${CLR_RESET}" "${CLR_GREEN}"  "$(T TXT_HM_RUN_ON)"  "${CLR_RESET}"
    else
        printf "  %b%-*s%b : %b%s%b\n"  "${CLR_BOLD}" "$_lw" "$(T TXT_HM_BANNER_LABEL)" \
            "${CLR_RESET}" "${CLR_RED}"    "$(T TXT_HM_RUN_OFF)" "${CLR_RESET}"
    fi
    printf "  %b%-*s%b : %b%b%s%b\n"      "${CLR_BOLD}" "$_lw" "$(T _ 'KZM Surum'    'KZM Version'    )"        "${CLR_RESET}" "${CLR_BOLD}" "${CLR_ORANGE}" "${SCRIPT_VERSION}"                               "${CLR_RESET}"
    printf "  %b%-*s%b : %b%b%s%b\n"      "${CLR_BOLD}" "$_lw" "$(T _ 'Zapret Surum' 'Zapret Version'  )"       "${CLR_RESET}" "${CLR_BOLD}" "${CLR_ORANGE}" "$(zkm_get_zapret_version)"                       "${CLR_RESET}"
    printf "  %b%-*s%b : %b%s%b\n"      "${CLR_BOLD}" "$_lw" "$(T _ 'GitHub'       'GitHub'          )"       "${CLR_RESET}" "${CLR_DIM}"   "github.com/RevolutionTR/keenetic-zapret-manager"  "${CLR_RESET}"

    print_line "="

    # Aciklama satirlari — her biri ayri satirda, kisa
    printf "  %b%s%b\n" "${CLR_DIM}" "$(T TXT_DESC1)" "${CLR_RESET}"
    printf "  %b%s%b\n" "${CLR_DIM}" "$(T TXT_DESC2)" "${CLR_RESET}"
    printf "  %b%s%b\n" "${CLR_DIM}" "$(T TXT_DESC3)" "${CLR_RESET}"
    # TXT_OPTIMIZED ve TXT_DPI_WARNING " " ile basliyor — " %b%s" ile toplam 2 bosluk olur
    printf " %b%s%b\n" "${CLR_DIM}" "$(T TXT_OPTIMIZED)" "${CLR_RESET}"
    printf " %b%s%b\n" "${CLR_DIM}" "$(T dpi_warn "$TXT_DPI_WARNING_TR" "$TXT_DPI_WARNING_EN")" "${CLR_RESET}"
    print_line "-"

    # _mi: menu item — numara TURUNCU, metin dim
    _mi() {
        local _raw="$1"
        local _num _txt _main _note
        _num="${_raw%%.*}."
        _txt="${_raw#*.}"
        # Parantez varsa: ana metin bold, parantez ici dim
        case "$_txt" in
            *" ("*")"*)
                _main="${_txt% (*}"
                _note=" (${_txt##* (}"
                printf "  %b%s%b%b%s%b%b%s%b\n" \
                    "${CLR_ORANGE}" "$_num"  "${CLR_RESET}" \
                    "${CLR_BOLD}"   "$_main" "${CLR_RESET}" \
                    "${CLR_DIM}"    "$_note" "${CLR_RESET}"
                ;;
            *)
                printf "  %b%s%b%b%s%b\n" \
                    "${CLR_ORANGE}" "$_num" "${CLR_RESET}" \
                    "${CLR_BOLD}"   "$_txt" "${CLR_RESET}"
                ;;
        esac
    }

    # Cizgi: terminal genisligine gore dinamik "- - - - ..." 
    local _cols _sep
    _cols="$(get_term_cols 2>/dev/null)"
    [ -z "$_cols" ] && _cols=80
    [ "$_cols" -lt 50 ] 2>/dev/null && _cols=50
    _sep="$(printf '%*s' "$_cols" '' | tr ' ' '-' | sed 's/--/- /g;s/ $//')"

    # ---- ZAPRET YONETIMI (1-8) ----
    printf "  %b%s%b\n" "${CLR_CYAN}" "$(T _ 'ZAPRET YONETIMI' 'ZAPRET MANAGEMENT')" "${CLR_RESET}"
    printf "%b%s%b\n"   "${CLR_DIM}"  "$_sep" "${CLR_RESET}"
    _mi "$(T TXT_MENU_1)"
    _mi "$(T TXT_MENU_2)"
    _mi "$(T TXT_MENU_3)"
    _mi "$(T TXT_MENU_4)"
    _mi "$(T TXT_MENU_5)"
    _mi "$(T TXT_MENU_6)"
    _mi "$(T TXT_MENU_7)"
    _mi "$(T TXT_MENU_8)"
    echo

    # ---- SISTEM & ARACLAR (9-16) ----
    printf "  %b%s%b\n" "${CLR_CYAN}" "$(T _ 'SISTEM & ARACLAR' 'SYSTEM & TOOLS')" "${CLR_RESET}"
    printf "%b%s%b\n"   "${CLR_DIM}"  "$_sep" "${CLR_RESET}"
    _mi "$(T TXT_MENU_9)"
    _mi "$(T TXT_MENU_10)"
    _mi "$(T TXT_MENU_11)"
    _mi "$(T TXT_MENU_12)"
    _mi "$(T TXT_MENU_13)"
    _mi "$(T TXT_MENU_14)"
    _mi "$(T TXT_MENU_15)"
    _mi "$(T TXT_MENU_16)"
    echo

    # ---- DIGER ----
    printf "  %b%s%b\n" "${CLR_CYAN}" "$(T _ 'DIGER' 'OTHER')" "${CLR_RESET}"
    printf "%b%s%b\n"   "${CLR_DIM}"  "$_sep" "${CLR_RESET}"
    _mi "$(T TXT_MENU_B)"
    _mi "$(T TXT_MENU_L)  ($(lang_label))"
    _mi "$(T TXT_MENU_R)"
    _mi "$(T TXT_MENU_U)"
    _mi "$(T TXT_MENU_0)"

    print_line "-"
    echo
    printf "$(T TXT_PROMPT_MAIN)"
}


# --- SAGLIK KONTROLU (HEALTH CHECK) ---
run_health_check() {
    clear
    printf "\n%b%s%b\n" "${CLR_CYAN}" "$(T TXT_HEALTH_TITLE)" "${CLR_RESET}"
    print_line "="

    local HC_NET="/tmp/healthcheck_net.$$"
    local HC_SYS="/tmp/healthcheck_sys.$$"
    local HC_SVC="/tmp/healthcheck_svc.$$"
    : > "$HC_NET"; : > "$HC_SYS"; : > "$HC_SVC"

    local total_n=0 pass_n=0 warn_n=0 fail_n=0 info_n=0

    add_line() {
        local file="$1" label="$2" value="$3" status="$4"
        printf "%-35s : %s%s\n" "$label" "$(hc_word "$status")" "$value" >> "$file"
        total_n=$((total_n+1))
        case "$status" in
            PASS) pass_n=$((pass_n+1)) ;;
            WARN) warn_n=$((warn_n+1)) ;;
            FAIL) fail_n=$((fail_n+1)) ;;
            INFO) info_n=$((info_n+1)) ;;
        esac
    }

    # ----------------------------
    # WAN STATUS (counts as a check)
    # ----------------------------
    local WAN_IF=""
    WAN_IF="$(get_wan_if 2>/dev/null)"
    [ -z "$WAN_IF" ] && WAN_IF="$(healthmon_detect_wan_iface_ndm 2>/dev/null)"
    [ -z "$WAN_IF" ] && WAN_IF="PPPoE0"

    local wan_link="" wan_conn="" wan_state=""
    wan_link="$(hm_ndmc_cmd "show interface $WAN_IF" 2>/dev/null | awk '/^[ \t]*link:/ {print $2; exit}')"
    wan_conn="$(hm_ndmc_cmd "show interface $WAN_IF" 2>/dev/null | awk '/^[ \t]*connected:/ {print $2; exit}')"

    if [ -z "$wan_link" ] && [ -z "$wan_conn" ]; then
        # fallback (best-effort)
        if ip link show "$WAN_IF" >/dev/null 2>&1; then
            wan_link="up"
            wan_conn="yes"
        else
            wan_link="down"
            wan_conn="no"
        fi
    fi

    if [ "$wan_link" = "up" ] && [ "$wan_conn" = "yes" ]; then
        wan_state="PASS"
    else
        wan_state="FAIL"
    fi
    add_line "$HC_NET" "$(T TXT_HEALTH_WAN_STATUS)" " ($WAN_IF)" "$wan_state"

    # ----------------------------
    # DNS MODE / SECURITY / PROVIDERS (meta lines, NOT counted)
    # ----------------------------
    local doh_list dot_list dot_on dns_mode dns_sec dns_providers
    doh_list="$(ps w 2>/dev/null | awk '
        /https_dns_proxy/ && !/awk/{
          r=""
          for(i=1;i<=NF;i++) if($i=="-r") r=$(i+1)
          if(r!=""){
            gsub(/^https:\/\//,"",r); gsub(/\/.*$/,"",r)
            print r
          }
        }' | sort -u 2>/dev/null | tr "\n" "," | sed 's/,$//')"

    # Keenetic dns-proxy'den tum saglayicilari oku
    local _dns_proxy_raw
    _dns_proxy_raw="$(LD_LIBRARY_PATH= ndmc -c 'show dns-proxy' 2>/dev/null)"
    # dns_server satirlarindan @sonrasi SNI al (dnsm ve bos haric)
    local _dot_providers
    _dot_providers="$(printf '%s\n' "$_dns_proxy_raw" | grep 'dns_server.*@' | \
        sed 's/.*@//' | sed 's/[[:space:]].*//' | grep -v '^dnsm$' | grep -v '^$' | sort -u)"
    # server-https uri'lerinden domain al
    local _doh_providers
    _doh_providers="$(printf '%s\n' "$_dns_proxy_raw" | grep 'uri:' | \
        sed 's|.*https://||' | sed 's|/.*||' | grep -v '^$' | sort -u)"
    # Ikisini birlestir ve tekrarlananlar temizle
    dot_list="$(printf '%s\n%s\n' "$_dot_providers" "$_doh_providers" | \
        sed '/^$/d' | sort -u | tr '\n' ',' | sed 's/,$//')"

    if netstat -lntp 2>/dev/null | grep -qE ':[[:space:]]*853[[:space:]]'; then
        dot_on="1"
    else
        dot_on="0"
    fi

    # Tum saglayicilari birlestir (https_dns_proxy + dns-proxy)
    local all_providers=""
    [ -n "$doh_list" ] && all_providers="$doh_list"
    if [ -n "$dot_list" ]; then
        if [ -n "$all_providers" ]; then
            all_providers="${all_providers},${dot_list}"
        else
            all_providers="$dot_list"
        fi
    fi
    all_providers="$(printf '%s\n' "$all_providers" | tr ',' '\n' | sed '/^$/d' | sort -u | tr '\n' ',' | sed 's/,$//')"

    if [ -n "$doh_list" ] && [ "$dot_on" = "1" ]; then
        dns_mode="$(T TXT_DNS_MODE_MIXED)"
    elif [ -n "$doh_list" ]; then
        dns_mode="$(T TXT_DNS_MODE_DOH)"
    elif [ "$dot_on" = "1" ]; then
        dns_mode="$(T TXT_DNS_MODE_DOT)"
    else
        dns_mode="$(T TXT_DNS_MODE_PLAIN)"
    fi

    if [ -n "$doh_list" ] || [ "$dot_on" = "1" ]; then
        dns_sec="$(T TXT_DNS_SEC_HIGH)"
    else
        dns_sec="$(T TXT_DNS_SEC_LOW)"
    fi

    dns_providers="${all_providers:-unknown}"
    if [ -n "$all_providers" ]; then
        dns_providers="$(printf '%s\n' "$all_providers" | tr ',' '\n' | sed '/^$/d' | head -n 8 | tr '\n' ',' | sed 's/,$//')"
    fi

    # DNS checks (existing behavior)
    local dns_local_ok="PASS"
    if check_dns_local; then
        dns_local_ok="PASS"
    else
        dns_local_ok="FAIL"
    fi

    local dns_8888_ok="PASS"
    if check_dns_external; then
        dns_8888_ok="PASS"
    else
        dns_8888_ok="FAIL"
    fi

    local dns_cons_ok="INFO"
    local dns_cons_msg="($(T TXT_HEALTH_DNS_MATCH_NOTE))"
    if check_dns_consistency; then
        dns_cons_ok="PASS"
        dns_cons_msg=""
    fi

    local route_ok="PASS"
    local route_msg="($(ip route | awk '/default/ {print $3; exit}'))"
    if [ -z "$route_msg" ] || [ "$route_msg" = "()" ]; then
        route_ok="FAIL"
        route_msg="(yok)"
    fi

    local script_ok="PASS"
    local SCRIPT_PATH_EXPECTED="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh"
    local SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")"
    local script_msg="(${SCRIPT_PATH})"
    if [ "$SCRIPT_PATH" != "$SCRIPT_PATH_EXPECTED" ]; then
        script_ok="WARN"
        script_msg="(Beklenen: ${SCRIPT_PATH_EXPECTED} | Su an: ${SCRIPT_PATH})"
    fi

    local ping_ok="PASS"
    local ping_msg=""
    if ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
        ping_ok="PASS"
    else
        ping_ok="FAIL"
        ping_msg="(ping 1.1.1.1)"
    fi

    local ram_ok="PASS"
    local ram_avail_kb="$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}')"
    local ram_avail_mb="$((ram_avail_kb/1024))"
    local ram_msg="(~${ram_avail_mb}MB)"
    if [ "$ram_avail_mb" -lt 100 ]; then
        ram_ok="WARN"
    fi

    local load_ok="PASS"
    local load_val="$(awk '{print $1}' /proc/loadavg 2>/dev/null)"
    local load_msg="($load_val)"
    if awk -v l="$load_val" 'BEGIN{exit (l>2.0)?0:1}'; then
        load_ok="WARN"
    fi

    local ntp_ok="PASS"
    local ntp_msg="($(date '+%Y-%m-%d %H:%M:%S'))"
    if ! check_ntp; then
        ntp_ok="WARN"
    fi

    local gh_ok="PASS"
    local gh_msg="(HTTP 200)"
    if ! check_github; then
        gh_ok="WARN"
        gh_msg="(fail)"
    fi

    local opkg_ok="PASS"
    if ! check_opkg; then opkg_ok="WARN"; fi

    local disk_ok="PASS"
    local disk_pct="$(df /opt 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')"
    local disk_free="$(df -k /opt 2>/dev/null | awk 'NR==2 {print $4}')"
    local disk_free_mb="$((disk_free/1024))"
    local disk_msg="(${disk_pct}%, free ~${disk_free_mb}MB)"
    if [ -n "$disk_pct" ] && [ "$disk_pct" -gt 90 ]; then
        disk_ok="WARN"
    fi

    local zap_ok="PASS"
    if ! is_zapret_running; then zap_ok="FAIL"; fi

    # ----------------------------
    # SECTION: Network & DNS
    # ----------------------------
    # meta lines first (not counted)
    printf "%-35s : %s\n" "$(T TXT_HEALTH_DNS_MODE)" "$dns_mode" >> "$HC_NET"
    printf "%-35s : %s\n" "$(T TXT_HEALTH_DNS_SEC)" "$dns_sec" >> "$HC_NET"
    printf "%-35s : %s\n" "$(T TXT_HEALTH_DNS_PROVIDERS)" "$dns_providers" >> "$HC_NET"

    add_line "$HC_NET" "$(T TXT_HEALTH_DNS_LOCAL)" "" "$dns_local_ok"
    add_line "$HC_NET" "$(T TXT_HEALTH_DNS_PUBLIC)" "" "$dns_8888_ok"
    add_line "$HC_NET" "$(T TXT_HEALTH_DNS_MATCH)" " $dns_cons_msg" "$dns_cons_ok"
    add_line "$HC_NET" "$(T TXT_HEALTH_ROUTE)" " $route_msg" "$route_ok"

    # ----------------------------
    # SECTION: System
    # ----------------------------
    add_line "$HC_SYS" "$(T TXT_HEALTH_SCRIPT_PATH)" " $script_msg" "$script_ok"
    add_line "$HC_SYS" "$(T TXT_HEALTH_PING)" " $ping_msg" "$ping_ok"
    add_line "$HC_SYS" "$(T TXT_HEALTH_RAM)" " $ram_msg" "$ram_ok"
    add_line "$HC_SYS" "$(T TXT_HEALTH_LOAD)" " $load_msg" "$load_ok"
    add_line "$HC_SYS" "$(T TXT_HEALTH_DISK)" " $disk_msg" "$disk_ok"
    add_line "$HC_SYS" "$(T TXT_HEALTH_TIME)" " $ntp_msg" "$ntp_ok"

    # ----------------------------
    # SECTION: Services
    # ----------------------------
    add_line "$HC_SVC" "$(T TXT_HEALTH_GITHUB)" " $gh_msg" "$gh_ok"
    add_line "$HC_SVC" "$(T TXT_HEALTH_OPKG)" "" "$opkg_ok"
    add_line "$HC_SVC" "$(T TXT_HEALTH_ZAPRET)" "" "$zap_ok"

    # KeenDNS durumu (ndns varsa goster, yoksa INFO)
    local kdns_raw kdns_name kdns_domain kdns_access kdns_can_direct
    kdns_raw="$(LD_LIBRARY_PATH= ndmc -c 'show ndns' 2>/dev/null)"
    kdns_name="$(printf '%s\n' "$kdns_raw"   | awk '/^[[:space:]]*name:/   {print $2; exit}')"
    kdns_domain="$(printf '%s\n' "$kdns_raw" | awk '/^[[:space:]]*domain:/ {print $2; exit}')"
    kdns_access="$(printf '%s\n' "$kdns_raw" | awk '/^[[:space:]]*access:/ {print $2; exit}')"
    kdns_can_direct="$(printf '%s\n' "$kdns_raw" | awk '/^[[:space:]]*direct:/ {print $2; exit}')"
    if [ -z "$kdns_name" ]; then
        add_line "$HC_SVC" "KeenDNS" " ($(T TXT_KEENDNS_NONE))" "INFO"
    else
        local kdns_fqdn="${kdns_name}.${kdns_domain}"
        local kdns_dest kdns_port kdns_http_code kdns_reach
        kdns_dest="$(printf '%s\n' "$kdns_raw" | awk '/^[[:space:]]*destination:/ {print $2; exit}')"
        kdns_port="$(printf '%s\n' "$kdns_dest" | awk -F: '{print $NF}')"
        [ -z "$kdns_port" ] && kdns_port="443"
        [ "$kdns_port" = "443" ] && kdns_proto="https" || kdns_proto="http"
        kdns_http_code="$(curl -sk --max-time 5 -o /dev/null -w "%{http_code}"             "${kdns_proto}://${kdns_fqdn}:${kdns_port}" 2>/dev/null)"
        case "$kdns_http_code" in
            2*|3*|401|403) kdns_reach="yes" ;;
            *)             kdns_reach="no"  ;;
        esac
        if [ "$kdns_access" = "direct" ] && [ "$kdns_reach" = "no" ]; then
            # Direct modda curl basarisiz > gercek sorun
            add_line "$HC_SVC" "KeenDNS" " (${kdns_fqdn} - ${CLR_RED}$(T TXT_KEENDNS_UNKNOWN)${CLR_RESET})" "FAIL"
        elif [ "$kdns_access" = "direct" ]; then
            add_line "$HC_SVC" "KeenDNS" " (${kdns_fqdn} - ${CLR_GREEN}$(T TXT_KEENDNS_DIRECT)${CLR_RESET})" "PASS"
        elif [ "$kdns_can_direct" = "no" ]; then
            # CGN / direct imkansiz > cloud kritik, kaybederse erisim tamamen gider
            add_line "$HC_SVC" "KeenDNS" " (${kdns_fqdn} - ${CLR_YELLOW}$(T TXT_KEENDNS_CLOUD)${CLR_RESET})" "WARN"
        else
            # direct: yes ama henuz cloud > OTO gecis yapacak, gecici
            add_line "$HC_SVC" "KeenDNS" " (${kdns_fqdn} - ${CLR_YELLOW}$(T TXT_KEENDNS_CLOUD)${CLR_RESET})" "INFO"
        fi
    fi

    # ----------------------------
    # SCORE + SUMMARY
    # ----------------------------
    local ok_n=$((pass_n+info_n))
    local score rating_key rating_txt
    score="$(awk -v ok="$ok_n" -v total="$total_n" 'BEGIN{ if(total<=0){printf "0.0"} else {printf "%.1f", (ok/total)*10} }')"

    rating_key="TXT_HEALTH_RATING_OK"
    if awk -v s="$score" 'BEGIN{exit (s>=9.5)?0:1}'; then
        rating_key="TXT_HEALTH_RATING_EXCELLENT"
    elif awk -v s="$score" 'BEGIN{exit (s>=8.5)?0:1}'; then
        rating_key="TXT_HEALTH_RATING_GREAT"
    elif awk -v s="$score" 'BEGIN{exit (s>=7.0)?0:1}'; then
        rating_key="TXT_HEALTH_RATING_GOOD"
    elif awk -v s="$score" 'BEGIN{exit (s>=5.0)?0:1}'; then
        rating_key="TXT_HEALTH_RATING_OK"
    else
        rating_key="TXT_HEALTH_RATING_BAD"
    fi
    rating_txt="$(T "$rating_key")"

    printf "\n%-35s : %s / 10  [OK] %s   (%d/%d OK)\n" "$(T TXT_HEALTH_SCORE)" "$score" "$rating_txt" "$ok_n" "$total_n"
    print_line "-"
    printf "%b%s%b\n" "${CLR_CYAN}" "$(T TXT_HEALTH_SECTION_NETDNS)" "${CLR_RESET}"
    print_line "-"
    cat "$HC_NET"

    print_line "-"
    printf "%b%s%b\n" "${CLR_CYAN}" "$(T TXT_HEALTH_SECTION_SYSTEM)" "${CLR_RESET}"
    print_line "-"
    cat "$HC_SYS"

    print_line "-"
    printf "%b%s%b\n" "${CLR_CYAN}" "$(T TXT_HEALTH_SECTION_SERVICES)" "${CLR_RESET}"
    print_line "-"
    cat "$HC_SVC"

    print_line "-"
    press_enter_to_continue

    rm -f "$HC_NET" "$HC_SYS" "$HC_SVC" 2>/dev/null
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
        read -r -p "$(T TXT_CHOICE) " ch || return 0
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
        read -r CH || return 0

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
        read -r sel || return 0
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
    add_rel "/opt/zapret/scope_mode"
    add_rel "/opt/zapret/ipset_clients.txt"
    add_rel "/opt/zapret/ipset_clients_mode"
    add_rel "/opt/zapret/dpi_profile"
    add_rel "/opt/zapret/dpi_profile_origin"
    add_rel "/opt/zapret/dpi_profile_params"
    add_rel "/opt/zapret/blockcheck_auto_params"
    add_rel "/opt/etc/healthmon.conf"
    add_rel "/opt/etc/telegram.conf"

    # include all .txt files from ipset dir (nozapret, zapret-hosts-*, future files)
    for f in /opt/zapret/ipset/*.txt; do
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

    press_enter_to_continue
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
    local BACKUP_BASE="${1:-/opt/zapret_backups}"
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
        press_enter_to_continue
        return 1
    fi

    # List backups (newest first). Expected: zapret_settings_YYYYmmdd_HHMMSS.tar.gz
    local backups
    backups="$(ls -1t "$SETTINGS_DIR"/zapret_settings_*.tar.gz 2>/dev/null)"
    if [ -z "$backups" ]; then
        print_status WARN "$(T TXT_BACKUP_NO_BACKUPS_FOUND)"
        press_enter_to_continue
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
    printf "\n"
    printf "  c) %s
" "$(T TXT_ZAPRET_SETTINGS_CLEAN_MENU)"
    printf "  0) %s
" "$(T TXT_BACK)"
    print_line "-"
    printf "%s" "$(T TXT_CHOICE)"
    read -r sel || return 0
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
        press_enter_to_continue
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
        press_enter_to_continue
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
    printf " 6. %s\n" "$(T TXT_RESTORE_SCOPE_KZM)"
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
    mkdir -p "$tmp" || { print_status FAIL "$(T TXT_BACKUP_RESTORE_FAILED)"; press_enter_to_continue; return 1; }

    # Extract to temp first (safer), then copy selected paths
    if ! tar -xzf "$chosen" -C "$tmp" >/dev/null 2>&1; then
        rm -rf "$tmp" 2>/dev/null
        print_status FAIL "$(T TXT_BACKUP_RESTORE_FAILED)"
        press_enter_to_continue
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

    # Varsayilan: islem basarili kabul edilir. Zorunlu parcalar yoksa/basarisizsa ok=1 yapilir.
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
            _copy_if_exists "opt/zapret/dpi_profile_origin" || true
            _copy_if_exists "opt/zapret/dpi_profile_params" || true
            _copy_if_exists "opt/zapret/blockcheck_auto_params" || true
            ;;
        3) # hostlist / autohostlist
            _copy_if_exists "opt/zapret/hostlist_mode" || ok=1
            _copy_if_exists "opt/zapret/scope_mode" || true
            _copy_if_exists "opt/zapret/ipset" || true
            ;;
        4) # ipset settings
            _copy_if_exists "opt/zapret/ipset_clients.txt" || true
            _copy_if_exists "opt/zapret/ipset" || true
            _copy_if_exists "opt/zapret/ipset_clients_mode" || true
            ;;
        5) # nfqws config only
            _copy_if_exists "opt/zapret/config" || ok=1
            ;;
        6) # KZM settings (healthmon + telegram)
            _copy_if_exists "opt/etc/healthmon.conf" || true
            _copy_if_exists "opt/etc/telegram.conf" || true
            ;;
        *)
            rm -rf "$tmp" 2>/dev/null
            print_status WARN "$(T TXT_INVALID_CHOICE)"
            press_enter_to_continue
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
    press_enter_to_continue
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

# -------------------------------------------------------------------
# Telegram: Device identity header (hostname / IP / model)
# Purpose: When multiple routers use the same bot, make it obvious which
# device generated the alert.
# -------------------------------------------------------------------
TG_INCLUDE_DEVICE_HEADER="${TG_INCLUDE_DEVICE_HEADER:-1}"
TG_DEVICE_NAME=""
TG_DEVICE_LAN_IP=""
TG_DEVICE_WAN_IP=""
TG_DEVICE_MODEL=""

telegram_device_info_init() {
    # Cache device identity once per run
    [ -n "$TG_DEVICE_NAME" ] && [ -n "$TG_DEVICE_LAN_IP" ] && [ -n "$TG_DEVICE_WAN_IP" ] && [ -n "$TG_DEVICE_MODEL" ] && return 0

    # Hostname (Keenetic "System Name")
    TG_DEVICE_NAME="$(hostname 2>/dev/null)"
    [ -z "$TG_DEVICE_NAME" ] && TG_DEVICE_NAME="$(cat /proc/sys/kernel/hostname 2>/dev/null)"
    [ -z "$TG_DEVICE_NAME" ] && TG_DEVICE_NAME="keenetic"

    # -------------------------
    # LAN IP (prefer bridge/br0)
    # -------------------------
    TG_DEVICE_LAN_IP=""
    for _if in br0 bridge0 home0; do
        _ip="$(ip -4 addr show "$_if" 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)"
        [ -n "$_ip" ] && TG_DEVICE_LAN_IP="$_ip" && break
    done
    # Fallback: first RFC1918 address on any interface
    if [ -z "$TG_DEVICE_LAN_IP" ]; then
        TG_DEVICE_LAN_IP="$(ip -4 addr show 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | \
            awk '/^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)/ {print; exit}')"
    fi
    [ -z "$TG_DEVICE_LAN_IP" ] && TG_DEVICE_LAN_IP="unknown"

    # -------------------------
    # WAN IP (best-effort)
    # - PPPoE users: ppp0 is the most reliable
    # - Otherwise: default-route interface IPv4
    # -------------------------
    TG_DEVICE_WAN_IP=""
    _wan_if=""
    # Prefer ppp0 if present
    _wan_if="$(ip -4 addr show ppp0 2>/dev/null | awk '/inet /{print "ppp0"; exit}')"
    if [ -z "$_wan_if" ]; then
        # Parse default route line: "default via X dev IF ..." or "default dev IF ..."
        _wan_if="$(ip -4 route show default 2>/dev/null | awk '{
            for(i=1;i<=NF;i++){
                if($i=="dev"){print $(i+1); exit}
            }
        }')"
    fi
    if [ -n "$_wan_if" ]; then
        TG_DEVICE_WAN_IP="$(ip -4 addr show "$_wan_if" 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)"
    fi
    [ -z "$TG_DEVICE_WAN_IP" ] && TG_DEVICE_WAN_IP="unknown"

    # -------------------------
    # Model (Keenetic / ndmc varies by firmware)
    # Try several sources in order.
    # -------------------------
    TG_DEVICE_MODEL=""

    _ver="$(LD_LIBRARY_PATH= ndmc -c show version 2>/dev/null)"
    if [ -n "$_ver" ]; then
        # 1) Key:value lines
        TG_DEVICE_MODEL="$(printf '%s\n' "$_ver" | awk -F': ' '
            /model:|description:|product:|device:|hardware:|board:/ {
                gsub(/^[ \t]+|[ \t]+$/, "", $2);
                if ($2 != "") { print $2; exit }
            }')"
        # 2) Sadece tam KN-xxxx ise tabloya bak; Keenetic ile baslamiyorsa ekle
        case "$TG_DEVICE_MODEL" in
            KN-[0-9]*)
                _kn2="$(_zkm_kn_to_name "$TG_DEVICE_MODEL" 2>/dev/null)"
                [ -n "$_kn2" ] && TG_DEVICE_MODEL="$_kn2"
                ;;
            Keenetic*) ;;
            ?*) TG_DEVICE_MODEL="Keenetic $TG_DEVICE_MODEL" ;;
        esac
        [ -z "$TG_DEVICE_MODEL" ] && TG_DEVICE_MODEL="$(printf '%s\n' "$_ver" | grep -Eo 'KN-[0-9]{3,5}' | head -n 1)"
        # 3) "Keenetic XXX" line (fallback human name)
        if [ -z "$TG_DEVICE_MODEL" ]; then
            TG_DEVICE_MODEL="$(printf '%s\n' "$_ver" | awk '
                BEGIN{IGNORECASE=1}
                /keenetic/ {print; exit}
            ' | sed 's/^[ \t]*//;s/[ \t]*$//')"
        fi
    fi

    # 4) ndmc show system (some firmwares keep product name there)
    if [ -z "$TG_DEVICE_MODEL" ]; then
        _sys="$(LD_LIBRARY_PATH= ndmc -c show system 2>/dev/null)"
        TG_DEVICE_MODEL="$(printf '%s\n' "$_sys" | awk -F': ' '
            /model:|description:|product:|device:|hardware:|board:/ {
                gsub(/^[ \t]+|[ \t]+$/, "", $2);
                if ($2 != "") { print $2; exit }
            }')"
        case "$TG_DEVICE_MODEL" in
            KN-[0-9]*)
                _kn2="$(_zkm_kn_to_name "$TG_DEVICE_MODEL" 2>/dev/null)"
                [ -n "$_kn2" ] && TG_DEVICE_MODEL="$_kn2"
                ;;
            Keenetic*) ;;
            ?*) TG_DEVICE_MODEL="Keenetic $TG_DEVICE_MODEL" ;;
        esac
        [ -z "$TG_DEVICE_MODEL" ] && TG_DEVICE_MODEL="$(printf '%s\n' "$_sys" | grep -Eo 'KN-[0-9]{3,5}' | head -n 1)"
    fi

    # 5) Device-tree model (varies by platform)
    if [ -z "$TG_DEVICE_MODEL" ]; then
        for _f in /proc/device-tree/model /sys/firmware/devicetree/base/model; do
            if [ -r "$_f" ]; then
                TG_DEVICE_MODEL="$(cat "$_f" 2>/dev/null | tr -d '\000' | sed 's/^[ \t]*//;s/[ \t]*$//')"
                [ -n "$TG_DEVICE_MODEL" ] && break
            fi
        done
    fi

    [ -z "$TG_DEVICE_MODEL" ] && TG_DEVICE_MODEL="Keenetic"

    # KN-xxxx kodunu tam ada cevir - sadece tam "KN-xxxx" veya "Keenetic KN-xxxx" formatindaysa
    # Keenetic ile baslamiyorsa ekle
    case "$TG_DEVICE_MODEL" in
        KN-[0-9]*)
            _full="$(_zkm_kn_to_name "$TG_DEVICE_MODEL" 2>/dev/null)"
            [ -n "$_full" ] && TG_DEVICE_MODEL="$_full"
            ;;
        Keenetic\ KN-[0-9]*)
            _kn_code="$(printf '%s' "$TG_DEVICE_MODEL" | grep -Eo 'KN-[0-9]{3,5}' | head -1)"
            _full="$(_zkm_kn_to_name "$_kn_code" 2>/dev/null)"
            [ -n "$_full" ] && TG_DEVICE_MODEL="$_full"
            ;;
        Keenetic*) ;;
        ?*) TG_DEVICE_MODEL="Keenetic $TG_DEVICE_MODEL" ;;
    esac
    return 0
}


telegram_build_msg() {
    # Wrap plain messages into a consistent, multi-router friendly format.
    # $1: event text (may contain newlines)
    local event="$1"
    telegram_device_info_init

    # If it's a single line, prefix with a neutral label for backward compat.
    if [ "$(printf '%s' "$event" | wc -l 2>/dev/null)" -le 1 ]; then
        event="📣 $(T TXT_TG_EVENT_LABEL) :
$event"
    fi

    cat <<EOF
📡 $(T TXT_TG_DEVICE_LABEL) : $TG_DEVICE_NAME
🏠 $(T TXT_TG_LAN_LABEL) : $TG_DEVICE_LAN_IP
🌍 $(T TXT_TG_WAN_LABEL) : $TG_DEVICE_WAN_IP
🔧 $(T TXT_TG_MODEL_LABEL) : $TG_DEVICE_MODEL

$event
🕒 $(T TXT_TG_TIME_LABEL) : $(date '+%Y-%m-%d %H:%M:%S')
EOF
}

telegram_ready() {
    # Ensure Telegram is configured (token + chat id). Best-effort device header init.
    telegram_load_config || return 1
    telegram_device_info_init >/dev/null 2>&1
    return 0
}


telegram_send() {
    # $1 message (UTF-8)
    [ -n "$1" ] || return 1

    # Telegram basic pre-req
    telegram_ready || return 1

    # Optional: include device header + timestamp (same format as other TG alerts)
    local _tg_msg="$1"
    if [ "${TG_INCLUDE_DEVICE_HEADER:-1}" = "1" ]; then
        # Always attempt to wrap with device header; avoid brittle shell builtins checks.
        _tg_msg="$(telegram_build_msg "$_tg_msg" 2>/dev/null)"
        [ -n "$_tg_msg" ] || _tg_msg="$1"
    fi

    # Find curl in daemon PATH too
    local CURL_BIN=""
    CURL_BIN="$(command -v curl 2>/dev/null)"
    [ -z "$CURL_BIN" ] && [ -x /opt/bin/curl ] && CURL_BIN="/opt/bin/curl"
    [ -z "$CURL_BIN" ] && [ -x /usr/bin/curl ] && CURL_BIN="/usr/bin/curl"
    [ -z "$CURL_BIN" ] && [ -x /bin/curl ] && CURL_BIN="/bin/curl"
    if [ -z "$CURL_BIN" ]; then
        healthmon_log "$(healthmon_now) | telegram | curl not found"
        return 127
    fi

    # After WAN flaps, DNS may not be ready immediately (curl rc=6).
    # We wait a bit and retry with exponential backoff.
    local try=1 max_try=6 rc=0
    local backoff=1
    local host_ok=0
    while [ "$try" -le "$max_try" ]; do
        # Optional DNS readiness check (best-effort)
        host_ok=0
        if command -v nslookup >/dev/null 2>&1; then
            nslookup api.telegram.org >/dev/null 2>&1 && host_ok=1
        elif command -v getent >/dev/null 2>&1; then
            getent hosts api.telegram.org >/dev/null 2>&1 && host_ok=1
        else
            host_ok=1  # no resolver tool; skip precheck
        fi

        if [ "$host_ok" -ne 1 ]; then
            healthmon_log "$(healthmon_now) | telegram | dns not ready try=$try"
            sleep "$backoff" 2>/dev/null
            backoff=$((backoff*2)); [ "$backoff" -gt 8 ] && backoff=8
            try=$((try+1))
            continue
        fi

        "$CURL_BIN" -sS \
            --connect-timeout 5 --max-time 15 \
            --retry 3 --retry-delay 1 --retry-all-errors \
            -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TG_CHAT_ID}" \
            --data-urlencode "text=$_tg_msg" \
            -d "disable_web_page_preview=true" \
            >/dev/null 2>&1
        rc=$?

        [ "$rc" -eq 0 ] && return 0

        healthmon_log "$(healthmon_now) | telegram | send failed rc=$rc try=$try"
        sleep "$backoff" 2>/dev/null
        backoff=$((backoff*2)); [ "$backoff" -gt 8 ] && backoff=8
        try=$((try+1))
    done

    return "$rc"
}


# Compatibility: old code may call tg_send
tg_send() { telegram_send "$@"; }
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
            printf "%b\n" "${CLR_BOLD}${CLR_ORANGE}$(T TXT_TG_STATUS_NOT_CONFIG)${CLR_RESET}"
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
        read -r c || return 0
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
HM_INTERVAL="60"
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
HM_UPDATECHECK_ENABLE="1"
HM_UPDATECHECK_SEC="21600"
HM_UPDATECHECK_REPO_ZKM="RevolutionTR/keenetic-zapret-manager"
HM_UPDATECHECK_REPO_ZAPRET="bol-van/zapret"
HM_COOLDOWN_SEC="600"
HM_ZAPRET_COOLDOWN_SEC="120"

# NFQUEUE qlen watchdog (qnum=200)
# qlen > HM_QLEN_WARN_TH olan ardisik tur sayisi HM_QLEN_CRIT_TURNS'e ulasirsa -> restart_zapret
HM_QLEN_WATCHDOG="1"          # 0=disable, 1=enable
HM_QLEN_WARN_TH="50"          # paket esigi: bu degeri asarsa sayac artar
HM_QLEN_CRIT_TURNS="3"        # kac ardisik tur ust uste yuksekse aksiyon alinir

# KeenDNS curl throttle: her dongu degil, bu kadar saniyede bir curl cek
HM_KEENDNS_CURL_SEC="120"     # 0 = her dongude (eski davranis)


healthmon_print_autoupdate_warning() {
    # Show a single WARN header, then plain indented lines (less noisy)
    print_status WARN "$(T TXT_HM_AUTOUPDATE_WARN_TITLE)"
    printf "  %s
" "$(T TXT_HM_AUTOUPDATE_WARN_L1)"
    printf "  %s
" "$(T TXT_HM_AUTOUPDATE_WARN_L2)"
}



healthmon_load_config() {
    HM_ENABLE="0"
    HM_INTERVAL="60"
    HM_CPU_WARN="70"
    HM_CPU_WARN_DUR="180"
    HM_CPU_CRIT="90"
    HM_CPU_CRIT_DUR="60"
    HM_DISK_WARN="90"
    HM_RAM_WARN_MB="40"
    HM_ZAPRET_WATCHDOG="1"
    HM_COOLDOWN_SEC="600"
    HM_ZAPRET_COOLDOWN_SEC="120"
    HM_UPDATECHECK_ENABLE="1"
    HM_UPDATECHECK_SEC="21600"
    HM_UPDATECHECK_REPO_ZKM="RevolutionTR/keenetic-zapret-manager"
    HM_UPDATECHECK_REPO_ZAPRET="bol-van/zapret"
    HM_AUTOUPDATE_MODE="2"

    HM_WANMON_ENABLE="0"
    HM_WANMON_FAIL_TH="3"
    HM_WANMON_OK_TH="2"
    HM_WANMON_IFACE=""
    HM_QLEN_WATCHDOG="1"
    HM_QLEN_WARN_TH="50"
    HM_QLEN_CRIT_TURNS="3"
    HM_KEENDNS_CURL_SEC="120"

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
HM_UPDATECHECK_ENABLE="$HM_UPDATECHECK_ENABLE"
HM_UPDATECHECK_SEC="$HM_UPDATECHECK_SEC"
HM_UPDATECHECK_REPO_ZKM="$HM_UPDATECHECK_REPO_ZKM"
HM_UPDATECHECK_REPO_ZAPRET="$HM_UPDATECHECK_REPO_ZAPRET"
HM_AUTOUPDATE_MODE="$HM_AUTOUPDATE_MODE"
HM_WANMON_ENABLE="$HM_WANMON_ENABLE"
HM_WANMON_FAIL_TH="$HM_WANMON_FAIL_TH"
HM_WANMON_OK_TH="$HM_WANMON_OK_TH"
HM_WANMON_IFACE="$HM_WANMON_IFACE"
HM_QLEN_WATCHDOG="$HM_QLEN_WATCHDOG"
HM_QLEN_WARN_TH="$HM_QLEN_WARN_TH"
HM_QLEN_CRIT_TURNS="$HM_QLEN_CRIT_TURNS"
HM_KEENDNS_CURL_SEC="$HM_KEENDNS_CURL_SEC"
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

# -------------------------------
# WAN Monitor (NDM/ndmc based, no ping)
# Uses: HM_WANMON_ENABLE, HM_WANMON_IFACE, HM_WANMON_FAIL_TH, HM_WANMON_OK_TH
# Requires ndmc but isolates Entware LD_LIBRARY_PATH conflicts.
# -------------------------------
hm_ndmc_cmd() { LD_LIBRARY_PATH= ndmc -c "$1" 2>/dev/null; }

hm_wanmon_get_iface() {
    # Priority:
    # 1) cached runtime iface (linux netdev)
    # 2) HM_WANMON_IFACE (user override)
    # 3) auto: use existing WAN helpers / default route (linux netdev)
    # 4) last resort: NDM PPPoE name -> map to ppp0 if present
    local cache="/tmp/wanmon.ndm_iface"
    local ifc=""

    if [ -f "$cache" ]; then
        ifc="$(cat "$cache" 2>/dev/null)"
    fi

    [ -z "$ifc" ] && ifc="$HM_WANMON_IFACE"

    if [ -z "$ifc" ]; then
        # Prefer existing helpers used elsewhere (Menu 14 / Health)
        ifc="$(get_wan_if 2>/dev/null)"
        [ -z "$ifc" ] && ifc="$(healthmon_detect_wan_iface_ndm 2>/dev/null)"

        # Fallback: parse default route robustly (avoid returning 'link')
        if [ -z "$ifc" ]; then
            ifc="$(ip route 2>/dev/null | awk '$1=="default"{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
        fi
    fi

    # If we still don't have a linux iface, try NDM PPPoE name and map to ppp0 if possible
    if [ -n "$ifc" ] && ! ip link show "$ifc" >/dev/null 2>&1; then
        local ndm_if=""
        ndm_if="$(hm_ndmc_cmd "show interface" | awk '
            BEGIN{RS="Interface, name = "; FS="
"}
            NR>1{
                name=$1; gsub(/".*/,"",name); gsub(/^[ 	"]+|[ 	"]+$/,"",name)
                is_pppoe=0
                for(i=1;i<=NF;i++){
                    if($i ~ /^[ 	]*type:[ 	]*PPPoE[ 	]*$/){ is_pppoe=1; break }
                }
                if(is_pppoe){ print name; exit }
            }
        ')"
        # Common mapping: PPPoE0 -> ppp0 (linux netdev)
        if ip link show ppp0 >/dev/null 2>&1; then
            ifc="ppp0"
        else
            # Keep empty if invalid
            ifc=""
        fi
    fi

    # Cache only valid linux netdev
    if [ -n "$ifc" ] && ip link show "$ifc" >/dev/null 2>&1; then
        echo "$ifc" >"$cache" 2>/dev/null
        chmod 600 "$cache" 2>/dev/null
    fi

    echo "$ifc"
}


hm_wanmon_is_linux_iface() {
    local ifc="$1"
    [ -z "$ifc" ] && return 1
    ip link show "$ifc" >/dev/null 2>&1
}

hm_wanmon_is_up() {
    local ifc="$1"
    [ -z "$ifc" ] && return 1

    # Linux netdev ise:
    # - PPP/IPOe gibi sanal WAN arayuzlerinde LOWER_UP tek basina yeterli degil (WAN kapali iken de UP kalabilir).
    #   Bu nedenle IPv4 adresi + default route varligini kontrol ediyoruz.
    # - Diger arayuzlerde (ethX, wlanX vb.) LOWER_UP yeterlidir.
    if ip link show "$ifc" >/dev/null 2>&1; then
        case "$ifc" in
            ppp*|ipoe*|pppoe*)
                ip -4 addr show dev "$ifc" 2>/dev/null | awk '/inet[[:space:]]/{found=1; exit} END{exit !found}' || return 1
                ip -4 route show default dev "$ifc" 2>/dev/null | grep -q '^default' || return 1
                return 0
                ;;
            *)
                ip link show "$ifc" 2>/dev/null | head -n 1 | grep -q LOWER_UP
                return
                ;;
        esac
    fi

    # ndmc fallback
    hm_ndmc_cmd "show interface $ifc" | awk '
        $1=="link:"      && l=="" {l=$2}
        $1=="connected:" && c=="" {c=$2}
        END { exit ! (l=="up" && c=="yes") }
    '
}
hm_wanmon_iface_exists() {
local ifc="$1"
[ -z "$ifc" ] && return 1

# Linux netdev ise direkt gecerlidir (ppp0, ipoe0, ethX, vb.)
if ip link show "$ifc" >/dev/null 2>&1; then
    return 0
fi

# ndmc fallback (varsa)
hm_ndmc_cmd "show interface $ifc" 2>/dev/null | grep -qE '^[[:space:]]*link:'
}
hm_fmt_hms() {
    # $1 seconds -> HH:MM:SS
    local s="$1"
    [ -z "$s" ] && s=0
    local hh=$((s/3600))
    local mm=$(((s%3600)/60))
    local ss=$((s%60))
    printf "%02d:%02d:%02d" "$hh" "$mm" "$ss"
}

hm_wanmon_tick() {
    [ "${HM_WANMON_ENABLE:-0}" = "1" ] || return 0

    local state_f="/tmp/wanmon.state"
    local down_ts_f="/tmp/wanmon.down_ts"
    local down_hms_f="/tmp/wanmon.down_hms"
    local fails_f="/tmp/wanmon.fails"
    local oks_f="/tmp/wanmon.oks"

    local ifc conf_disp
    ifc="$(hm_wanmon_get_iface)"
    conf_disp="${HM_WANMON_IFACE:-auto}"

    # one-time init log
    if [ ! -f /tmp/wanmon.inited ]; then
        healthmon_log "$(healthmon_now) | wanmon | init iface=${ifc:-N/A} conf=${conf_disp}"
        echo 1 >/tmp/wanmon.inited 2>/dev/null
        chmod 600 /tmp/wanmon.inited 2>/dev/null
    fi

    if [ -z "$ifc" ]; then
        if [ ! -f /tmp/wanmon.iface_warned ]; then
            healthmon_log "$(healthmon_now) | wanmon | iface not set, skipping"
            echo 1 >/tmp/wanmon.iface_warned 2>/dev/null
            chmod 600 /tmp/wanmon.iface_warned 2>/dev/null
        fi
        return 0
    fi

    if ! hm_wanmon_iface_exists "$ifc"; then
        if [ ! -f /tmp/wanmon.iface_bad_warned ]; then
            healthmon_log "$(healthmon_now) | wanmon | iface invalid ($ifc), skipping"
            echo 1 >/tmp/wanmon.iface_bad_warned 2>/dev/null
            chmod 600 /tmp/wanmon.iface_bad_warned 2>/dev/null
        fi
        return 0
    fi

    rm -f /tmp/wanmon.iface_warned /tmp/wanmon.iface_bad_warned 2>/dev/null

    # defaults
    [ -f "$fails_f" ] || echo 0 >"$fails_f"
    [ -f "$oks_f" ] || echo 0 >"$oks_f"
    chmod 600 "$fails_f" "$oks_f" 2>/dev/null

    local state now fails oks
    state="$(cat "$state_f" 2>/dev/null)"
    # CRITICAL FIX: Default to DOWN on first boot/startup so we can detect UP transition
    # If state file doesn't exist, assume DOWN (boot scenario)
    if [ -z "$state" ]; then
        state="DOWN"
        # Also save it so we know this is first run
        echo "DOWN" >"$state_f" 2>/dev/null
        chmod 600 "$state_f" 2>/dev/null
    fi

    fails="$(cat "$fails_f" 2>/dev/null)"; case "$fails" in ''|*[!0-9]*) fails=0;; esac
    oks="$(cat "$oks_f" 2>/dev/null)"; case "$oks" in ''|*[!0-9]*) oks=0;; esac

    now="$(healthmon_now)"

    if hm_wanmon_is_up "$ifc"; then
        # observed UP
        fails=0
        oks=$((oks+1))
        echo "$fails" >"$fails_f" 2>/dev/null
        echo "$oks" >"$oks_f" 2>/dev/null

        if [ "$state" = "DOWN" ] && [ "$oks" -ge "${HM_WANMON_OK_TH:-2}" ]; then
            # transition DOWN -> UP, send single rich UP message with duration
            local down_ts down_hms up_hms dur wan_disp
            down_ts="$(cat "$down_ts_f" 2>/dev/null)"; case "$down_ts" in ''|*[!0-9]*) down_ts="$now";; esac
            down_hms="$(cat "$down_hms_f" 2>/dev/null)"
            [ -z "$down_hms" ] && down_hms="$(date '+%H:%M:%S' 2>/dev/null)"

            up_hms="$(date '+%H:%M:%S' 2>/dev/null)"
            dur="$(hm_fmt_hms $((now - down_ts)))"

            wan_disp="$conf_disp"
            if [ -z "$wan_disp" ] || [ "$wan_disp" = "auto" ]; then
                wan_disp="$ifc"
            fi

            echo "UP" >"$state_f" 2>/dev/null
            chmod 600 "$state_f" 2>/dev/null
            rm -f "$down_ts_f" "$down_hms_f" 2>/dev/null

            telegram_send "$(printf '%s
%s : %s
%s : %s
%s : %s' \
                "$(tpl_render "$(T TXT_HM_WAN_UP_TITLE)" IF "$wan_disp")" \
                "📉 $(T TXT_HM_WAN_DOWN_TIME_LABEL)" "$down_hms" \
                "📈 $(T TXT_HM_WAN_UP_TIME_LABEL)" "$up_hms" \
                "🕐 $(T TXT_HM_WAN_DUR_LABEL)" "$dur")"
            healthmon_log "$now | wanmon | up iface=$ifc dur=$dur"
        fi
        return 0
    fi

    # observed DOWN
    oks=0
    fails=$((fails+1))
    echo "$fails" >"$fails_f" 2>/dev/null
    echo "$oks" >"$oks_f" 2>/dev/null

    if [ "$state" = "UP" ] && [ "$fails" -ge "${HM_WANMON_FAIL_TH:-3}" ]; then
        echo "DOWN" >"$state_f" 2>/dev/null
        chmod 600 "$state_f" 2>/dev/null
        echo "$now" >"$down_ts_f" 2>/dev/null
        chmod 600 "$down_ts_f" 2>/dev/null
        echo "$(date '+%H:%M:%S' 2>/dev/null)" >"$down_hms_f" 2>/dev/null
        chmod 600 "$down_hms_f" 2>/dev/null
        healthmon_log "$now | wanmon | down iface=$ifc"
        # NOTE: No Telegram on DOWN. We notify only when it comes back UP (with duration).
    fi
}



healthmon_log() {
    # $1 line
    # In daemon mode, stdout is redirected by init.d to /tmp/healthmon.log,
    # so printing to stdout is the most reliable way to make logs visible immediately.
    if [ -t 1 ]; then
        # Interactive: append to log file (best-effort)
        if [ -n "$HM_LOG_FILE" ]; then
            # Log rotation: truncate to last 200 lines if file exceeds 500KB
            if [ -f "$HM_LOG_FILE" ]; then
                local _sz
                _sz=$(wc -c < "$HM_LOG_FILE" 2>/dev/null)
                if [ "${_sz:-0}" -gt 512000 ] 2>/dev/null; then
                    local _tmp="${HM_LOG_FILE}.tmp"
                    tail -n 200 "$HM_LOG_FILE" > "$_tmp" 2>/dev/null && mv "$_tmp" "$HM_LOG_FILE" 2>/dev/null
                fi
            fi
            echo "$1" >>"$HM_LOG_FILE" 2>/dev/null
        fi
    else
        # Daemon: write to stdout (captured by init.d redirection)
        echo "$1"
    fi
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

healthmon_update_state_load() {
    # state to avoid repeated notifications
    HM_UPD_STATE_FILE="/opt/etc/healthmon_update.state"
    ZKM_LAST_NOTIFIED=""
    ZAPRET_LAST_NOTIFIED=""
    ZKM_LAST_AUTO_ATTEMPTED=""
    [ -f "$HM_UPD_STATE_FILE" ] && . "$HM_UPD_STATE_FILE" 2>/dev/null
}

healthmon_update_state_save() {
    mkdir -p /opt/etc 2>/dev/null
    umask 077
    cat >"$HM_UPD_STATE_FILE" <<EOF
ZKM_LAST_NOTIFIED="$ZKM_LAST_NOTIFIED"
ZAPRET_LAST_NOTIFIED="$ZAPRET_LAST_NOTIFIED"
ZKM_LAST_AUTO_ATTEMPTED="$ZKM_LAST_AUTO_ATTEMPTED"
EOF
    chmod 600 "$HM_UPD_STATE_FILE" 2>/dev/null
}

github_latest_release_tag() {
    # $1 = owner/repo
    local repo="$1"
    local api="https://api.github.com/repos/${repo}/releases/latest"
    local tag
    tag="$(curl -fsS "$api" 2>/dev/null | grep -m1 '"tag_name"' | cut -d '"' -f4)"
    if [ -n "$tag" ]; then
        echo "$tag"
        return 0
    fi
    # fallback: tags list
    api="https://api.github.com/repos/${repo}/tags?per_page=1"
    tag="$(curl -fsS "$api" 2>/dev/null | grep -m1 '"name"' | cut -d '"' -f4)"
    [ -n "$tag" ] && { echo "$tag"; return 0; }
    return 1
}
# Compare versions like v26.2.4 vs v26.2.3 (supports 3-4 numeric parts).
# Returns: 1 if A>B, -1 if A<B, 0 if equal.
zkm_ver_cmp() {
    local A="${1#v}"; A="${A#V}"
    local B="${2#v}"; B="${B#V}"
    # trim whitespace/CRLF just in case
    A="$(printf %s "$A" | tr -d ' 	
')"
    B="$(printf %s "$B" | tr -d ' 	
')"
    # If current version is empty/unknown, treat latest as newer
    case "$B" in ''|unknown|UNKNOWN) echo 1; return 0 ;; esac
    awk -v A="$A" -v B="$B" '
        function norm(x){ gsub(/[^0-9.]/,"",x); return x }
        function splitv(s, arr,   n,i){
            s=norm(s)
            n=split(s,arr,".")
            for(i=1;i<=n;i++){
                gsub(/[^0-9]/,"",arr[i])
                if(arr[i]=="") arr[i]=0
            }
            return n
        }
        BEGIN{
            na=splitv(A,a); nb=splitv(B,b)
            n=(na>nb?na:nb)
            for(i=1;i<=n;i++){
                av=(i in a?a[i]:0)+0
                bv=(i in b?b[i]:0)+0
                if(av>bv){print 1; exit}
                if(av<bv){print -1; exit}
            }
            print 0
        }'
}
zkm_ver_gt() { [ "$(zkm_ver_cmp "$1" "$2")" = "1" ]; }


healthmon_updatecheck_do() {
    # Update check master switch
    [ "${HM_UPDATECHECK_ENABLE:-0}" = "1" ] || return 0

    # Auto update mode:
    # 0 = OFF (no checks)
    # 1 = Notify only
    # 2 = Auto install (KZM only)
    local upd_mode="${HM_AUTOUPDATE_MODE:-1}"
    case "$upd_mode" in
        0) return 0 ;;
        1|2) : ;;
        *) upd_mode="1" ;;
    esac

    local now last_ts f sec
    f="/tmp/healthmon_updatecheck.ts"
    now="$(healthmon_now)"
    sec="${HM_UPDATECHECK_SEC:-21600}"   # default 6h

    # Throttle: only run the GitHub API check every HM_UPDATECHECK_SEC seconds.
    last_ts="$(cat "$f" 2>/dev/null)"
    if [ -n "$last_ts" ] && [ $((now - last_ts)) -lt "$sec" ] 2>/dev/null; then
        : > /tmp/healthmon_updatecheck.defer 2>/dev/null
        return 0
    fi

    # clear defer marker and stamp last check time early to avoid tight loops on failures
    rm -f /tmp/healthmon_updatecheck.defer 2>/dev/null
    echo "$now" > "$f" 2>/dev/null

    local repo api latest cur
    repo="${HM_UPDATECHECK_REPO_ZKM:-RevolutionTR/keenetic-zapret-manager}"
    api="https://api.github.com/repos/${repo}/releases/latest"

    cur="$(zkm_get_installed_script_version)"; [ -z "$cur" ] && cur="$SCRIPT_VERSION"
    latest="$(curl -fsS "$api" 2>/dev/null | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"

    # Always log what we saw, so "ran but did nothing" is visible.
    echo "$(date +%s 2>/dev/null) | updatecheck | zkm | cur=$cur latest=${latest:-N/A} mode=$upd_mode" >> /tmp/healthmon.log 2>/dev/null

    if [ -z "$latest" ]; then
        # GitHub unreachable: only log, do NOT send Telegram (network may be temporarily unavailable)
        echo "$(date +%s 2>/dev/null) | updatecheck | zkm | github_unreachable cur=$cur" >> /tmp/healthmon.log 2>/dev/null
        # Reset timestamp so it retries next cycle instead of waiting full HM_UPDATECHECK_SEC
        rm -f "$f" 2>/dev/null
        return 0
    fi

    # Never downgrade: skip if remote is not newer than local (dev builds like v26.2.5.1 must not be replaced by v26.2.5).
    if ! ver_is_newer "$latest" "$cur"; then
        echo "$(date +%s 2>/dev/null) | updatecheck | zkm | up_to_date cur=$cur latest=$latest" >> /tmp/healthmon.log 2>/dev/null
        telegram_send "$(tpl_render "$(T TXT_UPD_ZKM_UP_TO_DATE)" CUR "$cur")"
        return 0
    fi

    # New version exists
    local url msg
    url="https://github.com/${repo}/releases/latest"

    if [ "$upd_mode" = "1" ]; then
        msg="$(tpl_render "$(T TXT_UPD_ZKM_NEW)" NEW "$latest" CUR "$cur" URL "$url")"
        telegram_send "$msg"
        echo "$(date +%s 2>/dev/null) | updatecheck | zkm | notified cur=$cur latest=$latest" >> /tmp/healthmon.log 2>/dev/null
        return 0
    fi

    # upd_mode=2 -> auto install
    if [ "$upd_mode" = "2" ]; then
        echo "$(date +%s 2>/dev/null) | updatecheck | zkm | autoinstall_start cur=$cur latest=$latest" >> /tmp/healthmon.log 2>/dev/null
        if update_manager_script >/tmp/zkm_autoupdate.log 2>&1; then
            telegram_send "$(tpl_render "$(T TXT_UPD_ZKM_AUTO_OK)" NEW "$latest" CUR "$cur" URL "$url")"
            echo "$(date +%s 2>/dev/null) | updatecheck | zkm | autoinstall_ok cur=$cur latest=$latest" >> /tmp/healthmon.log 2>/dev/null
        else
            telegram_send "$(tpl_render "$(T TXT_UPD_ZKM_AUTO_FAIL)" CUR "$cur" NEW "$latest" URL "$url")"
            echo "$(date +%s 2>/dev/null) | updatecheck | zkm | autoinstall_fail cur=$cur latest=$latest" >> /tmp/healthmon.log 2>/dev/null
        fi
    fi
    return 0
}


ndmc_cmd() {
    # Important: prevent Entware /opt libs from breaking ndmc
    LD_LIBRARY_PATH= ndmc -c "$1" 2>/dev/null
}

healthmon_detect_wan_iface_ndm() {
    # Prefer explicit user config if set
    if [ -n "${HM_WANMON_IFACE:-}" ]; then
        echo "$HM_WANMON_IFACE"
        return 0
    fi

    # Prefer zapret-selected WAN info (single source of truth)
    local zif
    zif="$(cat /opt/zapret/wan_if 2>/dev/null)"

    # If PPP-based WAN is used (ppp0/ppp1), map to first PPPoE interface known by NDM (e.g., PPPoE0)
    if echo "$zif" | grep -Eq '^ppp[0-9]*$'; then
        ndmc_cmd "show interface" | awk '
            BEGIN{RS="Interface, name = "; FS="\n"}
            NR>1{
                name=$1
                gsub(/".*/,"",name); gsub(/^[ \t"]+|[ \t"]+$/,"",name)
                type=""
                for(i=1;i<=NF;i++){
                    if($i ~ /(^|[ \t])type:[ \t]/){sub(/.*type:[ \t]*/,"",$i); type=$i}
                }
                if(type=="PPPoE"){print name; exit}
            }'
        return 0
    fi

    # Generic fallback: pick first interface marked public=yes or having "Internet" trait
    ndmc_cmd "show interface" | awk '
        BEGIN{RS="Interface, name = "; FS="\n"}
        NR>1{
            name=$1
            gsub(/".*/,"",name); gsub(/^[ \t"]+|[ \t"]+$/,"",name)
            if(name ~ /GigabitEthernet0(\/|$)/) next
            if(name ~ /^[0-9]+$/) next
            pub="no"; inet="no"
            for(i=1;i<=NF;i++){
                if($i ~ /(^|[ \t])public:[ \t]yes/){pub="yes"}
                if($i ~ /(^|[ \t])traits:[ \t].*Internet/){inet="yes"}
            }
            if(pub=="yes" || inet=="yes"){print name; exit}
        }'
}

healthmon_wan_is_up() {
    local ifc="$1"
    [ -n "$ifc" ] || return 1
    ndmc_cmd "show interface $ifc" | awk '
        $1=="link:"      {l=$2}
        $1=="connected:" {c=$2}
        END { exit ! (l=="up" && c=="yes") }
    '
}


healthmon_wan_tick() {
    hm_wanmon_tick
}

healthmon_loop() {
    trap '' HUP 2>/dev/null
    # Stale-state cleanup on daemon start (keep PID/log intact)
    rm -f /tmp/wanmon.* /tmp/healthmon_wan.* 2>/dev/null
    rm -f /tmp/healthmon_cpu_* /tmp/healthmon_disk* /tmp/healthmon_ram* /tmp/healthmon_zapret_* /tmp/healthmon_last_* 2>/dev/null
    rm -f /tmp/healthmon_qlen.cnt /tmp/healthmon_qlen.prev /tmp/healthmon_keendns_curl.ts 2>/dev/null
    # single-instance guard (robust against stale PID/lock after power loss)
    if ! mkdir "$HM_LOCKDIR" 2>/dev/null; then
        # If a healthy daemon exists, do nothing.
        if [ -f "$HM_PID_FILE" ]; then
            local _p
            _p="$(cat "$HM_PID_FILE" 2>/dev/null)"
            if [ -n "$_p" ] && kill -0 "$_p" 2>/dev/null; then
                exit 0
            fi
        fi
        # Stale lock (directory) - clear and retry once
        rm -rf "$HM_LOCKDIR" 2>/dev/null
        if ! mkdir "$HM_LOCKDIR" 2>/dev/null; then
            exit 0
        fi
    fi
    echo "$$" >"$HM_PID_FILE" 2>/dev/null
    : >"$HM_LOG_FILE" 2>/dev/null
    echo "$(date +%s) | started" >>"$HM_LOG_FILE" 2>/dev/null

    # Load config early
    healthmon_load_config

    # CRITICAL FIX: Wait for network on startup (especially after power loss/reboot)
    # This must happen BEFORE any WAN monitoring or GitHub checks
    local net_wait=0
    local net_max=120
    healthmon_log "$(date +%s) | startup | waiting for network (max ${net_max}s)"
    while [ $net_wait -lt $net_max ]; do
        if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
            healthmon_log "$(date +%s) | startup | network ready after ${net_wait}s (ping OK)"
            break
        fi
        if command -v nslookup >/dev/null 2>&1 && nslookup google.com >/dev/null 2>&1; then
            healthmon_log "$(date +%s) | startup | network ready after ${net_wait}s (DNS OK)"
            break
        fi
        if ip route get 1.1.1.1 >/dev/null 2>&1; then
            healthmon_log "$(date +%s) | startup | network ready after ${net_wait}s (route OK)"
            break
        fi
        sleep 5
        net_wait=$((net_wait + 5))
    done
    if [ $net_wait -ge $net_max ]; then
        healthmon_log "$(date +%s) | startup | WARNING: network not ready after ${net_max}s, continuing anyway"
    fi

    # If script version changed since last run, force an early update check.
    # NOTE: This runs AFTER network wait so the forced check can actually reach GitHub.
    if [ -n "$SCRIPT_VERSION" ]; then
        _curv="$SCRIPT_VERSION"
        _lastv="$(cat /tmp/healthmon.last_script_ver 2>/dev/null)"
        if [ "$_curv" != "$_lastv" ]; then
            echo "$_curv" > /tmp/healthmon.last_script_ver 2>/dev/null
            rm -f /tmp/healthmon_updatecheck.ts /tmp/healthmon_updatecheck.defer 2>/dev/null
        fi
    fi

    # NOW that network is ready, run initial WAN monitoring tick
    # This will detect WAN UP state and send notification if needed
    if [ "$HM_ENABLE" = "1" ] && [ "${HM_WANMON_ENABLE:-0}" = "1" ]; then
        healthmon_log "$(date +%s) | startup | running initial WAN check"
        hm_wanmon_tick
    fi

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

        # ---- NFQUEUE qlen watchdog (qnum=200) ----
        # nfqws calisiyor gorunse de kuyruk tikanirsa (zombie working) tespit eder ve restart atar.
        if [ "${HM_QLEN_WATCHDOG:-1}" = "1" ]; then
            local qlen_th qlen_turns qlen_val qlen_cnt_f qlen_prev_f qlen_cnt qlen_prev
            qlen_th="${HM_QLEN_WARN_TH:-50}"
            qlen_turns="${HM_QLEN_CRIT_TURNS:-3}"
            qlen_cnt_f="/tmp/healthmon_qlen.cnt"
            qlen_prev_f="/tmp/healthmon_qlen.prev"

            # /proc/net/netfilter/nfnetlink_queue formati:
            # queue_num  portid  qlen  copy_mode  copy_range  ...
            # Alan 3 = qlen (0-indexed: $3)
            qlen_val="$(awk '$1 == 200 { print $3; exit }' /proc/net/netfilter/nfnetlink_queue 2>/dev/null)"
            case "$qlen_val" in ''|*[!0-9]*) qlen_val=0 ;; esac

            # Onceki qlen degerini oku (artip artmadigini loglamak icin)
            qlen_prev="$(cat "$qlen_prev_f" 2>/dev/null)"
            case "$qlen_prev" in ''|*[!0-9]*) qlen_prev=0 ;; esac
            echo "$qlen_val" > "$qlen_prev_f" 2>/dev/null

            if [ "$qlen_val" -gt "$qlen_th" ]; then
                # Kuyrug yuksek: sayaci artir
                qlen_cnt="$(cat "$qlen_cnt_f" 2>/dev/null)"
                case "$qlen_cnt" in ''|*[!0-9]*) qlen_cnt=0 ;; esac
                qlen_cnt=$((qlen_cnt + 1))
                echo "$qlen_cnt" > "$qlen_cnt_f" 2>/dev/null
                healthmon_log "$now | qlen_high | qnum=200 qlen=$qlen_val prev=$qlen_prev cnt=$qlen_cnt/${qlen_turns}"

                if [ "$qlen_cnt" -ge "$qlen_turns" ]; then
                    # Ardisik N tur yuksek: restart_zapret
                    healthmon_log "$now | qlen_crit | qnum=200 qlen=$qlen_val cnt=$qlen_cnt triggers=restart_zapret"
                    if healthmon_should_alert "qlen_crit" "${HM_ZAPRET_COOLDOWN_SEC:-120}"; then
                        telegram_send "$(tpl_render "$(T TXT_HM_ZAPRET_DOWN_MSG)" CPU "$cpu" LOAD "$load" RAM "$ram" DISK "$disk") [qlen=$qlen_val]"
                    fi
                    restart_zapret >/dev/null 2>&1
                    sleep 2
                    # zapret_watchdog ile cift-restart cakmasi onlemek icin state dosyalarini sifirla.
                    # zapret_watchdog bir sonraki turda is_zapret_running=true gorur (ok) ya da
                    # 30s sayacini bastan baslatir (fail) > tek kaynaktan kontrol saglanir.
                    rm -f /tmp/healthmon_zapret_down.start /tmp/healthmon_zapret_restart.tried 2>/dev/null
                    # Restart sonrasi kontrol
                    if is_zapret_running; then
                        healthmon_log "$now | qlen_restart_ok | qnum=200 zapret is running"
                        if healthmon_should_alert "qlen_restart_ok" "${HM_ZAPRET_COOLDOWN_SEC:-120}"; then
                            telegram_send "$(tpl_render "$(T TXT_HM_ZAPRET_UP_MSG)" CPU "$cpu" LOAD "$load" RAM "$ram" DISK "$disk") [qlen watchdog ok]"
                        fi
                    else
                        healthmon_log "$now | qlen_restart_fail | qnum=200 zapret still not running after restart"
                    fi
                    # Sayaci sifirla (restart sonrasi tekrar izlemeye basla)
                    rm -f "$qlen_cnt_f" 2>/dev/null
                fi
            else
                # qlen normal: sayaci sifirla
                if [ -f "$qlen_cnt_f" ]; then
                    qlen_cnt="$(cat "$qlen_cnt_f" 2>/dev/null)"
                    [ "${qlen_cnt:-0}" -gt 0 ] && healthmon_log "$now | qlen_recovered | qnum=200 qlen=$qlen_val cnt_reset"
                    rm -f "$qlen_cnt_f" 2>/dev/null
                fi
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
            fi
        fi

                # WAN monitor (NDM-based, no ping)

# periodic update check (GitHub)
        healthmon_updatecheck_do
        # ---- KEENDNS MONITOR ----
        local kdns_raw2 kdns_name2 kdns_domain2 kdns_access2
        kdns_raw2="$(LD_LIBRARY_PATH= ndmc -c 'show ndns' 2>/dev/null)"
        kdns_name2="$(printf '%s\n' "$kdns_raw2"   | awk '/^[[:space:]]*name:/   {print $2; exit}')"
        kdns_domain2="$(printf '%s\n' "$kdns_raw2" | awk '/^[[:space:]]*domain:/ {print $2; exit}')"
        kdns_access2="$(printf '%s\n' "$kdns_raw2" | awk '/^[[:space:]]*access:/ {print $2; exit}')"
        if [ -n "$kdns_name2" ]; then
            local kdns_fqdn="${kdns_name2}.${kdns_domain2}"
            # --- Erisim modu (direct/cloud) izleme ---
            local kdns_prev_f="/tmp/healthmon_keendns.prev"
            local kdns_prev
            kdns_prev="$(cat "$kdns_prev_f" 2>/dev/null)"
            local kdns_can_direct2
            kdns_can_direct2="$(printf '%s\n' "$kdns_raw2" | awk '/^[[:space:]]*direct:/ {print $2; exit}')"
            if [ -n "$kdns_prev" ] && [ "$kdns_prev" != "$kdns_access2" ]; then
                if [ "$kdns_access2" = "direct" ]; then
                    # direct'e dondu
                    if healthmon_should_alert "keendns_up" "$HM_COOLDOWN_SEC"; then
                        telegram_send "$(printf "$(T TXT_KEENDNS_BACK)" "$kdns_fqdn")"
                        healthmon_log "$now | keendns_up | $kdns_fqdn"
                    fi
                elif [ "$kdns_can_direct2" = "no" ]; then
                    # CGN: cloud'a dustu, direct imkansiz > kritik alarm
                    if healthmon_should_alert "keendns_down" "$HM_COOLDOWN_SEC"; then
                        telegram_send "$(printf "$(T TXT_KEENDNS_CGN_LOST)" "$kdns_fqdn")"
                        healthmon_log "$now | keendns_cgn_lost | $kdns_fqdn"
                    fi
                fi
                # direct:yes + cloud > OTO gecis yapacak, alarm verme
            fi
            printf '%s\n' "$kdns_access2" > "$kdns_prev_f" 2>/dev/null
            # --- Gercek erisim (curl) izleme --- THROTTLED (HM_KEENDNS_CURL_SEC) ---
            # curl her dongude degil, sadece HM_KEENDNS_CURL_SEC saniyede bir calisir.
            # Bu sayede NFQUEUE (qnum=200) kuyruklari curl yukunden korunur.
            local kdns_curl_ts_f="/tmp/healthmon_keendns_curl.ts"
            local kdns_curl_last kdns_curl_interval
            kdns_curl_last="$(cat "$kdns_curl_ts_f" 2>/dev/null)"
            case "$kdns_curl_last" in ''|*[!0-9]*) kdns_curl_last=0 ;; esac
            kdns_curl_interval="${HM_KEENDNS_CURL_SEC:-120}"
            case "$kdns_curl_interval" in ''|*[!0-9]*) kdns_curl_interval=120 ;; esac
            local kdns_dest2 kdns_port2 kdns_http2 kdns_reach2
            if [ "$kdns_curl_interval" -eq 0 ] || [ $((now - kdns_curl_last)) -ge "$kdns_curl_interval" ]; then
                echo "$now" > "$kdns_curl_ts_f" 2>/dev/null
                kdns_dest2="$(printf '%s\n' "$kdns_raw2" | awk '/^[[:space:]]*destination:/ {print $2; exit}')"
                kdns_port2="$(printf '%s\n' "$kdns_dest2" | awk -F: '{print $NF}')"
                [ -z "$kdns_port2" ] && kdns_port2="443"
                [ "$kdns_port2" = "443" ] && kdns_proto2="https" || kdns_proto2="http"
                kdns_http2="$(curl -sk --max-time 5 -o /dev/null -w "%{http_code}" "${kdns_proto2}://${kdns_fqdn}:${kdns_port2}" 2>/dev/null)"
                case "$kdns_http2" in
                    2*|3*|401|403) kdns_reach2="yes" ;;
                    *)             kdns_reach2="no"  ;;
                esac
            else
                # Throttled: onceki sonucu kullan, curl yapma
                kdns_reach2="$(cat "/tmp/healthmon_keendns_reach.prev" 2>/dev/null)"
                [ -z "$kdns_reach2" ] && kdns_reach2="yes"  # ilk turda bilinmiyor, alarm uretme
                # Log icin safe default: throttle turunda bu degerler set edilmemis olabilir
                [ -z "$kdns_port2" ]  && kdns_port2="(throttled)"
                [ -z "$kdns_http2" ]  && kdns_http2="(throttled)"
            fi
            local kdns_reach_f="/tmp/healthmon_keendns_reach.prev"
            local kdns_reach_prev
            kdns_reach_prev="$(cat "$kdns_reach_f" 2>/dev/null)"
            # Curl alarmi:
            # - direct modda: erisim kesilirse/gelirse alarm
            # - CGN (direct:no) + cloud modda: cloud erisimi kesilirse/gelirse alarm
            local kdns_do_curl_alarm="no"
            [ "$kdns_access2" = "direct" ] && kdns_do_curl_alarm="yes"
            [ "$kdns_can_direct2" = "no" ] && kdns_do_curl_alarm="yes"
            if [ "$kdns_do_curl_alarm" = "yes" ]; then
                if [ -n "$kdns_reach_prev" ] && [ "$kdns_reach_prev" != "$kdns_reach2" ]; then
                    if [ "$kdns_reach2" = "yes" ]; then
                        if healthmon_should_alert "keendns_reach" "$HM_COOLDOWN_SEC"; then
                            if [ "$kdns_can_direct2" = "no" ]; then
                                telegram_send "$(printf "$(T TXT_KEENDNS_CGN_BACK)" "$kdns_fqdn")"
                            else
                                telegram_send "$(printf "$(T TXT_KEENDNS_REACH)" "$kdns_fqdn")"
                            fi
                            healthmon_log "$now | keendns_reachable | $kdns_fqdn"
                        fi
                    else
                        if healthmon_should_alert "keendns_unreach" "$HM_COOLDOWN_SEC"; then
                            if [ "$kdns_can_direct2" = "no" ]; then
                                telegram_send "$(printf "$(T TXT_KEENDNS_CGN_LOST)" "$kdns_fqdn")"
                            else
                                telegram_send "$(printf "$(T TXT_KEENDNS_FAIL)" "$kdns_fqdn")"
                            fi
                            healthmon_log "$now | keendns_unreachable | $kdns_fqdn port=$kdns_port2 http=$kdns_http2"
                        fi
                    fi
                fi
            fi
            printf '%s\n' "$kdns_reach2" > "$kdns_reach_f" 2>/dev/null
        fi

        # ---- WAN MONITOR ----
        hm_wanmon_tick

        # ---- LOG ROTATION ----
        # Daemon stdout is redirected to HM_LOG_FILE by init.d (>> append).
        # Truncate to last 300 lines if file exceeds 500KB to protect /tmp RAM.
        if [ -f "$HM_LOG_FILE" ]; then
            _lsz=$(wc -c < "$HM_LOG_FILE" 2>/dev/null)
            if [ "${_lsz:-0}" -gt 512000 ] 2>/dev/null; then
                _ltmp="${HM_LOG_FILE}.tmp"
                tail -n 300 "$HM_LOG_FILE" > "$_ltmp" 2>/dev/null && mv "$_ltmp" "$HM_LOG_FILE" 2>/dev/null
            fi
        fi

        # ---- AUTOHOSTLIST LOG ROTATION ----
        # Zapret's autohostlist log lives on /opt (persistent). Cap at 1MB.
        _ahl_log="/opt/zapret/nfqws_autohostlist.log"
        if [ -f "$_ahl_log" ]; then
            _ahl_sz=$(wc -c < "$_ahl_log" 2>/dev/null)
            if [ "${_ahl_sz:-0}" -gt 1048576 ] 2>/dev/null; then
                _ahl_tmp="${_ahl_log}.tmp"
                tail -n 500 "$_ahl_log" > "$_ahl_tmp" 2>/dev/null && mv "$_ahl_tmp" "$_ahl_log" 2>/dev/null
            fi
        fi

        sleep "$HM_INTERVAL"
    done

    rm -f "$HM_PID_FILE" 2>/dev/null
    rmdir "$HM_LOCKDIR" 2>/dev/null
}

healthmon_is_running() {
  # 1) PID file check
  if [ -f "$HM_PID_FILE" ]; then
    PID="$(cat "$HM_PID_FILE" 2>/dev/null)"
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
      return 0
    fi
  fi

  # 2) Fallback: detect an existing daemon even if PID file was lost (/tmp wiped, manual edits, etc.)
  PID="$(ps 2>/dev/null | awk -v n="$SCRIPT_NAME" 'index($0,"--healthmon-daemon")>0 && index($0,n)>0 {print $1; exit}')"
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    # re-seed pid file for future checks (best-effort)
    echo "$PID" >"$HM_PID_FILE" 2>/dev/null
    return 0
  fi

  return 1
}



healthmon_autostart_install() {
    # Ensure HealthMon starts after reboot when enabled
    mkdir -p /opt/etc/init.d 2>/dev/null
    cat > "$HM_AUTOSTART_FILE" <<'EOF'
#!/opt/bin/sh
# Auto-start for KZM Health Monitor (Entware init.d)
# FIXED: Added network wait for post-reboot reliability
SCRIPT="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh"
CONF="/opt/etc/healthmon.conf"
PIDFILE="/tmp/healthmon.pid"
LOCKDIR="/tmp/healthmon.lock"
INITLOG="/tmp/healthmon_init.log"

log_init() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$INITLOG"
}

wait_for_network() {
  local max_wait=120
  local waited=0
  local interval=5
  
  log_init "Waiting for network..."
  
  while [ $waited -lt $max_wait ]; do
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
      log_init "Network ready (waited ${waited}s)"
      return 0
    fi
    
    if ip route get 1.1.1.1 >/dev/null 2>&1; then
      log_init "Network ready via routing (waited ${waited}s)"
      return 0
    fi
    
    sleep $interval
    waited=$((waited + interval))
  done
  
  log_init "WARNING: Network timeout after ${max_wait}s, starting anyway"
  return 1
}

cleanup_stale() {
  if [ -f "$PIDFILE" ]; then
    local old_pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$old_pid" ] && ! kill -0 "$old_pid" 2>/dev/null; then
      log_init "Removing stale PID: $old_pid"
      rm -f "$PIDFILE" 2>/dev/null
    fi
  fi
  
  if [ -d "$LOCKDIR" ]; then
    if [ -f "$LOCKDIR/pid" ]; then
      local lock_pid=$(cat "$LOCKDIR/pid" 2>/dev/null)
      if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
        log_init "Removing stale lock: $lock_pid"
        rm -rf "$LOCKDIR" 2>/dev/null
      fi
    else
      log_init "Removing orphaned lock directory"
      rm -rf "$LOCKDIR" 2>/dev/null
    fi
  fi
}

start() {
  log_init "=== Init start ==="
  
  if [ ! -f "$CONF" ] || ! grep -q '^HM_ENABLE="1"' "$CONF" 2>/dev/null; then
    log_init "HealthMon disabled in config"
    return 0
  fi
  
  cleanup_stale
  
  if [ -f "$PIDFILE" ]; then
    local pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      log_init "Already running (PID: $pid)"
      return 0
    fi
  fi
  
  wait_for_network
  
  log_init "Starting daemon..."
  "$SCRIPT" --healthmon-daemon </dev/null >>/tmp/healthmon.log 2>&1 &
  
  sleep 2
  if [ -f "$PIDFILE" ]; then
    local new_pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$new_pid" ] && kill -0 "$new_pid" 2>/dev/null; then
      log_init "Started successfully (PID: $new_pid)"
      return 0
    else
      log_init "ERROR: Startup failed (PID file exists but process dead)"
      return 1
    fi
  else
    log_init "ERROR: Startup failed (no PID file)"
    return 1
  fi
}

stop() {
  log_init "=== Init stop ==="
  if [ -f "$PIDFILE" ]; then
    local pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ]; then
      log_init "Stopping PID: $pid"
      kill "$pid" 2>/dev/null
      sleep 1
      if kill -0 "$pid" 2>/dev/null; then
        log_init "Force killing PID: $pid"
        kill -9 "$pid" 2>/dev/null
      fi
    fi
    rm -f "$PIDFILE" 2>/dev/null
  fi
  rm -rf "$LOCKDIR" 2>/dev/null
  log_init "Stopped"
}

case "$1" in
  start) start ;;
  stop) stop ;;
  restart) stop; sleep 1; start ;;
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
    # NOTE: Each iteration checks terminal liveness. If the controlling terminal
    # is gone (SSH/Telnet disconnect, Ctrl-C), we bail out immediately to prevent
    # the main script from getting stuck in a zombie loop.
    local i pid
    for i in 1 2 3 4 5; do
        pid="$(cat "$HM_PID_FILE" 2>/dev/null)"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        # If our controlling TTY is gone, don't keep looping
        if ! [ -t 0 ] && ! [ -e /dev/tty ]; then
            return 0
        fi
        sleep 1 || return 0
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

    # Stop daemon by PID file if present
    if [ -f "$HM_PID_FILE" ]; then
        kill "$(cat "$HM_PID_FILE" 2>/dev/null)" 2>/dev/null
        rm -f "$HM_PID_FILE" 2>/dev/null
    fi

    # Fallback: stop any stray daemon instances (e.g., PID file missing)
    ps 2>/dev/null | awk -v n="$SCRIPT_NAME" 'index($0,"--healthmon-daemon")>0 && index($0,n)>0 {print $1}' | while read -r p; do
        [ -n "$p" ] && kill "$p" 2>/dev/null
    done

    # Clear volatile state to avoid stale counters after reboot/power loss
    rm -f /tmp/wanmon.* /tmp/healthmon.* /tmp/healthmon_wan.* 2>/dev/null
    rm -rf "$HM_LOCKDIR" 2>/dev/null
}


healthmon_status() {
    healthmon_load_config

    local isrun=0
    healthmon_is_running && isrun=1

    local run_txt
    if [ "$isrun" -eq 1 ]; then
        run_txt="$(T TXT_HM_RUN_ON)"
        run_txt="${CLR_GREEN}${run_txt}${CLR_RESET}"
    else
        run_txt="$(T TXT_HM_RUN_OFF)"
        run_txt="${CLR_RED}${run_txt}${CLR_RESET}"
    fi

    local cpu load disk ram
    cpu=$(healthmon_cpu_pct)
    load=$(healthmon_loadavg)
    disk=$(healthmon_disk_used_pct /opt)
    ram=$(healthmon_mem_free_mb)

    local pid=""
    [ -f "$HM_PID_FILE" ] && pid="$(cat "$HM_PID_FILE" 2>/dev/null)"

    # zapret state
    local zst="n/a"
    if is_zapret_installed; then
        is_zapret_running && zst="$(T TXT_HM_ZAPRET_UP_SHORT)" || zst="$(T TXT_HM_ZAPRET_DOWN_SHORT)"
    else
        zst="$(T TXT_HM_ZAPRET_NA_SHORT)"
    fi

    # translate auto-update mode
    local mode_txt
    case "${HM_AUTOUPDATE_MODE:-0}" in
        2) mode_txt="$(T TXT_HM_MODE2)" ;;
        1) mode_txt="$(T TXT_HM_MODE1)" ;;
        *) mode_txt="$(T TXT_HM_MODE0)" ;;
    esac

    local upd_word
    if [ "${HM_UPDATECHECK_ENABLE:-0}" = "1" ]; then
        upd_word="$(T TXT_HM_WORD_ON)"
    else
        upd_word="$(T TXT_HM_WORD_OFF)"
    fi

    local _w=22
    local _lbl

    hm_kv() {
        # $1=label, $2=value
        _lbl="$1"
        _lbl="${_lbl%:}"
        printf "  %-*s : %s\n" "$_w" "$_lbl" "$2"
    }

    clear_screen
    print_line "="
    printf "%b%s%b\n" "${CLR_CYAN}" "$(T TXT_HM_STATUS_TITLE)" "${CLR_RESET}"
    print_line "="
    echo

    # Status line
    _lbl="$(T TXT_HM_STATUS_RUNNING)"; _lbl="${_lbl%:}"
    printf "  %-*s : %s (%s=%s%s)\n" "$_w" "$_lbl" "$run_txt" "$(T TXT_HM_ENABLE_LABEL)" "$HM_ENABLE" "${pid:+, pid=$pid}"

    echo
    printf "%b%s%b\n" "${CLR_CYAN}" "$(T TXT_HM_STATUS_SEC_SETTINGS)" "${CLR_RESET}"
    print_line "-"

    hm_kv "$(T TXT_HM_STATUS_INTERVAL)" "${HM_INTERVAL}s"
    hm_kv "$(T TXT_HM_CFG_ITEM10)" "${HM_HEARTBEAT_SEC}s"
    hm_kv "$(T TXT_HM_CFG_ITEM9)" "${HM_COOLDOWN_SEC}s"
    hm_kv "$(T TXT_HM_STATUS_UPDATECHECK)" "${upd_word}=${HM_UPDATECHECK_ENABLE}, $(T TXT_HM_FLAG_EVERY)=${HM_UPDATECHECK_SEC}s"
    hm_kv "$(T TXT_HM_STATUS_AUTOUPDATE)" "${mode_txt} ($(T TXT_HM_FLAG_MODE)=${HM_AUTOUPDATE_MODE:-0})"

    echo
    printf "%b%s%b\n" "${CLR_CYAN}" "$(T TXT_HM_STATUS_SEC_THRESH)" "${CLR_RESET}"
    print_line "-"

    hm_kv "$(T TXT_HM_STATUS_CPU_WARN)" "${HM_CPU_WARN}% / ${HM_CPU_WARN_DUR}s"
    hm_kv "$(T TXT_HM_STATUS_CPU_CRIT)" "${HM_CPU_CRIT}% / ${HM_CPU_CRIT_DUR}s"
    hm_kv "$(T TXT_HM_STATUS_DISK_WARN)" "${HM_DISK_WARN}%"
    hm_kv "$(T TXT_HM_STATUS_RAM_WARN)" "<= ${HM_RAM_WARN_MB} MB"

    echo
    printf "%b%s%b\n" "${CLR_CYAN}" "$(T TXT_HM_STATUS_SEC_ZAPRET)" "${CLR_RESET}"
    print_line "-"

    hm_kv "$(T TXT_HM_STATUS_ZAPRET_WD)" "$HM_ZAPRET_WATCHDOG"
    hm_kv "$(T TXT_HM_STATUS_ZAPRET_CD)" "${HM_ZAPRET_COOLDOWN_SEC}s"
    hm_kv "$(T TXT_HM_STATUS_ZAPRET_AR)" "$HM_ZAPRET_AUTORESTART"
    hm_kv "NFQUEUE qlen watchdog" "wd=${HM_QLEN_WATCHDOG} th=${HM_QLEN_WARN_TH} turns=${HM_QLEN_CRIT_TURNS}"
    hm_kv "KeenDNS curl interval" "${HM_KEENDNS_CURL_SEC}s"

    echo
    printf "%b%s%b\n" "${CLR_CYAN}" "$(T TXT_HM_STATUS_SEC_NOW)" "${CLR_RESET}"
    print_line "-"

    printf "  %s %s%% | %s %s
" \
        "$(T TXT_HM_STATUS_CPU)" "$cpu" \
        "$(T TXT_HM_STATUS_LOAD)" "$load"
    printf "  %s %s MB | %s %s%% | %s %s
" \
        "$(T TXT_HM_STATUS_RAM_FREE)" "$ram" \
        "$(T TXT_HM_STATUS_DISK_OPT)" "$disk" \
        "$(T TXT_HM_STATUS_ZAPRET)" "$zst"

    echo
}


healthmon_test() {
    local cpu load disk ram
    cpu=$(healthmon_cpu_pct)
    load=$(healthmon_loadavg)
    disk=$(healthmon_disk_used_pct /opt)
    ram=$(healthmon_mem_free_mb)
    telegram_send "$(tpl_render "$(T TXT_HM_TEST_MSG)" CPU "$cpu" LOAD "$load" RAM "$ram" DISK "$disk")"
}


healthmon_config_menu() {
    healthmon_load_config

    # helper: ask number with current value, empty keeps current
    hm_ask_num() {
        local _label="$1" _var="$2" _cur _v
        eval _cur="\${$_var}"
        printf "%s [%s]: " "$_label" "${_cur:-}"
        read -r _v
        if [ -n "$_v" ]; then
            case "$_v" in
                *[!0-9]*)
                    print_status WARN "$(T _ 'Gecersiz sayi, atlandi.' 'Invalid number, skipped.')"
                    ;;
                *)
                    eval "$_var=\"$_v\""
                    ;;
            esac
        fi
    }

    hm_ask_01() {
        local _label="$1" _var="$2" _cur _v
        eval _cur="\${$_var}"
        printf "%s (0/1) [%s]: " "$_label" "${_cur:-}"
        read -r _v
        if [ -n "$_v" ]; then
            case "$_v" in
                0|1) eval "$_var=\"$_v\"" ;;
                *) print_status WARN "$(T _ 'Gecersiz secim, atlandi.' 'Invalid choice, skipped.')" ;;
            esac
        fi
    }

    while true; do
        clear
        print_line "="
        echo "$(T TXT_HM_CFG_TITLE)"
        print_line "="
        echo
                local _w=24
        printf " %2s) %-*s : %s\n" "1" "$_w" "CPU WARN % / sure"  "$HM_CPU_WARN / $HM_CPU_WARN_DUR"
        printf " %2s) %-*s : %s\n" "2" "$_w" "CPU CRIT % / sure"  "$HM_CPU_CRIT / $HM_CPU_CRIT_DUR"
        printf " %2s) %-*s : %s\n" "3" "$_w" "Disk(/opt) esigi %" "$HM_DISK_WARN"
        printf " %2s) %-*s : %s\n" "4" "$_w" "RAM esigi (MB)"     "$HM_RAM_WARN_MB"
        printf " %2s) %-*s : %s\n" "5" "$_w" "$(T TXT_HM_CFG_ITEM5)" "wd=$HM_ZAPRET_WATCHDOG cd=$HM_ZAPRET_COOLDOWN_SEC ar=$HM_ZAPRET_AUTORESTART"
        local _en_lbl _ev_lbl
        _en_lbl="$(T TXT_HM_FLAG_ENABLED)"
        _ev_lbl="$(T TXT_HM_FLAG_EVERY)"
        printf " %2s) %-*s : %s\n" "6" "$_w" "$(T TXT_HM_CFG_ITEM6)" "${_en_lbl}=${HM_UPDATECHECK_ENABLE} ${_ev_lbl}=${HM_UPDATECHECK_SEC}s"
        printf " %2s) %-*s : %s\n" "7" "$_w" "$(T TXT_HM_CFG_ITEM7)" "$HM_AUTOUPDATE_MODE ($(T TXT_HM_AUTOUPDATE_MODE_HINT))"
        printf " %2s) %-*s : %s\n" "8" "$_w" "$(T TXT_HM_CFG_ITEM8)" "$HM_INTERVAL"
        printf " %2s) %-*s : %s\n" "9" "$_w" "$(T TXT_HM_CFG_ITEM9)" "$HM_COOLDOWN_SEC"
        printf " %2s) %-*s : %s\n" "10" "$_w" "$(T TXT_HM_CFG_ITEM10)" "$HM_HEARTBEAT_SEC"
        printf " %2s) %-*s : %s\n" "11" "$_w" "$(T TXT_HM_CFG_ITEM11)" "en=$HM_WANMON_ENABLE fail=$HM_WANMON_FAIL_TH ok=$HM_WANMON_OK_TH (conf=${HM_WANMON_IFACE:-auto} ndm=$(healthmon_detect_wan_iface_ndm))"
        printf " %2s) %-*s : %s\n" "12" "$_w" "NFQUEUE qlen watchdog" "wd=${HM_QLEN_WATCHDOG} th=${HM_QLEN_WARN_TH} turns=${HM_QLEN_CRIT_TURNS} keendns_curl=${HM_KEENDNS_CURL_SEC}s"
echo
        printf " %2s) %s\n" "0" "$(T _ 'Kaydet ve geri' 'Save & back')"
        echo
        read -r -p "$(T _ 'Secim: ' 'Choice: ')" _c || return 0

        case "$_c" in
            1)
                hm_ask_num "$(T TXT_HM_PROMPT_CPU_WARN)" HM_CPU_WARN
                hm_ask_num "$(T TXT_HM_PROMPT_CPU_WARN_DUR)" HM_CPU_WARN_DUR
                ;;
            2)
                hm_ask_num "$(T TXT_HM_PROMPT_CPU_CRIT)" HM_CPU_CRIT
                hm_ask_num "$(T TXT_HM_PROMPT_CPU_CRIT_DUR)" HM_CPU_CRIT_DUR
                ;;
            3)
                hm_ask_num "$(T TXT_HM_PROMPT_DISK_WARN)" HM_DISK_WARN
                ;;
            4)
                hm_ask_num "$(T TXT_HM_PROMPT_RAM_WARN)" HM_RAM_WARN_MB
                ;;
            5)
                hm_ask_01 "$(T TXT_HM_PROMPT_ZAPRET_WD)" HM_ZAPRET_WATCHDOG
                hm_ask_num "$(T TXT_HM_PROMPT_ZAPRET_COOLDOWN)" HM_ZAPRET_COOLDOWN_SEC
                hm_ask_01 "$(T TXT_HM_PROMPT_ZAPRET_AUTORESTART)" HM_ZAPRET_AUTORESTART
                ;;
            6)
                hm_ask_01 "$(T TXT_HM_PROMPT_UPDATECHECK_ENABLE)" HM_UPDATECHECK_ENABLE
                hm_ask_num "$(T TXT_HM_PROMPT_UPDATECHECK_SEC)" HM_UPDATECHECK_SEC
                ;;
            7)
                printf "%s [%s]: " "$(T TXT_HM_PROMPT_AUTOUPDATE_MODE)" "${HM_AUTOUPDATE_MODE:-}"
                read -r _v
                if [ -n "$_v" ]; then
                    case "$_v" in
                        0|1) HM_AUTOUPDATE_MODE="$_v" ;;
                        2)healthmon_print_autoupdate_warning
read -r -p "$(T TXT_HM_AUTOUPDATE_WARN_L3)" _w
                            case "$_w" in
    y|Y|e|E)
        HM_AUTOUPDATE_MODE="2"
        _msg="$(T TXT_HM_AUTOUPDATE_SET_MSG)"
        _msg="$(tpl_render "$_msg" MODE "2")"
        print_status PASS "$_msg"
        ;;
    n|N|h|H|"")
        HM_AUTOUPDATE_MODE="1"
        _msg="$(T TXT_HM_AUTOUPDATE_SET_MSG)"
        _msg="$(tpl_render "$_msg" MODE "1")"
        print_status INFO "$_msg"
        ;;
    *)
        HM_AUTOUPDATE_MODE="1"
        print_status WARN "$(T TXT_INVALID_CHOICE)"
        _msg="$(T TXT_HM_AUTOUPDATE_SET_MSG)"
        _msg="$(tpl_render "$_msg" MODE "1")"
        print_status INFO "$_msg"
        ;;
esac
                            ;;
                        *) print_status WARN "$(T TXT_INVALID_CHOICE)" ;;
                    esac
                fi
                ;;
            8)
                hm_ask_num "$(T _ 'Interval (sec)' 'Interval (sec)')" HM_INTERVAL
                ;;
            9)
                hm_ask_num "$(T _ 'Cooldown (sec)' 'Cooldown (sec)')" HM_COOLDOWN_SEC
                ;;
            10)
                hm_ask_num "$(T _ 'Heartbeat (sec)' 'Heartbeat (sec)')" HM_HEARTBEAT_SEC
                ;;
            11)
                hm_ask_01 "$(T TXT_HM_PROMPT_WANMON_ENABLE)" HM_WANMON_ENABLE
                hm_ask_num "$(T TXT_HM_PROMPT_WANMON_FAIL_TH)" HM_WANMON_FAIL_TH
                hm_ask_num "$(T TXT_HM_PROMPT_WANMON_OK_TH)" HM_WANMON_OK_TH
                print_status INFO "$(T _ \'NDM WAN: \' \'NDM WAN: \')$(healthmon_detect_wan_iface_ndm)"
                ;;
            12)
                hm_ask_01  "$(T _ 'NFQUEUE qlen watchdog (0=kapat 1=ac)' 'NFQUEUE qlen watchdog (0=off 1=on)')" HM_QLEN_WATCHDOG
                hm_ask_num "$(T _ 'qlen esigi (paket sayisi)' 'qlen threshold (packet count)')" HM_QLEN_WARN_TH
                hm_ask_num "$(T _ 'Ardisik yuksek tur sayisi -> restart' 'Consecutive high turns -> restart')" HM_QLEN_CRIT_TURNS
                hm_ask_num "$(T _ 'KeenDNS curl araligi (sn, 0=her tur)' 'KeenDNS curl interval (sec, 0=every loop)')" HM_KEENDNS_CURL_SEC
                ;;
            0)
                healthmon_write_config
                if healthmon_is_running; then
                    healthmon_stop
                    healthmon_start
                fi
                print_status PASS "$(T _ 'Ayarlar kaydedildi.' 'Settings saved.')"
                return 0
                ;;
            *)
                print_status WARN "$(T TXT_INVALID_CHOICE)"
                sleep 1
                ;;
        esac
    done
}

# =============================================================================
# ZAMANLI YENIDEN BASLAT (Scheduled Reboot via Cron)
# =============================================================================

# TR/EN Dictionary (Scheduled Reboot)
TXT_SCHED_TITLE_TR="Zamanli Yeniden Baslat"
TXT_SCHED_TITLE_EN="Scheduled Reboot"
TXT_SCHED_STATUS_TR="Mevcut Zamanlama"
TXT_SCHED_STATUS_EN="Current Schedule"
TXT_SCHED_NONE_TR="Zamanlama yok"
TXT_SCHED_NONE_EN="No schedule set"
TXT_SCHED_CROND_WARN_TR="UYARI: cron servisi (crond) calismiyor! Zamanlama aktif olmayacak."
TXT_SCHED_CROND_WARN_EN="WARNING: cron service (crond) is not running! Schedule will not be active."
TXT_SCHED_TIME_WARN_TR="UYARI: Router saatinin dogru oldugunu kontrol edin (Sistem Ayarlari > Genel)."
TXT_SCHED_TIME_WARN_EN="WARNING: Make sure the router time is set correctly (System Settings > General)."
TXT_SCHED_MENU_1_TR="1. Mevcut Zamanlamayi Goster"
TXT_SCHED_MENU_1_EN="1. Show Current Schedule"
TXT_SCHED_MENU_2_TR="2. Gunluk Yeniden Baslat Ekle/Guncelle"
TXT_SCHED_MENU_2_EN="2. Add/Update Daily Reboot"
TXT_SCHED_MENU_3_TR="3. Haftalik Yeniden Baslat Ekle/Guncelle"
TXT_SCHED_MENU_3_EN="3. Add/Update Weekly Reboot"
TXT_SCHED_MENU_4_TR="4. Zamanlamayi Sil"
TXT_SCHED_MENU_4_EN="4. Delete Schedule"
TXT_SCHED_MENU_0_TR="0. Geri Don"
TXT_SCHED_MENU_0_EN="0. Back"
TXT_SCHED_PROMPT_TR="Seciminiz (0-4): "
TXT_SCHED_PROMPT_EN="Your choice (0-4): "
TXT_SCHED_HOUR_TR="Saat girin (0-23): "
TXT_SCHED_HOUR_EN="Enter hour (0-23): "
TXT_SCHED_MIN_TR="Dakika girin (0-59): "
TXT_SCHED_MIN_EN="Enter minute (0-59): "
TXT_SCHED_DOW_TR="Hangi gun? (0=Pazar, 1=Pzt, 2=Sal, 3=Car, 4=Per, 5=Cum, 6=Cmt): "
TXT_SCHED_DOW_EN="Which day? (0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat): "
TXT_SCHED_INVALID_HOUR_TR="Gecersiz saat! 0-23 arasinda olmali."
TXT_SCHED_INVALID_HOUR_EN="Invalid hour! Must be between 0 and 23."
TXT_SCHED_INVALID_MIN_TR="Gecersiz dakika! 0-59 arasinda olmali."
TXT_SCHED_INVALID_MIN_EN="Invalid minute! Must be between 0 and 59."
TXT_SCHED_INVALID_DOW_TR="Gecersiz gun! 0-6 arasinda olmali."
TXT_SCHED_INVALID_DOW_EN="Invalid day! Must be between 0 and 6."
TXT_SCHED_ADDED_TR="Zamanlama eklendi/guncellendi."
TXT_SCHED_ADDED_EN="Schedule added/updated."
TXT_SCHED_DELETED_TR="Zamanlama silindi."
TXT_SCHED_DELETED_EN="Schedule deleted."
TXT_SCHED_DEL_NONE_TR="Silinecek zamanlama bulunamadi."
TXT_SCHED_DEL_NONE_EN="No schedule found to delete."
TXT_SCHED_CONFIRM_DEL_TR="Zamanli yeniden baslatma silinsin mi? (e/h): "
TXT_SCHED_CONFIRM_DEL_EN="Delete scheduled reboot? (y/n): "
TXT_SCHED_DAILY_SET_TR="Gunluk yeniden baslat: Her gun saat %HOUR%"
TXT_SCHED_DAILY_SET_EN="Daily reboot: Every day at %HOUR%"
TXT_SCHED_WEEKLY_SET_TR="Haftalik yeniden baslat: Her hafta saat %HOUR% (Gun: %DOW%)"
TXT_SCHED_WEEKLY_SET_EN="Weekly reboot: Every week at %HOUR% (Day: %DOW%)"

# Crontab'daki KZM reboot satirini tanımlayan etiket
KZM_REBOOT_TAG="# KZM_REBOOT"

# crond calisiyor mu kontrol et (ps -w ile)
_sched_crond_running() {
    ps -w 2>/dev/null | grep -v grep | grep -q 'cron'
}

# Mevcut KZM_REBOOT satirini oku (yoksa bos doner)
_sched_get_current() {
    crontab -l 2>/dev/null | grep "$KZM_REBOOT_TAG" | head -n 1
}

# Crontab'dan KZM_REBOOT satirini kaldir
_sched_remove() {
    local _tmp="/tmp/kzm_cron_remove.$$"
    crontab -l 2>/dev/null | grep -v '^#' | grep -v "$KZM_REBOOT_TAG" | grep -v '^[[:space:]]*$' > "$_tmp"
    crontab "$_tmp"
    rm -f "$_tmp"
}

# Crontab'a KZM_REBOOT satiri ekle
# $1: min  $2: hour  $3: dow (* = her gun)
_sched_write() {
    local _min="$1" _hour="$2" _dow="$3"
    local _tmp="/tmp/kzm_cron_write.$$"
    crontab -l 2>/dev/null | grep -v '^#' | grep -v "$KZM_REBOOT_TAG" | grep -v '^[[:space:]]*$' > "$_tmp"
    printf '%s %s * * %s LD_LIBRARY_PATH= ndmc -c "system reboot" %s\n' \
        "$_min" "$_hour" "$_dow" "$KZM_REBOOT_TAG" >> "$_tmp"
    crontab "$_tmp"
    rm -f "$_tmp"
}

# Mevcut satiri okunabilir formatta goster
_sched_show_current() {
    local _cur
    _cur="$(_sched_get_current)"
    if [ -z "$_cur" ]; then
        print_status INFO "$(T TXT_SCHED_NONE)"
    else
        # min hour * * dow seklinde parse et
        local _min _hour _dow
        _min="$(printf '%s\n' "$_cur" | awk '{print $1}')"
        _hour="$(printf '%s\n' "$_cur" | awk '{print $2}')"
        _dow="$(printf '%s\n' "$_cur" | awk '{print $5}')"
        local _hh _mm _time
        _hh="$(printf '%02d' "$_hour" 2>/dev/null)"
        _mm="$(printf '%02d' "$_min"  2>/dev/null)"
        _time="${CLR_ORANGE}${CLR_BOLD}${_hh}:${_mm}${CLR_RESET}"
        if [ "$_dow" = "*" ]; then
            print_status INFO "$(tpl_render "$(T TXT_SCHED_DAILY_SET)" HOUR "$_time" MIN "")"
        else
            # Gun adini bul
            local _dow_name
            if [ "$LANG" = "en" ]; then
                case "$_dow" in
                    0|7) _dow_name="Sunday" ;;
                    1)   _dow_name="Monday" ;;
                    2)   _dow_name="Tuesday" ;;
                    3)   _dow_name="Wednesday" ;;
                    4)   _dow_name="Thursday" ;;
                    5)   _dow_name="Friday" ;;
                    6)   _dow_name="Saturday" ;;
                    *)   _dow_name="$_dow" ;;
                esac
            else
                case "$_dow" in
                    0|7) _dow_name="Pazar" ;;
                    1)   _dow_name="Pazartesi" ;;
                    2)   _dow_name="Sali" ;;
                    3)   _dow_name="Carsamba" ;;
                    4)   _dow_name="Persembe" ;;
                    5)   _dow_name="Cuma" ;;
                    6)   _dow_name="Cumartesi" ;;
                    *)   _dow_name="$_dow" ;;
                esac
            fi
            local _dow_fmt="${_dow} ${CLR_ORANGE}${CLR_BOLD}${_dow_name}${CLR_RESET}"
            print_status INFO "$(tpl_render "$(T TXT_SCHED_WEEKLY_SET)" HOUR "$_time" MIN "" DOW "$_dow_fmt")"
        fi
    fi
}

scheduled_reboot_menu() {
    while true; do
        clear
        print_line "="
        printf "  %b%s%b\n" "${CLR_BOLD}${CLR_CYAN}" "$(T TXT_SCHED_TITLE)" "${CLR_RESET}"
        print_line "="
        echo

        # crond uyarisi
        if ! _sched_crond_running; then
            print_status WARN "$(T TXT_SCHED_CROND_WARN)"
            echo
        fi

        # Mevcut zamanlama
        printf "  %b%s:%b\n" "${CLR_BOLD}" "$(T TXT_SCHED_STATUS)" "${CLR_RESET}"
        _sched_show_current
        echo

        # Saat uyarisi
        print_status WARN "$(T TXT_SCHED_TIME_WARN)"
        echo

        print_line "-"
        printf "  %b%s%b\n" "${CLR_BOLD}" "$(T TXT_SCHED_MENU_1)" "${CLR_RESET}"
        printf "  %b%s%b\n" "${CLR_BOLD}" "$(T TXT_SCHED_MENU_2)" "${CLR_RESET}"
        printf "  %b%s%b\n" "${CLR_BOLD}" "$(T TXT_SCHED_MENU_3)" "${CLR_RESET}"
        printf "  %b%s%b\n" "${CLR_BOLD}" "$(T TXT_SCHED_MENU_4)" "${CLR_RESET}"
        printf "  %b%s%b\n" "${CLR_BOLD}" "$(T TXT_SCHED_MENU_0)" "${CLR_RESET}"
        print_line "-"
        echo

        printf "%s" "$(T TXT_SCHED_PROMPT)"
        read -r _schoice

        case "$_schoice" in
            1)
                clear
                print_line "="
                printf "  %b%s%b\n" "${CLR_BOLD}${CLR_CYAN}" "$(T TXT_SCHED_TITLE)" "${CLR_RESET}"
                print_line "="
                echo
                _sched_show_current
                echo
                press_enter_to_continue
                ;;
            2)
                # Gunluk reboot — saat + dakika sor
                clear
                print_line "-"
                printf "  %b%s%b\n" "${CLR_BOLD}" "$(T TXT_SCHED_MENU_2)" "${CLR_RESET}"
                print_line "-"
                echo
                local _hour _min
                printf "%s" "$(T TXT_SCHED_HOUR)"
                read -r _hour
                if ! printf '%s\n' "$_hour" | grep -Eq '^[0-9]+$' || [ "$_hour" -lt 0 ] 2>/dev/null || [ "$_hour" -gt 23 ] 2>/dev/null; then
                    print_status FAIL "$(T TXT_SCHED_INVALID_HOUR)"
                    press_enter_to_continue
                    continue
                fi
                printf "%s" "$(T TXT_SCHED_MIN)"
                read -r _min
                if ! printf '%s\n' "$_min" | grep -Eq '^[0-9]+$' || [ "$_min" -lt 0 ] 2>/dev/null || [ "$_min" -gt 59 ] 2>/dev/null; then
                    print_status FAIL "$(T TXT_SCHED_INVALID_MIN)"
                    press_enter_to_continue
                    continue
                fi
                _sched_write "$_min" "$_hour" "*"
                print_status PASS "$(T TXT_SCHED_ADDED)"
                press_enter_to_continue
                ;;
            3)
                # Haftalik reboot — saat + dakika + gun sor
                clear
                print_line "-"
                printf "  %b%s%b\n" "${CLR_BOLD}" "$(T TXT_SCHED_MENU_3)" "${CLR_RESET}"
                print_line "-"
                echo
                local _hour _min _dow
                printf "%s" "$(T TXT_SCHED_HOUR)"
                read -r _hour
                if ! printf '%s\n' "$_hour" | grep -Eq '^[0-9]+$' || [ "$_hour" -lt 0 ] 2>/dev/null || [ "$_hour" -gt 23 ] 2>/dev/null; then
                    print_status FAIL "$(T TXT_SCHED_INVALID_HOUR)"
                    press_enter_to_continue
                    continue
                fi
                printf "%s" "$(T TXT_SCHED_MIN)"
                read -r _min
                if ! printf '%s\n' "$_min" | grep -Eq '^[0-9]+$' || [ "$_min" -lt 0 ] 2>/dev/null || [ "$_min" -gt 59 ] 2>/dev/null; then
                    print_status FAIL "$(T TXT_SCHED_INVALID_MIN)"
                    press_enter_to_continue
                    continue
                fi
                printf "%s" "$(T TXT_SCHED_DOW)"
                read -r _dow
                if ! printf '%s\n' "$_dow" | grep -Eq '^[0-6]$'; then
                    print_status FAIL "$(T TXT_SCHED_INVALID_DOW)"
                    press_enter_to_continue
                    continue
                fi
                _sched_write "$_min" "$_hour" "$_dow"
                print_status PASS "$(T TXT_SCHED_ADDED)"
                press_enter_to_continue
                ;;
            4)
                # Silme
                if [ -z "$(_sched_get_current)" ]; then
                    print_status WARN "$(T TXT_SCHED_DEL_NONE)"
                    press_enter_to_continue
                    continue
                fi
                printf "%s" "$(T TXT_SCHED_CONFIRM_DEL)"
                read -r _ans
                case "$_ans" in
                    e|E|y|Y)
                        _sched_remove
                        print_status PASS "$(T TXT_SCHED_DELETED)"
                        ;;
                    *)
                        echo "$(T _ 'Iptal edildi.' 'Cancelled.')"
                        ;;
                esac
                press_enter_to_continue
                ;;
            0|"")
                return 0
                ;;
            *)
                echo "$(T _ 'Gecersiz secim.' 'Invalid choice.')"
                press_enter_to_continue
                ;;
        esac
    done
}

health_monitor_menu() {
    while true; do
        clear
        print_line "="
        echo "$(T TXT_HM_TITLE)"
        print_line "="
        echo
        healthmon_load_config
        local run_state="0"
        healthmon_is_running && run_state="1"
        local run_label
        [ "$run_state" = "1" ] && run_label="$(T TXT_HM_RUN_ON)" || run_label="$(T TXT_HM_RUN_OFF)"
        print_line "-"
        if [ "$run_state" = "1" ]; then
            printf "%b
" "${CLR_BOLD}${CLR_GREEN}$(T TXT_HM_STATUS) ${run_label} ($(T TXT_HM_ENABLE_LABEL)=${HM_ENABLE})${CLR_RESET}"
        else
            printf "%b
" "${CLR_BOLD}${CLR_RED}$(T TXT_HM_STATUS) ${run_label} ($(T TXT_HM_ENABLE_LABEL)=${HM_ENABLE})${CLR_RESET}"
        fi
        print_line "-"
        echo "CPU WARN %${HM_CPU_WARN}/${HM_CPU_WARN_DUR}s  |  CPU CRIT %${HM_CPU_CRIT}/${HM_CPU_CRIT_DUR}s"
        echo "$(tpl_render "$(T TXT_HM_MENU_LINE2)" DISK "$HM_DISK_WARN" RAM "$HM_RAM_WARN_MB")"
        echo "$(tpl_render "$(T TXT_HM_MENU_LINE3)" WD "$HM_ZAPRET_WATCHDOG" INT "$HM_INTERVAL")"
        echo
        print_line "-"
        echo " 1) $(T TXT_HM_ENABLE_DISABLE)"
        echo " 2) $(T TXT_HM_SHOW_STATUS)"
        echo " 3) $(T TXT_HM_SEND_TEST)"
        echo " 4) $(T TXT_HM_CONFIG_THRESHOLDS)"
        echo " 0) $(T TXT_BACK)"
        print_line "-"
        printf "%s" "$(T TXT_CHOICE) "
        read -r c || return 0
        clear
        case "$c" in
1)
    # Toggle based on *actual* daemon state (not only HM_ENABLE flag)
    # This prevents "OFF ($(T TXT_HM_ENABLE_LABEL)=1)" showing, then option 1 trying to stop a non-running daemon.
    if healthmon_is_running; then
        healthmon_stop
        print_status PASS "$(T TXT_HM_DISABLED)"
    else
        if healthmon_start; then
            print_status PASS "$(T TXT_HM_ENABLED)"
        else
            print_status FAIL "$(T TXT_HM_ENABLED)"
        fi
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
    healthmon_config_menu
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
        read -r choice || break
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
R|r) scheduled_reboot_menu ;;
        U|u) zkm_full_uninstall ;;
            0) echo "Cikis yapiliyor..."; break ;;
            *) echo "$(T _ 'Gecersiz secim! Lutfen 0-16, B, L, R veya U girin.' 'Invalid choice! Please enter 0-16, B, L, R or U.')" ;;
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
# Kullanim: ./script.sh cleanup  -> Zapret kurulu olmasa bile kalintilari temizler
if [ "$1" = "cleanup" ]; then
    cleanup_only_leftovers
    exit 0
fi

main_menu_loop

# WAN IP detection (best-effort)
WAN_IP="$(ip -4 addr show ppp0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)"
[ -z "$WAN_IP" ] && WAN_IP="$(ip -4 addr show eth0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)"
[ -z "$WAN_IP" ] && WAN_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -n1)"
[ -z "$WAN_IP" ] && WAN_IP="unknown"
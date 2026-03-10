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
SCRIPT_VERSION="v26.3.10.2"
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
    --telegram-daemon)  ZKM_SKIP_LOCK="1" ;;
    --self-test)        ZKM_SKIP_LOCK="1" ; ZKM_SELF_TEST="1" ;;
    --gui-status)      ZKM_SKIP_LOCK="1" ; ZKM_GUI_STATUS_GEN="1" ;;
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

    # 4) read -p usage (not supported in BusyBox ash)
    local readp_count
    readp_count="$(grep -E "read[[:space:]]+-r?[[:space:]]*-p|read[[:space:]]+-p" "$f" 2>/dev/null \
        | grep -v '[[:space:]]*#\|_fail\|_pass\|_warn' | wc -l | tr -d ' ')"
    readp_count="${readp_count:-0}"
    if [ "$readp_count" -gt 0 ]; then
        _fail "read -p detected ($readp_count occurrence(s)) - use 'printf + read -r' instead"
        grep -nE "read[[:space:]]+-r?[[:space:]]*-p|read[[:space:]]+-p" "$f" 2>/dev/null \
            | grep -v '[[:space:]]*#\|_fail\|_pass\|_warn' | head -n 10 | sed 's/^/  line /'
    else
        _pass "read -p: none detected"
    fi

    # 5) Telegram config (optional)
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

    # 6) HealthMon auto-start (optional)
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
            _lock_pid="$(cat "$ZKM_LOCKDIR/pid" 2>/dev/null)"
            _lock_lang="$(cat /opt/zapret/lang 2>/dev/null)"
            if [ "$_lock_lang" = "en" ]; then
                printf 'WARNING: Script is already running (PID: %s).\n' "$_lock_pid"
                printf 'Terminate the current session and continue? (y/n): '
            else
                printf 'UYARI: Betik zaten calisiyor (PID: %s).\n' "$_lock_pid"
                printf 'Mevcut oturumu sonlandirip devam etmek ister misiniz? (e/h): '
            fi
            read -r _lock_ans </dev/tty
            case "$_lock_ans" in
                e|E|y|Y)
                    kill "$_lock_pid" 2>/dev/null || true
                    sleep 1
                    rm -rf "$ZKM_LOCKDIR" 2>/dev/null
                    mkdir "$ZKM_LOCKDIR" 2>/dev/null || exit 1
                    ;;
                *)
                    exit 0
                    ;;
            esac
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

    # GUI kaldir (kurulu olsun olmasin, iz birakma)
    if kzm_gui_is_installed 2>/dev/null; then
        print_status INFO "$(T TXT_GUI_REMOVING)"
        kill $(pgrep lighttpd 2>/dev/null) 2>/dev/null || true
        /opt/etc/init.d/S80lighttpd stop >/dev/null 2>&1 || true
        rm -f /opt/etc/init.d/S80lighttpd 2>/dev/null
        rm -rf "$KZM_GUI_DIR" 2>/dev/null
        rm -rf /opt/etc/lighttpd 2>/dev/null
        rm -f "$KZM_GUI_STATUS_SCRIPT" "$KZM_GUI_STATUS_JSON" 2>/dev/null
        rm -f /opt/var/run/kzm_hw_model /opt/var/run/kzm_hw_firmware 2>/dev/null
        rm -f /opt/var/log/lighttpd_error.log /opt/var/log/lighttpd_access.log 2>/dev/null
        rm -f /opt/var/run/lighttpd.pid 2>/dev/null
        rm -f "$KZM_GUI_CONF_CUSTOM" 2>/dev/null
        iptables -D INPUT -p tcp --dport "$KZM_GUI_PORT" -j ACCEPT 2>/dev/null || true
        opkg remove lighttpd lighttpd-mod-cgi 2>/dev/null || true
        kzm_gui_remove_cron 2>/dev/null || true
        print_status PASS "$(T TXT_GUI_REMOVED)"
    fi

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

        printf '%s' "$(T TXT_WARN_CHOICE)"; read -r sel
        case "$sel" in
            1)
                if mv "$CURRENT" "$EXPECTED" 2>/dev/null; then
                    chmod +x "$EXPECTED" 2>/dev/null
                    if [ ! -x "$EXPECTED" ]; then
                        echo
                        printf "%b
" "${CLR_RED}$(T TXT_WARN_CHMOD_FAIL)${CLR_RESET}"
                        press_enter_to_continue
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
                    press_enter_to_continue
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
_nslookup_t() {
    # nslookup with 5s timeout via background+kill (timeout komutu gerekmez)
    nslookup "$1" "$2" >/dev/null 2>&1 &
    local _pid=$! _i=0
    while [ "$_i" -lt 5 ]; do
        if ! kill -0 "$_pid" 2>/dev/null; then
            wait "$_pid" 2>/dev/null
            return $?
        fi
        sleep 1
        _i=$(( _i + 1 ))
    done
    kill "$_pid" 2>/dev/null
    return 1
}

_nslookup_ip() {
    # nslookup ile IP coz, sonucu stdout'a yaz (5s timeout, temp dosya ile)
    local _tmp="/tmp/nslookup_ip_$$"
    nslookup "$1" "$2" 2>/dev/null | awk '/^Address [0-9]+:/{print $3; exit}' > "$_tmp" &
    local _pid=$! _i=0
    while [ "$_i" -lt 5 ]; do
        if ! kill -0 "$_pid" 2>/dev/null; then
            cat "$_tmp" 2>/dev/null
            rm -f "$_tmp"
            return 0
        fi
        sleep 1
        _i=$(( _i + 1 ))
    done
    kill "$_pid" 2>/dev/null
    rm -f "$_tmp"
    return 1
}

check_dns_local() {
    _nslookup_t github.com 127.0.0.1
}

check_dns_external() {
    _nslookup_t github.com 8.8.8.8
}

check_dns_consistency() {
    local dns_local_ip dns_pub_ip
    dns_local_ip="$(_nslookup_ip github.com 127.0.0.1)"
    dns_pub_ip="$(_nslookup_ip github.com 8.8.8.8)"
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

# IP adresini siniflandir: public / cgnat / private
zkm_classify_ip() {
    local ip="$1"
    # CGNAT: 100.64.0.0/10
    case "$ip" in
        100.6[4-9].*|100.[7-9][0-9].*|100.1[01][0-9].*|100.12[0-7].*)
            echo "cgnat"; return ;;
    esac
    # Private: 10.x, 192.168.x, 172.16-31.x
    case "$ip" in
        10.*|192.168.*) echo "private"; return ;;
    esac
    case "$ip" in
        172.1[6-9].*|172.2[0-9].*|172.3[01].*) echo "private"; return ;;
    esac
    echo "public"
}

# IP'yi renkli formatla (alt-shell uyumu icin hardcoded escape)
zkm_fmt_ip() {
    local ip="$1" type
    type="$(zkm_classify_ip "$ip")"
    case "$type" in
        cgnat)   printf '\033[1;33m%s\033[0m \033[33m[CGNAT]\033[0m'  "$ip" ;;
        private) printf '\033[1;33m%s\033[0m \033[33m[NAT]\033[0m'    "$ip" ;;
        *)       printf '\033[1;32m%s\033[0m'                            "$ip" ;;
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

TXT_MENU_6_TR=" 6. Zapret Guncelleme Kontrolu (Guncel/Kurulu - GitHub)"
TXT_MENU_6_EN=" 6. Zapret Update Check (Latest/Installed - GitHub)"

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
TXT_MENU_10_EN="10. Script Update Check (Latest/Installed - GitHub)"

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

TXT_TG_STATUS_ACTIVE_TR="Bildirimler: AKTIF (Token ve ChatID kayitli)"
TXT_TG_STATUS_ACTIVE_EN="Notifications: ACTIVE (Token and ChatID saved)"

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
TXT_TGBOT_BANNER_LABEL_TR="Telegram Bot"
TXT_TGBOT_BANNER_LABEL_EN="Telegram Bot"
TXT_TGBOT_BANNER_ACTIVE_TR="AKTIF"
TXT_TGBOT_BANNER_ACTIVE_EN="ACTIVE"
TXT_TGBOT_BANNER_INACTIVE_TR="KAPALI"
TXT_TGBOT_BANNER_INACTIVE_EN="INACTIVE"
TXT_SCHED_BANNER_LABEL_TR="Tekrar Baslat"
TXT_SCHED_BANNER_LABEL_EN="Sched.Reboot"

TXT_HM_MENU_LINE2_TR="Disk(/opt) >= %DISK%%%  |  RAM <= %RAM% MB  |  Load (uptime)"
TXT_HM_MENU_LINE2_EN="Disk(/opt) >= %DISK%%%  |  RAM <= %RAM% MB  |  Load via uptime"

TXT_HM_MENU_LINE3_TR="Zapret denetimi: %WD%  |  Aralik: %INT%s"
TXT_HM_MENU_LINE3_EN="Zapret watchdog: %WD%  |  Interval: %INT%s"

TXT_HM_CFG_TITLE_TR="Saglik Ayarlari"
TXT_HM_CFG_TITLE_EN="Health Settings"

TXT_HM_CFG_ITEM5_TR="Zapret (denetim)"
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
TXT_HM_CFG_ITEM12_TR="NFQUEUE kuyruk denetimi"
TXT_HM_CFG_ITEM12_EN="NFQUEUE qlen watchdog"

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

TXT_HM_STATUS_ZAPRET_WD_TR="Zapret denetimi"
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

TXT_HM_PROMPT_ZAPRET_WD_TR="Zapret denetimi (1=acik,0=kapali) [or: 1]:"
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
Zapret guncellemesi icin Ana Menu > 6 secenegi kullanin

📦 Paket  : Zapret
🔖 Kurulu : %CUR%
🆕 Yeni   : %NEW%
🔗 Link   : %URL%"
TXT_UPD_ZAPRET_NEW_EN="[Update]
Use Main Menu > Option 6 to update Zapret

📦 Package  : Zapret
🔖 Installed: %CUR%
🆕 Latest   : %NEW%
🔗 Link     : %URL%"
TXT_UPD_ZAPRET_ROLLED_TR="[Uyari] Zapret geri cekilmis surum
Ana Menu > 6 ile GitHub surumunu yeniden yukleyin

📦 Paket  : Zapret
⚠️ Kurulu : %CUR% (geri cekilmis)
✅ Stabil : %NEW%"
TXT_UPD_ZAPRET_ROLLED_EN="[Warning] Zapret pulled release
Use Main Menu > 6 to reinstall from GitHub

📦 Package  : Zapret
⚠️ Installed: %CUR% (pulled)
✅ Stable  : %NEW%"
TXT_UPD_ZKM_AUTO_OK_TR="[OtoGuncelleme]\nKZM otomatik kurulum basarili.\nBetigi yeniden calistirin.\n\n📦 Paket  : KZM\n🔖 Mevcut : %CUR%\n🆕 Yeni   : %NEW%\n🔗 Link   : %URL%"
TXT_UPD_ZKM_AUTO_OK_EN="[AutoUpdate]\nKZM auto install OK.\nPlease re-run the script.\n\n📦 Package  : KZM\n🔖 Current  : %CUR%\n🆕 Latest   : %NEW%\n🔗 Link     : %URL%"

TXT_UPD_ZKM_UP_TO_DATE_TR="[Guncelleme]
📦 Paket : KZM
🔄 Durum : Guncel ✅
🔖 Surum : %CUR%"
TXT_UPD_ZKM_UP_TO_DATE_EN="[Update]
📦 Package : KZM
🔄 Status  : Up to date ✅
🔖 Version : %CUR%"

TXT_UPD_ZKM_AUTO_FAIL_TR="[OtoGuncelleme]\n❌ KZM otomatik kurulum BASARISIZ.\n⚠️ Lutfen elle guncelleyin (menu 10).\n\n📦 Paket  : KZM\n🔖 Mevcut : %CUR%\n🆕 Yeni   : %NEW%\n🔗 Link   : %URL%"
TXT_UPD_ZKM_AUTO_FAIL_EN="[AutoUpdate]\n❌ KZM auto install FAILED.\n⚠️ Please update manually (menu 10).\n\n📦 Package : KZM\n🔖 Current : %CUR%\n🆕 Latest  : %NEW%\n🔗 Link    : %URL%"

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
TXT_HEALTH_WAN_IPV4_TR="WAN IPv4 adresi"
TXT_HEALTH_WAN_IPV4_EN="WAN IPv4 address"
TXT_HEALTH_WAN_IPV6_TR="WAN IPv6 adresi"
TXT_HEALTH_WAN_IPV6_EN="WAN IPv6 address"
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

# TR/EN Dictionary (Telegram Bot)
TXT_TGBOT_MENU_TITLE_TR="KZM Ana Menu"
TXT_TGBOT_MENU_TITLE_EN="KZM Main Menu"
TXT_TGBOT_BTN_STATUS_TR="Durum"
TXT_TGBOT_BTN_STATUS_EN="Status"
TXT_TGBOT_BTN_ZAPRET_TR="Zapret"
TXT_TGBOT_BTN_ZAPRET_EN="Zapret"
TXT_TGBOT_BTN_SYSTEM_TR="Sistem"
TXT_TGBOT_BTN_SYSTEM_EN="System"
TXT_TGBOT_BTN_LOGS_TR="Loglar"
TXT_TGBOT_BTN_LOGS_EN="Logs"
TXT_TGBOT_LOG_MENU_TITLE_TR="Log Secenekleri"
TXT_TGBOT_LOG_MENU_TITLE_EN="Log Options"
TXT_TGBOT_BTN_KZMLOG_TR="KZM Log"
TXT_TGBOT_BTN_KZMLOG_EN="KZM Log"
TXT_TGBOT_BTN_SYSLOG_TR="Sistem Log"
TXT_TGBOT_BTN_SYSLOG_EN="System Log"
TXT_TGBOT_BTN_BACK_TR="Geri"
TXT_TGBOT_BTN_BACK_EN="Back"
TXT_TGBOT_BTN_START_TR="Baslat"
TXT_TGBOT_BTN_START_EN="Start"
TXT_TGBOT_BTN_STOP_TR="Durdur"
TXT_TGBOT_BTN_STOP_EN="Stop"
TXT_TGBOT_BTN_RESTART_TR="Yeniden Baslat"
TXT_TGBOT_BTN_RESTART_EN="Restart"
TXT_TGBOT_BTN_REBOOT_TR="Yeniden Baslat (Router)"
TXT_TGBOT_BTN_REBOOT_EN="Reboot Router"
TXT_TGBOT_BTN_REBOOT_CONFIRM_TR="Onayla - Yeniden Baslat"
TXT_TGBOT_BTN_REBOOT_CONFIRM_EN="Confirm Reboot"
TXT_TGBOT_BTN_CANCEL_TR="Iptal"
TXT_TGBOT_BTN_CANCEL_EN="Cancel"
TXT_TGBOT_BTN_KZM_UPDATE_TR="KZM Guncelle"
TXT_TGBOT_BTN_KZM_UPDATE_EN="Update KZM"
TXT_TGBOT_BTN_ZAP_UPDATE_TR="Zapret Guncelle"
TXT_TGBOT_BTN_ZAP_UPDATE_EN="Update Zapret"
TXT_TGBOT_STATUS_RUNNING_TR="Calisiyor"
TXT_TGBOT_STATUS_RUNNING_EN="Running"
TXT_TGBOT_STATUS_STOPPED_TR="Durduruldu"
TXT_TGBOT_STATUS_STOPPED_EN="Stopped"
TXT_TGBOT_STATUS_UNKNOWN_TR="Bilinmiyor"
TXT_TGBOT_STATUS_UNKNOWN_EN="Unknown"
TXT_TGBOT_REBOOT_SENT_TR="Yeniden baslatma komutu gonderildi."
TXT_TGBOT_REBOOT_SENT_EN="Reboot command sent."
TXT_TGBOT_ZAPRET_STARTED_TR="Zapret baslatildi."
TXT_TGBOT_ZAPRET_STARTED_EN="Zapret started."
TXT_TGBOT_ZAPRET_STOPPED_TR="Zapret durduruldu."
TXT_TGBOT_ZAPRET_STOPPED_EN="Zapret stopped."
TXT_TGBOT_ZAPRET_RESTARTED_TR="Zapret yeniden baslatildi."
TXT_TGBOT_ZAPRET_RESTARTED_EN="Zapret restarted."
TXT_TGBOT_UPDATE_STARTED_TR="Guncelleme baslatildi, lutfen bekleyin..."
TXT_TGBOT_UPDATE_STARTED_EN="Update started, please wait..."
TXT_TGBOT_UPDATE_DONE_TR="Guncelleme tamamlandi."
TXT_TGBOT_UPDATE_DONE_EN="Update completed."
TXT_TGBOT_UPDATE_FAIL_TR="Guncelleme basarisiz."
TXT_TGBOT_UPDATE_FAIL_EN="Update failed."
TXT_TGBOT_ALREADY_UPTODATE_TR="KZM zaten guncel."
TXT_TGBOT_ALREADY_UPTODATE_EN="KZM is already up to date."
TXT_TGBOT_NO_LOGS_TR="Log bulunamadi."
TXT_TGBOT_NO_LOGS_EN="No logs found."
TXT_TGBOT_MENU_ZAPRET_TITLE_TR="Zapret Yonetimi"
TXT_TGBOT_MENU_ZAPRET_TITLE_EN="Zapret Management"
TXT_TGBOT_MENU_KZM_TITLE_TR="KZM Yonetimi"
TXT_TGBOT_MENU_KZM_TITLE_EN="KZM Management"
TXT_TGBOT_BTN_KZM_TR="KZM"
TXT_TGBOT_BTN_KZM_EN="KZM"
TXT_TGBOT_MENU_SISTEM_TITLE_TR="Sistem"
TXT_TGBOT_MENU_SISTEM_TITLE_EN="System"
TXT_TGBOT_BTN_NET_DEVICES_TR="Ag Cihazlari"
TXT_TGBOT_BTN_NET_DEVICES_EN="Network Devices"
TXT_TGBOT_BTN_WIFI_TR="Wifi Yonetim"
TXT_TGBOT_BTN_WIFI_EN="Wifi Management"
TXT_TGBOT_NET_DEVICES_TITLE_TR="Bagli Cihazlar"
TXT_TGBOT_NET_DEVICES_TITLE_EN="Connected Devices"
TXT_TGBOT_NET_NO_DEVICES_TR="Bagli cihaz bulunamadi."
TXT_TGBOT_NET_NO_DEVICES_EN="No connected devices found."
TXT_TGBOT_CLIENT_ACCESS_DENY_TR="Erisimi Engelle"
TXT_TGBOT_CLIENT_ACCESS_DENY_EN="Block Access"
TXT_TGBOT_CLIENT_ACCESS_PERMIT_TR="Erisime Izin Ver"
TXT_TGBOT_CLIENT_ACCESS_PERMIT_EN="Allow Access"
TXT_TGBOT_CLIENT_RENAME_TR="Ismi Degistir"
TXT_TGBOT_CLIENT_RENAME_EN="Rename Device"
TXT_TGBOT_CLIENT_RENAME_PROMPT_TR="Cihaz icin yeni isim girin. Iptal icin /iptal yaz."
TXT_TGBOT_CLIENT_RENAME_PROMPT_EN="Enter new name for the device. Type /iptal to cancel."
TXT_TGBOT_CLIENT_RENAME_DONE_TR="Isim guncellendi."
TXT_TGBOT_CLIENT_RENAME_DONE_EN="Name updated."
TXT_TGBOT_CLIENT_RENAME_CANCEL_TR="Isim degistirme iptal edildi."
TXT_TGBOT_CLIENT_RENAME_CANCEL_EN="Rename cancelled."
TXT_TGBOT_CLIENT_STATUS_ACTIVE_TR="Bagli"
TXT_TGBOT_CLIENT_STATUS_ACTIVE_EN="Connected"
TXT_TGBOT_CLIENT_STATUS_INACTIVE_TR="Bagli degil"
TXT_TGBOT_CLIENT_STATUS_INACTIVE_EN="Not connected"
TXT_TGBOT_CLIENT_ACCESS_LABEL_TR="Erisim"
TXT_TGBOT_CLIENT_ACCESS_LABEL_EN="Access"
TXT_TGBOT_CLIENT_ACCESS_OK_TR="Acik"
TXT_TGBOT_CLIENT_ACCESS_OK_EN="Allowed"
TXT_TGBOT_CLIENT_ACCESS_BLOCKED_TR="Engelli"
TXT_TGBOT_CLIENT_ACCESS_BLOCKED_EN="Blocked"
TXT_TGBOT_WIFI_TITLE_TR="Wifi Durumu"
TXT_TGBOT_WIFI_TITLE_EN="Wifi Status"
TXT_TGBOT_WIFI_NO_IF_TR="Wifi arayuzu bulunamadi."
TXT_TGBOT_WIFI_NO_IF_EN="No wifi interface found."
TXT_TGBOT_SISTEM_HEADER_ISIM_TR="Isim"
TXT_TGBOT_SISTEM_HEADER_ISIM_EN="Name"
TXT_TGBOT_SISTEM_HEADER_MODEL_TR="Model"
TXT_TGBOT_SISTEM_HEADER_MODEL_EN="Model"
TXT_TGBOT_DEVICE_KEENDNS_LABEL_TR="KeenDNS"
TXT_TGBOT_DEVICE_KEENDNS_LABEL_EN="KeenDNS"
TXT_TGBOT_DEVICE_RELEASE_LABEL_TR="Release"
TXT_TGBOT_DEVICE_RELEASE_LABEL_EN="Release"
TXT_TGBOT_DEVICE_TRAFFIC_LABEL_TR="Trafik (WAN)"
TXT_TGBOT_DEVICE_TRAFFIC_LABEL_EN="Traffic (WAN)"
TXT_TGBOT_BTN_SELFTEST_TR="Selftest"
TXT_TGBOT_BTN_SELFTEST_EN="Selftest"
TXT_TGBOT_SELFTEST_PASS_TR="PASS=0 - Tum testler basarili."
TXT_TGBOT_SELFTEST_PASS_EN="PASS=0 - All tests passed."
TXT_TGBOT_SELFTEST_FAIL_TR="Selftest hata buldu."
TXT_TGBOT_SELFTEST_FAIL_EN="Selftest found errors."
TXT_TGBOT_MENU_LOGS_TITLE_TR="Son Loglar"
TXT_TGBOT_MENU_LOGS_TITLE_EN="Recent Logs"
TXT_TGBOT_BOT_ENABLE_TR="Bot aktif mi"
TXT_TGBOT_BOT_ENABLE_EN="Bot enabled"
TXT_TGBOT_POLL_SEC_TR="Polling araligi (saniye)"
TXT_TGBOT_POLL_SEC_EN="Polling interval (seconds)"
TXT_TGBOT_MENU_BOT_TITLE_TR="Telegram Bot Yonetimi"
TXT_TGBOT_MENU_BOT_TITLE_EN="Telegram Bot Management"
TXT_TGBOT_BOT_STATUS_ACTIVE_TR="AKTIF - 2 yonlu haberlesme calisiyor"
TXT_TGBOT_BOT_STATUS_ACTIVE_EN="ACTIVE - 2-way communication running"
TXT_TGBOT_BOT_STATUS_INACTIVE_TR="Bot KAPALI"
TXT_TGBOT_BOT_STATUS_INACTIVE_EN="Bot DISABLED"
TXT_TGBOT_ENABLE_BOT_TR="Botu Etkinlestir / Ayarla"
TXT_TGBOT_ENABLE_BOT_EN="Enable / Configure Bot"
TXT_TGBOT_DISABLE_BOT_TR="Botu Devre Disi Birak"
TXT_TGBOT_DISABLE_BOT_EN="Disable Bot"
TXT_TGBOT_RESTART_BOT_TR="Botu Yeniden Baslat"
TXT_TGBOT_RESTART_BOT_EN="Restart Bot"
TXT_TGBOT_ENTER_POLL_TR="Polling araligi saniye cinsinden girin (varsayilan 5): "
TXT_TGBOT_ENTER_POLL_EN="Enter polling interval in seconds (default 5): "
TXT_TGBOT_BOT_STARTED_TR="Bot baslatildi."
TXT_TGBOT_BOT_STARTED_EN="Bot started."
TXT_TGBOT_BOT_STOPPED_TR="Bot durduruldu."
TXT_TGBOT_BOT_STOPPED_EN="Bot stopped."
TXT_TGBOT_BOT_NOT_CONFIG_TR="Bot yapilandirilmamis. Once Telegram token ve chat ID girin."
TXT_TGBOT_BOT_NOT_CONFIG_EN="Bot not configured. Enter Telegram token and chat ID first."
TXT_TGBOT_BTN_WAN_RESET_TR="WAN Sureli Kapatma"
TXT_TGBOT_BTN_WAN_RESET_EN="Timed WAN Shutdown"
TXT_TGBOT_BTN_CONFIRM_TR="Onayla"
TXT_TGBOT_BTN_CONFIRM_EN="Confirm"
TXT_TGBOT_WAN_RESET_SELECT_TR="WAN kac dakika kapatilsin?"
TXT_TGBOT_WAN_RESET_SELECT_EN="How long to disable WAN?"
TXT_TGBOT_WAN_RESET_CONFIRM_TR="WAN %MIN% dk kapatilacak. Onayliyor musun?"
TXT_TGBOT_WAN_RESET_CONFIRM_EN="WAN will be off for %MIN% min. Confirm?"
TXT_TGBOT_WAN_RESET_STARTED_TR="WAN kapatildi. %MIN% dk sonra yeniden baglanacak."
TXT_TGBOT_WAN_RESET_STARTED_EN="WAN disabled. Will reconnect in %MIN% min."
TXT_TGBOT_WAN_NO_IF_TR="WAN arayuzu bulunamadi."
TXT_TGBOT_WAN_NO_IF_EN="WAN interface not found."

TXT_TGBOT_ROUTER_ID_LABEL_TR="Router Kimlik"
TXT_TGBOT_ROUTER_ID_LABEL_EN="Router ID"
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
TXT_HEALTH_SHA256_KZM_TR="KZM dosya butunlugu (SHA256)"
TXT_HEALTH_SHA256_KZM_EN="KZM file integrity (SHA256)"
TXT_HEALTH_SHA256_ZAP_TR="Zapret surum durumu"
TXT_HEALTH_SHA256_ZAP_EN="Zapret version status"
TXT_HEALTH_SHA256_OK_TR="Dogrulandi"
TXT_HEALTH_SHA256_OK_EN="Verified"
TXT_HEALTH_SHA256_FAIL_TR="Eslesmiyor / Dogrulanmamis"
TXT_HEALTH_SHA256_FAIL_EN="Mismatch / Not verified"
TXT_HEALTH_SHA256_UNKNOWN_TR="Henuz kontrol edilmedi (Menu 10)"
TXT_HEALTH_SHA256_UNKNOWN_EN="Not checked yet (Menu 10)"
TXT_HEALTH_SHA256_ZAP_UNKNOWN_TR="Henuz kontrol edilmedi (Menu 6)"
TXT_HEALTH_SHA256_ZAP_UNKNOWN_EN="Not checked yet (Menu 6)"

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

TXT_MENU14_TITLE_TR="Ag Tanilama ve Sistem Kontrolu"
TXT_MENU14_TITLE_EN="Network Diagnostics & System Check"
TXT_MENU14_OPT1_TR="1. Kontrol Calistir"
TXT_MENU14_OPT1_EN="1. Run Diagnostics"
TXT_MENU14_OPT2_TR="2. OPKG Listesini Yenile"
TXT_MENU14_OPT2_EN="2. Refresh OPKG Package List"
TXT_OPKG_UPDATING_TR="OPKG paket listesi yenileniyor..."
TXT_OPKG_UPDATING_EN="Refreshing OPKG package list..."
TXT_OPKG_UPDATED_TR="OPKG paket listesi yenilendi."
TXT_OPKG_UPDATED_EN="OPKG package list refreshed."
TXT_OPKG_UPDATE_FAIL_TR="OPKG listesi yenilenemedi."
TXT_OPKG_UPDATE_FAIL_EN="Failed to refresh OPKG list."
TXT_OPKG_ALL_CURRENT_TR="Tum paketler guncel. Yukseltilecek paket yok."
TXT_OPKG_ALL_CURRENT_EN="All packages up to date. Nothing to upgrade."
TXT_OPKG_UPGRADABLE_TR="yukseltilecek paket bulundu:"
TXT_OPKG_UPGRADABLE_EN="upgradable package(s) found:"
TXT_OPKG_UPGRADE_WARN_TR="UYARI: opkg upgrade tum paketleri gunceller."
TXT_OPKG_UPGRADE_WARN_EN="WARNING: opkg upgrade will update ALL packages."
TXT_OPKG_UPGRADE_WARN2_TR="Keenetic'te bagimlilik cakismasi veya sistem bozulmasi yasanabilir."
TXT_OPKG_UPGRADE_WARN2_EN="Dependency conflicts or system breakage may occur on Keenetic."
TXT_OPKG_UPGRADE_CONFIRM_TR="Devam etmek ister misiniz? (e/h): "
TXT_OPKG_UPGRADE_CONFIRM_EN="Do you want to continue? (y/n): "
TXT_OPKG_UPGRADING_TR="Paketler yukseltiliyor, lutfen bekleyin..."
TXT_OPKG_UPGRADING_EN="Upgrading packages, please wait..."
TXT_OPKG_UPGRADED_TR="opkg upgrade tamamlandi."
TXT_OPKG_UPGRADED_EN="opkg upgrade completed."
TXT_OPKG_UPGRADE_FAIL_TR="opkg upgrade basarisiz oldu."
TXT_OPKG_UPGRADE_FAIL_EN="opkg upgrade failed."

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
TXT_HL_LIST_USER_TR="User Hostlist          "
TXT_HL_LIST_USER_EN="User Hostlist          "
TXT_HL_LIST_EXCLUDE_DOM_TR="Exclude (Domain)       "
TXT_HL_LIST_EXCLUDE_DOM_EN="Exclude (Domain)       "
TXT_HL_LIST_EXCLUDE_IP_TR="Exclude (IP/Subnet)    "
TXT_HL_LIST_EXCLUDE_IP_EN="Exclude (IP/Subnet)    "
TXT_HL_LIST_AUTO_TR="Auto Hostlist          "
TXT_HL_LIST_AUTO_EN="Auto Hostlist          "

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
TXT_BLK_HM_AUTORESTART_WARN_TR="HealthMon, Zapret'i test sirasinda otomatik baslatabilir. Gecici olarak devre disi birakilsin mi? (e/h): "
TXT_BLK_HM_AUTORESTART_WARN_EN="HealthMon may restart Zapret during test. Disable temporarily? (y/n): "
TXT_BLK_HM_AUTORESTART_PAUSED_TR="HealthMon otomatik baslama gecici olarak devre disi birakildi."
TXT_BLK_HM_AUTORESTART_PAUSED_EN="HealthMon auto-restart temporarily disabled."
TXT_BLK_HM_AUTORESTART_RESTORED_TR="HealthMon otomatik baslama eski haline getirildi."
TXT_BLK_HM_AUTORESTART_RESTORED_EN="HealthMon auto-restart restored."


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

TXT_PROMPT_MAIN_TR=" Seciminizi Yapin (0-17, B, L, R, U): "
TXT_PROMPT_MAIN_EN=" Select an Option (0-17, B, L, R, U): "

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

TXT_GITHUB_LATEST_TR="Guncel"
TXT_GITHUB_LATEST_EN="Latest"

TXT_DEVICE_VERSION_TR="Kurulu"
TXT_DEVICE_VERSION_EN="Installed"

TXT_UPTODATE_TR="En guncel surumu kullaniyorsunuz."
TXT_UPTODATE_EN="You are using the latest version."
TXT_ZAP_NEWER_LOCAL_TR="Kurulu surum GitHub'dakinden YENI (geri cekilmis olabilir). GitHub surumunu yeniden yuklemek ister misiniz? (e/h): "
TXT_ZAP_NEWER_LOCAL_EN="Installed version is NEWER than GitHub (may have been pulled). Reinstall GitHub version? (y/n): "
TXT_ZAP_NEWER_LOCAL_WARN_TR="UYARI: Kurulu surum GitHub'da mevcut degil veya geri cekilmis."
TXT_ZAP_NEWER_LOCAL_WARN_EN="WARNING: Installed version is not available on GitHub or was pulled back."

TXT_GITHUB_FAIL_TR="HATA: GitHub uzerinden surum bilgisi alinamadi."
TXT_GITHUB_FAIL_EN="ERROR: Could not fetch version info from GitHub."

TXT_ZAP_UPDATE_CONFIRM_TR="Guncellemek istiyor musunuz? (e/h): "
TXT_ZAP_UPDATE_CONFIRM_EN="Do you want to update? (y/n): "

TXT_ZAP_UPDATE_DOWNLOADING_TR="Zapret indiriliyor..."
TXT_ZAP_UPDATE_DOWNLOADING_EN="Downloading Zapret..."

TXT_ZAP_UPDATE_EXTRACTING_TR="Arsiv aciliyor..."
TXT_ZAP_UPDATE_EXTRACTING_EN="Extracting archive..."

TXT_ZAP_UPDATE_APPLYING_TR="Binary dosyalar yukleniyor..."
TXT_ZAP_UPDATE_APPLYING_EN="Applying binaries..."

TXT_ZAP_UPDATE_OK_TR="Zapret basariyla guncellendi."
TXT_ZAP_UPDATE_OK_EN="Zapret updated successfully."

TXT_ZAP_UPDATE_FAIL_DL_TR="HATA: Zapret indirilemedi."
TXT_ZAP_UPDATE_FAIL_DL_EN="ERROR: Failed to download Zapret."

TXT_ZAP_UPDATE_FAIL_EX_TR="HATA: Arsiv acilamadi."
TXT_ZAP_UPDATE_FAIL_EX_EN="ERROR: Failed to extract archive."

TXT_ZAP_UPDATE_FAIL_BIN_TR="HATA: Binary dosyalar kopyalanamadi."
TXT_ZAP_UPDATE_FAIL_BIN_EN="ERROR: Failed to apply binaries."

TXT_ZAP_UPDATE_SHA256_OK_TR="SHA256 dogrulamasi basarili."
TXT_ZAP_UPDATE_SHA256_OK_EN="SHA256 verification passed."

TXT_ZAP_UPDATE_SHA256_FAIL_TR="SHA256 dogrulamasi basarisiz! Dosya bozuk veya degistirilmis olabilir."
TXT_ZAP_UPDATE_SHA256_FAIL_EN="SHA256 verification failed! File may be corrupt or tampered."

TXT_ZAP_UPDATE_SHA256_SKIP_TR="SHA256 bilgisi alinamadi, dogrulama atlandi."
TXT_ZAP_UPDATE_SHA256_SKIP_EN="SHA256 not available from GitHub, verification skipped."

TXT_ZAP_UPDATE_CANCELLED_TR="Guncelleme iptal edildi."
TXT_ZAP_UPDATE_CANCELLED_EN="Update cancelled."

TXT_ZAP_UPDATE_NO_INSTALLED_TR="Zapret kurulu degil. Once kurulum yapin."
TXT_ZAP_UPDATE_NO_INSTALLED_EN="Zapret is not installed. Please install first."

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
TXT_KEENDNS_LOST_TR="⚠️ KeenDNS Uyari\n🔗 %s\n☁️ Dogrudan erisim kesildi, yalnizca cloud aktif."
TXT_KEENDNS_CGN_LOST_TR="⚠️ KeenDNS Uyari\n🔗 %s\n☁️ Cloud erisimi kesildi (CGN/direkt erisim yok)."
TXT_KEENDNS_CGN_LOST_EN="⚠️ KeenDNS Alert\n🔗 %s\n☁️ Cloud access lost (CGN / no direct access)."
TXT_KEENDNS_CGN_BACK_TR="✅ KeenDNS Geri Geldi\n🔗 %s\n☁️ Cloud erisimi yeniden aktif."
TXT_KEENDNS_CGN_BACK_EN="✅ KeenDNS Restored\n🔗 %s\n☁️ Cloud access is active again."
TXT_KEENDNS_LOST_EN="⚠️ KeenDNS Alert\n🔗 %s\n☁️ Direct access lost, cloud only."
TXT_KEENDNS_BACK_TR="✅ KeenDNS Geri Geldi\n🔗 %s\n🌐 Dogrudan erisim yeniden aktif."
TXT_KEENDNS_BACK_EN="✅ KeenDNS Restored\n🔗 %s\n🌐 Direct access is active again."
TXT_KEENDNS_FAIL_TR="❌ KeenDNS Erisim Yok\n🔗 %s\n🚫 Domain disaridan erisilebilir degil."
TXT_KEENDNS_FAIL_EN="❌ KeenDNS Unreachable\n🔗 %s\n🚫 Domain is not accessible from outside."
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
    printf '%s' "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")"; read -r _ </dev/tty || exit 0
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
        printf "%b%s: %s%b\n" "${CLR_GREEN}${CLR_BOLD}" "$(T dpi_current "$_cur_label_tr" "$_cur_label_en")" "$(T TXT_ACTIVE_DPI_AUTO)" "${CLR_RESET}"
        printf "%s: %s\n" "$(T TXT_DPI_BASE_PROFILE)" "$(T dpi_curp "$(dpi_profile_name_tr "$cur")" "$(dpi_profile_name_en "$cur")")"
    else
        printf "%b%s: %s%b\n" "${CLR_GREEN}${CLR_BOLD}" "$(T dpi_current "$_cur_label_tr" "$_cur_label_en")" "$(T dpi_curp "$(dpi_profile_name_tr "$cur")" "$(dpi_profile_name_en "$cur")")" "${CLR_RESET}"
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
    printf '%s' "$(T dpi_prompt "Seciminizi yapin (0-8): " "Select an option (0-8): ")"; read -r sel || return 1
    # sanitize selection (avoid "0 applies 1" edge cases)
    sel="$(echo "$sel" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [ -z "$sel" ] || [ "$sel" = "0" ]; then
        return 1
    fi


    # If auto profile is active, switching to a numbered profile disables auto (by user's choice)
    if [ "$origin" = "auto" ] && echo "$sel" | grep -Eq '^[1-8]$'; then
        local _ans
        printf '%s' "$(T TXT_DPI_AUTO_DISABLE_PROMPT)"; read -r _ans
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
        press_enter_to_continue
    fi

    return 0
}

apply_dpi_profile_now() {
    if ! is_zapret_installed; then
        echo "$(T err_not_inst "HATA: Zapret yuklu degil." "ERROR: Zapret is not installed.")"
        press_enter_to_continue
        return 1
    fi
    update_nfqws_parameters
    restart_zapret >/dev/null 2>&1 || true
    enforce_client_mode_rules >/dev/null 2>&1 || true
    enforce_wan_if_nfqueue_rules >/dev/null 2>&1 || true
    echo "$(T dpi_applied "DPI profili uygulandi." "DPI profile applied.")"
    press_enter_to_continue
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
    # PATH genislet: Entware ve sistem araclari her zaman erisilebilir olsun
    export PATH="/opt/sbin:/opt/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"
    
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
    press_enter_to_continue
    clear
}

# --- ZAPRET GUNCELLEME (6. MADDE) ---
update_zapret() {
    local repo="bol-van/zapret"
    local api="https://api.github.com/repos/${repo}/releases/latest"
    local tmpdir="/opt/tmp/zapret_update_$$"

    # GitHub API'den hem tag_name hem asset SHA256 al (tek istek)
    local api_raw latest tarball expected_sha256
    api_raw="$(curl -fsS "$api" 2>/dev/null)"
    latest="$(printf '%s\n' "$api_raw" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
    [ -z "$latest" ] && { print_status FAIL "$(T TXT_GITHUB_FAIL)"; return 1; }

    tarball="zapret-${latest}.tar.gz"
    local url="https://github.com/${repo}/releases/download/${latest}/${tarball}"

    # Asset SHA256 digest'ini API'den cek (format: "digest":"sha256:HASH")
    expected_sha256="$(printf '%s\n' "$api_raw" | grep -A5 "\"${tarball}\"" | \
        sed -n 's/.*"digest"[[:space:]]*:[[:space:]]*"sha256:\([^"]*\)".*/\1/p' | head -n1)"

    print_status INFO "$(T TXT_ZAP_UPDATE_DOWNLOADING)"
    mkdir -p "$tmpdir" || { print_status FAIL "$(T TXT_ZAP_UPDATE_FAIL_DL)"; return 1; }

    if ! curl -fsS -L "$url" -o "${tmpdir}/${tarball}" 2>/dev/null; then
        rm -rf "$tmpdir"
        print_status FAIL "$(T TXT_ZAP_UPDATE_FAIL_DL)"
        return 1
    fi

    # SHA256 dogrulamasi
    if [ -n "$expected_sha256" ]; then
        local actual_sha256
        actual_sha256="$(sha256sum "${tmpdir}/${tarball}" 2>/dev/null | cut -d' ' -f1)"
        if [ "$actual_sha256" = "$expected_sha256" ]; then
            print_status PASS "$(T TXT_ZAP_UPDATE_SHA256_OK)"
            printf 'ok' > /opt/etc/zkm_sha256_zapret.state
        else
            rm -rf "$tmpdir"
            print_status FAIL "$(T TXT_ZAP_UPDATE_SHA256_FAIL)"
            printf 'fail' > /opt/etc/zkm_sha256_zapret.state
            return 1
        fi
    else
        print_status WARN "$(T TXT_ZAP_UPDATE_SHA256_SKIP)"
    fi

    print_status INFO "$(T TXT_ZAP_UPDATE_EXTRACTING)"
    if ! tar -xzf "${tmpdir}/${tarball}" -C "$tmpdir" 2>/dev/null; then
        rm -rf "$tmpdir"
        print_status FAIL "$(T TXT_ZAP_UPDATE_FAIL_EX)"
        return 1
    fi

    print_status INFO "$(T TXT_ZAP_UPDATE_APPLYING)"
    local srcdir
    srcdir="$(find "$tmpdir" -maxdepth 1 -mindepth 1 -type d | head -n1)"
    if [ -z "$srcdir" ] || [ ! -d "${srcdir}/binaries" ]; then
        rm -rf "$tmpdir"
        print_status FAIL "$(T TXT_ZAP_UPDATE_FAIL_BIN)"
        return 1
    fi

    if ! cp -r "${srcdir}/binaries/." /opt/zapret/binaries/ 2>/dev/null; then
        rm -rf "$tmpdir"
        print_status FAIL "$(T TXT_ZAP_UPDATE_FAIL_BIN)"
        return 1
    fi

    if [ -f "${srcdir}/install_bin.sh" ]; then
        cp "${srcdir}/install_bin.sh" /opt/zapret/install_bin.sh 2>/dev/null
        sh /opt/zapret/install_bin.sh >/dev/null 2>&1 || true
    fi

    printf '%s\n' "$latest" > /opt/zapret/version 2>/dev/null
    rm -rf "$tmpdir"
    print_status PASS "$(T TXT_ZAP_UPDATE_OK)"

    # Binary surum dogrulamasi
    local nfqws_bin="/opt/zapret/nfq/nfqws"
    if [ -x "$nfqws_bin" ]; then
        local bin_ver
        bin_ver="$("$nfqws_bin" --version 2>&1 | head -n1)"
        [ -n "$bin_ver" ] && printf "     %s: %s\n" "$(T _ 'Binary' 'Binary')" "$bin_ver"
    fi

    restart_zapret >/dev/null 2>&1 || true
    printf 'ok' > /opt/etc/zkm_sha256_zapret.state 2>/dev/null
    return 0
}

check_remote_update() {
    if ! is_zapret_installed; then
        print_status FAIL "$(T TXT_ZAP_UPDATE_NO_INSTALLED)"
        press_enter_to_continue
        return 1
    fi

    print_status INFO "$(T TXT_CHECKING_GITHUB)"
    local repo="bol-van/zapret"
    local api="https://api.github.com/repos/${repo}/releases/latest"
    local REMOTE_VER LOCAL_VER
    REMOTE_VER="$(curl -fsS "$api" 2>/dev/null | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"

    if [ -z "$REMOTE_VER" ]; then
        print_status FAIL "$(T TXT_GITHUB_FAIL)"
        press_enter_to_continue
        return 1
    fi

    LOCAL_VER="$(cat /opt/zapret/version 2>/dev/null)"
    [ -z "$LOCAL_VER" ] && LOCAL_VER="$(T _ 'Bilinmiyor' 'Unknown')"

    # Renkleri duruma gore ata
    local CLR_REMOTE CLR_LOCAL
    if [ "$REMOTE_VER" = "$LOCAL_VER" ]; then
        # Guncel: ikisi de yesil
        CLR_REMOTE="${CLR_BOLD}${CLR_GREEN}"; CLR_LOCAL="${CLR_BOLD}${CLR_GREEN}"
    elif ver_is_newer "$REMOTE_VER" "$LOCAL_VER"; then
        # Normal guncelleme: remote yeni (yesil), local eski (sari)
        CLR_REMOTE="${CLR_BOLD}${CLR_GREEN}"; CLR_LOCAL="${CLR_BOLD}${CLR_YELLOW}"
    else
        # Geri cekilen release: local daha yeni ama hatali (kirmizi), remote stabil (yesil)
        CLR_REMOTE="${CLR_BOLD}${CLR_GREEN}"; CLR_LOCAL="${CLR_BOLD}${CLR_RED}"
    fi
    print_line "-"
    printf " %-10s: %b%s%b\n" "$(T TXT_GITHUB_LATEST)" "$CLR_REMOTE" "$REMOTE_VER" "${CLR_RESET}"
    printf " %-10s: %b%s%b\n" "$(T TXT_DEVICE_VERSION)" "$CLR_LOCAL" "$LOCAL_VER" "${CLR_RESET}"

    # Binary surum bilgisi
    local nfqws_bin="/opt/zapret/nfq/nfqws"
    if [ -x "$nfqws_bin" ]; then
        local bin_ver
        bin_ver="$("$nfqws_bin" --version 2>&1 | head -n1)"
        [ -n "$bin_ver" ] && printf " %-10s: %s\n" "INFO" "$bin_ver"
    fi

    print_line "-"

    if [ "$REMOTE_VER" = "$LOCAL_VER" ]; then
        printf 'ok' > /opt/etc/zkm_sha256_zapret.state
        print_status PASS "$(T TXT_UPTODATE)"
        press_enter_to_continue
        return 0
    fi

    if ver_is_newer "$REMOTE_VER" "$LOCAL_VER"; then
        # Normal guncelleme: GitHub daha yeni
        print_status WARN "$(T _ 'Yeni surum mevcut!' 'New version available!')"
        echo ""
        printf "%s" "$(T TXT_ZAP_UPDATE_CONFIRM)"
        read -r ans
        case "$ans" in
            e|E|y|Y)
                echo ""
                update_zapret
                ;;
            *)
                print_status INFO "$(T TXT_ZAP_UPDATE_CANCELLED)"
                ;;
        esac
    else
        # Kurulu surum GitHub'dakinden yeni: geri cekilmis release senaryosu
        print_status WARN "$(T TXT_ZAP_NEWER_LOCAL_WARN)"
        echo ""
        printf "%s" "$(T TXT_ZAP_NEWER_LOCAL)"
        read -r ans
        case "$ans" in
            e|E|y|Y)
                echo ""
                update_zapret
                ;;
            *)
                print_status INFO "$(T TXT_ZAP_UPDATE_CANCELLED)"
                ;;
        esac
    fi
    press_enter_to_continue
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
        press_enter_to_continue
        clear
        return 1
    fi

    echo "$(T ipv6_cfg_title 'Zapret icin IPv6 destegi ayarlanacak.' 'IPv6 support for Zapret will be configured.')"
    echo "$(T ipv6_cfg_desc 'Bu, zapretin IPv6 (ip6tables) tarafinda da kural/yonlendirme kurmasini saglar.' 'This enables Zapret to also set up rules/routing on the IPv6 (ip6tables) side.')"
    check_zapret_ipv6_status
    echo ""
    printf '%s' "$(T ipv6_cfg_prompt 'IPv6 destegi etkinlestirilsin mi? (e/h) [h]: ' 'Enable IPv6 support? (y/n) [n]: ')"; read -r ans

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
    press_enter_to_continue
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
        press_enter_to_continue
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
    press_enter_to_continue
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
        press_enter_to_continue
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
            printf '%b%s%b\n' "${CLR_ORANGE}${CLR_BOLD}" "$(T ipset_mode 'Mod: Secili IP' 'Mode: Selected IPs')" "${CLR_RESET}"
        else
            printf '%b%s%b\n' "${CLR_GREEN}${CLR_BOLD}" "$(T ipset_mode 'Mod: Tum ag' 'Mode: Whole network')" "${CLR_RESET}"
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
                press_enter_to_continue
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
                printf '%s' "IP'leri girin (Enter=iptal): "; read -r ips

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

                press_enter_to_continue
                clear
                ;;
            1)
                if [ "$MODE" = "list" ]; then
                    show_ipset_client_status
                else
                    echo "IP listesi sadece Secili IP'lere Uygula (mode=list) aktifken gosterilir."
                    show_ipset_client_status
                fi
                press_enter_to_continue
                clear
                ;;

            4)
                MODE="$(cat "$IPSET_CLIENT_MODE_FILE" 2>/dev/null)"
                [ -z "$MODE" ] && MODE="all"
                if [ "$MODE" != "list" ]; then
                    echo "Bu menu sadece \"Secili IP'lere Uygula\" (mod=list) acikken kullanilabilir. Once 3'u secin."
                else
                printf '%s' "$(T add_ip_prompt "$TXT_ADD_IP_TR" "$TXT_ADD_IP_EN")"; read -r oneip
                if [ -z "$oneip" ]; then
                    echo "$(T cancelled "Islem iptal edildi." "Cancelled.")"
                    press_enter_to_continue
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
                press_enter_to_continue
                clear
                ;;

            5)
                MODE="$(cat "$IPSET_CLIENT_MODE_FILE" 2>/dev/null)"
                [ -z "$MODE" ] && MODE="all"
                if [ "$MODE" != "list" ]; then
                    echo "Bu menu sadece \"Secili IP'lere Uygula\" (mod=list) acikken kullanilabilir. Once 3'u secin."
                else
                printf '%s' "$(T del_ip_prompt "$TXT_DEL_IP_TR" "$TXT_DEL_IP_EN")"; read -r oneip
                if [ -z "$oneip" ]; then
                    echo "$(T cancelled "Islem iptal edildi." "Cancelled.")"
                    press_enter_to_continue
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
                press_enter_to_continue
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
                press_enter_to_continue
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
    printf '%b %s%b\n' "${CLR_CYAN}${CLR_BOLD}" "$(T TXT_NOZAPRET_TITLE)" "${CLR_RESET}"
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
            printf '  %b%2d.%b %s\n' "${CLR_ORANGE}${CLR_BOLD}" "$i" "${CLR_RESET}" "$line"
        done < "$NOZAPRET_FILE"
        if [ "$i" -eq 0 ]; then
            echo "  $(T TXT_NOZAPRET_EMPTY)"
        fi
    fi
    echo ""
    printf '%b%s%b\n' "${CLR_GREEN}${CLR_BOLD}" "$(T TXT_NOZAPRET_IPSET_ACTIVE)" "${CLR_RESET}"
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
        printf '%b  %s%b\n' "${CLR_CYAN}${CLR_BOLD}" "$(T TXT_NOZAPRET_TITLE)" "${CLR_RESET}"
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
                press_enter_to_continue
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
                press_enter_to_continue
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
                press_enter_to_continue
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
                press_enter_to_continue
                ;;
            0)
                break
                ;;
            *)
                echo "$(T invalid_main 'Gecersiz secim!' 'Invalid choice!')"
                press_enter_to_continue
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
    printf '%s' "Devam edilsin mi? (e/h): "; read -r _c
    echo "$_c" | grep -qi '^e' || { echo "Iptal edildi."; return 0; }

    cleanup_zapret_firewall_leftovers
    remove_nfqueue_rules_200

    # ipset mod dosyalari (opsiyonel)
    rm -f /opt/zapret/ipset_clients_mode /opt/zapret/ipset_clients.txt /opt/zapret/wan_if 2>/dev/null

    echo "Kalinti temizligi tamamlandi."
    press_enter_to_continue
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
    opkg install coreutils-sort curl grep gzip ipset iptables kmod_ndms xtables-addons_legacy cron >/dev/null 2>&1 || \
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
    press_enter_to_continue
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
    local repo="RevolutionTR/keenetic-zapret-manager"
    local api="https://api.github.com/repos/${repo}/releases/latest"
    local script_name="keenetic_zapret_otomasyon_ipv6_ipset.sh"
    DL_URL="https://github.com/${repo}/releases/latest/download/${script_name}"
    TMP_FILE="/tmp/keenetic_zapret_manager_update.$$"
    LOCAL_VER="$(zkm_get_installed_script_version)"
    [ -z "$LOCAL_VER" ] && LOCAL_VER="$SCRIPT_VERSION"
    BACKUP_FILE="${TARGET_SCRIPT}.bak_${LOCAL_VER#v}_$(date +%Y%m%d_%H%M%S 2>/dev/null).sh"

    # GitHub API'den SHA256 digest al (tek istek)
    local api_raw expected_sha256
    api_raw="$(curl -fsS "$api" 2>/dev/null)"
    expected_sha256="$(printf '%s\n' "$api_raw" | grep -A30 "\"${script_name}\"" | \
        sed -n 's/.*"digest"[[:space:]]*:[[:space:]]*"sha256:\([^"]*\)".*/\1/p' | head -n1)"

    echo "$(T mgr_update_start 'Betik indiriliyor (GitHub)...' 'Downloading script (GitHub)...')"
    if ! download_file "$DL_URL" "$TMP_FILE"; then
        echo "$(T mgr_update_dl_fail 'Indirme basarisiz (curl/wget/SSL kontrol edin).' 'Download failed (check curl/wget/SSL).')"
        rm -f "$TMP_FILE" 2>/dev/null
        return 1
    fi

    # SHA256 dogrulamasi
    if [ -n "$expected_sha256" ]; then
        local actual_sha256
        actual_sha256="$(sha256sum "$TMP_FILE" 2>/dev/null | cut -d' ' -f1)"
        if [ "$actual_sha256" = "$expected_sha256" ]; then
            print_status PASS "$(T TXT_ZAP_UPDATE_SHA256_OK)"
            printf 'ok' > /opt/etc/zkm_sha256_zapret.state
        else
            rm -f "$TMP_FILE" 2>/dev/null
            print_status FAIL "$(T TXT_ZAP_UPDATE_SHA256_FAIL)"
            printf 'fail' > /opt/etc/zkm_sha256_zapret.state
            return 1
        fi
    else
        print_status WARN "$(T TXT_ZAP_UPDATE_SHA256_SKIP)"
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
    return 2
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

    printf 'ok' > /opt/etc/zkm_sha256_kzm.state 2>/dev/null
    echo "$(T mgr_update_done 'Guncelleme tamamlandi. Lutfen betigi yeniden calistirin.' 'Update completed. Please re-run the script.')"
    return 0
}


check_manager_update() {
    print_status INFO "$(T TXT_CHECKING_GITHUB)"
    local repo="RevolutionTR/keenetic-zapret-manager"
    local script_name="keenetic_zapret_otomasyon_ipv6_ipset.sh"
    local api="https://api.github.com/repos/${repo}/releases/latest"
    local REMOTE_VER LOCAL_VER api_raw CLR_REMOTE CLR_LOCAL sha256sums_url expected_sha256 actual_sha256
    api_raw="$(curl -fsS "$api" 2>/dev/null)"
    REMOTE_VER="$(printf '%s\n' "$api_raw" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"

    if [ -z "$REMOTE_VER" ]; then
        print_status FAIL "$(T TXT_GITHUB_FAIL)"
        press_enter_to_continue
        return 1
    fi

    LOCAL_VER="$(zkm_get_installed_script_version)"
    [ -z "$LOCAL_VER" ] && LOCAL_VER="$SCRIPT_VERSION"

    # Renkleri duruma gore ata
    if ver_is_newer "$REMOTE_VER" "$LOCAL_VER"; then
        CLR_REMOTE="${CLR_BOLD}${CLR_GREEN}"; CLR_LOCAL="${CLR_BOLD}${CLR_YELLOW}"
    elif ver_is_newer "$LOCAL_VER" "$REMOTE_VER"; then
        CLR_REMOTE="${CLR_BOLD}${CLR_YELLOW}"; CLR_LOCAL="${CLR_BOLD}${CLR_GREEN}"
    else
        CLR_REMOTE="${CLR_BOLD}${CLR_GREEN}"; CLR_LOCAL="${CLR_BOLD}${CLR_GREEN}"
    fi

    # SHA256SUMS dosyasini GitHub release'ten indir ve karsilastir
    sha256sums_url="https://github.com/${repo}/releases/download/${REMOTE_VER}/SHA256SUMS"
    expected_sha256="$(curl -fsSL "$sha256sums_url" 2>/dev/null | grep "${script_name}" | cut -d' ' -f1)"
    actual_sha256="$(sha256sum "$ZKM_SCRIPT_PATH" 2>/dev/null | cut -d' ' -f1)"

    print_line "-"
    printf " %-10s: %b%s%b\n" "$(T TXT_GITHUB_LATEST)" "$CLR_REMOTE" "$REMOTE_VER" "${CLR_RESET}"
    printf " %-10s: %b%s%b\n" "$(T TXT_DEVICE_VERSION)" "$CLR_LOCAL" "$LOCAL_VER" "${CLR_RESET}"

    if [ -n "$expected_sha256" ] && [ -n "$actual_sha256" ]; then
        if [ "$actual_sha256" = "$expected_sha256" ]; then
            printf " %-10s: %b%s%b\n" "PASS" "${CLR_GREEN}${CLR_BOLD}" "$(T TXT_ZAP_UPDATE_SHA256_OK)" "${CLR_RESET}"
            printf 'ok' > /opt/etc/zkm_sha256_kzm.state
        else
            printf " %-10s: %b%s%b\n" "WARN" "${CLR_ORANGE}${CLR_BOLD}" "$(T TXT_ZAP_UPDATE_SHA256_FAIL)" "${CLR_RESET}"
            printf 'fail' > /opt/etc/zkm_sha256_kzm.state
            printf " %-10s: %s\n" "GitHub" "$expected_sha256"
            printf " %-10s: %s\n" "Kurulu" "$actual_sha256"
        fi
    elif [ -n "$actual_sha256" ]; then
        printf " %-10s: %s\n" "INFO" "$actual_sha256"
    fi
    print_line "-"

    if [ "$REMOTE_VER" = "$LOCAL_VER" ]; then
        print_status PASS "$(T TXT_UPTODATE)"
        press_enter_to_continue
        return 0
    fi

    if ver_is_newer "$LOCAL_VER" "$REMOTE_VER"; then
        # Kurulu surum GitHub'dan daha yeni (gelistirici build)
        print_status INFO "$(T _ 'Kurulu surum GitHub surununden daha yeni (gelistirici build).' 'Installed version is newer than GitHub release (developer build).')"
        press_enter_to_continue
        return 0
    fi

    # Remote > Local: guncelleme mevcut
    print_status WARN "$(T _ 'Yeni surum mevcut!' 'New version available!')"
    echo ""
    printf "%s" "$(T _ 'Guncellemek ister misiniz? (e/h): ' 'Update now? (y/n): ')"
    read -r _ans
    case "$_ans" in
        e|E|y|Y)
            echo ""
            update_manager_script
            ;;
        *)
            print_status INFO "$(T TXT_ZAP_UPDATE_CANCELLED)"
            ;;
    esac
    press_enter_to_continue
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
    # $1=file $2=title_key (TXT_HL_LIST_*)
    [ "$ZKM_PAGE_ABORT" = "1" ] && return
    local f="$1" tk="$2"
    local c
    c="$(hostlist_stats "$f")"
    print_line "-"; zkm_page_line
    printf '%b%-25s:%b ' "${CLR_ORANGE}${CLR_BOLD}" "$(T "$tk")" "${CLR_RESET}"
    if [ "$c" -eq 0 ]; then
        printf '%b%s%b\n' "${CLR_RED}" "$(T TXT_EMPTY)" "${CLR_RESET}"
        zkm_page_line
    else
        printf '%b%d %s%b\n' "${CLR_GREEN}" "$c" "$(T _ 'domain' 'domains')" "${CLR_RESET}"
        zkm_page_line
        [ "$ZKM_PAGE_ABORT" = "1" ] && return
        echo ""; zkm_page_line
        while IFS= read -r _hl_line; do
            [ "$ZKM_PAGE_ABORT" = "1" ] && return
            printf '%s\n' "$_hl_line"
            zkm_page_line
        done << HLEOF
$(awk -v cyan="${CLR_CYAN}" -v reset="${CLR_RESET}" '
    NF && $0 !~ /^[[:space:]]*#/ {
        printf "  %s%2d.%s %s\n", cyan, NR, reset, $0
    }' "$f" 2>/dev/null)
HLEOF
    fi
}

# ZKM_PAGE_LINES: show_hostlist_tail tarafindan kullanilan global sayac
# zkm_page_check: her satir basilinca cagrilir, sayfa dolunca duraklar
ZKM_PAGE_LINES=0
ZKM_PAGE_ROWS=0
ZKM_PAGE_ABORT=0
zkm_page_init() {
    ZKM_PAGE_ABORT=0
    ZKM_PAGE_LINES=0
    ZKM_PAGE_ROWS="$(stty size 2>/dev/null | awk '{print $1}')"
    { [ -z "$ZKM_PAGE_ROWS" ] || [ "$ZKM_PAGE_ROWS" -lt 5 ]; } && ZKM_PAGE_ROWS=24
    ZKM_PAGE_ROWS=$(( ZKM_PAGE_ROWS - 3 ))
}
zkm_page_line() {
    [ "$ZKM_PAGE_ABORT" = "1" ] && return
    ZKM_PAGE_LINES=$(( ZKM_PAGE_LINES + 1 ))
    if [ "$ZKM_PAGE_LINES" -ge "$ZKM_PAGE_ROWS" ]; then
        printf '\033[7m-- Devam: ENTER | Cik: q --\033[0m '
        read -r _pans </dev/tty
        case "$_pans" in q|Q) ZKM_PAGE_ABORT=1; printf '\n'; return ;; esac
        ZKM_PAGE_LINES=0
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
            press_enter_to_continue
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
        press_enter_to_continue
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
        echo " 1. $(T TXT_HL_OPT_6)"
        echo " 2. $(T TXT_HL_OPT_1)"
        echo " 3. $(T TXT_HL_OPT_2)"
        echo " 4. $(T TXT_HL_OPT_3)"
        echo " 5. $(T TXT_HL_OPT_4)"
        echo " 6. $(T TXT_HL_OPT_5)"
        echo " 7. $(T TXT_HL_OPT_7)"
        echo " 8. $(T TXT_HL_OPT_8)"
        echo " 0. $(T TXT_HL_OPT_0)"
        print_line "-"
        printf "%s" "$(T TXT_HL_PICK)"
        read -r sel || return 0
        case "$sel" in
            1)
                zkm_page_init
                show_hostlist_tail "$HOSTLIST_USER"         TXT_HL_LIST_USER
                show_hostlist_tail "$HOSTLIST_EXCLUDE_DOM"   TXT_HL_LIST_EXCLUDE_DOM
                show_hostlist_tail "$HOSTLIST_EXCLUDE_IP"    TXT_HL_LIST_EXCLUDE_IP
                show_hostlist_tail "$HOSTLIST_AUTO"         TXT_HL_LIST_AUTO
                [ "$ZKM_PAGE_ABORT" != "1" ] && { print_line "-"; press_enter_to_continue; }
                clear
                ;;
            2)
                mode="$(choose_mode_filter_interactive)"
                [ "$mode" = "__invalid__" ] && { echo "$(T invalid_main 'Gecersiz secim!' 'Invalid choice!')"; continue; }
                [ -n "$mode" ] && apply_mode_filter "$mode"
                if type press_enter_to_continue >/dev/null 2>&1; then
                    press_enter_to_continue
                else
                    press_enter_to_continue
                fi
                clear
                ;;

            3)
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
    press_enter_to_continue
fi
clear

    ;;
            4)
                printf '%s' "$(T TXT_HL_PROMPT_DEL)"; read -r d
                [ "$d" = "0" ] && continue
                nd="$(normalize_domain "$d")"
                [ -z "$nd" ] && { echo "$(T TXT_HL_INVALID_DOMAIN)"; continue; }
                remove_line_exact "$HOSTLIST_USER" "$nd"
                echo "$(T TXT_HL_MSG_REMOVED)$nd"
                ;;

            5)
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
    press_enter_to_continue
fi
clear

    ;;
            6)
                printf '%s' "$(T TXT_HL_PROMPT_DEL)"; read -r d
                [ "$d" = "0" ] && continue
                nd="$(normalize_domain "$d")"
                [ -z "$nd" ] && { echo "$(T TXT_HL_INVALID_DOMAIN)"; continue; }
                remove_line_exact "$HOSTLIST_EXCLUDE_DOM" "$nd"
                echo "$(T TXT_HL_MSG_REMOVED)$nd"
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
                    press_enter_to_continue
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
                    press_enter_to_continue
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

        printf '%s' "$(T TXT_ROLLBACK_MAIN_PICK) "; read -r sel || return 0
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
    local _wan_ipv4 _wan_ipv6 _wan_ip_str
    _wan_ipv4="$(ip -4 addr show "$_wan_dev" 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)"
    _wan_ipv6="$(ip -6 addr show "$_wan_dev" 2>/dev/null | awk '/inet6 / && !/fe80/{print $2; exit}' | cut -d/ -f1)"
    _wan_ip_str=""
    [ -n "$_wan_ipv4" ] && _wan_ip_str=" | $(zkm_fmt_ip "$_wan_ipv4")"
    [ -n "$_wan_ipv6" ] && _wan_ip_str="${_wan_ip_str} | ${CLR_CYAN}${_wan_ipv6}${CLR_RESET}"
    printf "  %b%-*s%b : %b%s%b | %b%s\n"   "${CLR_BOLD}" "$_lw" "$(T TXT_MAIN_WAN_LABEL)" \
        "${CLR_RESET}" "${CLR_RESET}" "$_wan_dev" "${CLR_RESET}" \
        "$(zkm_banner_fmt_wan_state "$_wan_state")${_wan_ip_str}"
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
    _sched_cur="$(crontab -l 2>/dev/null | grep '# KZM_REBOOT' 2>/dev/null)"
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
    # Telegram Bot - sadece TG_BOT_ENABLE=1 ise goster
    if [ "$(grep -s '^TG_BOT_ENABLE=' /opt/etc/telegram.conf | cut -d= -f2 | tr -d '"')" = "1" ]; then
        if [ -f "/tmp/zkm_telegram_bot.pid" ] && kill -0 "$(cat "/tmp/zkm_telegram_bot.pid" 2>/dev/null)" 2>/dev/null; then
            printf "  %b%-*s%b : %b%s%b\n" "${CLR_BOLD}" "$_lw" "$(T TXT_TGBOT_BANNER_LABEL)" \
                "${CLR_RESET}" "${CLR_GREEN}" "$(T TXT_TGBOT_BANNER_ACTIVE)" "${CLR_RESET}"
        else
            printf "  %b%-*s%b : %b%s%b\n" "${CLR_BOLD}" "$_lw" "$(T TXT_TGBOT_BANNER_LABEL)" \
                "${CLR_RESET}" "${CLR_RED}"   "$(T TXT_TGBOT_BANNER_INACTIVE)" "${CLR_RESET}"
        fi
    fi
    local _kzm_sha_state _zap_sha_state _clr_kzm _clr_zap
    _kzm_sha_state="$(cat /opt/etc/zkm_sha256_kzm.state 2>/dev/null)"
    _zap_sha_state="$(cat /opt/etc/zkm_sha256_zapret.state 2>/dev/null)"
    [ "$_kzm_sha_state" = "ok" ] && _clr_kzm="${CLR_GREEN}" || _clr_kzm="${CLR_ORANGE}"
    [ "$_zap_sha_state" = "ok" ] && _clr_zap="${CLR_GREEN}" || _clr_zap="${CLR_ORANGE}"
    printf "  %b%-*s%b : %b%b%s%b\n"      "${CLR_BOLD}" "$_lw" "$(T _ 'KZM Surum'    'KZM Version'    )"        "${CLR_RESET}" "${CLR_BOLD}" "$_clr_kzm" "${SCRIPT_VERSION}"                               "${CLR_RESET}"
    printf "  %b%-*s%b : %b%b%s%b\n"      "${CLR_BOLD}" "$_lw" "$(T _ 'Zapret Surum' 'Zapret Version'  )"       "${CLR_RESET}" "${CLR_BOLD}" "$_clr_zap" "$(zkm_get_zapret_version)"                       "${CLR_RESET}"
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
    _mi "$(T TXT_MENU_17)"
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


# --- OPKG GUNCELLEME ---
run_opkg_update() {
    print_line "-"
    print_status INFO "$(T TXT_OPKG_UPDATING)"
    if opkg update 2>/dev/null; then
        print_status PASS "$(T TXT_OPKG_UPDATED)"
    else
        print_status WARN "$(T TXT_OPKG_UPDATE_FAIL)"
        press_enter_to_continue
        return 1
    fi

    local _upgradable
    _upgradable="$(opkg list-upgradable 2>/dev/null)"
    if [ -z "$_upgradable" ]; then
        print_status INFO "$(T TXT_OPKG_ALL_CURRENT)"
        press_enter_to_continue
        return 0
    fi

    local _count
    _count="$(printf '%s\n' "$_upgradable" | grep -c .)"
    print_status INFO "${_count} $(T TXT_OPKG_UPGRADABLE)"
    echo
    printf '%s\n' "$_upgradable"
    echo
    print_line "-"
    printf '%b%s%b\n' "${CLR_ORANGE}${CLR_BOLD}" "$(T TXT_OPKG_UPGRADE_WARN)" "${CLR_RESET}"
    printf '%b%s%b\n' "${CLR_ORANGE}" "$(T TXT_OPKG_UPGRADE_WARN2)" "${CLR_RESET}"
    echo
    printf '%s' "$(T TXT_OPKG_UPGRADE_CONFIRM)"
    local _ans
    read -r _ans </dev/tty
    case "$_ans" in
        e|E|y|Y)
            print_status INFO "$(T TXT_OPKG_UPGRADING)"
            if opkg upgrade 2>&1; then
                print_status PASS "$(T TXT_OPKG_UPGRADED)"
            else
                print_status WARN "$(T TXT_OPKG_UPGRADE_FAIL)"
            fi
            ;;
        *)
            print_status INFO "$(T TXT_CANCELLED)"
            ;;
    esac
    press_enter_to_continue
}

# --- AG TANILAMA ALT MENUSU ---
network_diag_menu() {
    while true; do
        clear
        print_line "="
        echo "$(T TXT_MENU14_TITLE)"
        print_line "="
        echo " $(T TXT_MENU14_OPT1)"
        echo " $(T TXT_MENU14_OPT2)"
        echo " 0. $(T TXT_BACK)"
        print_line "="
        printf '%s' "$(T TXT_CHOICE) "
        read -r _c || return 0
        case "$_c" in
            1) run_health_check ;;
            2) clear; run_opkg_update ;;
            0) return 0 ;;
            *) print_status WARN "$(T TXT_INVALID_CHOICE)"; sleep 1 ;;
        esac
    done
}

# --- SAGLIK KONTROLU (HEALTH CHECK) ---
run_health_check() {
    clear
    printf "\n %b%s%b\n" "${CLR_CYAN}" "$(T TXT_HEALTH_TITLE)" "${CLR_RESET}"
    print_line "="

    local HC_NET="/tmp/healthcheck_net.$$"
    local HC_SYS="/tmp/healthcheck_sys.$$"
    local HC_SVC="/tmp/healthcheck_svc.$$"
    : > "$HC_NET"; : > "$HC_SYS"; : > "$HC_SVC"

    local total_n=0 pass_n=0 warn_n=0 fail_n=0 info_n=0

    add_line() {
        local file="$1" label="$2" value="$3" status="$4"
        printf " %-35s : %s%s\n" "$label" "$(hc_word "$status")" "$value" >> "$file"
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

    # WAN IP adresleri
    local wan_ipv4 wan_ipv6 wan_ip_type wan_ip_label
    wan_ipv4="$(ip -4 addr show "$WAN_IF" 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)"
    wan_ipv6="$(ip -6 addr show "$WAN_IF" 2>/dev/null | awk '/inet6 / && !/fe80/{print $2; exit}' | cut -d/ -f1)"
    if [ -n "$wan_ipv4" ]; then
        wan_ip_type="$(zkm_classify_ip "$wan_ipv4")"
        case "$wan_ip_type" in
            cgnat)   wan_ip_label=" ${CLR_YELLOW}[CGNAT]${CLR_RESET}" ;;
            private) wan_ip_label=" ${CLR_ORANGE}[NAT]${CLR_RESET}" ;;
            *)       wan_ip_label=" ${CLR_GREEN}[Public]${CLR_RESET}" ;;
        esac
        add_line "$HC_NET" "$(T TXT_HEALTH_WAN_IPV4)" " ${wan_ipv4}${wan_ip_label}" "INFO"
    fi
    [ -n "$wan_ipv6" ] && add_line "$HC_NET" "$(T TXT_HEALTH_WAN_IPV6)" " ${wan_ipv6}" "INFO"

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
    printf " %-35s : %s\n" "$(T TXT_HEALTH_DNS_MODE)" "$dns_mode" >> "$HC_NET"
    printf " %-35s : %s\n" "$(T TXT_HEALTH_DNS_SEC)" "$dns_sec" >> "$HC_NET"
    printf " %-35s : %s\n" "$(T TXT_HEALTH_DNS_PROVIDERS)" "$dns_providers" >> "$HC_NET"

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
    # SHA256 DOSYA BUTUNLUGU (state dosyasindan, hizli)
    # ----------------------------
    local _sha_kzm _sha_zap _sha_kzm_status _sha_zap_status
    _sha_kzm="$(cat /opt/etc/zkm_sha256_kzm.state 2>/dev/null)"
    _sha_zap="$(cat /opt/etc/zkm_sha256_zapret.state 2>/dev/null)"

    case "$_sha_kzm" in
        ok)   _sha_kzm_status="PASS"; _sha_kzm_msg=" $(T TXT_HEALTH_SHA256_OK)" ;;
        fail) _sha_kzm_status="WARN"; _sha_kzm_msg=" $(T TXT_HEALTH_SHA256_FAIL)" ;;
        *)    _sha_kzm_status="INFO"; _sha_kzm_msg=" $(T TXT_HEALTH_SHA256_UNKNOWN)" ;;
    esac
    case "$_sha_zap" in
        ok)   _sha_zap_status="PASS"; _sha_zap_msg=" $(T TXT_HEALTH_SHA256_OK)" ;;
        fail) _sha_zap_status="WARN"; _sha_zap_msg=" $(T TXT_HEALTH_SHA256_FAIL)" ;;
        *)    _sha_zap_status="INFO"; _sha_zap_msg=" $(T TXT_HEALTH_SHA256_ZAP_UNKNOWN)" ;;
    esac

    add_line "$HC_SVC" "$(T TXT_HEALTH_SHA256_KZM)" "$_sha_kzm_msg" "$_sha_kzm_status"
    add_line "$HC_SVC" "$(T TXT_HEALTH_SHA256_ZAP)" "$_sha_zap_msg" "$_sha_zap_status"

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

    # Skora gore renk ve etiket sec
    local score_clr score_emoji
    if awk -v s="$score" 'BEGIN{exit (s>=9.5)?0:1}'; then
        score_clr="${CLR_GREEN}"; score_emoji="MUKEMMEL"
    elif awk -v s="$score" 'BEGIN{exit (s>=8.5)?0:1}'; then
        score_clr="${CLR_GREEN}"; score_emoji="COK IYI"
    elif awk -v s="$score" 'BEGIN{exit (s>=7.0)?0:1}'; then
        score_clr="${CLR_ORANGE}"; score_emoji="IYI"
    elif awk -v s="$score" 'BEGIN{exit (s>=5.0)?0:1}'; then
        score_clr="${CLR_YELLOW}"; score_emoji="ORTA"
    else
        score_clr="${CLR_RED}"; score_emoji="KOTU"
    fi

    printf "\n %-35s : %b%b%s / 10%b  [%b%s%b]   %b(%d/%d OK)%b\n" \
        "$(T TXT_HEALTH_SCORE)" \
        "${CLR_BOLD}" "$score_clr" "$score" "${CLR_RESET}" \
        "${CLR_BOLD}${score_clr}" "$score_emoji" "${CLR_RESET}" \
        "${CLR_BOLD}${score_clr}" "$ok_n" "$total_n" "${CLR_RESET}"
    print_line "-"
    printf " %b%s%b\n" "${CLR_CYAN}" "$(T TXT_HEALTH_SECTION_NETDNS)" "${CLR_RESET}"
    print_line "-"
    cat "$HC_NET"

    print_line "-"
    printf " %b%s%b\n" "${CLR_CYAN}" "$(T TXT_HEALTH_SECTION_SYSTEM)" "${CLR_RESET}"
    print_line "-"
    cat "$HC_SYS"

    print_line "-"
    printf " %b%s%b\n" "${CLR_CYAN}" "$(T TXT_HEALTH_SECTION_SERVICES)" "${CLR_RESET}"
    print_line "-"
    cat "$HC_SVC"

    print_line "-"
    press_enter_to_continue

    rm -f "$HC_NET" "$HC_SYS" "$HC_SVC" 2>/dev/null
    clear
}


# --- BLOCKCHECK (DPI TEST) ---
run_blockcheck() {
    # $1 - scan level: 1=quick, 2=standard (default), 3=force
    local BLOCKCHECK="/opt/zapret/blockcheck.sh"
    local DEF_DOMAIN="pastebin.com"
    local domains report today was_running stop_ans do_stop stopped_by_us
    local hm_was_autorestart hm_pause_ans dns_check_ip hm_pause_done
    local _scan_level="${1:-2}"
    hm_was_autorestart=0
    hm_pause_done=0

    print_line "-"
    echo "$(T blk_title 'Blockcheck (DPI Test Raporu)' 'Blockcheck (DPI Test Report)')"
    print_line "-"

    if [ ! -x "$BLOCKCHECK" ]; then
        echo "$(T blk_missing 'HATA: /opt/zapret/blockcheck.sh bulunamadi veya calistirilabilir degil.' 'ERROR: /opt/zapret/blockcheck.sh not found or not executable.')"
        press_enter_to_continue
        clear
        return 1
    fi

    # Domain(ler)
    printf '%s' "$(T blk_domain 'Test edilecek domain(ler) (Enter=pastebin.com, 0=Iptal): ' 'Domain(s) to test (Enter=pastebin.com, 0=Cancel): ')"; read -r domains
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
        printf '%s' "$(T blk_stopq 'Zapret gecici olarak durdurulsun mu? (e/h) [e]: ' 'Stop Zapret temporarily? (y/n) [y]: ')"; read -r stop_ans
        case "$stop_ans" in
            [hHnN]) do_stop=0 ;;
            *) do_stop=1 ;;
        esac
        if [ "$do_stop" -eq 1 ]; then
            stop_zapret >/dev/null 2>&1
            stopped_by_us=1
        fi
    fi

    # HealthMon autorestart kontrolu
    healthmon_load_config 2>/dev/null
    if [ "${HM_ZAPRET_AUTORESTART:-0}" = "1" ]; then
        hm_was_autorestart=1
        printf "%s" "$(T TXT_BLK_HM_AUTORESTART_WARN)"
        read -r hm_pause_ans </dev/tty 2>/dev/null || read -r hm_pause_ans
        case "$hm_pause_ans" in
            e|E|y|Y|"")
                HM_ZAPRET_AUTORESTART="0"
                healthmon_write_config 2>/dev/null
                hm_pause_done=1
                echo "$(T TXT_BLK_HM_AUTORESTART_PAUSED)"
                ;;
        esac
    fi

    echo
    echo "$(T blk_running2 "Calistiriliyor... (Rapor: ${report})" "Running... (Report: ${report})")"
    print_line "-"

    # blockcheck kendi icinde domain prompt'u aciyor; stdin'e domainleri basarak takilmasini engelliyoruz.
    # stdout+stderr rapora yazilsin diye tee kullan.
    # (tee yoksa sadece > ile yazar)
    export SECURE_DNS=0
    # BusyBox xargs bu router'da pipe icinde Illegal instruction verir.
    # Sahte xargs: argumansiz cagrilirsa stdin satirlarini tek satira birlestir.
    _xargs_wrap="/opt/etc/kzm_xargs_wrap.sh"
    {
        printf '%s\n' '#!/bin/sh'
        printf '%s\n' 'if [ $# -eq 0 ]; then'
        printf '%s\n' "    tr '\\n' ' ' | sed 's/^ *//;s/ *\$//'"
        printf '%s\n' 'else'
        printf '%s\n' '    _cmd="$1"; shift'
        printf '%s\n' '    while IFS= read -r _line; do "$_cmd" "$@" $_line; done'
        printf '%s\n' 'fi'
    } > "$_xargs_wrap"
    chmod +x "$_xargs_wrap"
    _kzm_path_dir="/tmp/kzm_path_$$"
    mkdir -p "$_kzm_path_dir"
    ln -sf "$_xargs_wrap" "$_kzm_path_dir/xargs"
    export PATH="$_kzm_path_dir:$PATH"
    if command -v tee >/dev/null 2>&1; then
        printf "%s\n\n\n\n\n\n%s\n" "$domains" "$_scan_level" | sh "$BLOCKCHECK" 2>&1 | tee "$report"
    else
        printf "%s\n\n\n\n\n\n%s\n" "$domains" "$_scan_level" | sh "$BLOCKCHECK" >"$report" 2>&1
        cat "$report" 2>/dev/null
    fi
    unset SECURE_DNS
    export PATH="$(printf '%s' "$PATH" | sed "s|$_kzm_path_dir:||")"
    rm -rf "$_kzm_path_dir"

    print_line "-"
    echo "$(T blk_done "Bitti. Rapor dosyasi: ${report}" "Done. Report file: ${report}")"

    # HealthMon autorestart eski haline getir
    if [ "$hm_pause_done" -eq 1 ]; then
        HM_ZAPRET_AUTORESTART="$hm_was_autorestart"
        healthmon_write_config 2>/dev/null
        echo "$(T TXT_BLK_HM_AUTORESTART_RESTORED)"
    fi

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

    press_enter_to_continue
    clear
    return 0
}


run_blockcheck_save_summary() {
    # Run the full interactive test exactly like "Tam Test", then save only * SUMMARY * to a separate file.
    run_blockcheck 1

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

    # GUI icin blockcheck sonucunu JSON olarak kaydet
    local _bcts
    _bcts="$(date +%s 2>/dev/null)"
    printf '{\n  "score": %s,\n  "dns_ok": %s,\n  "tls12_ok": %s,\n  "udp_weak": %s,\n  "ts": %s\n}\n' \
        "$score" "$dns_ok" "${tls12_ok:-0}" "${udp_weak:-1}" "$_bcts" \
        > /opt/zapret/blockcheck_result.json 2>/dev/null

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
        printf '%s' "$(T TXT_BLOCKCHECK_ACTION_PROMPT) "; read -r ans
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
                press_enter_to_continue
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
        printf '%s' "$(T TXT_CHOICE) "; read -r ch || return 0
        case "$ch" in
            1) run_blockcheck ;;
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
                    press_enter_to_continue
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
                press_enter_to_continue
                ;;
            2)
                # Restore: let user pick a file from current backups
                if [ ! -d "$CUR_DIR" ] || ! ls "$CUR_DIR"/*.txt >/dev/null 2>&1; then
                    echo "$(T TXT_BACKUP_NO_BACKUP)"
                    press_enter_to_continue
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
                press_enter_to_continue
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
        press_enter_to_continue
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
                press_enter_to_continue
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
        press_enter_to_continue
        return 0
    fi

    # create archive (busybox tar is usually available)
    tar -C / -czf "$ARCHIVE" $RELS 2>/dev/null
    if [ $? -ne 0 ] || [ ! -s "$ARCHIVE" ]; then
        rm -f "$ARCHIVE" 2>/dev/null
        print_status FAIL "$(T backup_tar_fail 'Yedekleme basarisiz.' 'Backup failed.')"
        press_enter_to_continue
        return 1
    fi

    print_status PASS "$(printf "$(T TXT_BACKUP_CFG_BACKED_UP)" "$ARCHIVE")"
    press_enter_to_continue
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
        press_enter_to_continue
        return 0
    fi
    clear
print_line "="
    echo "$(T TXT_BACKUP_MENU_TITLE)"
print_line "="
    echo
    ls -la "$DIR" 2>/dev/null | sed -n '1,200p'
    print_line "-"
    press_enter_to_continue
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
    TG_BOT_ENABLE="0"
    TG_BOT_POLL_SEC="5"
    TG_ROUTER_ID=""
    [ -f "$TG_CONF_FILE" ] && . "$TG_CONF_FILE" 2>/dev/null
    # Bos ise hostname'den al
    if [ -z "$TG_ROUTER_ID" ]; then
        TG_ROUTER_ID="$(hostname 2>/dev/null)"
        [ -z "$TG_ROUTER_ID" ] && TG_ROUTER_ID="$(cat /proc/sys/kernel/hostname 2>/dev/null)"
        [ -z "$TG_ROUTER_ID" ] && TG_ROUTER_ID="keenetic"
    fi
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
    [ -n "$TG_DEVICE_NAME" ] && [ -n "$TG_DEVICE_LAN_IP" ] && [ -n "$TG_DEVICE_MODEL" ] && {
        # Diger alanlar cache'lendi, sadece WAN IP'yi taze oku
        TG_DEVICE_WAN_IP=""
        local _wan_if_live=""
        _wan_if_live="$(ip -4 addr show ppp0 2>/dev/null | awk '/inet /{print "ppp0"; exit}')"
        [ -z "$_wan_if_live" ] && _wan_if_live="$(ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
        [ -n "$_wan_if_live" ] && TG_DEVICE_WAN_IP="$(ip -4 addr show "$_wan_if_live" 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)"
        [ -z "$TG_DEVICE_WAN_IP" ] && TG_DEVICE_WAN_IP="unknown"
        return 0
    }

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
    # $1 token, $2 chatid, $3 bot_enable (opt), $4 poll_sec (opt)
    local token="$1"
    local chatid="$2"
    local bot_enable="${3:-${TG_BOT_ENABLE:-0}}"
    local poll_sec="${4:-${TG_BOT_POLL_SEC:-5}}"
    # Router ID her zaman hostname'den alinir, config'e yazilmaz
    mkdir -p /opt/etc 2>/dev/null
    umask 077
    cat >"$TG_CONF_FILE" <<EOF
TG_BOT_TOKEN="$token"
TG_CHAT_ID="$chatid"
TG_BOT_ENABLE="$bot_enable"
TG_BOT_POLL_SEC="$poll_sec"
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
        echo " 4) $(T TXT_TGBOT_MENU_BOT_TITLE)"
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
            4) telegram_bot_menu ;;
            0) return 0 ;;
            *) echo "$(T TXT_INVALID_CHOICE)" ; sleep 1 ;;
        esac
    done
}

# -------------------------------------------------------------------
# TELEGRAM BOT (INTERACTIVE)
# -------------------------------------------------------------------
TG_BOT_PID_FILE="/tmp/zkm_telegram_bot.pid"
TG_BOT_LOG_FILE="/tmp/zkm_telegram_bot.log"
TG_BOT_AUTOSTART="/opt/etc/init.d/S98zkm_telegram"
_TGBOT_TMP="/tmp/zkm_tgbot_resp.json"

# Low-level: call Telegram Bot API, save response to tmp file
# $1=method, $2=JSON body
# returns 0 on success, response in $_TGBOT_TMP
_tgbot_api() {
    local method="$1"
    local body="$2"
    local CURL_BIN
    CURL_BIN="$(command -v curl 2>/dev/null)"
    [ -z "$CURL_BIN" ] && [ -x /opt/bin/curl ] && CURL_BIN="/opt/bin/curl"
    [ -z "$CURL_BIN" ] && return 1
    "$CURL_BIN" -sS --connect-timeout 8 --max-time 25 \
        -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/${method}" \
        -H "Content-Type: application/json" \
        -d "$body" > "$_TGBOT_TMP" 2>/dev/null
}

# Safe text: escape backslash and double-quote for JSON string
_tgbot_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/ /g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//'
}


# Send file as document
# $1=chat_id, $2=filepath, $3=caption (optional)
tgbot_send_document() {
    local chat_id="$1"
    local filepath="$2"
    local caption="${3:-}"
    local CURL_BIN
    CURL_BIN="$(command -v curl 2>/dev/null)"
    [ -z "$CURL_BIN" ] && [ -x /opt/bin/curl ] && CURL_BIN="/opt/bin/curl"
    [ -z "$CURL_BIN" ] && return 1
    [ ! -f "$filepath" ] && return 1
    if [ -n "$caption" ]; then
        "$CURL_BIN" -sS --connect-timeout 8 --max-time 60 \
            -F "chat_id=${chat_id}" \
            -F "document=@${filepath}" \
            -F "caption=${caption}" \
            "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendDocument" >/dev/null 2>&1
    else
        "$CURL_BIN" -sS --connect-timeout 8 --max-time 60 \
            -F "chat_id=${chat_id}" \
            -F "document=@${filepath}" \
            "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendDocument" >/dev/null 2>&1
    fi
}

# Send new message with optional inline keyboard
# $1=chat_id, $2=text, $3=keyboard_json (optional, empty string = no keyboard)
tgbot_send() {
    local chat_id="$1"
    local text="$2"
    local keyboard="$3"
    local safe
    safe="$(_tgbot_escape "$text")"
    local body
    if [ -n "$keyboard" ]; then
        body="{\"chat_id\":${chat_id},\"text\":\"${safe}\",\"reply_markup\":{\"inline_keyboard\":${keyboard}}}"
    else
        body="{\"chat_id\":${chat_id},\"text\":\"${safe}\"}"
    fi
    if _tgbot_api "sendMessage" "$body"; then
        grep -q '"ok":true' "$_TGBOT_TMP" 2>/dev/null || \
            printf '%s\n' "$(date '+%Y-%m-%d %H:%M:%S') | tgbot | send failed: $(head -c 120 "$_TGBOT_TMP" 2>/dev/null)" >> "$TG_BOT_LOG_FILE"
    fi
}

# Edit existing message
# $1=chat_id, $2=message_id, $3=text, $4=keyboard_json (optional)
tgbot_edit() {
    local chat_id="$1"
    local msg_id="$2"
    local text="$3"
    local keyboard="$4"
    local safe
    safe="$(_tgbot_escape "$text")"
    local body
    if [ -n "$keyboard" ]; then
        body="{\"chat_id\":${chat_id},\"message_id\":${msg_id},\"text\":\"${safe}\",\"reply_markup\":{\"inline_keyboard\":${keyboard}}}"
    else
        body="{\"chat_id\":${chat_id},\"message_id\":${msg_id},\"text\":\"${safe}\",\"reply_markup\":{\"inline_keyboard\":[]}}"
    fi
    _tgbot_api "editMessageText" "$body" >/dev/null 2>&1
}

# Answer callback query (dismiss spinner)
# $1=callback_query_id
tgbot_ack() {
    _tgbot_api "answerCallbackQuery" "{\"callback_query_id\":\"$1\"}" >/dev/null 2>&1
}

# Keyboards
tgbot_kb_main() {
    local rid="${TG_ROUTER_ID:-default}"
    printf '[[{"text":"📊 %s","callback_data":"%s:menu_status"},{"text":"⚙️ %s","callback_data":"%s:menu_sistem"}],[{"text":"🛠️ %s","callback_data":"%s:menu_kzm"},{"text":"🔧 %s","callback_data":"%s:menu_zapret"}],[{"text":"📋 %s","callback_data":"%s:menu_logs"}]]' \
        "$(T TXT_TGBOT_BTN_STATUS)" "$rid" \
        "$(T TXT_TGBOT_BTN_SYSTEM)" "$rid" \
        "$(T TXT_TGBOT_BTN_KZM)" "$rid" \
        "$(T TXT_TGBOT_BTN_ZAPRET)" "$rid" \
        "$(T TXT_TGBOT_BTN_LOGS)" "$rid"
}

tgbot_kb_zapret() {
    local rid="${TG_ROUTER_ID:-default}"
    printf '[[{"text":"▶️ %s","callback_data":"%s:zap_start"},{"text":"⏹ %s","callback_data":"%s:zap_stop"}],[{"text":"🔄 %s","callback_data":"%s:zap_restart"}],[{"text":"⬆️ %s","callback_data":"%s:zap_update"}],[{"text":"⬅️ %s","callback_data":"%s:menu_main"}]]'         "$(T TXT_TGBOT_BTN_START)" "$rid"         "$(T TXT_TGBOT_BTN_STOP)" "$rid"         "$(T TXT_TGBOT_BTN_RESTART)" "$rid"         "$(T TXT_TGBOT_BTN_ZAP_UPDATE)" "$rid"         "$(T TXT_TGBOT_BTN_BACK)" "$rid"
}

tgbot_kb_kzm() {
    local rid="${TG_ROUTER_ID:-default}"
    printf '[[{"text":"⬆️ %s","callback_data":"%s:sys_kzm_update"}],[{"text":"⬅️ %s","callback_data":"%s:menu_main"}]]'         "$(T TXT_TGBOT_BTN_KZM_UPDATE)" "$rid"         "$(T TXT_TGBOT_BTN_BACK)" "$rid"
}

tgbot_kb_reboot_confirm() {
    local rid="${TG_ROUTER_ID:-default}"
    printf '[[{"text":"✅ %s","callback_data":"%s:sys_reboot_do"},{"text":"❌ %s","callback_data":"%s:sys_device_detail"}]]'         "$(T TXT_TGBOT_BTN_REBOOT_CONFIRM)" "$rid"         "$(T TXT_TGBOT_BTN_CANCEL)" "$rid"
}

tgbot_kb_wan_reset_time() {
    local rid="${TG_ROUTER_ID:-default}"
    printf '[[{"text":"5 dk","callback_data":"%s:wan_rc_5"},{"text":"10 dk","callback_data":"%s:wan_rc_10"},{"text":"15 dk","callback_data":"%s:wan_rc_15"}],[{"text":"20 dk","callback_data":"%s:wan_rc_20"},{"text":"25 dk","callback_data":"%s:wan_rc_25"},{"text":"30 dk","callback_data":"%s:wan_rc_30"}],[{"text":"⬅️ %s","callback_data":"%s:menu_sistem"}]]' \
        "$rid" "$rid" "$rid" \
        "$rid" "$rid" "$rid" \
        "$(T TXT_TGBOT_BTN_BACK)" "$rid"
}

tgbot_kb_wan_reset_confirm() {
    local min="$1"
    local rid="${TG_ROUTER_ID:-default}"
    printf '[[{"text":"✅ %s","callback_data":"%s:wan_rd_%s"},{"text":"❌ %s","callback_data":"%s:sys_wan_reset"}]]' \
        "$(T TXT_TGBOT_BTN_CONFIRM)" "$rid" "$min" \
        "$(T TXT_TGBOT_BTN_CANCEL)" "$rid"
}

tgbot_kb_sistem() {
    local rid="${TG_ROUTER_ID:-default}"
    # Router buton etiketi: "🟢 SweetHome (KN-1812)" formatinda
    local _dev_label
    _dev_label="${TG_DEVICE_NAME:-Router}"
    [ -n "$TG_DEVICE_MODEL" ] && _dev_label="${_dev_label} (${TG_DEVICE_MODEL})"
    printf '[[{"text":"📡 %s","callback_data":"%s:sys_net_devices"},{"text":"📶 %s","callback_data":"%s:sys_wifi"}],[{"text":"🌐 %s","callback_data":"%s:sys_wan_reset"}],[{"text":"🟢 %s","callback_data":"%s:sys_device_detail"}],[{"text":"⬅️ %s","callback_data":"%s:menu_main"}]]' \
        "$(T TXT_TGBOT_BTN_NET_DEVICES)" "$rid" \
        "$(T TXT_TGBOT_BTN_WIFI)" "$rid" \
        "$(T TXT_TGBOT_BTN_WAN_RESET)" "$rid" \
        "$_dev_label" "$rid" \
        "$(T TXT_TGBOT_BTN_BACK)" "$rid"
}

# Cihaz detay klavyesi: Reboot / KZM Log + Sistem Log / Selftest / Geri
tgbot_kb_device() {
    local rid="${TG_ROUTER_ID:-default}"
    printf '[[{"text":"🔁 %s","callback_data":"%s:sys_reboot_confirm"}],[{"text":"📋 %s","callback_data":"%s:sys_kzmlog"},{"text":"📄 %s","callback_data":"%s:sys_syslog"}],[{"text":"🧪 %s","callback_data":"%s:sys_selftest"}],[{"text":"⬅️ %s","callback_data":"%s:menu_sistem"}]]'         "$(T TXT_TGBOT_BTN_REBOOT)" "$rid"         "$(T TXT_TGBOT_BTN_KZMLOG)" "$rid"         "$(T TXT_TGBOT_BTN_SYSLOG)" "$rid"         "$(T TXT_TGBOT_BTN_SELFTEST)" "$rid"         "$(T TXT_TGBOT_BTN_BACK)" "$rid"
}

# Log alt menu klavyesi
tgbot_kb_logs() {
    local rid="${TG_ROUTER_ID:-default}"
    printf '[[{"text":"📋 %s","callback_data":"%s:sys_kzmlog"},{"text":"📄 %s","callback_data":"%s:sys_syslog"}],[{"text":"⬅️ %s","callback_data":"%s:menu_main"}]]' \
        "$(T TXT_TGBOT_BTN_KZMLOG)" "$rid" \
        "$(T TXT_TGBOT_BTN_SYSLOG)" "$rid" \
        "$(T TXT_TGBOT_BTN_BACK)" "$rid"
}

# Ag cihazlari: ndmc show ip hotspot ile aktif hostlari inline keyboard olarak listele
# $1=offset (sayfalama, varsayilan 0)
tgbot_net_devices_kb() {
    local offset="${1:-0}"
    local rid="${TG_ROUTER_ID:-default}"
    local page_size=10
    local hotspot_raw all_names cnt kb next_offset prev_offset nav_row
    hotspot_raw="$(LD_LIBRARY_PATH= ndmc -c 'show ip hotspot' 2>/dev/null)"
    # awk ile aktif cihaz adlarini cikart
    # Format: host: > hostname: > name: (cihaz adi)
    # hostname: bir alt-bloktur; altindaki name: cihaz adini verir
    # awk: her aktif host icin "name|mac" formatinda satir uret
    all_names="$(printf '%s\n' "$hotspot_raw" | awk '
        BEGIN { in_host=0; in_hostname=0; devname=""; devmac=""; active="" }
        /^[[:space:]]*host:/ {
            if (in_host && active=="yes" && devname!="" && devmac!="") print devname "|" devmac
            in_host=1; in_hostname=0; devname=""; devmac=""; active=""; next
        }
        in_host && /^[[:space:]]*mac:/ && devmac=="" {
            s=$0; sub(/.*mac:[[:space:]]*/,"",s); gsub(/^[[:space:]]+|[[:space:]]+$/,"",s); devmac=s
        }
        in_host && /^[[:space:]]*hostname:/ { in_hostname=1; next }
        in_host && in_hostname && /^[[:space:]]*name:/ {
            s=$0; sub(/.*name:[[:space:]]*/,"",s); gsub(/^[[:space:]]+|[[:space:]]+$/,"",s)
            if(s!="" && s!="-") devname=s
            in_hostname=0
        }
        in_host && /^[[:space:]]*interface:/ { in_hostname=0 }
        in_host && /^[[:space:]]*active:/ {
            s=$0; sub(/.*active:[[:space:]]*/,"",s); gsub(/^[[:space:]]+|[[:space:]]+$/,"",s); active=s
        }
        END { if (in_host && active=="yes" && devname!="" && devmac!="") print devname "|" devmac }
    ')"
    cnt="$(printf '%s\n' "$all_names" | grep -c .)"
    if [ "$cnt" -eq 0 ]; then
        printf '[[{"text":"⬅️ %s","callback_data":"%s:menu_sistem"}]]' "$(T TXT_TGBOT_BTN_BACK)" "$rid"
        return
    fi
    # Sayfa butonlarini olustur
    kb="["
    local row=0
    while IFS="|" read -r name mac; do
        [ -z "$name" ] || [ -z "$mac" ] && continue
        row=$((row+1))
        [ "$row" -le "$offset" ] && continue
        [ "$row" -gt "$((offset+page_size))" ] && continue
        # MAC icindeki : isaretini - ile degistir (callback_data uyumlulugu)
        local safe_name mac_enc
        safe_name="$(printf '%s' "$name" | sed 's/"/\\"/g')"
        mac_enc="$(printf '%s' "$mac" | tr ':' '-')"
        kb="${kb}[{\"text\":\"🟢 ${safe_name}\",\"callback_data\":\"${rid}:sys_client_${mac_enc}\"}],"
    done << NEOF
$(printf '%s\n' "$all_names")
NEOF
    kb="${kb%,}"
    # Sayfalama satiri
    nav_row=""
    next_offset=$((offset+page_size))
    prev_offset=$((offset-page_size))
    [ "$prev_offset" -lt 0 ] && prev_offset=0
    if [ "$offset" -gt 0 ] && [ "$cnt" -gt "$next_offset" ]; then
        nav_row="{\"text\":\"◀️\",\"callback_data\":\"${rid}:sys_clients_${prev_offset}\"},{\"text\":\"▶️\",\"callback_data\":\"${rid}:sys_clients_${next_offset}\"}"
    elif [ "$offset" -gt 0 ]; then
        nav_row="{\"text\":\"◀️\",\"callback_data\":\"${rid}:sys_clients_${prev_offset}\"}"
    elif [ "$cnt" -gt "$next_offset" ]; then
        nav_row="{\"text\":\"▶️\",\"callback_data\":\"${rid}:sys_clients_${next_offset}\"}"
    fi
    [ -n "$nav_row" ] && kb="${kb},[${nav_row}]"
    kb="${kb},[{\"text\":\"⬅️ $(T TXT_TGBOT_BTN_BACK)\",\"callback_data\":\"${rid}:menu_sistem\"}]]"
    printf '%s' "$kb"
}

# Wifi segmentlerini inline keyboard JSON olarak olustur
# Her AP icin bireysel show interface sorgusu - link durumu kesin dogru
tgbot_wifi_kb() {
    local rid="${TG_ROUTER_ID:-default}"
    local back_btn
    back_btn="$(T TXT_TGBOT_BTN_BACK)"

    local rc_raw _tmprc _apfile
    rc_raw="$(LD_LIBRARY_PATH= ndmc -c 'show running-config' 2>/dev/null)"
    _tmprc="/tmp/_zkm_rc_$$.txt"
    _apfile="/tmp/_zkm_aps_$$.txt"
    printf '%s\n' "$rc_raw" > "$_tmprc"
    : > "$_apfile"

    local _cur_id _cur_name _cur_ssid _in_ap
    _cur_id=""; _cur_name=""; _cur_ssid=""; _in_ap=0
    while IFS= read -r _rc_line; do
        case "$_rc_line" in
            interface\ WifiMaster*)
                _cur_id="${_rc_line#interface }"
                _cur_name=""; _cur_ssid=""; _in_ap=1
                ;;
            "!"*)
                if [ "$_in_ap" = "1" ] && [ -n "$_cur_name" ]; then
                    printf '%s|%s|%s\n' "$_cur_id" "$_cur_name" "$_cur_ssid" >> "$_apfile"
                fi
                _cur_id=""; _cur_name=""; _cur_ssid=""; _in_ap=0
                ;;
            *)
                if [ "$_in_ap" = "1" ]; then
                    case "$_rc_line" in
                        *"rename "*)
                            _cur_name="${_rc_line#*rename }"
                            _cur_name="${_cur_name#\"}"
                            _cur_name="${_cur_name%\"}"
                            ;;
                        *"ssid "*)
                            _cur_ssid="${_rc_line#*ssid }"
                            _cur_ssid="${_cur_ssid#\"}"
                            _cur_ssid="${_cur_ssid%\"}"
                            ;;
                    esac
                fi
                ;;
        esac
    done < "$_tmprc"
    if [ "$_in_ap" = "1" ] && [ -n "$_cur_name" ]; then
        printf '%s|%s|%s\n' "$_cur_id" "$_cur_name" "$_cur_ssid" >> "$_apfile"
    fi
    rm -f "$_tmprc" 2>/dev/null

    local out="" cnt=0
    while IFS="|" read -r _apid _apname _apssid; do
        [ -z "$_apid" ] || [ -z "$_apname" ] && continue
        local _iface_out _aplink
        _iface_out="$(LD_LIBRARY_PATH= ndmc -c "show interface ${_apname}" 2>/dev/null)"
        _aplink="$(printf '%s\n' "$_iface_out" | grep '^[[:space:]]*link:' | head -1 \
            | sed 's/.*link:[[:space:]]*//' | tr -d ' ')"
        if [ -z "$_apssid" ]; then
            _apssid="$(printf '%s\n' "$_iface_out" \
                | grep '^[[:space:]]*ssid:' | head -1 \
                | sed 's/.*ssid:[[:space:]]*//' | tr -d '"')"
        fi
        [ -z "$_apssid" ] && _apssid="$_apname"
        local _band
        case "$_apid" in
            *WifiMaster1/*) _band="5GHz" ;;
            *) _band="2.4GHz" ;;
        esac
        local _dot _tog _safename _lbl
        _safename="$(printf '%s' "$_apname" | sed 's/[^a-zA-Z0-9_]/_/g')"
        if [ "$_aplink" = "up" ]; then
            _dot="🟢"; _tog="wifi_off_${_safename}"
        else
            _dot="⚪"; _tog="wifi_on_${_safename}"
        fi
        _lbl="$(printf '%s (%s)' "$_apssid" "$_band" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        [ -n "$out" ] && out="${out},"
        out="${out}[{\"text\":\"${_dot} ${_lbl}\",\"callback_data\":\"${rid}:${_tog}\"}]"
        cnt=$((cnt+1))
    done < "$_apfile"
    rm -f "$_apfile" 2>/dev/null

    if [ "$cnt" -eq 0 ]; then
        printf '[[{"text":"(bos)","callback_data":"%s:noop"}],[{"text":"⬅️ %s","callback_data":"%s:menu_sistem"}]]' \
            "$rid" "$back_btn" "$rid"
    else
        printf '[%s,[{"text":"⬅️ %s","callback_data":"%s:menu_sistem"}]]' \
            "$out" "$back_btn" "$rid"
    fi
}
# Bayt degerini okunabilir formata cevir (GB/MB/KB)
_tgbot_fmt_bytes() {
    local bytes="$1"
    [ -z "$bytes" ] && { echo "-"; return; }
    # awk ile hesapla
    echo "$bytes" | awk '{
        b = $1 + 0
        if (b >= 1099511627776) printf "%.2f TB", b/1099511627776
        else if (b >= 1073741824) printf "%.2f GB", b/1073741824
        else if (b >= 1048576) printf "%.2f MB", b/1048576
        else if (b >= 1024) printf "%.2f KB", b/1024
        else printf "%d B", b
    }'
}

# WAN arayuzunden rx/tx bytes oku (/proc/net/dev)
_tgbot_wan_traffic() {
    local wan_if="$1"
    [ -z "$wan_if" ] && { echo "- / -"; return; }
    local rx tx
    rx="$(awk -v iface="${wan_if}:" '$1==iface{print $2}' /proc/net/dev 2>/dev/null)"
    tx="$(awk -v iface="${wan_if}:" '$1==iface{print $10}' /proc/net/dev 2>/dev/null)"
    [ -z "$rx" ] && rx=0
    [ -z "$tx" ] && tx=0
    printf '⬇️%s ⬆️%s' "$(_tgbot_fmt_bytes "$rx")" "$(_tgbot_fmt_bytes "$tx")"
}

# Belirli bir MAC adresine ait hotspot host bilgisini parse eder
# Cikti: satirlar halinde key=value
_tgbot_parse_client() {
    local target_mac="$1"
    local hotspot_raw
    hotspot_raw="$(LD_LIBRARY_PATH= ndmc -c 'show ip hotspot' 2>/dev/null)"
    printf '%s\n' "$hotspot_raw" | awk -v tmac="$target_mac" '
        BEGIN { in_host=0; in_hostname=0; found=0
            mac=""; name=""; ip=""; active=""; access=""; rxbytes=""; txbytes="" }
        /^[[:space:]]*host:/ {
            if (found) { exit }
            in_host=1; in_hostname=0
            mac=""; name=""; ip=""; active=""; access=""; rxbytes=""; txbytes=""
            next
        }
        in_host && /^[[:space:]]*mac:/ && mac=="" {
            s=$0; sub(/.*mac:[[:space:]]*/,"",s); gsub(/^[[:space:]]+|[[:space:]]+$/,"",s)
            mac=s
            if (mac==tmac) found=1
        }
        in_host && found && /^[[:space:]]*ip:/ && ip=="" {
            s=$0; sub(/.*ip:[[:space:]]*/,"",s); gsub(/^[[:space:]]+|[[:space:]]+$/,"",s); ip=s
        }
        in_host && found && /^[[:space:]]*hostname:/ { in_hostname=1; next }
        in_host && found && in_hostname && /^[[:space:]]*name:/ {
            s=$0; sub(/.*name:[[:space:]]*/,"",s); gsub(/^[[:space:]]+|[[:space:]]+$/,"",s)
            if(s!="" && s!="-") name=s
            in_hostname=0
        }
        in_host && /^[[:space:]]*interface:/ { in_hostname=0 }
        in_host && found && /^[[:space:]]*active:/ {
            s=$0; sub(/.*active:[[:space:]]*/,"",s); gsub(/^[[:space:]]+|[[:space:]]+$/,"",s); active=s
        }
        in_host && found && /^[[:space:]]*access:/ {
            s=$0; sub(/.*access:[[:space:]]*/,"",s); gsub(/^[[:space:]]+|[[:space:]]+$/,"",s); access=s
        }
        in_host && found && /^[[:space:]]*rxbytes:/ {
            s=$0; sub(/.*rxbytes:[[:space:]]*/,"",s); gsub(/^[[:space:]]+|[[:space:]]+$/,"",s); rxbytes=s
        }
        in_host && found && /^[[:space:]]*txbytes:/ {
            s=$0; sub(/.*txbytes:[[:space:]]*/,"",s); gsub(/^[[:space:]]+|[[:space:]]+$/,"",s); txbytes=s
        }
        END {
            if (found) {
                print "mac=" mac
                print "name=" name
                print "ip=" ip
                print "active=" active
                print "access=" access
                print "rxbytes=" rxbytes
                print "txbytes=" txbytes
            }
        }
    '
}

# Istemci detay mesaj metni
tgbot_client_detail_text() {
    local mac="$1"
    local info name ip active access rxbytes txbytes
    info="$(_tgbot_parse_client "$mac")"
    [ -z "$info" ] && { printf '%s' "$(T _ 'Cihaz bulunamadi.' 'Device not found.')"; return; }
    name="$(printf '%s\n' "$info" | grep '^name=' | cut -d= -f2-)"
    ip="$(printf '%s\n' "$info" | grep '^ip=' | cut -d= -f2-)"
    active="$(printf '%s\n' "$info" | grep '^active=' | cut -d= -f2-)"
    access="$(printf '%s\n' "$info" | grep '^access=' | cut -d= -f2-)"
    rxbytes="$(printf '%s\n' "$info" | grep '^rxbytes=' | cut -d= -f2-)"
    txbytes="$(printf '%s\n' "$info" | grep '^txbytes=' | cut -d= -f2-)"
    [ -z "$name" ] && name="$mac"
    [ -z "$ip" ] && ip="-"
    local status_str access_str
    if [ "$active" = "yes" ]; then
        status_str="🟢 $(T TXT_TGBOT_CLIENT_STATUS_ACTIVE)"
    else
        status_str="⚪ $(T TXT_TGBOT_CLIENT_STATUS_INACTIVE)"
    fi
    if [ "$access" = "deny" ]; then
        access_str="🚫 $(T TXT_TGBOT_CLIENT_ACCESS_BLOCKED)"
    else
        access_str="✅ $(T TXT_TGBOT_CLIENT_ACCESS_OK)"
    fi
    printf '%s\nMAC  : %s\nIP   : %s\n%s    : %s\n%s   : %s\n%s: %s\n%s: %s' \
        "📱 ${name}" \
        "$mac" \
        "$ip" \
        "$(T TXT_TGBOT_CLIENT_ACCESS_LABEL)" "$access_str" \
        "$(T _ 'Durum' 'Status')" "$status_str" \
        "$(T _ 'Indir' 'Down')" "$(_tgbot_fmt_bytes "$rxbytes")" \
        "$(T _ 'Yukle' 'Up')" "$(_tgbot_fmt_bytes "$txbytes")"
}

# Istemci detay klavyesi
tgbot_kb_client() {
    local mac="$1"
    local access="$2"
    local mac_enc rid
    mac_enc="$(printf '%s' "$mac" | tr ':' '-')"
    rid="${TG_ROUTER_ID:-default}"
    local access_btn access_cb
    if [ "$access" = "deny" ]; then
        access_btn="✅ $(T TXT_TGBOT_CLIENT_ACCESS_PERMIT)"
        access_cb="${rid}:client_permit_${mac_enc}"
    else
        access_btn="🚫 $(T TXT_TGBOT_CLIENT_ACCESS_DENY)"
        access_cb="${rid}:client_deny_${mac_enc}"
    fi
    printf '[[{"text":"%s","callback_data":"%s"}],[{"text":"✏️ %s","callback_data":"%s:client_rename_%s"}],[{"text":"⬅️ %s","callback_data":"%s:sys_net_devices"}]]' \
        "$access_btn" "$access_cb" \
        "$(T TXT_TGBOT_CLIENT_RENAME)" "$rid" "$mac_enc" \
        "$(T TXT_TGBOT_BTN_BACK)" "$rid"
}

# Cihaz detay metni (resim 2 gibi)
tgbot_device_detail_text() {
    telegram_device_info_init >/dev/null 2>&1
    local name model fw cpu_val mem_val
    name="${TG_DEVICE_NAME:-Keenetic}"
    model="${TG_DEVICE_MODEL:-}"
    fw="$(zkm_banner_get_firmware 2>/dev/null)"
    [ -z "$fw" ] && fw="-"
    # CPU (busybox top)
    cpu_val="$(top -bn1 2>/dev/null | awk '/CPU:/{gsub(/%/,""); print int($2+$4); exit}')"
    [ -z "$cpu_val" ] && cpu_val="-"
    # MEM
    mem_val="$(free 2>/dev/null | awk '/Mem:/{printf "%d%%", ($3/$2)*100}')"
    [ -z "$mem_val" ] && mem_val="-"
    # KeenDNS
    local kdns_str kdns_raw kdns_name kdns_domain
    kdns_raw="$(LD_LIBRARY_PATH= ndmc -c 'show ndns' 2>/dev/null)"
    kdns_name="$(printf '%s' "$kdns_raw" | awk '/name:/{print $2; exit}')"
    kdns_domain="$(printf '%s' "$kdns_raw" | awk '/domain:/{print $2; exit}')"
    if [ -n "$kdns_name" ] && [ -n "$kdns_domain" ]; then
        kdns_str="${kdns_name}.${kdns_domain}"
    else
        kdns_str="-"
    fi
    # WAN trafik (boot'tan bu yana)
    local wan_if traffic_str
    wan_if="$(cat /opt/zapret/wan_if 2>/dev/null)"
    traffic_str="$(_tgbot_wan_traffic "$wan_if")"
    # Cikti
    local out
    out="Name:  ${name}"
    [ -n "$model" ] && out="${out} (${model})"
    out="${out}
KeenDNS: ${kdns_str}
Release: ${fw}
CPU: ${cpu_val}%  MEM: ${mem_val}

$(T TXT_TGBOT_DEVICE_TRAFFIC_LABEL)
→ $traffic_str"
    printf '%s' "$out"
}



# System status text
tgbot_status_text() {
    local zapret_st profile_name wan_if wan_ip lan_ip cpu_val ram_val disk_val uptime_val hm_st
    if is_zapret_running 2>/dev/null; then
        zapret_st="$(T TXT_TGBOT_STATUS_RUNNING)"
    else
        zapret_st="$(T TXT_TGBOT_STATUS_STOPPED)"
    fi
    local _cur_profile
    _cur_profile="$(get_dpi_profile 2>/dev/null)"
    if [ -n "$_cur_profile" ]; then
        profile_name="$(T dpi_pname "$(dpi_profile_name_tr "$_cur_profile" 2>/dev/null)" "$(dpi_profile_name_en "$_cur_profile" 2>/dev/null)")"
    fi
    [ -z "$profile_name" ] && profile_name="$(T TXT_TGBOT_STATUS_UNKNOWN)"
    wan_if="$(cat /opt/zapret/wan_if 2>/dev/null)"
    if [ -n "$wan_if" ]; then
        wan_ip="$(ip -4 addr show "$wan_if" 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d'/' -f1)"
    fi
    [ -z "$wan_ip" ] && wan_ip="$(T TXT_TGBOT_STATUS_UNKNOWN)"
    lan_ip=""
    for _lan_if in br0 bridge0 home0; do
        lan_ip="$(ip -4 addr show "$_lan_if" 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d'/' -f1)"
        [ -n "$lan_ip" ] && break
    done
    [ -z "$lan_ip" ] && lan_ip="$(T TXT_TGBOT_STATUS_UNKNOWN)"
    cpu_val="$(top -bn1 2>/dev/null | awk '/CPU:/{gsub(/%/,""); print int($2+$4); exit}')"
    [ -z "$cpu_val" ] && cpu_val="-"
    ram_val="$(free 2>/dev/null | awk '/Mem:/{printf "%d/%d MB", ($3/1024), ($2/1024)}')"
    [ -z "$ram_val" ] && ram_val="-"
    disk_val="$(df /opt 2>/dev/null | awk 'NR==2{print $5}')"
    [ -z "$disk_val" ] && disk_val="-"
    uptime_val="$(uptime 2>/dev/null | sed 's/.*up //' | cut -d',' -f1)"
    [ -z "$uptime_val" ] && uptime_val="-"
    if [ -f /tmp/healthmon.pid ] && kill -0 "$(cat /tmp/healthmon.pid 2>/dev/null)" 2>/dev/null; then
        hm_st="$(T TXT_TGBOT_STATUS_RUNNING)"
    else
        hm_st="$(T TXT_TGBOT_STATUS_STOPPED)"
    fi
    local kzm_ver zapret_ver
    kzm_ver="$(zkm_get_installed_script_version 2>/dev/null)"
    [ -z "$kzm_ver" ] && kzm_ver="$SCRIPT_VERSION"
    zapret_ver="$(cat /opt/zapret/version 2>/dev/null)"
    [ -z "$zapret_ver" ] && zapret_ver="$(T TXT_TGBOT_STATUS_UNKNOWN)"
    printf "Zapret: %s | %s\nWAN IP: %s\nLAN IP: %s\nCPU: %s%% | RAM: %s\nDisk: %s | Uptime: %s\nHealthMon: %s\nKZM: %s | Zapret: %s" \
        "$zapret_st" "$profile_name" "$wan_ip" "$lan_ip" \
        "$cpu_val" "$ram_val" "$disk_val" "$uptime_val" "$hm_st" \
        "$kzm_ver" "$zapret_ver"
}

# Handle callback query action
# $1=callback_data, $2=chat_id, $3=message_id, $4=callback_id
tgbot_handle_callback() {
    local cb_data="$1"
    local chat_id="$2"
    local msg_id="$3"
    local cb_id="$4"

    # Router ID prefix kontrolu: "rid:action" formatinda
    local cb_rid cb_action
    cb_rid="$(printf '%s' "$cb_data" | cut -d':' -f1)"
    cb_action="$(printf '%s' "$cb_data" | cut -d':' -f2-)"
    # Eski format (prefix yok) veya kendi ID'si degil ise yok say
    if [ -z "$cb_action" ]; then
        # prefix yok - eski format, direkt isle (geriye donuk uyumluluk)
        cb_action="$cb_rid"
    elif [ "$cb_rid" != "${TG_ROUTER_ID:-default}" ]; then
        # Baska routerin callback'i - yoksay
        tgbot_ack "$cb_id"
        return 0
    fi

    tgbot_ack "$cb_id"

    case "$cb_action" in
        menu_main)
            tgbot_edit "$chat_id" "$msg_id" \
                "${TG_ROUTER_ID} | $(T TXT_TGBOT_MENU_TITLE)" "$(tgbot_kb_main)"
            ;;
        menu_status)
            tgbot_edit "$chat_id" "$msg_id" \
                "$(tgbot_status_text)" "$(tgbot_kb_main)"
            ;;
        menu_zapret)
            tgbot_edit "$chat_id" "$msg_id" \
                "$(T TXT_TGBOT_MENU_ZAPRET_TITLE)" "$(tgbot_kb_zapret)"
            ;;
        menu_kzm)
            tgbot_edit "$chat_id" "$msg_id" \
                "${TG_ROUTER_ID} | $(T TXT_TGBOT_MENU_KZM_TITLE)" "$(tgbot_kb_kzm)"
            ;;
        menu_sistem)
            telegram_device_info_init >/dev/null 2>&1
            _dev_header="$(printf '%s: %s\n%s: %s' \
                "$(T TXT_TGBOT_SISTEM_HEADER_ISIM)" "${TG_DEVICE_NAME:-Keenetic}" \
                "$(T TXT_TGBOT_SISTEM_HEADER_MODEL)" "${TG_DEVICE_MODEL:--}")"
            tgbot_edit "$chat_id" "$msg_id" \
                "$_dev_header" "$(tgbot_kb_sistem)"
            ;;
        sys_kzmlog)
            local _log_file="/tmp/healthmon.log"
            local _log_tmp="/tmp/tgbot_kzmlog_$$.txt"
            if [ -f "$_log_file" ] && [ -s "$_log_file" ]; then
                cp "$_log_file" "$_log_tmp" 2>/dev/null
                tgbot_send_document "$chat_id" "$_log_tmp" \
                    "📋 KZM HealthMon Log | ${TG_ROUTER_ID:-router}"
                rm -f "$_log_tmp" 2>/dev/null
            else
                tgbot_send "$chat_id" "$(T TXT_TGBOT_NO_LOGS)" ""
            fi
            # Dosyadan sonra log menusunu ALTA taze gonder
            tgbot_send "$chat_id" \
                "$(T TXT_TGBOT_LOG_MENU_TITLE)" "$(tgbot_kb_logs)"
            ;;
        sys_syslog)
            local _syslog_tmp="/tmp/tgbot_syslog_$$.txt"
            LD_LIBRARY_PATH= ndmc -c 'show log' 2>/dev/null > "$_syslog_tmp"
            if [ -s "$_syslog_tmp" ]; then
                tgbot_send_document "$chat_id" "$_syslog_tmp" \
                    "📄 System Log | ${TG_ROUTER_ID:-router}"
            else
                tgbot_send "$chat_id" "$(T TXT_TGBOT_NO_LOGS)" ""
            fi
            rm -f "$_syslog_tmp" 2>/dev/null
            # Dosyadan sonra log menusunu ALTA taze gonder
            tgbot_send "$chat_id" \
                "$(T TXT_TGBOT_LOG_MENU_TITLE)" "$(tgbot_kb_logs)"
            ;;
        menu_logs)
            tgbot_edit "$chat_id" "$msg_id" \
                "$(T TXT_TGBOT_LOG_MENU_TITLE)" "$(tgbot_kb_logs)"
            ;;
        zap_start)
            start_zapret >/dev/null 2>&1
            tgbot_edit "$chat_id" "$msg_id" \
                "$(T TXT_TGBOT_ZAPRET_STARTED)" "$(tgbot_kb_zapret)"
            ;;
        zap_stop)
            stop_zapret >/dev/null 2>&1
            tgbot_edit "$chat_id" "$msg_id" \
                "$(T TXT_TGBOT_ZAPRET_STOPPED)" "$(tgbot_kb_zapret)"
            ;;
        zap_restart)
            restart_zapret >/dev/null 2>&1
            tgbot_edit "$chat_id" "$msg_id" \
                "$(T TXT_TGBOT_ZAPRET_RESTARTED)" "$(tgbot_kb_zapret)"
            ;;
        zap_update)
            tgbot_edit "$chat_id" "$msg_id" "$(T TXT_TGBOT_UPDATE_STARTED)" ""
            if update_zapret >/dev/null 2>&1; then
                tgbot_edit "$chat_id" "$msg_id" \
                    "$(T TXT_TGBOT_UPDATE_DONE)" "$(tgbot_kb_zapret)"
            else
                tgbot_edit "$chat_id" "$msg_id" \
                    "$(T TXT_TGBOT_UPDATE_FAIL)" "$(tgbot_kb_zapret)"
            fi
            ;;
        sys_kzm_update)
            tgbot_edit "$chat_id" "$msg_id" "$(T TXT_TGBOT_UPDATE_STARTED)" ""
            update_manager_script >/dev/null 2>&1
            _upd_rc=$?
            case "$_upd_rc" in
                0) tgbot_edit "$chat_id" "$msg_id" \
                    "$(T TXT_TGBOT_UPDATE_DONE)" "$(tgbot_kb_kzm)" ;;
                2) tgbot_edit "$chat_id" "$msg_id" \
                    "$(T TXT_TGBOT_ALREADY_UPTODATE)" "$(tgbot_kb_kzm)" ;;
                *) tgbot_edit "$chat_id" "$msg_id" \
                    "$(T TXT_TGBOT_UPDATE_FAIL)" "$(tgbot_kb_kzm)" ;;
            esac
            ;;
        sys_net_devices)
            local _nd_total
            _nd_total="$(LD_LIBRARY_PATH= ndmc -c 'show ip hotspot' 2>/dev/null | grep -c 'active: yes')"
            [ -z "$_nd_total" ] && _nd_total=0
            tgbot_edit "$chat_id" "$msg_id" \
                "$(T TXT_TGBOT_NET_DEVICES_TITLE) (${_nd_total})" "$(tgbot_net_devices_kb 0)"
            ;;
        sys_clients_*)
            local _pg_offset
            _pg_offset="$(printf '%s' "$cb_action" | sed 's/sys_clients_//')"
            _pg_offset="${_pg_offset:-0}"
            local _nd_total2
            _nd_total2="$(LD_LIBRARY_PATH= ndmc -c 'show ip hotspot' 2>/dev/null | grep -c 'active: yes')"
            [ -z "$_nd_total2" ] && _nd_total2=0
            tgbot_edit "$chat_id" "$msg_id" \
                "$(T TXT_TGBOT_NET_DEVICES_TITLE) (${_nd_total2})" "$(tgbot_net_devices_kb "$_pg_offset")"
            ;;
        sys_wifi)
            local _wifi_kb _wifi_title _ts
            _wifi_kb="$(tgbot_wifi_kb)"
            # Segment sayisi: noop olmayan wifi buton satirlari
            local _wifi_cnt
            _wifi_cnt="$(printf '%s' "$_wifi_kb" | grep -o '"callback_data":"[^"]*:wifi_' | grep -c .)"
            # Title: her zaman farkli olmali (timestamp) - "message is not modified" hatasini onler
            _ts="$(date +%H:%M 2>/dev/null)"
            _wifi_title="$(T TXT_TGBOT_WIFI_TITLE) (${_wifi_cnt}) ${_ts}"
            tgbot_edit "$chat_id" "$msg_id" "$_wifi_title" "$_wifi_kb"
            ;;
        noop)
            # ack zaten yukarda gonderildi, ek islem yok
            ;;
        wifi_on_*|wifi_off_*)
            local _wf_safe _wf_id _wf_cmd
            if printf '%s' "$cb_action" | grep -q '^wifi_on_'; then
                _wf_safe="${cb_action#wifi_on_}"
                _wf_cmd="up"
            else
                _wf_safe="${cb_action#wifi_off_}"
                _wf_cmd="down"
            fi
            # Gercek ndmc ID bul (WifiMaster0/AccessPoint1 gibi - rename edilmis olabilir)
            _wf_id="$(LD_LIBRARY_PATH= ndmc -c "show interface ${_wf_safe}" 2>/dev/null \
                | grep "^[[:space:]]*id:" | sed "s/.*id:[[:space:]]*//" | tr -d " ")"
            [ -z "$_wf_id" ] && _wf_id="$_wf_safe"
            LD_LIBRARY_PATH= ndmc -c "interface ${_wf_id} ${_wf_cmd}" >/dev/null 2>&1
            LD_LIBRARY_PATH= ndmc -c "system configuration save" >/dev/null 2>&1
            sleep 2
            local _wf_kb _wf_cnt _wf_ts
            _wf_kb="$(tgbot_wifi_kb)"
            _wf_cnt="$(printf '%s' "$_wf_kb" | grep -o '"callback_data":"[^"]*:wifi_' | grep -c .)"
            _wf_ts="$(date +%H:%M 2>/dev/null)"
            tgbot_send "$chat_id" \
                "$(T TXT_TGBOT_WIFI_TITLE) (${_wf_cnt}) ${_wf_ts}" "$_wf_kb"
            ;;
        sys_device_detail)
            tgbot_edit "$chat_id" "$msg_id" \
                "$(tgbot_device_detail_text)" "$(tgbot_kb_device)"
            ;;
        sys_client_*)
            local _cl_mac_enc _cl_mac _cl_info _cl_access
            _cl_mac_enc="${cb_action#sys_client_}"
            _cl_mac="$(printf '%s' "$_cl_mac_enc" | tr '-' ':')"
            _cl_info="$(_tgbot_parse_client "$_cl_mac")"
            _cl_access="$(printf '%s\n' "$_cl_info" | grep '^access=' | cut -d= -f2-)"
            [ -z "$_cl_access" ] && _cl_access="permit"
            tgbot_edit "$chat_id" "$msg_id" \
                "$(tgbot_client_detail_text "$_cl_mac")" \
                "$(tgbot_kb_client "$_cl_mac" "$_cl_access")"
            ;;
        client_deny_*)
            local _cd_mac_enc _cd_mac
            _cd_mac_enc="${cb_action#client_deny_}"
            _cd_mac="$(printf '%s' "$_cd_mac_enc" | tr '-' ':')"
            LD_LIBRARY_PATH= ndmc -c "ip hotspot host ${_cd_mac} deny" >/dev/null 2>&1
            LD_LIBRARY_PATH= ndmc -c "system configuration save" >/dev/null 2>&1
            local _cd_info _cd_access
            _cd_info="$(_tgbot_parse_client "$_cd_mac")"
            _cd_access="$(printf '%s\n' "$_cd_info" | grep '^access=' | cut -d= -f2-)"
            [ -z "$_cd_access" ] && _cd_access="deny"
            tgbot_edit "$chat_id" "$msg_id" \
                "$(tgbot_client_detail_text "$_cd_mac")" \
                "$(tgbot_kb_client "$_cd_mac" "$_cd_access")"
            ;;
        client_permit_*)
            local _cp_mac_enc _cp_mac
            _cp_mac_enc="${cb_action#client_permit_}"
            _cp_mac="$(printf '%s' "$_cp_mac_enc" | tr '-' ':')"
            LD_LIBRARY_PATH= ndmc -c "ip hotspot host ${_cp_mac} permit" >/dev/null 2>&1
            LD_LIBRARY_PATH= ndmc -c "system configuration save" >/dev/null 2>&1
            local _cpr_info _cpr_access
            _cpr_info="$(_tgbot_parse_client "$_cp_mac")"
            _cpr_access="$(printf '%s\n' "$_cpr_info" | grep '^access=' | cut -d= -f2-)"
            [ -z "$_cpr_access" ] && _cpr_access="permit"
            tgbot_edit "$chat_id" "$msg_id" \
                "$(tgbot_client_detail_text "$_cp_mac")" \
                "$(tgbot_kb_client "$_cp_mac" "$_cpr_access")"
            ;;
        client_rename_*)
            local _cr_mac_enc _cr_mac
            _cr_mac_enc="${cb_action#client_rename_}"
            _cr_mac="$(printf '%s' "$_cr_mac_enc" | tr '-' ':')"
            # Pending state kaydet
            printf '%s\n' "rename:${_cr_mac}" > "/tmp/tgbot_pending_${chat_id}"
            tgbot_send "$chat_id" "$(T TXT_TGBOT_CLIENT_RENAME_PROMPT)" ""
            ;;
        sys_selftest)
            # Selftest ciktiyi dosya olarak gonder - tam sonucu goruntule
            local _st_tmp="/tmp/tgbot_selftest_$$.txt"
            sh "$ZKM_SCRIPT_PATH" --self-test > "$_st_tmp" 2>&1
            local _st_fail
            _st_fail="$(grep -c 'FAIL' "$_st_tmp" 2>/dev/null || echo 0)"
            if [ "${_st_fail:-0}" -eq 0 ]; then
                tgbot_edit "$chat_id" "$msg_id" \
                    "$(T TXT_TGBOT_SELFTEST_PASS)" "$(tgbot_kb_device)"
                tgbot_send_document "$chat_id" "$_st_tmp" \
                    "✅ Selftest PASS | ${TG_ROUTER_ID:-router}"
            else
                tgbot_edit "$chat_id" "$msg_id" \
                    "$(T TXT_TGBOT_SELFTEST_FAIL)" "$(tgbot_kb_device)"
                tgbot_send_document "$chat_id" "$_st_tmp" \
                    "❌ Selftest FAIL (${_st_fail}) | ${TG_ROUTER_ID:-router}"
            fi
            rm -f "$_st_tmp" 2>/dev/null
            ;;
        sys_reboot_confirm)
            tgbot_edit "$chat_id" "$msg_id" \
                "$(T TXT_TGBOT_BTN_REBOOT)?" "$(tgbot_kb_reboot_confirm)"
            ;;
        sys_reboot_do)
            tgbot_edit "$chat_id" "$msg_id" "$(T TXT_TGBOT_REBOOT_SENT)" ""
            sleep 2
            LD_LIBRARY_PATH= ndmc -c "system reboot" >/dev/null 2>&1 || true
            ;;
        sys_wan_reset)
            tgbot_edit "$chat_id" "$msg_id" \
                "$(T TXT_TGBOT_WAN_RESET_SELECT)" "$(tgbot_kb_wan_reset_time)"
            ;;
        wan_rc_*)
            local _wr_min
            _wr_min="${cb_action#wan_rc_}"
            tgbot_edit "$chat_id" "$msg_id" \
                "$(tpl_render "$(T TXT_TGBOT_WAN_RESET_CONFIRM)" MIN "$_wr_min")" \
                "$(tgbot_kb_wan_reset_confirm "$_wr_min")"
            ;;
        wan_rd_*)
            local _wd_min _wd_ndm _wd_sec
            _wd_min="${cb_action#wan_rd_}"
            _wd_ndm="$(LD_LIBRARY_PATH= ndmc -c 'show interface' 2>/dev/null | awk '
                BEGIN{RS="Interface, name = "; FS="\n"}
                NR>1{
                    id=""; role=""
                    for(i=1;i<=NF;i++){
                        if($i ~ /^[[:space:]]*id:/){v=$i; sub(/.*id:[[:space:]]*/,"",v); gsub(/[[:space:]]/,"",v); id=v}
                        if($i ~ /^[[:space:]]*role:[[:space:]]*inet/){role="inet"}
                    }
                    if(role=="inet" && id!=""){print id; exit}
                }
            ')"
            if [ -z "$_wd_ndm" ]; then
                tgbot_edit "$chat_id" "$msg_id" \
                    "$(T TXT_TGBOT_WAN_NO_IF)" "$(tgbot_kb_wan_reset_time)"
            else
                tgbot_edit "$chat_id" "$msg_id" \
                    "$(tpl_render "$(T TXT_TGBOT_WAN_RESET_STARTED)" MIN "$_wd_min")" ""
                _wd_sec=$(( _wd_min * 60 ))
                ( LD_LIBRARY_PATH= ndmc -c "interface ${_wd_ndm} down" >/dev/null 2>&1
                  sleep "$_wd_sec"
                  LD_LIBRARY_PATH= ndmc -c "interface ${_wd_ndm} up" >/dev/null 2>&1
                ) &
            fi
            ;;
    esac
}

# setMyCommands - Telegram komut listesini ayarla
tgbot_set_commands() {
    local _token="$1"
    local _cmds
    _cmds='[{"command":"start","description":"Ana menuyu ac"},{"command":"durum","description":"Sistem durumunu goster"},{"command":"zapret","description":"Zapret yonetimi"},{"command":"sistem","description":"Sistem ve router"},{"command":"kzm","description":"KZM yonetimi"},{"command":"help","description":"Yardim"}]'
    local _sc_result
    _sc_result="$(curl -fsSL -X POST "https://api.telegram.org/bot${_token}/setMyCommands" \
        -H "Content-Type: application/json" \
        -d "{\"commands\":${_cmds}}" 2>&1)"
    printf '%s\n' "$(date '+%Y-%m-%d %H:%M:%S') | tgbot | setMyCommands: ${_sc_result}" >> "$TG_BOT_LOG_FILE"
}

# Main bot polling loop
telegram_bot_daemon() {
    telegram_load_config || return 1
    [ "${TG_BOT_ENABLE:-0}" != "1" ] && return 1

    local offset=0
    local raw ids update_id blk
    local cb_id cb_data cb_chat cb_msg_id msg_chat msg_text

    printf '%s\n' "$(date '+%Y-%m-%d %H:%M:%S') | tgbot | started" >> "$TG_BOT_LOG_FILE"
    # Eski pending dosyalarini temizle
    rm -f /tmp/tgbot_pending_* 2>/dev/null
    tgbot_set_commands "$TG_BOT_TOKEN"

    while true; do
        # getUpdates
        _tgbot_api "getUpdates" \
            "{\"offset\":${offset},\"timeout\":${TG_BOT_POLL_SEC:-5},\"allowed_updates\":[\"message\",\"callback_query\"]}"

        if [ ! -s "$_TGBOT_TMP" ]; then
            sleep "${TG_BOT_POLL_SEC:-5}"
            continue
        fi

        raw="$(cat "$_TGBOT_TMP" 2>/dev/null)"

        # ok:true kontrolu
        printf '%s' "$raw" | grep -q '"ok":true' || {
            printf '%s\n' "$(date '+%Y-%m-%d %H:%M:%S') | tgbot | api error: $(printf '%s' "$raw" | head -c 120)" >> "$TG_BOT_LOG_FILE"
            sleep "${TG_BOT_POLL_SEC:-5}"
            continue
        }

        # update_id listesi
        ids="$(printf '%s' "$raw" | grep -o '"update_id":[0-9]*' | sed 's/"update_id"://')"
        [ -z "$ids" ] && { sleep "${TG_BOT_POLL_SEC:-5}"; continue; }

        # Tum newline'lari kaldir - tek satir yap
        raw="$(printf '%s' "$raw" | tr -d '\n\r')"

        for update_id in $ids; do
            offset=$((update_id + 1))

            # Bu update'e ait bolumu kes
            # update_id sonrasindaki ilk 800 karakteri al
            blk="$(printf '%s' "$raw" | sed "s/.*\"update_id\":${update_id}//" | cut -c1-2000)"

            # Tip: callback_query
            if printf '%s' "$blk" | grep -q '"callback_query"'; then
                cb_id="$(printf '%s' "$blk" | grep -o '"id":"[0-9]*"' | head -1 | cut -d'"' -f4)"
                cb_data="$(printf '%s' "$blk" | grep -o '"data":"[^"]*"' | tail -1 | cut -d'"' -f4)"
                cb_chat="$(printf '%s' "$blk" | grep -o '"chat":{"id":[0-9-]*' | head -1 | sed 's/.*://')"
                cb_msg_id="$(printf '%s' "$blk" | grep -o '"message_id":[0-9]*' | head -1 | sed 's/.*://')"
                printf '%s\n' "$(date '+%Y-%m-%d %H:%M:%S') | tgbot | cb data=$cb_data chat=$cb_chat msg=$cb_msg_id" >> "$TG_BOT_LOG_FILE"
                if [ -n "$cb_chat" ] && [ "$cb_chat" = "$TG_CHAT_ID" ] && [ -n "$cb_data" ]; then
                    tgbot_handle_callback "$cb_data" "$cb_chat" "$cb_msg_id" "$cb_id"
                fi

            # Tip: message
            elif printf '%s' "$blk" | grep -q '"message"'; then
                msg_chat="$(printf '%s' "$blk" | grep -o '"chat":{"id":[0-9-]*' | head -1 | sed 's/.*://')"
                msg_text="$(printf '%s' "$blk" | grep -o '"text":"[^"]*"' | head -1 | cut -d'"' -f4)"
                printf '%s\n' "$(date '+%Y-%m-%d %H:%M:%S') | tgbot | msg text=$msg_text chat=$msg_chat" >> "$TG_BOT_LOG_FILE"
                if [ -n "$msg_chat" ] && [ "$msg_chat" = "$TG_CHAT_ID" ]; then
                    # Bekleyen islem var mi kontrol et (ornegin isim degistirme)
                    local _pending_file="/tmp/tgbot_pending_${msg_chat}"
                    if [ -f "$_pending_file" ]; then
                        local _pending
                        _pending="$(cat "$_pending_file" 2>/dev/null)"
                        rm -f "$_pending_file" 2>/dev/null
                        case "$_pending" in
                            rename:*)
                                local _rn_mac="${_pending#rename:}"
                                if [ "$msg_text" = "/iptal" ] || [ "$msg_text" = "/cancel" ]; then
                                    tgbot_send "$msg_chat" "$(T TXT_TGBOT_CLIENT_RENAME_CANCEL)" ""
                                else
                                    local _rn_name="$msg_text"
                                    # Telegram JSON unicode escape (\u0131 gibi) UTF-8'e donustur
                                    _rn_name="$(printf '%s' "$_rn_name" | awk '{
                                        s = $0
                                        result = ""
                                        while (match(s, /\\u[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]/)) {
                                            result = result substr(s, 1, RSTART-1)
                                            hex = substr(s, RSTART+2, 4)
                                            code = 0
                                            for (i=1; i<=4; i++) {
                                                c = substr(hex, i, 1)
                                                if (c >= "0" && c <= "9") v = c - "0"
                                                else if (c >= "a" && c <= "f") v = 10 + index("abcdef", c) - 1
                                                else if (c >= "A" && c <= "F") v = 10 + index("ABCDEF", c) - 1
                                                code = code * 16 + v
                                            }
                                            if (code < 128) {
                                                result = result sprintf("%c", code)
                                            } else if (code < 2048) {
                                                b1 = 192 + int(code/64)
                                                b2 = 128 + (code % 64)
                                                result = result sprintf("%c%c", b1, b2)
                                            } else {
                                                b1 = 224 + int(code/4096)
                                                b2 = 128 + int((code%4096)/64)
                                                b3 = 128 + (code % 64)
                                                result = result sprintf("%c%c%c", b1, b2, b3)
                                            }
                                            s = substr(s, RSTART+6)
                                        }
                                        print result s
                                    }')"
                                    # Bos kaldiysa hata ver
                                    if [ -z "$_rn_name" ]; then
                                        tgbot_send "$msg_chat" "$(T _ 'Gecersiz isim.' 'Invalid name.')" ""
                                        continue
                                    fi
                                    printf '%s\n' "$(date '+%Y-%m-%d %H:%M:%S') | tgbot | rename mac=$_rn_mac name=$_rn_name" >> "$TG_BOT_LOG_FILE"
                                    local _rn_out
                                    _rn_out="$(LD_LIBRARY_PATH= ndmc -c "known host \"${_rn_name}\" ${_rn_mac}" 2>&1)"
                                    printf '%s\n' "$(date '+%Y-%m-%d %H:%M:%S') | tgbot | rename ndmc: $_rn_out" >> "$TG_BOT_LOG_FILE"
                                    LD_LIBRARY_PATH= ndmc -c "system configuration save" >/dev/null 2>&1
                                    local _rn_info _rn_access
                                    _rn_info="$(_tgbot_parse_client "$_rn_mac")"
                                    _rn_access="$(printf '%s\n' "$_rn_info" | grep '^access=' | cut -d= -f2-)"
                                    [ -z "$_rn_access" ] && _rn_access="permit"
                                    tgbot_send "$msg_chat" \
                                        "$(T TXT_TGBOT_CLIENT_RENAME_DONE)
$(tgbot_client_detail_text "$_rn_mac")" \
                                        "$(tgbot_kb_client "$_rn_mac" "$_rn_access")"
                                fi
                                ;;
                        esac
                        continue
                    fi
                    case "$msg_text" in
                        /start|/menu)
                            tgbot_send "$msg_chat" \
                                "${TG_ROUTER_ID} | $(T TXT_TGBOT_MENU_TITLE)" \
                                "$(tgbot_kb_main)"
                            ;;
                        /durum|/status)
                            tgbot_send "$msg_chat" \
                                "$(tgbot_status_text)" \
                                "$(tgbot_kb_main)"
                            ;;
                        /zapret)
                            tgbot_send "$msg_chat" \
                                "$(T TXT_TGBOT_BTN_ZAPRET)" \
                                "$(tgbot_kb_zapret)"
                            ;;
                        /sistem|/system)
                            tgbot_send "$msg_chat" \
                                "$(T TXT_TGBOT_BTN_SYSTEM)" \
                                "$(tgbot_kb_sistem)"
                            ;;
                        /kzm)
                            tgbot_send "$msg_chat" \
                                "$(T TXT_TGBOT_BTN_KZM)" \
                                "$(tgbot_kb_kzm)"
                            ;;
                        /help|/yardim)
                            tgbot_send "$msg_chat" \
                                "$(T _ '📖 KZM Yardim

📊 /durum — Sistemin anlik durumu
  Zapret, HealthMon, WAN, IP bilgilerini gosterir.

🔧 /zapret — Zapret yonetimi
  Zapreti baslat, durdur, yeniden baslat veya guncelle.
  DPI tabanli internet kisitlamalarini asmak icin kullanilir.

⚙️ /sistem — Sistem ve router
  Bagli cihazlari gor, WiFi ac/kapat, routeri yeniden baslat.

🛠️ /kzm — KZM yonetimi
  Betigi guncelle, self-test calistir.

📋 /loglar — Log goruntulemek
  KZM ve sistem loglarini Telegramdan oku.

💡 Ipucu: Butonlara basarak da tum menulere ulasabilirsin.
  Komutlar sadece hizli erisim icindir.' '📖 KZM Help

📊 /durum — Live system status
  Shows Zapret, HealthMon, WAN and IP info.

🔧 /zapret — Zapret management
  Start, stop, restart or update Zapret.
  Used to bypass DPI-based internet restrictions.

⚙️ /sistem — System and router
  View connected devices, toggle WiFi, reboot router.

🛠️ /kzm — KZM management
  Update the script, run self-test.

📋 /loglar — View logs
  Read KZM and system logs from Telegram.

💡 Tip: You can also use the buttons to access all menus.
  Commands are just for quick access.')" \
                                ""
                            ;;
                    esac
                fi
            fi
        done

        # long-poll timeout handles delay, no extra sleep needed
    done
}

telegram_bot_start() {
    telegram_load_config || { print_status FAIL "$(T TXT_TGBOT_BOT_NOT_CONFIG)"; return 1; }
    [ "${TG_BOT_ENABLE:-0}" != "1" ] && { print_status WARN "$(T TXT_TGBOT_BOT_NOT_CONFIG)"; return 1; }
    if [ -f "$TG_BOT_PID_FILE" ] && kill -0 "$(cat "$TG_BOT_PID_FILE" 2>/dev/null)" 2>/dev/null; then
        print_status WARN "$(T TXT_TGBOT_BOT_STATUS_ACTIVE)"
        return 0
    fi
    if command -v nohup >/dev/null 2>&1; then
        nohup "$0" --telegram-daemon </dev/null >>"$TG_BOT_LOG_FILE" 2>&1 &
    else
        "$0" --telegram-daemon </dev/null >>"$TG_BOT_LOG_FILE" 2>&1 &
    fi
    echo $! > "$TG_BOT_PID_FILE"
    print_status PASS "$(T TXT_TGBOT_BOT_STARTED)"
}

# Bot'u durdur
telegram_bot_stop() {
    if [ -f "$TG_BOT_PID_FILE" ]; then
        local pid
        pid="$(cat "$TG_BOT_PID_FILE" 2>/dev/null)"
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null || true
            sleep 1
            kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
        fi
        rm -f "$TG_BOT_PID_FILE" 2>/dev/null
    fi
    ps 2>/dev/null | awk -v n="$SCRIPT_NAME" \
        'index($0,"--telegram-daemon")>0 && index($0,n)>0 {print $1}' | \
        while read -r _p; do kill "$_p" 2>/dev/null || true; done
    print_status PASS "$(T TXT_TGBOT_BOT_STOPPED)"
}

# Autostart - HealthMon watchdog tarafindan yonetilir, ayri init.d gerekmez
telegram_bot_setup_autostart() {
    # Eski init.d script varsa temizle — watchdog halleder
    rm -f "$TG_BOT_AUTOSTART" 2>/dev/null
}

# Bot yonetim menusu
telegram_bot_menu() {
    while true; do
        clear
        print_line "="
        echo "$(T TXT_TGBOT_MENU_BOT_TITLE)"
        print_line "="
        echo
        telegram_load_config 2>/dev/null
        if [ -f "$TG_BOT_PID_FILE" ] && kill -0 "$(cat "$TG_BOT_PID_FILE" 2>/dev/null)" 2>/dev/null; then
            printf " %-26s: %b%s%b\n" "$(T TXT_TGBOT_BOT_ENABLE)" \
                "${CLR_GREEN}${CLR_BOLD}" "$(T TXT_TGBOT_BOT_STATUS_ACTIVE)" "${CLR_RESET}"
        else
            printf " %-26s: %b%s%b\n" "$(T TXT_TGBOT_BOT_ENABLE)" \
                "${CLR_ORANGE}${CLR_BOLD}" "$(T TXT_TGBOT_BOT_STATUS_INACTIVE)" "${CLR_RESET}"
        fi
        printf " %-26s: %s\n" "$(T TXT_TGBOT_POLL_SEC)" "${TG_BOT_POLL_SEC:-5}"
        printf " %-26s: %s\n" "$(T TXT_TGBOT_ROUTER_ID_LABEL)" "${TG_ROUTER_ID}"
        echo
        print_line "-"
        echo " 1) $(T TXT_TGBOT_ENABLE_BOT)"
        echo " 2) $(T TXT_TGBOT_DISABLE_BOT)"
        echo " 3) $(T TXT_TGBOT_RESTART_BOT)"
        echo " 0) $(T TXT_BACK)"
        print_line "-"
        printf "%s" "$(T TXT_CHOICE) "
        read -r c || return 0
        clear
        case "$c" in
            1)
                printf "%s" "$(T TXT_TGBOT_ENTER_POLL)"
                read -r poll_input
                [ -z "$poll_input" ] && poll_input=5
                case "$poll_input" in
                    [0-9]*) : ;;
                    *) poll_input=5 ;;
                esac
                telegram_load_config 2>/dev/null
                telegram_write_config "$TG_BOT_TOKEN" "$TG_CHAT_ID" "1" "$poll_input"
                telegram_bot_setup_autostart "1"
                telegram_bot_stop >/dev/null 2>&1
                sleep 1
                telegram_bot_start
                press_enter_to_continue
                ;;
            2)
                telegram_load_config 2>/dev/null
                telegram_write_config "$TG_BOT_TOKEN" "$TG_CHAT_ID" "0" "${TG_BOT_POLL_SEC:-5}"
                telegram_bot_stop
                telegram_bot_setup_autostart "0"
                press_enter_to_continue
                ;;
            3)
                telegram_bot_stop >/dev/null 2>&1
                sleep 1
                telegram_bot_start
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
HM_TGBOT_WATCHDOG="1"
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
    HM_TGBOT_WATCHDOG="1"
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

    # --- Zapret surum kontrolu (sadece bildirim, otomatik kurulum yok) ---
    local zap_repo zap_api zap_latest zap_cur zap_url
    zap_repo="${HM_UPDATECHECK_REPO_ZAPRET:-bol-van/zapret}"
    zap_api="https://api.github.com/repos/${zap_repo}/releases/latest"
    zap_cur="$(cat /opt/zapret/version 2>/dev/null)"

    if [ -n "$zap_cur" ]; then
        zap_latest="$(curl -fsS "$zap_api" 2>/dev/null | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
        echo "$(date +%s 2>/dev/null) | updatecheck | zapret | cur=$zap_cur latest=${zap_latest:-N/A}" >> /tmp/healthmon.log 2>/dev/null

        if [ -n "$zap_latest" ]; then
            if ver_is_newer "$zap_latest" "$zap_cur"; then
                # Normal guncelleme: yeni surum mevcut
                zap_url="https://github.com/${zap_repo}/releases/latest"
                telegram_send "$(tpl_render "$(T TXT_UPD_ZAPRET_NEW)" CUR "$zap_cur" NEW "$zap_latest" URL "$zap_url")"
                echo "$(date +%s 2>/dev/null) | updatecheck | zapret | notified cur=$zap_cur latest=$zap_latest" >> /tmp/healthmon.log 2>/dev/null
            elif ver_is_newer "$zap_cur" "$zap_latest"; then
                # Geri cekilmis release: kurulu surum GitHub'dan yeni
                telegram_send "$(tpl_render "$(T TXT_UPD_ZAPRET_ROLLED)" CUR "$zap_cur" NEW "$zap_latest")"
                echo "$(date +%s 2>/dev/null) | updatecheck | zapret | pulled_release cur=$zap_cur stable=$zap_latest" >> /tmp/healthmon.log 2>/dev/null
            fi
        fi
    fi

    # --- KZM surum kontrolu ---
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
    rm -f /tmp/healthmon_updatecheck.ts 2>/dev/null
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

        # ---- TELEGRAM BOT WATCHDOG ----
        if [ "${HM_TGBOT_WATCHDOG:-1}" = "1" ]; then
            _tgconf="/opt/etc/telegram.conf"
            _tgbot_enable="$(grep -s '^TG_BOT_ENABLE=' "$_tgconf" | cut -d= -f2 | tr -d '"')"
            if [ "$_tgbot_enable" = "1" ]; then
                _tgpid_f="$TG_BOT_PID_FILE"
                _tgpid="$(cat "$_tgpid_f" 2>/dev/null)"
                if [ -z "$_tgpid" ] || ! kill -0 "$_tgpid" 2>/dev/null; then
                    healthmon_log "$now | tgbot_watchdog | bot dead, restarting"
                    # Eski tum telegram-daemon processleri temizle
                    ps 2>/dev/null | grep -- '--telegram-daemon' | grep -v grep | \
                        while IFS= read -r _pline; do
                            _ppid="$(printf '%s' "$_pline" | awk '{print $1}')"
                            [ -n "$_ppid" ] && kill "$_ppid" 2>/dev/null
                        done
                    sleep 1
                    "$ZKM_SCRIPT_PATH" --telegram-daemon </dev/null >>"$TG_BOT_LOG_FILE" 2>&1 &
                    echo $! > "$_tgpid_f"
                fi
            fi
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

# ---------------------------------------------------------------------------
# --cgi-action: CGI tarafindan cagrilir, dogrudan fonksiyon calistirir
# ---------------------------------------------------------------------------
if [ "$1" = "--cgi-action" ]; then
    trap \'\' HUP 2>/dev/null
    case "$2" in
        start_zapret)    start_zapret   2>/dev/null ;;
        stop_zapret)     stop_zapret    2>/dev/null ;;
        restart_zapret)  restart_zapret 2>/dev/null ;;
        healthmon_start)
            if [ -f "$ZKM_SCRIPT_PATH" ]; then
                ZKM_SKIP_LOCK=1 sh "$ZKM_SCRIPT_PATH" --healthmon-daemon &
            fi
            ;;
        healthmon_stop)
            if [ -f /tmp/healthmon.pid ]; then
                kill "$(cat /tmp/healthmon.pid 2>/dev/null)" 2>/dev/null
            fi
            ;;
        tg_test)
            if [ -f /opt/etc/telegram.conf ]; then
                . /opt/etc/telegram.conf 2>/dev/null
                [ -n "$TG_BOT_TOKEN" ] && [ -n "$TG_CHAT_ID" ] && \
                curl -fsSL -m 10 \
                    "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
                    -d "chat_id=${TG_CHAT_ID}&text=%E2%9C%85+Telegram+Test%3A+Bildirim+calisiyor" \
                    >/dev/null 2>&1 || true
            fi
            ;;
        dpi_set)
            # $3: profil adi
            _cgi_p="$3"
            # ZAPRET_IPV6 config'den oku (--cgi-action sirasinda varsayilan "n")
            if [ -f /opt/zapret/config ] && grep -q -- '--dpi-desync-ttl6' /opt/zapret/config 2>/dev/null; then
                ZAPRET_IPV6="y"
            fi
            case "$_cgi_p" in
                tt_default|tt_fiber|tt_alt|sol|sol_alt|sol_fiber|turkcell_mob|vodafone_mob|blockcheck_auto)
                    set_dpi_profile "$_cgi_p"
                    set_dpi_origin "manual"
                    update_nfqws_parameters >/dev/null 2>&1
                    restart_zapret >/dev/null 2>&1
                    ;;
            esac
            ;;
        health_run_bg)
            _hc_out="/tmp/kzm_health_result.json"
            printf '{"running":1}\n' > "$_hc_out"
            # crash durumunda hata JSON yaz
            trap 'printf '"'"'{"ok":0,"msg":"Kontrol sirasinda hata olustu"}'"'"' > "$_hc_out"' EXIT

            # --- yardimci: JSON string escape ---
            _js() { printf '%s' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g;s/	/ /g'; }

            # --- sonuc biriktirici ---
            _items=""
            _pass=0; _warn=0; _fail=0; _info=0; _total=0

            _add() {
                # $1=section $2=label $3=value $4=status
                local _s _comma
                _s="$4"; _total=$((_total+1))
                case "$_s" in
                    PASS) _pass=$((_pass+1)) ;;
                    WARN) _warn=$((_warn+1)) ;;
                    FAIL) _fail=$((_fail+1)) ;;
                    INFO) _info=$((_info+1)) ;;
                esac
                [ -n "$_items" ] && _comma="," || _comma=""
                _items="${_items}${_comma}{\"sec\":\"$(_js "$1")\",\"lbl\":\"$(_js "$2")\",\"val\":\"$(_js "$3")\",\"st\":\"$4\"}"
            }

            # --- WAN ---
            _wan_if="$(get_wan_if 2>/dev/null)"
            [ -z "$_wan_if" ] && _wan_if="$(healthmon_detect_wan_iface_ndm 2>/dev/null)"
            [ -z "$_wan_if" ] && _wan_if="PPPoE0"
            _wan_raw="$(LD_LIBRARY_PATH= ndmc -c "show interface $_wan_if" 2>/dev/null)"
            _wan_link="$(printf '%s\n' "$_wan_raw" | awk '/link:/ {print $2; exit}')"
            _wan_conn="$(printf '%s\n' "$_wan_raw" | awk '/connected:/ {print $2; exit}')"
            if [ -z "$_wan_link" ] && [ -z "$_wan_conn" ]; then
                if ip link show "$_wan_if" >/dev/null 2>&1; then
                    _wan_link="up"; _wan_conn="yes"
                else
                    _wan_link="down"; _wan_conn="no"
                fi
            fi
            if [ "$_wan_link" = "up" ] && [ "$_wan_conn" = "yes" ]; then _wan_st="PASS"; else _wan_st="FAIL"; fi
            _add "net" "$(T TXT_HEALTH_WAN_STATUS)" "$_wan_if" "$_wan_st"

            _wan_ipv4="$(ip -4 addr show "$_wan_if" 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)"
            _wan_ipv6="$(ip -6 addr show "$_wan_if" 2>/dev/null | awk '/inet6 / && !/fe80/{print $2; exit}' | cut -d/ -f1)"
            if [ -n "$_wan_ipv4" ]; then
                _ip_type="$(zkm_classify_ip "$_wan_ipv4")"
                case "$_ip_type" in
                    cgnat)   _ip_lbl="$_wan_ipv4 [CGNAT]" ;;
                    private) _ip_lbl="$_wan_ipv4 [NAT]" ;;
                    *)       _ip_lbl="$_wan_ipv4 [Public]" ;;
                esac
                _add "net" "$(T TXT_HEALTH_WAN_IPV4)" "$_ip_lbl" "INFO"
            fi
            [ -n "$_wan_ipv6" ] && _add "net" "$(T TXT_HEALTH_WAN_IPV6)" "$_wan_ipv6" "INFO"

            # DNS meta (INFO - sayilmaz, ayri key)
            _dns_raw="$(LD_LIBRARY_PATH= ndmc -c 'show dns-proxy' 2>/dev/null)"
            _dot_p="$(printf '%s\n' "$_dns_raw" | grep 'dns_server.*@' | sed 's/.*@//;s/[[:space:]].*//' | grep -v '^dnsm$' | grep -v '^$' | sort -u)"
            _doh_p="$(printf '%s\n' "$_dns_raw" | grep 'uri:' | sed 's|.*https://||;s|/.*||' | grep -v '^$' | sort -u)"
            _all_p="$(printf '%s\n%s\n' "$_dot_p" "$_doh_p" | sed '/^$/d' | sort -u | tr '\n' ',' | sed 's/,$//')"
            _doh_ps="$(ps w 2>/dev/null | awk '/https_dns_proxy/ && !/awk/{for(i=1;i<=NF;i++) if($i=="-r"){r=$(i+1); gsub(/^https:\/\//,"",r); gsub(/\/.*/,"",r); print r}}' | sort -u | tr '\n' ',' | sed 's/,$//')"
            [ -n "$_doh_ps" ] && { [ -n "$_all_p" ] && _all_p="${_all_p},${_doh_ps}" || _all_p="$_doh_ps"; }
            _dns_providers="$(printf '%s\n' "$_all_p" | tr ',' '\n' | sed '/^$/d' | sort -u | tr '\n' ',' | sed 's/,$//')"
            _dot_on=0; netstat -lntp 2>/dev/null | grep -qE ':853[[:space:]]' && _dot_on=1
            if [ -n "$_doh_ps" ] && [ "$_dot_on" = "1" ]; then _dns_mode="DoH+DoT"
            elif [ -n "$_doh_ps" ]; then _dns_mode="DoH"
            elif [ "$_dot_on" = "1" ]; then _dns_mode="DoT"
            else _dns_mode="Plain"; fi

            # DNS checks
            if check_dns_local; then _add "net" "$(T TXT_HEALTH_DNS_LOCAL)" "" "PASS"
            else _add "net" "$(T TXT_HEALTH_DNS_LOCAL)" "" "FAIL"; fi
            if check_dns_external; then _add "net" "$(T TXT_HEALTH_DNS_PUBLIC)" "" "PASS"
            else _add "net" "$(T TXT_HEALTH_DNS_PUBLIC)" "" "FAIL"; fi
            if check_dns_consistency; then _add "net" "$(T TXT_HEALTH_DNS_MATCH)" "" "PASS"
            else _add "net" "$(T TXT_HEALTH_DNS_MATCH)" "$(T TXT_HEALTH_DNS_MATCH_NOTE)" "INFO"; fi

            # Route
            _gw="$(ip route 2>/dev/null | awk '/default/ {print $3; exit}')"
            if [ -n "$_gw" ]; then _add "net" "$(T TXT_HEALTH_ROUTE)" "$_gw" "PASS"
            else _add "net" "$(T TXT_HEALTH_ROUTE)" "$(T _ 'yok' 'none')" "FAIL"; fi

            # --- System ---
            if ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then _add "sys" "$(T TXT_HEALTH_PING)" "" "PASS"
            else _add "sys" "$(T TXT_HEALTH_PING)" "" "FAIL"; fi

            _ram_kb="$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}')"
            _ram_mb=$((_ram_kb/1024))
            if [ "$_ram_mb" -lt 100 ]; then _add "sys" "$(T TXT_HEALTH_RAM)" "${_ram_mb}MB" "WARN"
            else _add "sys" "$(T TXT_HEALTH_RAM)" "${_ram_mb}MB" "PASS"; fi

            _load="$(awk '{print $1}' /proc/loadavg 2>/dev/null)"
            if awk -v l="$_load" 'BEGIN{exit (l>2.0)?0:1}'; then _add "sys" "$(T TXT_HEALTH_LOAD)" "$_load" "WARN"
            else _add "sys" "$(T TXT_HEALTH_LOAD)" "$_load" "PASS"; fi

            _disk_pct="$(df /opt 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')"
            _disk_free_mb="$(df -k /opt 2>/dev/null | awk 'NR==2 {printf "%d", $4/1024}')"
            if [ -n "$_disk_pct" ] && [ "$_disk_pct" -gt 90 ]; then _add "sys" "$(T TXT_HEALTH_DISK)" "${_disk_pct}% (${_disk_free_mb}MB $(T _ 'bos' 'free'))" "WARN"
            else _add "sys" "$(T TXT_HEALTH_DISK)" "${_disk_pct}% (${_disk_free_mb}MB $(T _ 'bos' 'free'))" "PASS"; fi

            if check_ntp; then _add "sys" "$(T TXT_HEALTH_TIME)" "$(date '+%Y-%m-%d %H:%M')" "PASS"
            else _add "sys" "$(T TXT_HEALTH_TIME)" "$(date '+%Y-%m-%d %H:%M')" "WARN"; fi

            _kzm_exp="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh"
            _kzm_real="$(readlink -f "$ZKM_SCRIPT_PATH" 2>/dev/null || echo "$ZKM_SCRIPT_PATH")"
            if [ "$_kzm_real" = "$_kzm_exp" ]; then _add "sys" "$(T TXT_HEALTH_SCRIPT_PATH)" "$_kzm_real" "PASS"
            else _add "sys" "$(T TXT_HEALTH_SCRIPT_PATH)" "$_kzm_real" "WARN"; fi

            # --- Services ---
            if check_github; then _add "svc" "$(T TXT_HEALTH_GITHUB)" "" "PASS"
            else _add "svc" "$(T TXT_HEALTH_GITHUB)" "" "WARN"; fi

            if check_opkg; then _add "svc" "$(T TXT_HEALTH_OPKG)" "" "PASS"
            else _add "svc" "$(T TXT_HEALTH_OPKG)" "" "WARN"; fi

            if is_zapret_running; then _add "svc" "$(T TXT_HEALTH_ZAPRET)" "$(T _ 'Calisiyor' 'Running')" "PASS"
            else _add "svc" "$(T TXT_HEALTH_ZAPRET)" "$(T _ 'durduruldu' 'stopped')" "FAIL"; fi

            # KeenDNS
            _kdns_raw="$(LD_LIBRARY_PATH= ndmc -c 'show ndns' 2>/dev/null)"
            _kdns_name="$(printf '%s
' "$_kdns_raw" | awk '/name:/ {print $2; exit}')"
            _kdns_dom="$(printf '%s
' "$_kdns_raw"  | awk '/domain:/ {print $2; exit}')"
            _kdns_acc="$(printf '%s
' "$_kdns_raw"  | awk '/access:/ {print $2; exit}')"
            _kdns_dir="$(printf '%s
' "$_kdns_raw"  | awk '/direct:/ {print $2; exit}')"
            if [ -z "$_kdns_name" ]; then
                _add "svc" "KeenDNS" "$(T TXT_KEENDNS_NONE)" "INFO"
            else
                _kdns_fqdn="${_kdns_name}.${_kdns_dom}"
                _kdns_dest="$(printf '%s
' "$_kdns_raw" | awk '/destination:/ {print $2; exit}')"
                _kdns_port="$(printf '%s
' "$_kdns_dest" | awk -F: '{print $NF}')"
                [ -z "$_kdns_port" ] && _kdns_port="443"
                [ "$_kdns_port" = "443" ] && _kp="https" || _kp="http"
                _kdns_code="$(curl -sk --max-time 5 -o /dev/null -w "%{http_code}" "${_kp}://${_kdns_fqdn}:${_kdns_port}" 2>/dev/null)"
                case "$_kdns_code" in 2*|3*|401|403) _kdns_reach="yes" ;; *) _kdns_reach="no" ;; esac
                if [ "$_kdns_acc" = "direct" ] && [ "$_kdns_reach" = "no" ]; then
                    _add "svc" "KeenDNS" "$_kdns_fqdn [$(T TXT_KEENDNS_UNKNOWN)]" "FAIL"
                elif [ "$_kdns_acc" = "direct" ]; then
                    _add "svc" "KeenDNS" "$_kdns_fqdn [$(T TXT_KEENDNS_DIRECT)]" "PASS"
                elif [ "$_kdns_dir" = "no" ]; then
                    _add "svc" "KeenDNS" "$_kdns_fqdn [$(T TXT_KEENDNS_CLOUD)]" "WARN"
                else
                    _add "svc" "KeenDNS" "$_kdns_fqdn [$(T TXT_KEENDNS_CLOUD)]" "INFO"
                fi
            fi

            # SHA256
            _sha_kzm="$(cat /opt/etc/zkm_sha256_kzm.state 2>/dev/null)"
            _sha_zap="$(cat /opt/etc/zkm_sha256_zapret.state 2>/dev/null)"
            case "$_sha_kzm" in ok) _add "svc" "$(T TXT_HEALTH_SHA256_KZM)" "$(T TXT_HEALTH_SHA256_OK)" "PASS" ;; fail) _add "svc" "$(T TXT_HEALTH_SHA256_KZM)" "$(T TXT_HEALTH_SHA256_FAIL)" "WARN" ;; *) _add "svc" "$(T TXT_HEALTH_SHA256_KZM)" "$(T TXT_HEALTH_SHA256_UNKNOWN)" "INFO" ;; esac
            case "$_sha_zap" in ok) _add "svc" "$(T TXT_HEALTH_SHA256_ZAP)" "$(T TXT_HEALTH_SHA256_OK)" "PASS" ;; fail) _add "svc" "$(T TXT_HEALTH_SHA256_ZAP)" "$(T TXT_HEALTH_SHA256_FAIL)" "WARN" ;; *) _add "svc" "$(T TXT_HEALTH_SHA256_ZAP)" "$(T TXT_HEALTH_SHA256_ZAP_UNKNOWN)" "INFO" ;; esac

            # Score
            _ok_n=$((_pass+_info))
            _score="$(awk -v ok="$_ok_n" -v t="$_total" 'BEGIN{if(t<=0)print "0.0"; else printf "%.1f",(ok/t)*10}')"
            _ts="$(date +%s 2>/dev/null || echo 0)"

            printf '{"ok":1,"ts":%s,"score":"%s","pass":%d,"warn":%d,"fail":%d,"info":%d,"total":%d,"dns_mode":"%s","dns_providers":"%s","items":[%s]}\n' \
                "$_ts" "$_score" "$_pass" "$_warn" "$_fail" "$_info" "$_total" \
                "$(_js "$_dns_mode")" "$(_js "$_dns_providers")" "$_items" \
                > "$_hc_out"
            trap - EXIT
            ;;
        *) ;;
    esac
    exit 0
fi

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
    hm_kv "$(T _ 'NFQUEUE kuyruk denetimi' 'NFQUEUE qlen watchdog')" "wd=${HM_QLEN_WATCHDOG} th=${HM_QLEN_WARN_TH} turns=${HM_QLEN_CRIT_TURNS}"
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
        local _label="$1" _var="$2" _cur _v _sec _readable
        eval _cur="\${$_var}"
        # Mevcut degeri okunabilir formatla goster
        _readable=""
        if [ -n "$_cur" ] && [ "$_cur" -gt 0 ] 2>/dev/null; then
            if [ "$_cur" -ge 3600 ] && [ "$((_cur % 3600))" -eq 0 ]; then
                _readable=" = $((_cur/3600)) sa"
            elif [ "$_cur" -ge 60 ] && [ "$((_cur % 60))" -eq 0 ]; then
                _readable=" = $((_cur/60)) dk"
            else
                _readable=" = ${_cur} sn"
            fi
        fi
        printf "%s [%s%s] (ornek: 300s/5m/2h): " "$_label" "${_cur:-}" "$_readable"
        read -r _v
        [ -z "$_v" ] && return 0
        # Birim parse: 5m, 2h, 300s veya duz sayi
        case "$_v" in
            *h) _num="${_v%h}"; _sec=$((_num * 3600)) ;;
            *m) _num="${_v%m}"; _sec=$((_num * 60))   ;;
            *s) _num="${_v%s}"; _sec="$_num"           ;;
            *)  _sec="$_v"                              ;;
        esac
        # Sayi dogrulama
        case "$_sec" in
            *[!0-9]*)
                print_status WARN "$(T _ 'Gecersiz deger, atlandi. (ornek: 300s, 5m, 2h)' 'Invalid value, skipped. (example: 300s, 5m, 2h)')"
                ;;
            *)
                eval "$_var=\"$_sec\""
                # Onay mesaji
                if [ "$_sec" -ge 3600 ] && [ "$((_sec % 3600))" -eq 0 ]; then
                    print_status INFO "$(T _ 'Kaydedildi' 'Saved'): ${_sec}s = $((_sec/3600)) sa"
                elif [ "$_sec" -ge 60 ] && [ "$((_sec % 60))" -eq 0 ]; then
                    print_status INFO "$(T _ 'Kaydedildi' 'Saved'): ${_sec}s = $((_sec/60)) dk"
                else
                    print_status INFO "$(T _ 'Kaydedildi' 'Saved'): ${_sec}s"
                fi
                ;;
        esac
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
        printf " %2s) %-*s : %s\n" "12" "$_w" "$(T TXT_HM_CFG_ITEM12)" "wd=${HM_QLEN_WATCHDOG} th=${HM_QLEN_WARN_TH} turns=${HM_QLEN_CRIT_TURNS} keendns_curl=${HM_KEENDNS_CURL_SEC}s"
echo
        printf " %2s) %s\n" "0" "$(T _ 'Kaydet ve geri' 'Save & back')"
        echo
        printf '%s' "$(T _ 'Secim: ' 'Choice: ')"; read -r _c || return 0

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
printf '%s' "$(T TXT_HM_AUTOUPDATE_WARN_L3)"; read -r _w
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
                hm_ask_01  "$(T _ 'NFQUEUE kuyruk denetimi (0=kapat 1=ac)' 'NFQUEUE qlen watchdog (0=off 1=on)')" HM_QLEN_WATCHDOG
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

# Crontab'daki KZM reboot satirini tanimlayan etiket
KZM_REBOOT_TAG="# KZM_REBOOT"

# crond calisiyor mu kontrol et (ps -w ile)
_sched_crond_running() {
    ps -w 2>/dev/null | awk '/cron/ && !/awk/{found=1} END{exit !found}'
}

# Mevcut KZM_REBOOT satirini oku (yoksa bos doner)
_sched_get_current() {
    crontab -l 2>/dev/null | awk '/KZM_REBOOT/'
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
        printf "%-22s| %s\n" \
            "CPU WARN %${HM_CPU_WARN}/${HM_CPU_WARN_DUR}s" \
            "CPU CRIT %${HM_CPU_CRIT}/${HM_CPU_CRIT_DUR}s"
        printf "%-22s| %-21s| %s\n" \
            "Disk(/opt) >= ${HM_DISK_WARN}%" \
            "RAM <= ${HM_RAM_WARN_MB} MB" \
            "$(T _ 'Load (uptime)' 'Load via uptime')"
        printf "%-22s| %s\n" \
            "$(T _ "Zapret denetimi: ${HM_ZAPRET_WATCHDOG}" "Zapret watchdog: ${HM_ZAPRET_WATCHDOG}")" \
            "$(T _ "Aralik: ${HM_INTERVAL}s" "Interval: ${HM_INTERVAL}s")"
        # Telegram Bot durumu
        if [ "$(grep -s '^TG_BOT_ENABLE=' /opt/etc/telegram.conf | cut -d= -f2 | tr -d '"')" = "1" ]; then
            if [ -f "/tmp/zkm_telegram_bot.pid" ] && kill -0 "$(cat "/tmp/zkm_telegram_bot.pid" 2>/dev/null)" 2>/dev/null; then
                printf "%-22s| %b%s%b\n" "Telegram Bot" \
                    "${CLR_GREEN}" "$(T TXT_TGBOT_BANNER_ACTIVE) (PID: $(cat /tmp/zkm_telegram_bot.pid 2>/dev/null))" "${CLR_RESET}"
            else
                printf "%-22s| %b%s%b\n" "Telegram Bot" \
                    "${CLR_RED}" "$(T TXT_TGBOT_BANNER_INACTIVE)" "${CLR_RESET}"
            fi
        fi
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

# ===========================================================================
# TR/EN Dictionary (Web Panel GUI)
# ===========================================================================
TXT_MENU_17_TR="17. Web Panel (GUI)"
TXT_MENU_17_EN="17. Web Panel (GUI)"

TXT_GUI_TITLE_TR="Web Panel (GUI)"
TXT_GUI_TITLE_EN="Web Panel (GUI)"

TXT_GUI_OPT_1_TR="1) Web Panel Kur"
TXT_GUI_OPT_1_EN="1) Install Web Panel"
TXT_GUI_OPT_2_TR="2) Web Panel Kaldir"
TXT_GUI_OPT_2_EN="2) Remove Web Panel"
TXT_GUI_OPT_3_TR="3) Web Panel Guncelle"
TXT_GUI_OPT_3_EN="3) Update Web Panel"
TXT_GUI_OPT_4_TR="4) Web Panel Durumu"
TXT_GUI_OPT_4_EN="4) Web Panel Status"
TXT_GUI_OPT_6_TR="6) Web Panel Ac/Kapat"
TXT_GUI_OPT_6_EN="6) Enable/Disable Web Panel"
TXT_GUI_OPT_0_TR="0) Geri"
TXT_GUI_OPT_0_EN="0) Back"
TXT_GUI_PORT_PROMPT_TR="Yeni port (1024-65535, bos=iptal): "
TXT_GUI_PORT_PROMPT_EN="New port (1024-65535, empty=cancel): "
TXT_GUI_PORT_INVALID_TR="Gecersiz port numarasi."
TXT_GUI_PORT_INVALID_EN="Invalid port number."
TXT_GUI_PORT_CHANGED_TR="Port degistirildi. Web panel yeniden baslatildi."
TXT_GUI_PORT_CHANGED_EN="Port changed. Web panel restarted."

TXT_GUI_INSTALLED_TR="Web Panel kuruldu."
TXT_GUI_INSTALLED_EN="Web Panel installed."
TXT_GUI_REMOVED_TR="Web Panel kaldirildi."
TXT_GUI_REMOVED_EN="Web Panel removed."
TXT_GUI_UPDATED_TR="Web Panel guncellendi."
TXT_GUI_UPDATED_EN="Web Panel updated."
TXT_GUI_NOT_INSTALLED_TR="Web Panel kurulu degil."
TXT_GUI_NOT_INSTALLED_EN="Web Panel is not installed."
TXT_GUI_STATUS_ON_TR="Web Panel : AKTIF"
TXT_GUI_STATUS_ON_EN="Web Panel : ACTIVE"
TXT_GUI_STATUS_OFF_TR="Web Panel : PASIF"
TXT_GUI_STATUS_OFF_EN="Web Panel : INACTIVE"
TXT_GUI_URL_LABEL_TR="Web Panel URL"
TXT_GUI_URL_LABEL_EN="Web Panel URL"
TXT_GUI_ENABLED_TR="Web Panel etkinlestirildi."
TXT_GUI_ENABLED_EN="Web Panel enabled."
TXT_GUI_DISABLED_TR="Web Panel durduruldu."
TXT_GUI_DISABLED_EN="Web Panel stopped."
TXT_GUI_ERR_OPT_TR="Hata: /opt dizini bulunamadi. Entware kurulu mu?"
TXT_GUI_ERR_OPT_EN="Error: /opt not found. Is Entware installed?"
TXT_GUI_ERR_LIGHTTPD_TR="Hata: lighttpd kurulamadi."
TXT_GUI_ERR_LIGHTTPD_EN="Error: lighttpd install failed."
TXT_GUI_ERR_CGI_TR="Hata: lighttpd-mod-cgi kurulamadi."
TXT_GUI_ERR_CGI_EN="Error: lighttpd-mod-cgi install failed."
TXT_GUI_HTML_OK_TR="HTML        : OK"
TXT_GUI_HTML_OK_EN="HTML        : OK"
TXT_GUI_HTML_MISS_TR="HTML        : EKSIK"
TXT_GUI_HTML_MISS_EN="HTML        : MISSING"
TXT_GUI_JSON_OK_TR="JSON        : OK"
TXT_GUI_JSON_OK_EN="JSON        : OK"
TXT_GUI_JSON_MISS_TR="JSON        : EKSIK"
TXT_GUI_JSON_MISS_EN="JSON        : MISSING"
TXT_GUI_CGI_OK_TR="CGI         : OK"
TXT_GUI_CGI_OK_EN="CGI         : OK"
TXT_GUI_CGI_MISS_TR="CGI         : EKSIK"
TXT_GUI_CGI_MISS_EN="CGI         : MISSING"
TXT_GUI_REMOVING_TR="Web Panel kaldiriliyor..."
TXT_GUI_REMOVING_EN="Removing Web Panel..."
TXT_GUI_CONFIRM_REMOVE_TR="Web Panel kaldirilsin mi? (e/h): "
TXT_GUI_CONFIRM_REMOVE_EN="Remove Web Panel? (y/n): "
TXT_GUI_LIGHTTPD_OK_TR="lighttpd    : OK"
TXT_GUI_LIGHTTPD_OK_EN="lighttpd    : OK"
TXT_GUI_LIGHTTPD_OFF_TR="lighttpd    : PASIF"
TXT_GUI_LIGHTTPD_OFF_EN="lighttpd    : INACTIVE"
TXT_GUI_OPKG_UPD_TR="opkg guncelleniyor..."
TXT_GUI_OPKG_UPD_EN="Running opkg update..."
TXT_GUI_CRON_OK_TR="Cron        : OK"
TXT_GUI_CRON_OK_EN="Cron        : OK"


# ===========================================================================
# KZM GUI — Fonksiyonlar
# ===========================================================================

KZM_GUI_DIR="/opt/www/kzm"
KZM_GUI_CGI_DIR="/opt/www/kzm/cgi-bin"
KZM_GUI_HTML="$KZM_GUI_DIR/index.html"
KZM_GUI_CGI="$KZM_GUI_CGI_DIR/action.sh"
KZM_GUI_CONF="/opt/etc/lighttpd/lighttpd.conf"
KZM_GUI_STATUS_JSON="/opt/var/run/kzm_status.json"
KZM_GUI_STATUS_SCRIPT="/opt/bin/kzm_status_gen.sh"
KZM_GUI_CONF_CUSTOM="/opt/etc/kzm_gui.conf"
KZM_GUI_PORT="8088"
[ -f "$KZM_GUI_CONF_CUSTOM" ] && {
    _p="$(grep -s '^KZM_GUI_PORT=' "$KZM_GUI_CONF_CUSTOM" | cut -d= -f2 | tr -d '"' | tr -d "'")"
    [ -n "$_p" ] && KZM_GUI_PORT="$_p"
    unset _p
}

# ---------------------------------------------------------------------------
# kzm_gui_is_installed: lighttpd ve HTML dosyasi var mi?
# ---------------------------------------------------------------------------
kzm_gui_is_installed() {
    [ -f "$KZM_GUI_HTML" ] && command -v lighttpd >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# kzm_gui_is_running: lighttpd sureci calisiyor mu?
# ---------------------------------------------------------------------------
kzm_gui_is_running() {
    pgrep -x lighttpd >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# kzm_gui_get_lan_ip: LAN IP adresini dinamik al
# ---------------------------------------------------------------------------
kzm_gui_get_lan_ip() {
    local _ip
    # Once br0 veya eth0 gibi LAN arayuzunden al
    _ip="$(ip -4 addr show br0 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)"
    [ -z "$_ip" ] && _ip="$(ip -4 addr show eth0 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)"
    # Fallback: 192.168 ile baslayan ilk IP
    [ -z "$_ip" ] && _ip="$(ip -4 addr 2>/dev/null | awk '/inet 192\.168\./{print $2; exit}' | cut -d/ -f1)"
    [ -z "$_ip" ] && _ip="192.168.1.1"
    printf '%s' "$_ip"
}

# ---------------------------------------------------------------------------
# kzm_gui_gen_status: /opt/var/run/kzm_status.json uret (hafif, ndmc yok)
# ---------------------------------------------------------------------------
kzm_gui_gen_status() {
    local _dir="/opt/var/run"
    mkdir -p "$_dir" 2>/dev/null

    # Zapret calisiyor mu?
    local _zap_run=0
    pgrep -x nfqws >/dev/null 2>&1 && _zap_run=1

    # HealthMon calisiyor mu?
    local _hm_run=0
    local _hm_pid_file="/tmp/healthmon.pid"
    if [ -f "$_hm_pid_file" ]; then
        local _hm_pid
        _hm_pid="$(cat "$_hm_pid_file" 2>/dev/null)"
        [ -n "$_hm_pid" ] && kill -0 "$_hm_pid" 2>/dev/null && _hm_run=1
    fi

    # HealthMon etkin mi? (config)
    local _hm_enabled=0
    [ "$(grep -s '^HM_ENABLE=' /opt/etc/healthmon.conf | cut -d= -f2 | tr -d '"')" = "1" ] && _hm_enabled=1

    # Telegram bot etkin/calisiyor mu?
    local _tg_enabled=0 _tg_run=0 _tg_configured=0
    [ "$(grep -s '^TG_BOT_ENABLE=' /opt/etc/telegram.conf | cut -d= -f2 | tr -d '"')" = "1" ] && _tg_enabled=1
    # Yapilandirilmis mi? Token + ChatID var mi?
    local _tg_tok _tg_chat
    _tg_tok="$(grep -s '^TG_BOT_TOKEN=' /opt/etc/telegram.conf | cut -d= -f2 | tr -d '"')"
    _tg_chat="$(grep -s '^TG_CHAT_ID=' /opt/etc/telegram.conf | cut -d= -f2 | tr -d '"')"
    [ -n "$_tg_tok" ] && [ -n "$_tg_chat" ] && _tg_configured=1
    if [ -f "/tmp/zkm_telegram_bot.pid" ]; then
        local _tg_pid
        _tg_pid="$(cat "/tmp/zkm_telegram_bot.pid" 2>/dev/null)"
        [ -n "$_tg_pid" ] && kill -0 "$_tg_pid" 2>/dev/null && _tg_run=1
    fi

    # CPU load
    local _load1 _load5 _load15
    _load1="$(awk '{print $1}' /proc/loadavg 2>/dev/null)"
    _load5="$(awk '{print $2}' /proc/loadavg 2>/dev/null)"
    _load15="$(awk '{print $3}' /proc/loadavg 2>/dev/null)"
    [ -z "$_load1" ] && _load1="0.00"

    # RAM (KB)
    local _ram_total=0 _ram_free=0 _ram_used_mb=0 _ram_total_mb=0
    _ram_total="$(awk '/^MemTotal:/{print $2}' /proc/meminfo 2>/dev/null)"
    _ram_free="$(awk '/^MemAvailable:/{print $2}' /proc/meminfo 2>/dev/null)"
    [ -z "$_ram_free" ] && _ram_free="$(awk '/^MemFree:/{print $2}' /proc/meminfo 2>/dev/null)"
    [ -z "$_ram_total" ] && _ram_total=0
    [ -z "$_ram_free"  ] && _ram_free=0
    _ram_total_mb=$(( _ram_total / 1024 ))
    _ram_used_mb=$(( (_ram_total - _ram_free) / 1024 ))

    # Disk /opt
    local _disk_used_pct=0 _disk_total_mb=0
    if [ -d /opt ]; then
        local _df_line
        _df_line="$(df /opt 2>/dev/null | awk 'NR==2{print $2,$3,$5}')"
        _disk_total_mb="$(printf '%s' "$_df_line" | awk '{printf "%.0f", $1/1024}')"
        _disk_used_pct="$(printf '%s' "$_df_line" | awk '{gsub(/%/,"",$3); print $3}')"
    fi
    [ -z "$_disk_used_pct" ] && _disk_used_pct=0
    [ -z "$_disk_total_mb" ] && _disk_total_mb=0

    # Zapret version
    local _zap_ver="unknown"
    if [ -f /opt/zapret/ip2net/ip2net ]; then
        _zap_ver="$(strings /opt/zapret/ip2net/ip2net 2>/dev/null | grep -E '^v[0-9]+\.' | head -n1)"
    fi
    [ -z "$_zap_ver" ] && _zap_ver="$(cat /opt/zapret/VERSION 2>/dev/null | head -n1 | tr -d '\n')"
    [ -z "$_zap_ver" ] && _zap_ver="unknown"

    # WAN bilgisi
    local _wan_dev _wan_ip
    _wan_dev="$(cat /opt/zapret/wan_if 2>/dev/null | tr -d '\n')"
    [ -z "$_wan_dev" ] && _wan_dev="$(ip -4 route show default 2>/dev/null | awk '/^default/{print $5; exit}')"
    [ -z "$_wan_dev" ] && _wan_dev="unknown"
    _wan_ip="$(ip -4 addr show "$_wan_dev" 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)"
    [ -z "$_wan_ip" ] && _wan_ip="unknown"

    # Model ve firmware: statik dosyadan oku (kurulumda yazildi)
    local _model _firmware
    _model="$(cat /opt/var/run/kzm_hw_model 2>/dev/null | tr -d '\n')"
    _firmware="$(cat /opt/var/run/kzm_hw_firmware 2>/dev/null | tr -d '\n')"
    [ -z "$_model"    ] && _model="Keenetic"
    [ -z "$_firmware" ] && _firmware="unknown"

    # DPI profil bilgisi
    local _dpi_profile _dpi_origin
    _dpi_profile="$(cat /opt/zapret/dpi_profile 2>/dev/null | tr -d '\n')"
    _dpi_origin="$(cat /opt/zapret/dpi_profile_origin 2>/dev/null | tr -d '\n')"
    [ -z "$_dpi_profile" ] && _dpi_profile="unknown"
    [ -z "$_dpi_origin"  ] && _dpi_origin="manual"

    # Blockcheck sonucu
    local _bc_score=0 _bc_dns_ok=0 _bc_tls12_ok=0 _bc_udp_weak=1 _bc_ts=0
    if [ -f /opt/zapret/blockcheck_result.json ]; then
        _bc_score="$(grep '"score"'    /opt/zapret/blockcheck_result.json | grep -o '[0-9]*' | head -1)"
        _bc_dns_ok="$(grep '"dns_ok"'  /opt/zapret/blockcheck_result.json | grep -o '[0-9]' | head -1)"
        _bc_tls12_ok="$(grep '"tls12_ok"' /opt/zapret/blockcheck_result.json | grep -o '[0-9]' | head -1)"
        _bc_udp_weak="$(grep '"udp_weak"' /opt/zapret/blockcheck_result.json | grep -o '[0-9]' | head -1)"
        _bc_ts="$(grep '"ts"'         /opt/zapret/blockcheck_result.json | grep -o '[0-9]*' | head -1)"
        [ -z "$_bc_score"    ] && _bc_score=0
        [ -z "$_bc_dns_ok"   ] && _bc_dns_ok=0
        [ -z "$_bc_tls12_ok" ] && _bc_tls12_ok=0
        [ -z "$_bc_udp_weak" ] && _bc_udp_weak=1
        [ -z "$_bc_ts"       ] && _bc_ts=0
    fi

    # KeenDNS bilgisi
    local _kdns_raw _kdns_access _kdns_fqdn
    _kdns_raw="$(LD_LIBRARY_PATH= ndmc -c 'show ndns' 2>/dev/null)"
    _kdns_access="$(printf '%s\n' "$_kdns_raw" | awk '/^[[:space:]]*access:/ {print $2; exit}')"
    _kdns_fqdn=""
    if [ -n "$_kdns_access" ]; then
        local _kdns_name _kdns_domain
        _kdns_name="$(printf '%s\n' "$_kdns_raw"   | awk '/^[[:space:]]*name:/   {print $2; exit}')"
        _kdns_domain="$(printf '%s\n' "$_kdns_raw" | awk '/^[[:space:]]*domain:/ {print $2; exit}')"
        _kdns_fqdn="${_kdns_name}.${_kdns_domain}"
    fi
    [ -z "$_kdns_access" ] && _kdns_access="none"
    [ -z "$_kdns_fqdn"   ] && _kdns_fqdn=""

    # Timestamp
    local _ts
    _ts="$(date +%s 2>/dev/null)"
    [ -z "$_ts" ] && _ts=0

    # JSON yaz (jq yok, elle compose)
    cat > "$_dir/kzm_status.json" << EOF
{
  "ts": $_ts,
  "kzm_version": "$SCRIPT_VERSION",
  "model": "$_model",
  "firmware": "$_firmware",
  "wan_dev": "$_wan_dev",
  "wan_ip": "$_wan_ip",
  "keendns_fqdn": "$_kdns_fqdn",
  "keendns_access": "$_kdns_access",
  "zapret_running": $_zap_run,
  "zapret_version": "$_zap_ver",
  "healthmon_running": $_hm_run,
  "healthmon_enabled": $_hm_enabled,
  "telegram_enabled": $_tg_enabled,
  "telegram_running": $_tg_run,
  "telegram_configured": $_tg_configured,
  "load1": "$_load1",
  "load5": "$_load5",
  "load15": "$_load15",
  "ram_used_mb": $_ram_used_mb,
  "ram_total_mb": $_ram_total_mb,
  "disk_used_pct": $_disk_used_pct,
  "disk_total_mb": $_disk_total_mb,
  "dpi_profile": "$_dpi_profile",
  "dpi_origin": "$_dpi_origin",
  "bc_score": $_bc_score,
  "bc_dns_ok": $_bc_dns_ok,
  "bc_tls12_ok": $_bc_tls12_ok,
  "bc_udp_weak": $_bc_udp_weak,
  "bc_ts": $_bc_ts
}
EOF
}

# ---------------------------------------------------------------------------
# kzm_gui_write_status_script: /opt/bin/kzm_status_gen.sh olustur
# ---------------------------------------------------------------------------
kzm_gui_write_status_script() {
    mkdir -p /opt/bin 2>/dev/null
    cat > "$KZM_GUI_STATUS_SCRIPT" << 'STATEOF'
#!/bin/sh
# kzm_status_gen.sh — KZM Web Panel JSON durum uretici (standalone)
# Cron: */1 * * * * /opt/bin/kzm_status_gen.sh >/dev/null 2>&1
# NOT: Bu dosya KZM script tarafindan otomatik uretilmistir.

export PATH=/opt/sbin:/opt/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
mkdir -p /opt/var/run 2>/dev/null

_zap=0; pgrep nfqws >/dev/null 2>&1 && _zap=1
_hm=0
_hmpid="$(cat /tmp/healthmon.pid 2>/dev/null)"
[ -n "$_hmpid" ] && kill -0 "$_hmpid" 2>/dev/null && _hm=1
_hm_en=0
[ "$(grep -s '^HM_ENABLE=' /opt/etc/healthmon.conf | cut -d= -f2 | tr -d '"')" = "1" ] && _hm_en=1
_tg_en=0
[ "$(grep -s '^TG_BOT_ENABLE=' /opt/etc/telegram.conf | cut -d= -f2 | tr -d '"')" = "1" ] && _tg_en=1
_tg=0
_tgpid="$(cat /tmp/zkm_telegram_bot.pid 2>/dev/null)"
[ -n "$_tgpid" ] && kill -0 "$_tgpid" 2>/dev/null && _tg=1
_tg_configured=0
_tg_tok="$(grep -s '^TG_BOT_TOKEN=' /opt/etc/telegram.conf | cut -d= -f2 | tr -d '"')"
_tg_chat="$(grep -s '^TG_CHAT_ID=' /opt/etc/telegram.conf | cut -d= -f2 | tr -d '"')"
[ -n "$_tg_tok" ] && [ -n "$_tg_chat" ] && _tg_configured=1

_load1="$(awk '{print $1}' /proc/loadavg 2>/dev/null)"; [ -z "$_load1" ] && _load1="0.00"
_load5="$(awk '{print $2}' /proc/loadavg 2>/dev/null)"; [ -z "$_load5" ] && _load5="0.00"
_load15="$(awk '{print $3}' /proc/loadavg 2>/dev/null)"; [ -z "$_load15" ] && _load15="0.00"

_rtotal="$(awk '/^MemTotal:/{print $2}' /proc/meminfo 2>/dev/null)"; [ -z "$_rtotal" ] && _rtotal=0
_rfree="$(awk '/^MemAvailable:/{print $2}' /proc/meminfo 2>/dev/null)"; [ -z "$_rfree" ] && _rfree=0
_rtmb=$(( _rtotal / 1024 ))
_rumb=$(( (_rtotal - _rfree) / 1024 ))

_dpct=0; _dtmb=0
if [ -d /opt ]; then
    _dpct="$(df /opt 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5);print $5}')"
    _dtmb="$(df /opt 2>/dev/null | awk 'NR==2{printf "%.0f",$2/1024}')"
    [ -z "$_dpct" ] && _dpct=0
    [ -z "$_dtmb" ] && _dtmb=0
fi

_wan="$(cat /opt/zapret/wan_if 2>/dev/null | tr -d '\n')"
[ -z "$_wan" ] && _wan="$(ip -4 route show default 2>/dev/null | awk '/^default/{print $5;exit}')"
[ -z "$_wan" ] && _wan="unknown"
_wip="$(ip -4 addr show "$_wan" 2>/dev/null | awk '/inet /{print $2;exit}' | cut -d/ -f1)"
[ -z "$_wip" ] && _wip="unknown"

_zver="$(cat /opt/zapret/version 2>/dev/null | head -n1 | tr -d '\n')"
[ -z "$_zver" ] && _zver="unknown"

_kzmver="$(grep '^SCRIPT_VERSION=' /opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh 2>/dev/null | head -n1 | cut -d= -f2 | tr -d '"')"
[ -z "$_kzmver" ] && _kzmver="unknown"

_model="$(cat /opt/var/run/kzm_hw_model 2>/dev/null | tr -d '\n')"; [ -z "$_model" ] && _model="Keenetic"
_fw="$(cat /opt/var/run/kzm_hw_firmware 2>/dev/null | tr -d '\n')"; [ -z "$_fw" ] && _fw="unknown"
_ts="$(date +%s 2>/dev/null)"; [ -z "$_ts" ] && _ts=0

_kdns_raw="$(LD_LIBRARY_PATH= ndmc -c 'show ndns' 2>/dev/null)"
_kdns_access="$(printf '%s\n' "$_kdns_raw" | awk '/^[[:space:]]*access:/ {print $2; exit}')"
_kdns_fqdn=""
if [ -n "$_kdns_access" ]; then
    _kdns_name="$(printf '%s\n' "$_kdns_raw"   | awk '/^[[:space:]]*name:/   {print $2; exit}')"
    _kdns_domain="$(printf '%s\n' "$_kdns_raw" | awk '/^[[:space:]]*domain:/ {print $2; exit}')"
    _kdns_fqdn="${_kdns_name}.${_kdns_domain}"
fi
[ -z "$_kdns_access" ] && _kdns_access="none"

_dpi_profile="$(cat /opt/zapret/dpi_profile 2>/dev/null | tr -d '\n')"
_dpi_origin="$(cat /opt/zapret/dpi_profile_origin 2>/dev/null | tr -d '\n')"
[ -z "$_dpi_profile" ] && _dpi_profile="unknown"
[ -z "$_dpi_origin"  ] && _dpi_origin="manual"

_bc_score=0; _bc_dns_ok=0; _bc_tls12_ok=0; _bc_udp_weak=1; _bc_ts=0
if [ -f /opt/zapret/blockcheck_result.json ]; then
    _bc_score="$(grep '"score"'    /opt/zapret/blockcheck_result.json | grep -o '[0-9]*' | head -1)"
    _bc_dns_ok="$(grep '"dns_ok"'  /opt/zapret/blockcheck_result.json | grep -o '[0-9]' | head -1)"
    _bc_tls12_ok="$(grep '"tls12_ok"' /opt/zapret/blockcheck_result.json | grep -o '[0-9]' | head -1)"
    _bc_udp_weak="$(grep '"udp_weak"' /opt/zapret/blockcheck_result.json | grep -o '[0-9]' | head -1)"
    _bc_ts="$(grep '"ts"'         /opt/zapret/blockcheck_result.json | grep -o '[0-9]*' | head -1)"
    [ -z "$_bc_score"    ] && _bc_score=0
    [ -z "$_bc_dns_ok"   ] && _bc_dns_ok=0
    [ -z "$_bc_tls12_ok" ] && _bc_tls12_ok=0
    [ -z "$_bc_udp_weak" ] && _bc_udp_weak=1
    [ -z "$_bc_ts"       ] && _bc_ts=0
fi

printf '{\n  "ts": %s,\n  "kzm_version": "%s",\n  "model": "%s",\n  "firmware": "%s",\n  "wan_dev": "%s",\n  "wan_ip": "%s",\n  "keendns_fqdn": "%s",\n  "keendns_access": "%s",\n  "zapret_running": %s,\n  "zapret_version": "%s",\n  "healthmon_running": %s,\n  "healthmon_enabled": %s,\n  "telegram_enabled": %s,\n  "telegram_running": %s,\n  "telegram_configured": %s,\n  "load1": "%s",\n  "load5": "%s",\n  "load15": "%s",\n  "ram_used_mb": %s,\n  "ram_total_mb": %s,\n  "disk_used_pct": %s,\n  "disk_total_mb": %s,\n  "dpi_profile": "%s",\n  "dpi_origin": "%s",\n  "bc_score": %s,\n  "bc_dns_ok": %s,\n  "bc_tls12_ok": %s,\n  "bc_udp_weak": %s,\n  "bc_ts": %s\n}\n' \
    "$_ts" "$_kzmver" "$_model" "$_fw" "$_wan" "$_wip" \
    "$_kdns_fqdn" "$_kdns_access" \
    "$_zap" "$_zver" "$_hm" "$_hm_en" "$_tg_en" "$_tg" "$_tg_configured" \
    "$_load1" "$_load5" "$_load15" \
    "$_rumb" "$_rtmb" "$_dpct" "$_dtmb" \
    "$_dpi_profile" "$_dpi_origin" \
    "$_bc_score" "$_bc_dns_ok" "$_bc_tls12_ok" "$_bc_udp_weak" "$_bc_ts" \
    > /opt/var/run/kzm_status.json
STATEOF
    chmod +x "$KZM_GUI_STATUS_SCRIPT"
}

# ---------------------------------------------------------------------------
# kzm_gui_write_cgi: /opt/www/kzm/cgi-bin/action.sh olustur
# ---------------------------------------------------------------------------
kzm_gui_write_cgi() {
    mkdir -p "$KZM_GUI_CGI_DIR" 2>/dev/null
    cat > "$KZM_GUI_CGI" << 'CGIEOF'
#!/bin/sh
export PATH=/opt/sbin:/opt/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
printf 'Content-Type: application/json\r\n\r\n'

CONTENT_LENGTH="${CONTENT_LENGTH:-0}"
if [ "$CONTENT_LENGTH" -gt 0 ] 2>/dev/null; then
    POST_BODY=$(dd bs=1 count="$CONTENT_LENGTH" 2>/dev/null)
else
    read -r POST_BODY
fi

ACTION=$(printf '%s' "$POST_BODY" | sed 's/.*action=\([^&]*\).*/\1/' | tr -d '"'\''[:space:]')
get_param() { printf '%s' "$POST_BODY" | sed "s/.*$1=\([^&]*\).*/\1/" | sed 's/%2F/\//g;s/%2C/,/g;s/%20/ /g;s/%2E/./g;s/%2D/-/g;s/%3A/:/g;s/+/ /g' | tr -d '\n'; }

ok()      { printf '{"ok":1,"msg":"%s"}' "$1"; }
ok_data() { printf '{"ok":1,"data":%s}' "$1"; }
ok_str()  { printf '{"ok":1,"data":"%s"}' "$1"; }
fail()    { printf '{"ok":0,"msg":"%s"}' "$1"; }

HL_USER="/opt/zapret/ipset/zapret-hosts-user.txt"
HL_EXCL="/opt/zapret/ipset/zapret-hosts-user-exclude.txt"
IPSET_FILE="/opt/zapret/ipset_clients.txt"
DPI_FILE="/opt/zapret/dpi_profile"
SCHED_TAG="# KZM_REBOOT"

json_arr() {
    [ -f "$1" ] || { printf '[]'; return; }
    awk 'BEGIN{printf "["} NF{if(NR>1)printf ","; printf "\"%s\"",$0} END{print "]"}' "$1" 2>/dev/null || printf '[]'
}

refresh() { sh /opt/bin/kzm_status_gen.sh >/dev/null 2>&1; }

wait_zapret() {
    # $1: "up" veya "down" — beklenen durum; max 8 saniye
    local _want="$1" _i=0
    while [ "$_i" -lt 8 ]; do
        if [ "$_want" = "up" ]; then
            pgrep -x nfqws >/dev/null 2>&1 && break
        else
            pgrep -x nfqws >/dev/null 2>&1 || break
        fi
        sleep 1; _i=$(( _i + 1 ))
    done
}

case "$ACTION" in
    zapret_start)
        sh /opt/etc/init.d/S90-zapret start >/dev/null 2>&1
        wait_zapret up; refresh; ok "Zapret baslatildi" ;;
    zapret_stop)
        sh /opt/etc/init.d/S90-zapret stop >/dev/null 2>&1
        wait_zapret down; refresh; ok "Zapret durduruldu" ;;
    zapret_restart)
        sh /opt/etc/init.d/S90-zapret restart >/dev/null 2>&1
        wait_zapret down; wait_zapret up; refresh; ok "Zapret yeniden baslatildi" ;;
    healthmon_start)
        sh /opt/etc/init.d/S99zkm_healthmon start >/dev/null 2>&1
        sleep 1; refresh; ok "Health Monitor baslatildi" ;;
    healthmon_stop)
        sh /opt/etc/init.d/S99zkm_healthmon stop >/dev/null 2>&1
        sleep 1; refresh; ok "Health Monitor durduruldu" ;;
    hm_get)
        CONF=/opt/etc/healthmon.conf
        [ -f "$CONF" ] || { fail "Config bulunamadi"; exit 0; }
        . "$CONF" 2>/dev/null
        HM_INTERVAL="${HM_INTERVAL:-60}"
        HM_HEARTBEAT_SEC="${HM_HEARTBEAT_SEC:-300}"
        HM_COOLDOWN_SEC="${HM_COOLDOWN_SEC:-600}"
        HM_UPDATECHECK_ENABLE="${HM_UPDATECHECK_ENABLE:-1}"
        HM_UPDATECHECK_SEC="${HM_UPDATECHECK_SEC:-21600}"
        HM_AUTOUPDATE_MODE="${HM_AUTOUPDATE_MODE:-2}"
        HM_CPU_WARN="${HM_CPU_WARN:-70}"
        HM_CPU_WARN_DUR="${HM_CPU_WARN_DUR:-180}"
        HM_CPU_CRIT="${HM_CPU_CRIT:-90}"
        HM_CPU_CRIT_DUR="${HM_CPU_CRIT_DUR:-60}"
        HM_DISK_WARN="${HM_DISK_WARN:-90}"
        HM_RAM_WARN_MB="${HM_RAM_WARN_MB:-40}"
        HM_ZAPRET_WATCHDOG="${HM_ZAPRET_WATCHDOG:-1}"
        HM_ZAPRET_COOLDOWN_SEC="${HM_ZAPRET_COOLDOWN_SEC:-120}"
        HM_ZAPRET_AUTORESTART="${HM_ZAPRET_AUTORESTART:-0}"
        HM_QLEN_WATCHDOG="${HM_QLEN_WATCHDOG:-1}"
        HM_QLEN_WARN_TH="${HM_QLEN_WARN_TH:-50}"
        HM_QLEN_CRIT_TURNS="${HM_QLEN_CRIT_TURNS:-3}"
        HM_KEENDNS_CURL_SEC="${HM_KEENDNS_CURL_SEC:-120}"
        _load=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "?")
        _ram_free=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo "?")
        _disk=$(df /opt 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%' || echo "?")
        pgrep -x nfqws >/dev/null 2>&1 && _zst="UP" || _zst="DOWN"
        case "$HM_AUTOUPDATE_MODE" in
            2) _mode="Oto Kur" ;; 1) _mode="Bildir" ;; *) _mode="Kapali" ;;
        esac
        [ "$HM_UPDATECHECK_ENABLE" = "1" ] && _upd="Acik" || _upd="Kapali"
        _r() { printf "<div class='info-row'><div class='lbl'>%s</div><div class='val'>%s</div></div>" "$1" "$2"; }
        _s() { printf "<div class='info-sec'>%s</div>" "$1"; }
        _rows=""
        _rows="${_rows}$(_s "Ayarlar")"
        _rows="${_rows}$(_r "Interval" "${HM_INTERVAL}s")"
        _rows="${_rows}$(_r "Heartbeat" "${HM_HEARTBEAT_SEC}s")"
        _rows="${_rows}$(_r "Cooldown" "${HM_COOLDOWN_SEC}s")"
        _rows="${_rows}$(_r "Guncelleme" "${_upd} / ${HM_UPDATECHECK_SEC}s")"
        _rows="${_rows}$(_r "Oto Guncelleme" "${_mode} (${HM_AUTOUPDATE_MODE})")"
        _rows="${_rows}$(_s "Esikler")"
        _rows="${_rows}$(_r "CPU Uyari" "${HM_CPU_WARN}% / ${HM_CPU_WARN_DUR}s")"
        _rows="${_rows}$(_r "CPU Kritik" "${HM_CPU_CRIT}% / ${HM_CPU_CRIT_DUR}s")"
        _rows="${_rows}$(_r "Disk /opt" "${HM_DISK_WARN}%")"
        _rows="${_rows}$(_r "RAM Uyari" "<= ${HM_RAM_WARN_MB} MB")"
        _rows="${_rows}$(_s "Zapret")"
        _rows="${_rows}$(_r "Watchdog" "${HM_ZAPRET_WATCHDOG}")"
        _rows="${_rows}$(_r "WD Cooldown" "${HM_ZAPRET_COOLDOWN_SEC}s")"
        _rows="${_rows}$(_r "Oto Restart" "${HM_ZAPRET_AUTORESTART}")"
        _rows="${_rows}$(_r "NFQUEUE qlen" "wd=${HM_QLEN_WATCHDOG} th=${HM_QLEN_WARN_TH} turns=${HM_QLEN_CRIT_TURNS}")"
        _rows="${_rows}$(_r "KeenDNS interval" "${HM_KEENDNS_CURL_SEC}s")"
        _rows="${_rows}$(_s "Anlik Durum")"
        _rows="${_rows}$(_r "Load" "${_load}")"
        _rows="${_rows}$(_r "RAM Bos" "${_ram_free} MB")"
        _rows="${_rows}$(_r "Disk /opt" "${_disk}%")"
        _rows="${_rows}$(_r "Zapret" "${_zst}")"
        printf '{"ok":1,"data":"%s"}' "$(printf '%s' "$_rows" | sed 's/"/\\"/g')" ;;
    tg_test)
        _kzm="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh"
        [ -f "$_kzm" ] || { fail "KZM script bulunamadi"; exit 0; }
        ZKM_SKIP_LOCK=1 sh "$_kzm" --cgi-action tg_test >/dev/null 2>&1
        ok "Test mesaji gonderildi" ;;
    tg_start)
        _kzm="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh"
        [ -f "$_kzm" ] || { fail "KZM script bulunamadi"; exit 0; }
        _tg_en="$(grep -s '^TG_BOT_ENABLE=' /opt/etc/telegram.conf | cut -d= -f2 | tr -d '"')"
        [ "$_tg_en" != "1" ] && { fail "Bot yapilandirilmamis"; exit 0; }
        _pid_f="/tmp/zkm_telegram_bot.pid"
        if [ -f "$_pid_f" ] && kill -0 "$(cat "$_pid_f" 2>/dev/null)" 2>/dev/null; then
            ok "Bot zaten calisiyor"; exit 0
        fi
        _log="/tmp/zkm_telegram_bot.log"
        if command -v nohup >/dev/null 2>&1; then
            nohup sh "$_kzm" --telegram-daemon </dev/null >>"$_log" 2>&1 &
        else
            sh "$_kzm" --telegram-daemon </dev/null >>"$_log" 2>&1 &
        fi
        echo $! > "$_pid_f"
        ok "Bot baslatildi" ;;
    tg_stop)
        _pid_f="/tmp/zkm_telegram_bot.pid"
        if [ -f "$_pid_f" ]; then
            _pid="$(cat "$_pid_f" 2>/dev/null)"
            if [ -n "$_pid" ]; then
                kill "$_pid" 2>/dev/null || true
                kill -9 "$_pid" 2>/dev/null || true
            fi
            rm -f "$_pid_f" 2>/dev/null
        fi
        # PID dosyasi disinda kalan --telegram-daemon processleri de temizle
        ps 2>/dev/null | awk '/--telegram-daemon/ && !/awk/{print $1}' | \
            while IFS= read -r _p; do kill -9 "$_p" 2>/dev/null || true; done
        ok "Bot durduruldu" ;;
    tg_info)
        _tok="$(grep -s '^TG_BOT_TOKEN=' /opt/etc/telegram.conf | cut -d= -f2 | tr -d '"')"
        _chat="$(grep -s '^TG_CHAT_ID=' /opt/etc/telegram.conf | cut -d= -f2 | tr -d '"')"
        _tok_m=""; _chat_m=""
        if [ -n "$_tok" ]; then
            _tok_pfx="$(printf '%s' "$_tok" | cut -c1-6)"
            _tok_m="${_tok_pfx}...****"
        fi
        if [ -n "$_chat" ]; then
            _clen="${#_chat}"
            if [ "$_clen" -gt 4 ]; then
                _chat_sfx="$(printf '%s' "$_chat" | sed 's/.*\(....\)$/\1/')"
                _chat_m="****${_chat_sfx}"
            else
                _chat_m="****"
            fi
        fi
        printf '{"ok":1,"token":"%s","chat":"%s"}' "$_tok_m" "$_chat_m" ;;
    health_run)
        _kzm="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh"
        [ -f "$_kzm" ] || { fail "KZM script bulunamadi"; exit 0; }
        printf '{"running":1}\n' > /tmp/kzm_health_result.json
        ZKM_SKIP_LOCK=1 sh "$_kzm" --cgi-action health_run_bg >/dev/null 2>&1 &
        ok "Saglik kontrolu baslatildi" ;;
    health_get)
        _hf="/tmp/kzm_health_result.json"
        if [ -f "$_hf" ]; then
            cat "$_hf"
        else
            printf '{"ok":0,"msg":"Sonuc bulunamadi. Once calistirin."}'
        fi ;;
    dpi_get)
        _p=$(cat "$DPI_FILE" 2>/dev/null | tr -d '\n'); [ -z "$_p" ] && _p="tt_default"
        case "$_p" in
            tt_default)     _n="Turk Telekom Fiber (TTL2 fake)" ;;
            tt_fiber)       _n="Turk Telekom Fiber (TTL4 fake)" ;;
            tt_alt)         _n="KabloNet (TTL3 fake)" ;;
            sol)            _n="Superonline (fake + m5sig)" ;;
            sol_alt)        _n="Superonline Alternatif (TTL3 fake)" ;;
            sol_fiber)      _n="Superonline Fiber (TTL5 fake + badsum)" ;;
            turkcell_mob)   _n="Turkcell Mobil (TTL1 + AutoTTL3)" ;;
            vodafone_mob)   _n="Vodafone Mobil (multisplit)" ;;
            blockcheck_auto) _n="Blockcheck Otomatik (Auto)" ;;
            *)              _n="$_p" ;;
        esac
        printf '{"ok":1,"data":"%s","name":"%s"}' "$_p" "$_n" ;;
    dpi_set)
        _p=$(get_param profile)
        [ -z "$_p" ] && { fail "Profil belirtilmedi"; exit 0; }
        case "$_p" in
            tt_default|tt_fiber|tt_alt|sol|sol_alt|sol_fiber|turkcell_mob|vodafone_mob|blockcheck_auto) ;;
            *) fail "Gecersiz profil: $_p"; exit 0 ;;
        esac
        _kzm="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh"
        [ -f "$_kzm" ] || { fail "KZM script bulunamadi"; exit 0; }
        ZKM_SKIP_LOCK=1 sh "$_kzm" --cgi-action dpi_set "$_p" >/dev/null 2>&1 &
        sleep 3; refresh; ok "Profil ${_p} ayarlandi ve Zapret yeniden baslatildi" ;;
    hl_get)
        ok_data "$(json_arr "$HL_USER")" ;;
    hl_add)
        _d=$(get_param domain); [ -z "$_d" ] && { fail "Domain bos"; exit 0; }
        grep -qxF "$_d" "$HL_USER" 2>/dev/null || printf '%s\n' "$_d" >> "$HL_USER"
        ok "Eklendi: $_d" ;;
    hl_del)
        _d=$(get_param domain); [ -z "$_d" ] && { fail "Domain bos"; exit 0; }
        sed -i "/^$(printf '%s' "$_d" | sed 's/[.[\*^$]/\\&/g')$/d" "$HL_USER" 2>/dev/null
        ok "Silindi: $_d" ;;
    ex_get)
        ok_data "$(json_arr "$HL_EXCL")" ;;
    ex_add)
        _d=$(get_param domain); [ -z "$_d" ] && { fail "Domain bos"; exit 0; }
        grep -qxF "$_d" "$HL_EXCL" 2>/dev/null || printf '%s\n' "$_d" >> "$HL_EXCL"
        ok "Eklendi: $_d" ;;
    ex_del)
        _d=$(get_param domain); [ -z "$_d" ] && { fail "Domain bos"; exit 0; }
        sed -i "/^$(printf '%s' "$_d" | sed 's/[.[\*^$]/\\&/g')$/d" "$HL_EXCL" 2>/dev/null
        ok "Silindi: $_d" ;;
    auto_get)
        ok_data "$(json_arr "/opt/zapret/ipset/zapret-hosts-auto.txt")" ;;
    nozapret_get)
        ok_data "$(json_arr "/opt/zapret/ipset/nozapret.txt")" ;;
    ipset_active_get)
        _members="$(ipset list zapret_clients 2>/dev/null | awk '/^Members:/{found=1;next} found && NF{print}' | sort)"
        if [ -z "$_members" ]; then
            ok_data "[]"
        else
            _json="$(printf '%s\n' "$_members" | awk 'BEGIN{printf "["} NR>1{printf ","} {printf "\"%s\"",$0} END{print "]"}')"
            ok_data "$_json"
        fi ;;
    ip_get)
        ok_data "$(json_arr "$IPSET_FILE")" ;;
    ip_add)
        _ip=$(get_param ip); [ -z "$_ip" ] && { fail "IP bos"; exit 0; }
        grep -qxF "$_ip" "$IPSET_FILE" 2>/dev/null || printf '%s\n' "$_ip" >> "$IPSET_FILE"
        ok "Eklendi: $_ip" ;;
    ip_del)
        _ip=$(get_param ip); [ -z "$_ip" ] && { fail "IP bos"; exit 0; }
        sed -i "/^$(printf '%s' "$_ip" | sed 's/[.[\*^$]/\\&/g')$/d" "$IPSET_FILE" 2>/dev/null
        ok "Silindi: $_ip" ;;
    sched_get)
        _line=$(crontab -l 2>/dev/null | grep "$SCHED_TAG" 2>/dev/null)
        [ -z "$_line" ] && { printf '{"ok":1,"data":""}'; exit 0; }
        _h=$(printf '%s' "$_line" | awk '{print $2}')
        _m=$(printf '%s' "$_line" | awk '{print $1}')
        _dow=$(printf '%s' "$_line" | awk '{print $5}')
        printf '{"ok":1,"data":"%02d:%02d","dow":"%s"}' "$_h" "$_m" "$_dow" ;;
    sched_set)
        _t=$(get_param time); [ -z "$_t" ] && { fail "Saat bos"; exit 0; }
        _dow=$(get_param dow); [ -z "$_dow" ] && _dow="*"
        case "$_dow" in [0-6]|"*") ;; *) _dow="*" ;; esac
        _h=$(printf '%s' "$_t" | cut -d: -f1 | sed 's/^0*//')
        _m=$(printf '%s' "$_t" | cut -d: -f2 | sed 's/^0*//')
        [ -z "$_h" ] && _h=0; [ -z "$_m" ] && _m=0
        _tmp="/tmp/kzm_cron_set.$$"
        crontab -l 2>/dev/null | grep -v "$SCHED_TAG" > "$_tmp"
        printf '%s %s * * %s LD_LIBRARY_PATH= ndmc -c "system reboot" %s\n' "$_m" "$_h" "$_dow" "$SCHED_TAG" >> "$_tmp"
        crontab "$_tmp"; rm -f "$_tmp"
        ok "Zamanlama ayarlandi: $_t (dow:$_dow)" ;;
    sched_del)
        _tmp="/tmp/kzm_cron_del.$$"
        crontab -l 2>/dev/null | grep -v "$SCHED_TAG" > "$_tmp"
        crontab "$_tmp"; rm -f "$_tmp"
        ok "Zamanlama kaldirildi" ;;
    backup_settings)
        _dir="/opt/zapret_backups/zapret_settings"
        mkdir -p "$_dir" 2>/dev/null
        _ts=$(date +%Y%m%d_%H%M%S 2>/dev/null)
        _f="$_dir/zapret_settings_${_ts}.tar.gz"
        _rels=""
        _ar() { [ -e "$1" ] && _rels="$_rels ${1#/}"; }
        _ar /opt/zapret/config
        _ar /opt/zapret/wan_if
        _ar /opt/zapret/lang
        _ar /opt/zapret/hostlist_mode
        _ar /opt/zapret/scope_mode
        _ar /opt/zapret/ipset_clients.txt
        _ar /opt/zapret/ipset_clients_mode
        _ar /opt/zapret/dpi_profile
        _ar /opt/zapret/dpi_profile_origin
        _ar /opt/zapret/dpi_profile_params
        _ar /opt/zapret/blockcheck_auto_params
        _ar /opt/etc/healthmon.conf
        _ar /opt/etc/telegram.conf
        for _xf in /opt/zapret/ipset/*.txt; do [ -e "$_xf" ] && _rels="$_rels ${_xf#/}"; done
        [ -z "$(printf '%s' "$_rels" | tr -d ' ')" ] && { fail "Yedeklenecek dosya yok"; exit 0; }
        tar -C / -czf "$_f" $_rels 2>/dev/null
        [ -f "$_f" ] && [ -s "$_f" ] && ok "Yedeklendi: zapret_settings_${_ts}.tar.gz" || { rm -f "$_f" 2>/dev/null; fail "Yedekleme basarisiz"; } ;;
    ipset_backup)
        _src="/opt/zapret/ipset"
        _cur="/opt/zapret_backups/current"
        _hist="/opt/zapret_backups/history"
        mkdir -p "$_cur" "$_hist" 2>/dev/null
        ! ls "$_src"/*.txt >/dev/null 2>&1 && { fail "IPSET dosyasi bulunamadi"; exit 0; }
        _ts=$(date +%Y%m%d_%H%M%S 2>/dev/null)
        mkdir -p "$_hist/$_ts" 2>/dev/null
        _count=0
        for _xf in "$_src"/*.txt; do
            [ -f "$_xf" ] || continue
            cp -a "$_xf" "$_cur/$(basename "$_xf")" 2>/dev/null
            cp -a "$_xf" "$_hist/$_ts/$(basename "$_xf")" 2>/dev/null
            _count=$((_count+1))
        done
        ok "IPSET yedeklendi: $_count dosya" ;;
    ipset_list)
        _cur="/opt/zapret_backups/current"
        _hist="/opt/zapret_backups/history"
        _files=""
        if ls "$_cur"/*.txt >/dev/null 2>&1; then
            for _xf in "$_cur"/*.txt; do
                [ -f "$_xf" ] || continue
                _bn=$(basename "$_xf")
                _sz=$(wc -l < "$_xf" 2>/dev/null || echo "?")
                _files="${_files}${_bn}:${_sz}|"
            done
        fi
        _hlist="$(ls -1 "$_hist" 2>/dev/null | tail -n 5 | tr '\n' '|' | sed 's/|$//')"
        printf '{"ok":1,"files":"%s","history":"%s"}' "$_files" "$_hlist" ;;
    ipset_restore)
        _fn=$(get_param file); [ -z "$_fn" ] && { fail "Dosya belirtilmedi"; exit 0; }
        _cur="/opt/zapret_backups/current"
        _dst="/opt/zapret/ipset"
        _src="$_cur/$_fn"
        [ -f "$_src" ] || { fail "Dosya bulunamadi: $_fn"; exit 0; }
        mkdir -p "$_dst" 2>/dev/null
        cp -a "$_src" "$_dst/$_fn" 2>/dev/null || { fail "Geri yukleme basarisiz"; exit 0; }
        _kzm="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh"
        ZKM_SKIP_LOCK=1 sh "$_kzm" --cgi-action zapret_restart >/dev/null 2>&1 &
        ok "Geri yuklendi: $_fn" ;;
    settings_list)
        _dir="/opt/zapret_backups/zapret_settings"
        if ! ls "$_dir"/*.tar.gz >/dev/null 2>&1; then
            printf '{"ok":1,"data":[]}'
        else
            _json="$(ls -1t "$_dir"/*.tar.gz 2>/dev/null | head -10 | \
                awk 'BEGIN{printf "["} NR>1{printf ","} {f=$0; gsub(/.*\//,"",f); printf "{\"path\":\"%s\",\"name\":\"%s\"}",$0,f} END{print "]"}')"
            printf '{"ok":1,"data":%s}' "$_json"
        fi ;;
    settings_restore)
        _f=$(get_param file); [ -z "$_f" ] && { fail "Dosya belirtilmedi"; exit 0; }
        _scope=$(get_param scope); [ -z "$_scope" ] && _scope="1"
        [ -f "$_f" ] || { fail "Arsiv bulunamadi"; exit 0; }
        _tmp="/tmp/zapret_restore_cgi.$$"
        rm -rf "$_tmp" 2>/dev/null
        mkdir -p "$_tmp" || { fail "Gecici dizin olusturulamadi"; exit 0; }
        tar -xzf "$_f" -C "$_tmp" >/dev/null 2>&1 || { rm -rf "$_tmp"; fail "Arsiv acma basarisiz"; exit 0; }
        _tsrc="$_tmp"
        [ -d "$_tmp/opt" ] || { for _td in "$_tmp"/*; do [ -d "$_td/opt" ] && _tsrc="$_td" && break; done; }
        _cpif() { _sp="$_tsrc/$1"; if [ -d "$_sp" ]; then mkdir -p "/$1" 2>/dev/null; cp -a "$_sp/." "/$1/" 2>/dev/null; elif [ -e "$_sp" ]; then mkdir -p "/$(dirname "$1")" 2>/dev/null; cp -a "$_sp" "/$1" 2>/dev/null; fi; }
        case "$_scope" in
            1) cp -a "$_tsrc/"* / 2>/dev/null ;;
            2) _cpif opt/zapret/config; _cpif opt/zapret/lang; _cpif opt/zapret/wan_if
               _cpif opt/zapret/dpi_profile; _cpif opt/zapret/dpi_profile_origin
               _cpif opt/zapret/dpi_profile_params; _cpif opt/zapret/blockcheck_auto_params ;;
            3) _cpif opt/zapret/hostlist_mode; _cpif opt/zapret/scope_mode; _cpif opt/zapret/ipset ;;
            4) _cpif opt/zapret/ipset_clients.txt; _cpif opt/zapret/ipset_clients_mode; _cpif opt/zapret/ipset ;;
        esac
        rm -rf "$_tmp" 2>/dev/null
        _kzm="/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh"
        ZKM_SKIP_LOCK=1 sh "$_kzm" --cgi-action zapret_restart >/dev/null 2>&1 &
        ok "Geri yuklendi (kapsam:$_scope)" ;;
    status_refresh)
        refresh; ok "Durum guncellendi" ;;
    opkg_update)
        if opkg update >/dev/null 2>&1; then
            _upgradable="$(opkg list-upgradable 2>/dev/null)"
            _count=0
            [ -n "$_upgradable" ] && _count="$(printf '%s\n' "$_upgradable" | grep -c .)"
            printf '{"ok":1,"count":%s}' "$_count"
        else
            fail "opkg update basarisiz"
        fi ;;
    opkg_upgrade)
        if opkg upgrade >/dev/null 2>&1; then
            ok "opkg upgrade tamamlandi"
        else
            fail "opkg upgrade basarisiz"
        fi ;;
    *)
        fail "Bilinmeyen action: $ACTION" ;;
esac
CGIEOF
    chmod +x "$KZM_GUI_CGI"
}

# ---------------------------------------------------------------------------
# kzm_gui_write_lighttpd_conf: lighttpd.conf olustur
# ---------------------------------------------------------------------------
kzm_gui_write_lighttpd_conf() {
    mkdir -p /opt/etc/lighttpd /opt/var/run 2>/dev/null
    cat > "$KZM_GUI_CONF" << CONFEOF
server.document-root = "/opt/www/kzm"
server.port          = $KZM_GUI_PORT
server.bind          = "0.0.0.0"
server.pid-file      = "/opt/var/run/lighttpd.pid"

server.modules = (
  "mod_alias",
  "mod_cgi",
  "mod_setenv"
)

index-file.names = ( "index.html" )

mimetype.assign = (
  ".html" => "text/html; charset=utf-8",
  ".js"   => "application/javascript",
  ".json" => "application/json",
  ".css"  => "text/css",
  ".ico"  => "image/x-icon"
)

setenv.add-response-header = (
  "Cache-Control" => "no-cache, no-store, must-revalidate",
  "Pragma"        => "no-cache",
  "Expires"       => "0"
)

alias.url = ( "/run/" => "/opt/var/run/" )

\$HTTP["url"] =~ "^/cgi-bin/" {
  cgi.assign = ( ".sh" => "/bin/sh" )
}
CONFEOF
}

# ---------------------------------------------------------------------------
# kzm_gui_write_html: /opt/www/kzm/index.html yaz
# NOT: Turkce karakterler HTML entity olarak yazilmistir (self-test uyumu)
# ---------------------------------------------------------------------------
kzm_gui_write_html() {
    mkdir -p "$KZM_GUI_DIR" 2>/dev/null
    cat > "$KZM_GUI_HTML" << 'HTMLEOF'
<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8"/>
<meta name="kzm-version" content="__KZM_VER__"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate"/>
<meta http-equiv="Pragma" content="no-cache"/>
<meta http-equiv="Expires" content="0"/>
<title>KZM Control Panel</title>
<link rel="icon" type="image/svg+xml" href="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA2NCA2NCI+PHJlY3Qgd2lkdGg9IjY0IiBoZWlnaHQ9IjY0IiByeD0iMTIiIGZpbGw9IiMzMzRlYWMiLz48dGV4dCB4PSIzMiIgeT0iNDYiIGZvbnQtZmFtaWx5PSJBcmlhbCxzYW5zLXNlcmlmIiBmb250LXNpemU9IjM4IiBmb250LXdlaWdodD0iYm9sZCIgZmlsbD0id2hpdGUiIHRleHQtYW5jaG9yPSJtaWRkbGUiPks8L3RleHQ+PC9zdmc+"/>
<style>
:root{
  --bg:#0b1220;--panel:#0f1b33;--card:#111f3d;
  --text:#e7eefc;--muted:#a9b7d6;--line:rgba(231,238,252,.10);
  --accent:#4b7dff;--good:#2ecc71;--warn:#f1c40f;--bad:#e74c3c;
  --radius:14px;--mono:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace;
  --sw:240px;--swc:54px;--str:.22s cubic-bezier(.4,0,.2,1);
}
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,Arial;
  background:radial-gradient(1200px 600px at 20% -10%,rgba(75,125,255,.22),transparent 55%),
             linear-gradient(180deg,#081022,#070d18);
  color:var(--text);min-height:100vh;}
.app{display:grid;grid-template-columns:var(--sw) 1fr;min-height:100vh;transition:grid-template-columns var(--str);}
.app.sb-off{grid-template-columns:var(--swc) 1fr;}
aside{border-right:1px solid var(--line);
  background:linear-gradient(180deg,rgba(15,27,51,.97),rgba(12,23,48,.97));
  padding:12px 8px;position:sticky;top:0;height:100vh;overflow:hidden;
  display:flex;flex-direction:column;gap:2px;
  width:var(--sw);transition:width var(--str);position:relative;}
.app.sb-off aside{width:var(--swc);}
.sb-toggle{position:absolute;top:14px;right:-11px;width:22px;height:22px;border-radius:50%;
  background:var(--accent);border:1px solid rgba(75,125,255,.5);display:grid;place-items:center;
  cursor:pointer;color:#fff;font-size:13px;font-weight:700;z-index:50;
  transition:background .15s,transform var(--str),box-shadow .15s;line-height:1;user-select:none;
  box-shadow:0 0 8px rgba(75,125,255,.5);}
.sb-toggle:hover{background:rgba(75,125,255,.8);box-shadow:0 0 14px rgba(75,125,255,.7);}
.app.sb-off .sb-toggle{transform:rotate(180deg);}
.brand{display:flex;gap:10px;align-items:center;padding:6px 4px 12px;
  border-bottom:1px solid var(--line);margin-bottom:8px;overflow:hidden;}
.logo{width:32px;height:32px;border-radius:9px;flex-shrink:0;
  background:linear-gradient(135deg,rgba(75,125,255,.95),rgba(75,125,255,.3));
  display:grid;place-items:center;font-weight:800;font-size:15px;
  cursor:pointer;transition:opacity .15s;}
.logo:hover{opacity:.75;}
.brand-text{overflow:hidden;white-space:nowrap;transition:opacity var(--str),max-width var(--str);max-width:180px;}
.app.sb-off aside .brand-text{opacity:0;max-width:0;}
.brand h1{font-size:13px;font-weight:700;white-space:nowrap;}
.brand small{display:block;color:var(--muted);font-size:10px;margin-top:1px;white-space:nowrap;}
nav{display:flex;flex-direction:column;gap:2px;padding:0 2px;}
.sec{color:rgba(169,183,214,.65);font-size:10px;letter-spacing:.12em;
  margin:8px 4px 2px;text-transform:uppercase;font-weight:600;
  white-space:nowrap;overflow:hidden;transition:opacity var(--str);}
.app.sb-off aside .sec{opacity:0;}
.item{display:flex;align-items:center;gap:9px;
  padding:8px 9px;border-radius:9px;border:1px solid transparent;cursor:pointer;
  user-select:none;transition:.12s ease;overflow:hidden;white-space:nowrap;position:relative;}
.item:hover{border-color:rgba(75,125,255,.2);background:rgba(75,125,255,.08);}
.item.active{border-color:rgba(75,125,255,.5);background:rgba(75,125,255,.12);}
.item-icon{font-size:15px;flex-shrink:0;width:20px;text-align:center;}
.item-label{font-size:12.5px;flex:1;white-space:nowrap;overflow:hidden;
  transition:opacity var(--str),max-width var(--str);max-width:150px;}
.app.sb-off aside .item-label{opacity:0;max-width:0;}
.pill{font-size:10px;color:var(--muted);padding:1px 6px;border-radius:999px;
  border:1px solid var(--line);white-space:nowrap;flex-shrink:0;
  transition:opacity var(--str);margin-left:auto;}
.app.sb-off aside .pill{opacity:0;width:0;padding:0;border:none;margin:0;}
.tip{display:none;position:fixed;
  background:rgba(15,27,51,.97);border:1px solid var(--line);border-radius:7px;
  padding:5px 10px;font-size:12px;white-space:nowrap;color:var(--text);
  pointer-events:none;box-shadow:0 4px 16px rgba(0,0,0,.5);z-index:9999;}
.app.sb-off .item:hover .tip{display:block;}
.fnote{padding:10px 4px 4px;color:var(--muted);font-size:11px;
  border-top:1px solid var(--line);margin-top:auto;
  white-space:nowrap;overflow:hidden;transition:opacity var(--str);}
.app.sb-off aside .fnote{opacity:0;}
main{display:flex;flex-direction:column;min-height:100vh}
header{display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:8px;
  padding:14px 22px;border-bottom:1px solid var(--line);
  background:rgba(11,18,32,.75);backdrop-filter:blur(12px);
  position:sticky;top:0;z-index:10;}
.title h2{font-size:17px;font-weight:700}
.title small{color:var(--muted);font-size:11px}
.meta{display:flex;flex-wrap:wrap;gap:14px;font-size:12px;color:var(--muted);align-items:center}
.meta b{color:var(--text)}
.good{color:var(--good)!important}.bad{color:var(--bad)!important}.warn{color:var(--warn)!important}
#view{padding:18px 22px;flex:1}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(270px,1fr));gap:14px}
.card{background:var(--card);border:1px solid var(--line);border-radius:var(--radius);
  padding:16px 16px 13px;display:flex;flex-direction:column;gap:10px;}
.card.wide{grid-column:1/-1}
.card h3{font-size:13px;color:var(--muted);font-weight:600;letter-spacing:.04em}
.big{font-size:30px;font-weight:800;letter-spacing:-.02em}
.sub{font-size:12px;color:var(--muted);line-height:1.5}
.row{display:flex;flex-wrap:wrap;gap:7px;align-items:center}
.badge{display:inline-block;font-size:11px;font-weight:700;padding:3px 9px;
  border-radius:999px;letter-spacing:.03em;}
.badge.good{background:rgba(46,204,113,.15);color:var(--good);border:1px solid rgba(46,204,113,.3)}
.badge.bad{background:rgba(231,76,60,.15);color:var(--bad);border:1px solid rgba(231,76,60,.3)}
.badge.warn{background:rgba(241,196,15,.12);color:var(--warn);border:1px solid rgba(241,196,15,.25)}
.badge.off{background:rgba(169,183,214,.1);color:var(--muted);border:1px solid var(--line)}
.btns{display:flex;flex-wrap:wrap;gap:7px;margin-top:2px}
button{font-size:12px;padding:6px 13px;border-radius:7px;border:none;cursor:pointer;
  font-weight:600;transition:.13s;background:var(--accent);color:#fff;}
button:hover{opacity:.85}button:disabled{opacity:.35;cursor:not-allowed}
button.ghost{background:rgba(75,125,255,.13);color:var(--accent);border:1px solid rgba(75,125,255,.3)}
button.ghost:hover{background:rgba(75,125,255,.22)}
button.danger{background:rgba(231,76,60,.18);color:var(--bad);border:1px solid rgba(231,76,60,.35)}
button.danger:hover{background:rgba(231,76,60,.3)}
button.ok{background:rgba(46,204,113,.18);color:var(--good);border:1px solid rgba(46,204,113,.35)}
button.ok:hover{background:rgba(46,204,113,.28)}
.progress{background:rgba(255,255,255,.06);border-radius:999px;height:5px;overflow:hidden}
.bar{height:100%;border-radius:999px;background:var(--accent);transition:.4s}
.bar.good{background:var(--good)}.bar.warn{background:var(--warn)}.bar.bad{background:var(--bad)}
.hint{font-size:11px;color:rgba(169,183,214,.55)}
.info-grid{border:1px solid var(--line);border-radius:10px;overflow:hidden;background:rgba(0,0,0,.1)}
.info-sec{padding:6px 11px;font-size:11px;font-weight:700;letter-spacing:.06em;color:var(--muted);background:rgba(255,255,255,.04);border-bottom:1px solid var(--line);text-transform:uppercase}
.info-row{display:grid;grid-template-columns:200px 1fr;border-bottom:1px solid var(--line)}
.info-row:last-child{border-bottom:none}
.info-row .lbl{padding:8px 11px;color:var(--muted);font-size:12.5px}
.info-row .val{padding:8px 11px;font-size:12.5px}
.spinner{display:inline-block;width:11px;height:11px;border:2px solid rgba(255,255,255,.25);
  border-top-color:#fff;border-radius:50%;animation:spin .7s linear infinite;margin-right:5px;vertical-align:middle;}
@keyframes spin{to{transform:rotate(360deg)}}
.toast{position:fixed;bottom:20px;right:20px;z-index:999;padding:11px 16px;
  border-radius:9px;font-size:12.5px;font-weight:600;opacity:0;transition:.3s;pointer-events:none;}
.toast.show{opacity:1}
.toast.ok{background:rgba(46,204,113,.95);color:#fff}
.toast.err{background:rgba(231,76,60,.95);color:#fff}
.rbtn{font-size:11px;padding:4px 9px;background:rgba(75,125,255,.13);
  color:var(--accent);border:1px solid rgba(75,125,255,.28);border-radius:6px;cursor:pointer;}
.ts{font-size:11px;color:rgba(169,183,214,.45)}
.irow{display:flex;gap:7px;align-items:center;flex-wrap:wrap}
input[type=text],input[type=number],select{
  background:rgba(0,0,0,.3);border:1px solid var(--line);border-radius:7px;
  color:var(--text);padding:6px 10px;font-size:12.5px;outline:none;transition:.12s;}
input:focus,select:focus{border-color:rgba(75,125,255,.5)}
select option{background:#111f3d}
.li{display:flex;justify-content:space-between;align-items:center;
  padding:7px 10px;border-bottom:1px solid var(--line);font-size:12.5px;}
.li:last-child{border-bottom:none}
.lw{border:1px solid var(--line);border-radius:9px;overflow:hidden;
  background:rgba(0,0,0,.15);max-height:240px;overflow-y:auto;}
.empty{padding:20px;text-align:center;color:var(--muted);font-size:12px}
.tag{display:inline-block;font-size:10px;padding:2px 7px;border-radius:999px;
  background:rgba(75,125,255,.15);color:var(--accent);border:1px solid rgba(75,125,255,.25);}
</style>
</head>
<body>
<div class="app" id="kzmApp">
<aside>
  <div class="sb-toggle" onclick="sbToggle()" title="Sidebar">&#8249;</div>
  <div class="brand">
    <div class="logo" onclick="sbToggle()">K</div>
    <div class="brand-text"><h1>KZM Control Panel</h1><small>Keenetic &bull; Entware &bull; __KZM_PORT__</small></div>
  </div>
  <div class="sec">GENEL</div>
  <nav>
    <div class="item active" data-view="dash"><span class="item-icon">&#9783;</span><span class="item-label">Dashboard</span><span class="pill">Live</span><span class="tip">Dashboard</span></div>
  </nav>
  <div class="sec">ZAPRET Y&#214;NET&#304;M&#304;</div>
  <nav>
    <div class="item" data-view="zapret"><span class="item-icon">&#8644;</span><span class="item-label">Zapret Kontrol</span><span class="pill">3-5</span><span class="tip">Zapret Kontrol</span></div>
    <div class="item" data-view="dpi"><span class="item-icon">&#9889;</span><span class="item-label">DPI Profili</span><span class="pill">9</span><span class="tip">DPI Profili</span></div>
    <div class="item" data-view="hostlist"><span class="item-icon">&#9776;</span><span class="item-label">Hostlist</span><span class="pill">11</span><span class="tip">Hostlist</span></div>
    <div class="item" data-view="ipset"><span class="item-icon">&#9636;</span><span class="item-label">IPSET</span><span class="pill">12</span><span class="tip">IPSET</span></div>
  </nav>
  <div class="sec">SERV&#304;SLER</div>
  <nav>
    <div class="item" data-view="healthmon"><span class="item-icon">&#9829;</span><span class="item-label">Sistem &#304;zleme</span><span class="pill">16</span><span class="tip">Sistem &#304;zleme</span></div>
    <div class="item" data-view="healthcheck"><span class="item-icon">&#9906;</span><span class="item-label">Ag Tanilama</span><span class="pill">14</span><span class="tip">Ag Tanilama</span></div>
    <div class="item" data-view="telegram"><span class="item-icon">&#9992;</span><span class="item-label">Telegram</span><span class="pill">15</span><span class="tip">Telegram</span></div>
  </nav>
  <div class="sec">D&#304;&#286;ER</div>
  <nav>
    <div class="item" data-view="sched"><span class="item-icon">&#9719;</span><span class="item-label">Zamanl&#305; Reboot</span><span class="pill">R</span><span class="tip">Zamanl&#305; Reboot</span></div>
    <div class="item" data-view="backup"><span class="item-icon">&#128190;</span><span class="item-label">Yedekle</span><span class="pill">8</span><span class="tip">Yedekle</span></div>
  </nav>
  <div class="fnote">KZM Web Panel<br/><small id="atick">Otomatik yenileme: 15s</small></div>
</aside>

<main>
  <header>
    <div class="title"><h2 id="pTitle">Dashboard</h2><small id="pSub">Canl&#305; sistem &#246;zeti.</small></div>
    <div class="meta">
      <span>WAN: <b id="hWan">&#8212;</b></span>
      <span>Load: <b id="hLoad">&#8212;</b></span>
      <span>KZM: <b id="hVer">&#8212;</b></span>
      <span>Zapret: <b id="hZap">&#8212;</b></span>
      <button class="rbtn" onclick="act('status_refresh',null,'');setTimeout(fetchS,800);">&#8635; Yenile</button>
      <span class="ts" id="tsLbl"></span>
    </div>
  </header>
  <div id="view"><div style="padding:40px;color:var(--muted);text-align:center">Y&#252;kleniyor...</div></div>
</main>
</div>
<div class="toast" id="toast"></div>

<script>
var S=null,curV='dash',aTimer=null;

function sbToggle(){
  var a=document.getElementById('kzmApp');
  var collapsed=a.classList.toggle('sb-off');
  try{localStorage.setItem('kzm_sb',collapsed?'0':'1');}catch(e){}
}
(function(){
  try{if(localStorage.getItem('kzm_sb')==='0')document.getElementById('kzmApp').classList.add('sb-off');}catch(e){}
})();
document.addEventListener('mouseover',function(e){
  var item=e.target.closest('.item');
  if(!item)return;
  var app=document.getElementById('kzmApp');
  if(!app.classList.contains('sb-off'))return;
  var tip=item.querySelector('.tip');
  if(!tip)return;
  var r=item.getBoundingClientRect();
  tip.style.top=(r.top+r.height/2-14)+'px';
  tip.style.left=(r.right+6)+'px';
});

function toast(msg,ok){
  var t=document.getElementById('toast');
  t.textContent=msg;t.className='toast '+(ok?'ok':'err')+' show';
  clearTimeout(t._t);t._t=setTimeout(function(){t.className='toast';},3000);
}

function fetchS(){
  return fetch('/run/kzm_status.json?t='+Date.now())
    .then(function(r){return r.json();})
    .then(function(d){
      S=d;updHdr();if(curV==='dash')render(curV);
      var dt=new Date(d.ts*1000);
      document.getElementById('tsLbl').textContent=dt.toLocaleTimeString('tr-TR');
    })
    .catch(function(){
      if(!S)document.getElementById('view').innerHTML=
        '<div style="padding:40px;color:var(--bad);text-align:center">Status JSON okunamad&#305;. kzm_status_gen.sh &#231;al&#305;&#351;&#305;yor mu?</div>';
    });
}

function startAuto(){clearInterval(aTimer);aTimer=setInterval(fetchS,15000);}

function quickPoll(times,interval){
  var n=0;
  var t=setInterval(function(){
    fetchS();n++;
    if(n>=times){clearInterval(t);startAuto();}
  },interval);
}

function act(action,btn,msg){
  if(btn){btn._o=btn.innerHTML;btn.disabled=true;btn.innerHTML='<span class="spinner"></span>';}
  fetch('/cgi-bin/action.sh',{method:'POST',
    headers:{'Content-Type':'application/x-www-form-urlencoded'},
    body:'action='+action})
  .then(function(r){return r.json();})
  .then(function(res){
    toast(res.msg||msg,!!res.ok);
    if(btn){btn.disabled=false;btn.innerHTML=btn._o;}
    clearInterval(aTimer);
    fetchS();
    quickPoll(5,2000);
  })
  .catch(function(){toast('Ba&#287;lant&#305; hatas&#305;',false);if(btn){btn.disabled=false;btn.innerHTML=btn._o;}});
}

function actD(action,data,btn,msg){
  if(btn){btn._o=btn.innerHTML;btn.disabled=true;btn.innerHTML='<span class="spinner"></span>';}
  fetch('/cgi-bin/action.sh',{method:'POST',
    headers:{'Content-Type':'application/x-www-form-urlencoded'},
    body:'action='+action+'&'+data})
  .then(function(r){return r.json();})
  .then(function(res){
    toast(res.msg||msg,!!res.ok);
    setTimeout(function(){if(btn){btn.disabled=false;btn.innerHTML=btn._o;}fetchS();},1500);
  })
  .catch(function(){toast('Ba&#287;lant&#305; hatas&#305;',false);if(btn){btn.disabled=false;btn.innerHTML=btn._o;}});
}

function getD(action,cb){
  fetch('/cgi-bin/action.sh',{method:'POST',
    headers:{'Content-Type':'application/x-www-form-urlencoded'},
    body:'action='+action})
  .then(function(r){return r.json();}).then(cb)
  .catch(function(e){cb({ok:0,msg:''+e});});
}

function updHdr(){
  if(!S)return;
  document.getElementById('hWan').textContent=S.wan_ip||'—';
  document.getElementById('hLoad').textContent=S.load1||'—';
  document.getElementById('hVer').textContent=S.kzm_version||'—';
  var z=document.getElementById('hZap');
  z.innerHTML=S.zapret_running?'<span class="good">AKT&#304;F</span>':'<span class="bad">PAS&#304;F</span>';
}

function bdg(on,a,b){return on?'<span class="badge good">'+(a||'AKT&#304;F')+'</span>':'<span class="badge bad">'+(b||'PAS&#304;F')+'</span>';}
function bdgO(on,a,b){return on?'<span class="badge good">'+(a||'AKT&#304;F')+'</span>':'<span class="badge off">'+(b||'KAPALI')+'</span>';}
function brr(p){var c=p>85?'bad':p>60?'warn':'good';return '<div class="progress"><div class="bar '+c+'" style="width:'+p+'%"></div></div>';}
function pct(u,t){return t?Math.round(u/t*100):0;}
function ir(l,v){return '<div class="info-row"><div class="lbl">'+l+'</div><div class="val">'+v+'</div></div>';}
function nd(){return '<div class="empty">Y&#252;kleniyor...</div>';}
function fmtKeenDns(a){var m={'direct':'<span style="color:var(--good)">&#9679; Direct</span>','cloud':'<span style="color:var(--warn)">&#9679; Cloud</span>'};return m[a]||'<span style="color:var(--bad)">&#9679; Unknown</span>';}
var opkgState={status:null,count:0,upgraded:false};

function fmtOpkgCard(){
  var statusHtml='Paket listesini yenilemek i&#231;in butona basin.';
  var upgradeShow='none';
  if(opkgState.status==='ok_current'){
    statusHtml='<span style="color:var(--good)">&#10003; Liste yenilendi. Tum paketler guncel.</span>';
  } else if(opkgState.status==='ok_upgradable'){
    statusHtml='<span style="color:var(--warn)">&#9888; Liste yenilendi. <b>'+opkgState.count+'</b> paket yukseltilmeyi bekliyor.</span>';
    upgradeShow='';
  } else if(opkgState.status==='upgraded'){
    statusHtml='<span style="color:var(--good)">&#10003; opkg upgrade tamamlandi.</span>';
  } else if(opkgState.status==='err'){
    statusHtml='<span style="color:var(--bad)">&#10007; Hata olustu.</span>';
  }
  return '<div class="card" id="opkgCard">'+
    '<h3>OPKG Paketleri</h3>'+
    '<div id="opkgStatus" style="font-size:12.5px;color:var(--muted);margin:8px 0 10px">'+statusHtml+'</div>'+
    '<div class="btns">'+
      '<button id="opkgUpdateBtn" onclick="opkgUpdate(this)">&#8635; Listeyi Yenile</button>'+
      '<button id="opkgUpgradeBtn" class="danger" style="display:'+upgradeShow+'" onclick="opkgUpgrade(this)">&#8679; Yukselt</button>'+
    '</div>'+
    '<div id="opkgWarn" style="display:none;margin-top:10px;padding:8px 10px;background:rgba(231,76,60,.12);border:1px solid rgba(231,76,60,.3);border-radius:7px;font-size:11.5px;color:var(--bad)">'+
      '&#9888; opkg upgrade Keenetic\'te sistem bozulmasina yol acabilir.<br>'+
      'Devam etmek istediginizden emin misiniz?<br>'+
      '<div class="btns" style="margin-top:8px">'+
        '<button class="danger" onclick="opkgUpgradeConfirm(this)">Evet, Yukselt</button>'+
        '<button class="ghost" onclick="document.getElementById(\'opkgWarn\').style.display=\'none\'">Iptal</button>'+
      '</div>'+
    '</div>'+
  '</div>';
}

function opkgUpdate(btn){
  btn.disabled=true;btn.innerHTML='<span class="spinner"></span> Yenileniyor...';
  document.getElementById('opkgStatus').innerHTML='<span class="spinner"></span> opkg update calistiriliyor...';
  document.getElementById('opkgUpgradeBtn').style.display='none';
  document.getElementById('opkgWarn').style.display='none';
  fetch('/cgi-bin/action.sh',{method:'POST',
    headers:{'Content-Type':'application/x-www-form-urlencoded'},
    body:'action=opkg_update'})
  .then(function(r){return r.json();})
  .then(function(d){
    btn.disabled=false;btn.innerHTML='&#8635; Listeyi Yenile';
    if(d.ok){
      var cnt=parseInt(d.count)||0;
      if(cnt===0){
        opkgState={status:'ok_current',count:0,upgraded:false};
        document.getElementById('opkgStatus').innerHTML=
          '<span style="color:var(--good)">&#10003; Liste yenilendi. Tum paketler guncel.</span>';
      } else {
        opkgState={status:'ok_upgradable',count:cnt,upgraded:false};
        document.getElementById('opkgStatus').innerHTML=
          '<span style="color:var(--warn)">&#9888; Liste yenilendi. <b>'+cnt+'</b> paket yukseltilmeyi bekliyor.</span>';
        document.getElementById('opkgUpgradeBtn').style.display='';
      }
    } else {
      opkgState={status:'err',count:0,upgraded:false};
      document.getElementById('opkgStatus').innerHTML=
        '<span style="color:var(--bad)">&#10007; '+(d.msg||'Hata')+'</span>';
    }
  })
  .catch(function(){
    btn.disabled=false;btn.innerHTML='&#8635; Listeyi Yenile';
    opkgState={status:'err',count:0,upgraded:false};
    document.getElementById('opkgStatus').innerHTML='<span style="color:var(--bad)">&#10007; Baglanti hatasi</span>';
  });
}

function opkgUpgrade(btn){
  btn.style.display='none';
  document.getElementById('opkgWarn').style.display='';
}

function opkgUpgradeConfirm(btn){
  btn.disabled=true;btn.innerHTML='<span class="spinner"></span> Yukseltiliyor...';
  document.getElementById('opkgStatus').innerHTML='<span class="spinner"></span> opkg upgrade calistiriliyor, lutfen bekleyin...';
  fetch('/cgi-bin/action.sh',{method:'POST',
    headers:{'Content-Type':'application/x-www-form-urlencoded'},
    body:'action=opkg_upgrade'})
  .then(function(r){return r.json();})
  .then(function(d){
    document.getElementById('opkgWarn').style.display='none';
    if(d.ok){
      opkgState={status:'upgraded',count:0,upgraded:true};
      document.getElementById('opkgStatus').innerHTML=
        '<span style="color:var(--good)">&#10003; opkg upgrade tamamlandi.</span>';
      document.getElementById('opkgUpgradeBtn').style.display='none';
    } else {
      opkgState={status:'err',count:0,upgraded:false};
      document.getElementById('opkgStatus').innerHTML=
        '<span style="color:var(--bad)">&#10007; '+(d.msg||'Hata')+'</span>';
    }
  })
  .catch(function(){
    document.getElementById('opkgWarn').style.display='none';
    opkgState={status:'err',count:0,upgraded:false};
    document.getElementById('opkgStatus').innerHTML='<span style="color:var(--bad)">&#10007; Baglanti hatasi</span>';
  });
}

function fmtBcCard(S){
  var profileNames={
    'tt_default':'Turk Telekom Fiber (TTL2 fake)',
    'tt_fiber':'Turk Telekom Fiber (TTL4 fake)',
    'tt_alt':'KabloNet (TTL3 fake)',
    'sol':'Superonline (fake + m5sig)',
    'sol_alt':'Superonline Alternatif (TTL3 fake + m5sig)',
    'sol_fiber':'Superonline Fiber (TTL5 fake + badsum)',
    'turkcell_mob':'Turkcell Mobil (TTL1 + AutoTTL3 fake)',
    'vodafone_mob':'Vodafone Mobil (multisplit split-pos=2)',
    'blockcheck_auto':'Blockcheck Otomatik (Auto)'
  };
  var profLabel=profileNames[S.dpi_profile]||S.dpi_profile||'—';
  if(!S.bc_ts){
    return '<div class="card"><h3>DPI Health Score</h3>'+
      '<div style="color:var(--muted);font-size:13px;margin:10px 0 6px">Blockcheck hen&#252;z &#231;al&#305;&#351;t&#305;r&#305;lmad&#305;.</div>'+
      '<div style="font-size:12px;color:var(--muted)">Aktif Profil: <span style="color:var(--text)">'+profLabel+'</span></div>'+
      '<div style="margin-top:10px;font-size:11.5px;color:var(--muted)">Score g&#246;rmek i&#231;in SSH ile ba&#287;lan&#305;p<br><span style="color:var(--accent);font-family:monospace">kzm</span> &rarr; Men&#252; <b>B</b> (Blockcheck) &#231;al&#305;&#351;t&#305;r&#305;n.</div>'+
    '</div>';
  }
  var sc=S.bc_score||0;
  var clr=sc>=9?'var(--good)':sc>=7?'#4b9fff':sc>=5?'var(--warn)':'var(--bad)';
  var rat=sc>=9.5?'M&#252;kemmel':sc>=8.5?'&#199;ok &#304;yi':sc>=7?'&#304;yi':sc>=5?'Orta':'K&#246;t&#252;';
  var pct=Math.round(sc*10);
  var dt=new Date(S.bc_ts*1000);
  var dtStr=dt.toLocaleDateString('tr-TR')+' '+dt.toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit'});
  var warns='';
  if(!S.bc_dns_ok) warns+='<span class="badge bad" style="font-size:10px">DNS: WARN</span> ';
  if(!S.bc_tls12_ok) warns+='<span class="badge bad" style="font-size:10px">TLS12: WARN</span> ';
  if(S.bc_udp_weak) warns+='<span class="badge warn" style="font-size:10px">UDP 443: WARN</span>';
  return '<div class="card"><h3>DPI Health Score</h3>'+
    '<div style="display:flex;align-items:flex-end;gap:8px;margin:8px 0 4px">'+
      '<span style="font-size:2.4em;font-weight:800;color:'+clr+'">'+sc+'</span>'+
      '<span style="color:var(--muted);font-size:13px;padding-bottom:6px">/ 10 ('+rat+')</span>'+
      (warns?'<span style="margin-left:auto">'+warns+'</span>':'')+
    '</div>'+
    '<div style="background:rgba(255,255,255,.07);border-radius:6px;height:8px;overflow:hidden;margin-bottom:8px">'+
      '<div style="height:100%;width:'+pct+'%;background:linear-gradient(90deg,'+clr+',#4b7dff);border-radius:6px"></div>'+
    '</div>'+
    '<div style="font-size:12px;color:var(--muted);margin-bottom:4px">Aktif Profil: <span style="color:var(--text)">'+profLabel+'</span></div>'+
    '<div style="color:var(--muted);font-size:11px">Son blockcheck: '+dtStr+'</div>'+
  '</div>';
}

var V={
  dash:{title:'Dashboard',sub:'Canl&#305; sistem &#246;zeti.',html:function(){
    if(!S)return nd();
    var rp=pct(S.ram_used_mb,S.ram_total_mb);
    return '<div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">'+
      '<div class="card"><h3>KZM S&#252;r&#252;m</h3><div class="big">'+(S.kzm_version||'—')+'</div>'+
        '<div class="sub">Zapret: '+(S.zapret_version||'—')+'</div></div>'+
      '<div class="card"><h3>Zapret Durumu</h3>'+
        '<div class="row">'+bdg(S.zapret_running,'RUNNING','STOPPED')+
          ' <span class="pill">'+(S.wan_dev||'—')+'</span>'+
          ' <span class="pill">'+(S.wan_ip||'—')+'</span></div>'+
        '<div class="btns">'+
          '<button class="danger" onclick="zapretAct(\'zapret_restart\',this,\'Restart OK\')">&#8635; Restart</button>'+
          '<button class="ghost" onclick="zapretAct(\'zapret_stop\',this,\'Stop OK\')">&#9646;&#9646; Stop</button>'+
          '<button class="ok" onclick="zapretAct(\'zapret_start\',this,\'Start OK\')">&#9654; Start</button>'+
        '</div></div>'+
      '<div class="card"><h3>CPU / RAM / Disk</h3>'+
        '<div class="row"><span class="pill">Load: '+S.load1+'</span>'+
          '<span class="pill">RAM: '+S.ram_used_mb+'/'+S.ram_total_mb+' MB</span>'+
          '<span class="pill">/opt: '+S.disk_used_pct+'%</span></div>'+
        '<div style="margin-top:8px"><div class="sub" style="margin-bottom:3px">RAM '+rp+'%</div>'+brr(rp)+'</div>'+
        '<div style="margin-top:6px"><div class="sub" style="margin-bottom:3px">Disk '+S.disk_used_pct+'%</div>'+brr(S.disk_used_pct)+'</div>'+
      '</div>'+
      '<div class="card"><h3>Servisler</h3>'+
        '<div class="row">'+bdg(S.healthmon_running,'Health Mon OK','Health Mon PAS&#304;F')+'</div>'+
        '<div class="row" style="margin-top:6px">'+bdgO(S.telegram_enabled&&S.telegram_running,'Telegram AKT&#304;F','Telegram KAPALI')+'</div>'+
      '</div>'+
      fmtBcCard(S)+
      fmtOpkgCard()+
      '<div class="card wide"><h3>Sistem Bilgisi</h3><div class="info-grid">'+
        ir('Model',S.model||'—')+ir('Firmware',S.firmware||'—')+
        ir('WAN',(S.wan_dev||'—')+' | '+(S.wan_ip||'—'))+
        (S.keendns_fqdn ? ir('KeenDNS',S.keendns_fqdn+' | '+fmtKeenDns(S.keendns_access)) : '')+
        ir('Zapret',bdg(S.zapret_running,'&#199;ALI&#350;IYOR','DURDURULDU'))+
        ir('Health Monitor',bdg(S.healthmon_running,'AKT&#304;F','PAS&#304;F'))+
        ir('Telegram Bot',bdgO(S.telegram_enabled&&S.telegram_running,'AKT&#304;F','KAPALI'))+
        ir('KZM S&#252;r&#252;m',S.kzm_version||'—')+ir('Zapret S&#252;r&#252;m',S.zapret_version||'—')+
        ir('GitHub','<a href="https://github.com/RevolutionTR/keenetic-zapret-manager" target="_blank" style="color:var(--accent)">github.com/RevolutionTR/keenetic-zapret-manager</a>')+
      '</div></div></div>';
  }},

  zapret:{title:'Zapret Kontrol',sub:'Zapret servisini y&#246;net.',html:function(){
    if(!S)return nd();
    return '<div class="grid" style="grid-template-columns:1fr 1fr">'+
      '<div class="card"><h3>Durum</h3>'+
        '<div class="row">'+bdg(S.zapret_running,'RUNNING','STOPPED')+
          ' <span class="pill">WAN: '+(S.wan_dev||'—')+'</span>'+
          ' <span class="pill">'+(S.zapret_version||'—')+'</span></div></div>'+
      '<div class="card"><h3>Kontrol</h3>'+
        '<div class="btns">'+
          '<button class="ok" onclick="zapretAct(\'zapret_start\',this,\'Baslatildi\')">&#9654; Ba&#351;lat</button>'+
          '<button class="danger" onclick="zapretAct(\'zapret_stop\',this,\'Durduruldu\')">&#9646;&#9646; Durdur</button>'+
          '<button class="ghost" onclick="zapretAct(\'zapret_restart\',this,\'Yeniden baslatildi\')">&#8635; Yeniden Ba&#351;lat</button>'+
        '</div>'+
        '<div class="hint" style="margin-top:8px">HealthMon AUTORESTART=1 ise durdurma kal&#305;c&#305; olmaz.</div>'+
      '</div></div>';
  }},

  dpi:{title:'DPI Profili',sub:'Mevcut DPI profilini g&#246;r&#252;nt&#252;le ve de&#287;i&#351;tir.',html:function(){
    var h='<div class="grid" style="grid-template-columns:1fr 1fr">'+
      '<div class="card"><h3>Mevcut Profil</h3>'+
        '<div class="big" id="dpiVal">...</div></div>'+
      '<div class="card"><h3>Profil Se&#231;</h3>'+
        '<div class="irow">'+
          '<select id="dpiSel" style="flex:1">'+
            '<option value="tt_default">Turk Telekom Fiber (TTL2 fake)</option>'+
            '<option value="tt_fiber">Turk Telekom Fiber (TTL4 fake)</option>'+
            '<option value="tt_alt">KabloNet (TTL3 fake)</option>'+
            '<option value="sol">Superonline (fake + m5sig)</option>'+
            '<option value="sol_alt">Superonline Alternatif (TTL3 fake)</option>'+
            '<option value="sol_fiber">Superonline Fiber (TTL5 fake + badsum)</option>'+
            '<option value="turkcell_mob">Turkcell Mobil (TTL1 + AutoTTL3)</option>'+
            '<option value="vodafone_mob">Vodafone Mobil (multisplit)</option>'+
            '<option value="blockcheck_auto">Blockcheck Otomatik (Auto)</option>'+
          '</select>'+
          '<button onclick="(function(b){var v=document.getElementById(\'dpiSel\').value;actD(\'dpi_set\',\'profile=\'+v,b,\'Profil ayarlandi\')})(this)">Uygula</button>'+
        '</div>'+
        '<div class="hint" style="margin-top:8px">De&#287;i&#351;iklik sonras&#305; Zapret yeniden ba&#351;lar.</div>'+
      '</div></div>';
    setTimeout(function(){
      getD('dpi_get',function(r){
        var el=document.getElementById('dpiVal');
        if(el)el.textContent=r.ok?(r.name||r.data):'?';
        var sel=document.getElementById('dpiSel');
        if(sel&&r.ok)sel.value=r.data;
      });
    },100);
    return h;
  }},

  hostlist:{title:'Hostlist Y&#246;netimi',sub:'Domain ekle, sil, listele.',html:function(){
    var h='<div class="grid">'+
      '<div class="card"><h3>Domain Ekle</h3>'+
        '<div class="irow">'+
          '<input type="text" id="hlIn" placeholder="example.com" style="flex:1"/>'+
          '<button onclick="hlAdd()">Ekle</button></div></div>'+
      '<div class="card wide"><h3>User Hostlist <span id="hlCnt" class="tag">0</span></h3>'+
        '<div class="lw" id="hlL"><div class="empty">Y&#252;kleniyor...</div></div></div>'+
      '<div class="card wide"><h3>Auto Hostlist <span id="autoCnt" class="tag">0</span></h3>'+
        '<div class="hint" style="margin-bottom:6px">Otomatik olu&#351;turulan liste (salt okunur)</div>'+
        '<div class="lw" id="autoL"><div class="empty">Y&#252;kleniyor...</div></div></div>'+
      '<div class="card"><h3>Exclude Listesi</h3>'+
        '<div class="irow">'+
          '<input type="text" id="exIn" placeholder="example.com" style="flex:1"/>'+
          '<button onclick="exAdd()">Ekle</button></div>'+
        '<div class="lw" style="margin-top:8px" id="exL"><div class="empty">Y&#252;kleniyor...</div></div>'+
      '</div></div>';
    setTimeout(hlLoad,100);return h;
  }},

  ipset:{title:'IPSET Y&#246;netimi',sub:'Statik IP tabanl&#305; filtreleme.',html:function(){
    var h='<div class="grid">'+
      '<div class="card"><h3>IP Ekle</h3>'+
        '<div class="irow">'+
          '<input type="text" id="ipIn" placeholder="192.168.1.100" style="flex:1"/>'+
          '<button onclick="ipAdd()">Ekle</button></div>'+
        '<div class="hint" style="margin-top:6px">DHCP desteklenmez, statik IP girin.</div></div>'+
      '<div class="card wide"><h3>IP Listesi <span id="ipCnt" class="tag">0</span></h3>'+
        '<div class="lw" id="ipL"><div class="empty">Y&#252;kleniyor...</div></div></div>'+
      '<div class="card wide"><h3>IPSET Aktif &#220;yeler <span id="ipaCnt" class="tag">0</span></h3>'+
        '<div class="hint" style="margin-bottom:6px">Kernel ipset\'teki aktif &#252;yeler (salt okunur)</div>'+
        '<div class="lw" id="ipaL"><div class="empty">Y&#252;kleniyor...</div></div></div>'+
      '<div class="card wide"><h3>No Zapret (Muafiyet) <span id="nzCnt" class="tag">0</span></h3>'+
        '<div class="hint" style="margin-bottom:6px">Zapret i&#351;leminden muaf IP&#39;ler</div>'+
        '<div class="lw" id="nzL"><div class="empty">Y&#252;kleniyor...</div></div></div>'+
      '</div>';
    setTimeout(ipLoad,100);return h;
  }},

  healthmon:{title:'Sistem Izleme',sub:'CPU/RAM/Disk/Load/Zapret + HealthMon daemon (Menu 16).',html:function(){
    if(!S)return nd();
    var rp=pct(S.ram_used_mb,S.ram_total_mb);
    var h='<div class="grid">'+
      '<div class="card"><h3>CPU Load</h3><div class="big">'+S.load1+'</div>'+
        '<div class="sub">5dk: '+S.load5+' &nbsp; 15dk: '+S.load15+'</div></div>'+
      '<div class="card"><h3>RAM</h3><div class="big">'+rp+'%</div>'+
        '<div class="sub">'+S.ram_used_mb+' / '+S.ram_total_mb+' MB</div>'+brr(rp)+'</div>'+
      '<div class="card"><h3>Disk /opt</h3><div class="big">'+S.disk_used_pct+'%</div>'+
        '<div class="sub">Toplam: '+Math.round(S.disk_total_mb/1024)+' GB</div>'+brr(S.disk_used_pct)+'</div>'+
      '<div class="card"><h3>Zapret &amp; HealthMon</h3>'+
        '<div class="row">'+bdg(S.zapret_running,'Zapret OK','Zapret PAS&#304;F')+'</div>'+
        '<div class="row" style="margin-top:6px">'+bdg(S.healthmon_running,'HealthMon OK','HealthMon PAS&#304;F')+'</div>'+
        '<div class="btns" style="margin-top:10px">';
    h+=S.healthmon_running
      ?'<button class="danger" onclick="act(\'healthmon_stop\',this,\'HM durduruldu\')">&#9632; Durdur</button>'
      :'<button class="ok" onclick="act(\'healthmon_start\',this,\'HM baslatildi\')">&#9654; Ba&#351;lat</button>';
    h+='<button class="ghost" onclick="act(\'status_refresh\',this,\'Guncellendi\')">&#8635; Yenile</button>'+
      '</div></div>'+
      '<div class="card wide" id="hmC"><h3>Konfig&#252;rasyon</h3><div class="sub">Y&#252;kleniyor...</div></div>'+
    '</div>';
    setTimeout(function(){
      getD('hm_get',function(r){
        var el=document.getElementById('hmC');
        if(!el)return;
        el.innerHTML='<h3>Konfig&#252;rasyon</h3>'+(r.ok?'<div class="info-grid">'+r.data+'</div>':'<div class="sub">Okunamad&#305;</div>');
      });
    },100);
    return h;
  }},

  healthcheck:{title:'Ag Tanilama',sub:'DNS/NTP/GitHub/OPKG/Disk/Zapret kontrolu (Menu 14).',html:function(){
    if(!S)return nd();
    setTimeout(function(){hcRun();},50);
    return '<div id="hcResult"><div style="display:flex;align-items:center;gap:10px;color:var(--muted)"><span class="spinner"></span> Kontrol yapiliyor, lutfen bekleyin...</div></div>';
  }},

  telegram:{title:'Telegram',sub:'Bildirim ve interaktif bot.',html:function(){
    if(!S)return nd();
    var cfg=!!S.telegram_configured;
    var run=!!S.telegram_running;
    var en=!!S.telegram_enabled;
    var dis=cfg?'':'disabled';
    var notCfg='<div style="background:rgba(255,180,0,0.12);border:1px solid var(--warn);border-radius:6px;padding:8px 10px;margin-bottom:12px;font-size:0.88em;color:var(--warn)">&#9888; Yapilandirilmamis &mdash; SSH &gt; Menu 15</div>';
    var startBtn=run
      ?'<button class="danger" onclick="tgStop(this)">&#9632; Durdur</button>'
      :'<button '+dis+' onclick="tgStart(this)">&#9654; Baslat</button>';
    var h='<div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">'+
      // Kart 1: Tek yonlu bildirim
      '<div class="card">'+
        '<h3>&#128276; Bildirim <span style="font-size:0.7em;font-weight:normal;color:var(--muted)">(Tek Yon)</span></h3>'+
        (cfg?'':''+notCfg)+
        '<div style="font-size:0.85em;color:var(--muted);margin-bottom:10px">HealthMon uyarilari, Zapret durum bildirimleri</div>'+
        '<div class="row">'+bdgO(cfg,'Yapilandirilmis','Kurulmamis')+'</div>'+
        '<div class="row" style="margin-top:6px">'+bdgO(en,'Etkin','Devre Disi')+'</div>'+
        '<div class="btns" style="margin-top:12px">'+
          '<button '+dis+' onclick="act(\'tg_test\',this,\'Test gonderildi\')">&#128172; Test Gonder</button>'+
        '</div>'+
      '</div>'+
      // Kart 2: Cift yonlu interaktif bot
      '<div class="card">'+
        '<h3>&#129302; Interaktif Bot <span style="font-size:0.7em;font-weight:normal;color:var(--muted)">(Cift Yon)</span></h3>'+
        (cfg?'':''+notCfg)+
        '<div style="font-size:0.85em;color:var(--muted);margin-bottom:10px">Telegram\'dan komut gonder, router\'i yonet</div>'+
        '<div class="row">'+bdgO(run,'Calisiyor','Durdu')+'</div>'+
        '<div class="btns" style="margin-top:12px">'+startBtn+'</div>'+
      '</div>'+
    '</div>'+
    // Alt satir: Bot bilgileri
    '<div style="margin-top:16px">'+
      '<div class="card" id="tgInfoCard"><h3>&#128272; Baglanti Bilgileri</h3>'+
        '<div style="color:var(--muted);font-size:0.9em">Yukleniyor...</div>'+
      '</div>'+
    '</div>';
    setTimeout(function(){
      getD('tg_info',function(r){
        var el=document.getElementById('tgInfoCard');
        if(!el)return;
        if(r.ok&&(r.token||r.chat)){
          el.innerHTML='<h3>&#128272; Baglanti Bilgileri</h3>'+
            '<table style="width:100%;border-collapse:collapse;font-size:0.9em">'+
            '<tr><td style="color:var(--muted);padding:5px 0;width:80px">Token</td>'+
            '<td style="font-family:monospace;letter-spacing:0.03em">'+r.token+'</td></tr>'+
            '<tr><td style="color:var(--muted);padding:5px 0">Chat ID</td>'+
            '<td style="font-family:monospace">'+r.chat+'</td></tr>'+
            '</table>';
        } else {
          el.innerHTML='<h3>&#128272; Baglanti Bilgileri</h3>'+
            '<div style="color:var(--muted);font-size:0.9em">Yapilandirilmamis &mdash; SSH ile Menu 15\'i kullanin.</div>';
        }
      });
    },100);
    return h;
  }},

  mon:{title:'Sistem &#304;zleme',sub:'Canl&#305; kaynak kullan&#305;m&#305;.',html:function(){
    if(!S)return nd();
    var rp=pct(S.ram_used_mb,S.ram_total_mb);
    return '<div class="grid">'+
      '<div class="card"><h3>CPU Load</h3><div class="big">'+S.load1+'</div>'+
        '<div class="sub">5dk: '+S.load5+' &nbsp; 15dk: '+S.load15+'</div></div>'+
      '<div class="card"><h3>RAM</h3><div class="big">'+rp+'%</div>'+
        '<div class="sub">'+S.ram_used_mb+' / '+S.ram_total_mb+' MB</div>'+brr(rp)+'</div>'+
      '<div class="card"><h3>Disk /opt</h3><div class="big">'+S.disk_used_pct+'%</div>'+
        '<div class="sub">Toplam: '+Math.round(S.disk_total_mb/1024)+' GB</div>'+brr(S.disk_used_pct)+'</div>'+
      '<div class="card"><h3>Servisler</h3>'+
        '<div class="row">'+bdg(S.zapret_running,'Zapret OK','Zapret PAS&#304;F')+'</div>'+
        '<div class="row" style="margin-top:6px">'+bdg(S.healthmon_running,'HealthMon OK','HealthMon PAS&#304;F')+'</div>'+
        '<div class="btns" style="margin-top:10px">'+
          '<button class="ghost" onclick="act(\'status_refresh\',this,\'Guncellendi\')">&#8635; G&#252;ncelle</button>'+
        '</div></div>'+
      '</div>';
  }},

  sched:{title:'Zamanl&#305; Reboot',sub:'Cron tabanl&#305; yeniden ba&#351;latma.',html:function(){
    var h='<div class="grid">'+
      '<div class="card" id="schedC"><h3>Mevcut Zamanlama</h3><div class="sub">Y&#252;kleniyor...</div></div>'+
      '<div class="card"><h3>Zamanlama Ayarla</h3>'+
        '<div class="irow" style="margin-bottom:8px">'+
          '<select id="schedMode" style="flex:1" onchange="schedModeChange()">'+
            '<option value="daily">G&#252;nl&#252;k</option>'+
            '<option value="weekly">Haftal&#305;k</option>'+
          '</select>'+
        '</div>'+
        '<div id="schedDowRow" style="display:none;margin-bottom:8px">'+
          '<select id="schedDow" style="width:100%">'+
            '<option value="1">Pazartesi</option>'+
            '<option value="2">Sal&#305;</option>'+
            '<option value="3">&#199;ar&#351;amba</option>'+
            '<option value="4">Per&#351;embe</option>'+
            '<option value="5">Cuma</option>'+
            '<option value="6">Cumartesi</option>'+
            '<option value="0">Pazar</option>'+
          '</select>'+
        '</div>'+
        '<div class="irow">'+
          '<input type="text" id="schedT" placeholder="02:00" style="width:90px"/>'+
          '<button onclick="schedSet()">Ayarla</button>'+
          '<button class="danger" onclick="schedDel(this)">Kald&#305;r</button>'+
        '</div>'+
        '<div class="hint" style="margin-top:6px">Format: SS:DD &mdash; &#246;rn. 03:30</div>'+
      '</div></div>';
    setTimeout(function(){
      getD('sched_get',function(r){
        var el=document.getElementById('schedC');
        if(!el)return;
        var dowNames=['Pazar','Pazartesi','Sali','Carsamba','Persembe','Cuma','Cumartesi'];
        if(r.ok&&r.data){
          var dow=r.dow||'*';
          var sub=dow==='*'?'Her g&#252;n bu saatte reboot':'Her hafta <b>'+(dowNames[parseInt(dow)]||dow)+'</b> g&#252;n&#252; bu saatte reboot';
          el.innerHTML='<h3>Mevcut Zamanlama</h3><div class="big">'+r.data+'</div><div class="sub">'+sub+'</div>';
          // Formu mevcut ayara gore doldur
          if(dow!=='*'){
            var modeEl=document.getElementById('schedMode');
            var dowEl=document.getElementById('schedDow');
            var rowEl=document.getElementById('schedDowRow');
            if(modeEl)modeEl.value='weekly';
            if(dowEl)dowEl.value=dow;
            if(rowEl)rowEl.style.display='';
          }
          var tEl=document.getElementById('schedT');
          if(tEl)tEl.value=r.data;
        } else {
          el.innerHTML='<h3>Mevcut Zamanlama</h3><div class="sub">Zamanlama yok</div>';
        }
      });
    },100);
    return h;
  }},

  backup:{title:'Yedekle / Geri Y&#252;kle',sub:'Zapret ayarlar&#305; yedekleme ve geri y&#252;kleme.',html:function(){
    setTimeout(function(){bkLoad();},100);
    return '<div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">'+ 

      '<div class="card"><h3>&#128190; Zapret Ayarlar&#305; Yedekle</h3>'+
        '<div class="sub">config, hostlist, IPSET, DPI profili, healthmon, telegram ayarlar&#305; tar.gz olarak yedekler.</div>'+
        '<div class="btns" style="margin-top:8px">'+
          '<button onclick="act(\'backup_settings\',this,\'Yedeklendi\')">&#128190; Yedekle</button>'+
          '<button onclick="bkSettingsList(this)" style="background:#444">&#128220; Yedekleri G&#246;r</button>'+
        '</div>'+
        '<div class="hint" style="margin-top:8px">Konum: /opt/zapret_backups/zapret_settings/</div>'+
        '<div id="bkSetList" style="margin-top:8px"></div>'+
      '</div>'+

      '<div class="card"><h3>&#9850; Zapret Ayarlar&#305; Geri Y&#252;kle</h3>'+
        '<div class="sub">Kapsam se&#231;erek yedekten geri y&#252;kle. Zapret otomatik yeniden ba&#351;lar.</div>'+
        '<div style="margin-top:8px">'+
          '<select id="bkScope" style="width:100%;padding:6px;background:#1e1e2e;color:#cdd6f4;border:1px solid #444;border-radius:6px;margin-bottom:8px">'+
            '<option value="1">Tam Geri Y&#252;kleme</option>'+
            '<option value="2">Sadece DPI Ayarlar&#305;</option>'+
            '<option value="3">Sadece Hostlist</option>'+
            '<option value="4">Sadece IPSET</option>'+
          '</select>'+
          '<div id="bkSetRestore" style="margin-top:4px"><div class="sub">&#8593; Once Yedekleri G&#246;r\'e t&#305;klay&#305;n</div></div>'+
        '</div>'+
      '</div>'+

      '<div class="card"><h3>&#128190; IPSET Yedekle</h3>'+
        '<div class="sub">Mevcut IPSET .txt dosyalar&#305;n&#305; current + history klas&#246;rlerine kopyalar.</div>'+
        '<div class="btns" style="margin-top:8px">'+
          '<button onclick="act(\'ipset_backup\',this,\'IPSET Yedeklendi\')">&#128190; Yedekle</button>'+
          '<button onclick="bkIpsetList(this)" style="background:#444">&#128220; Yedekleri G&#246;r</button>'+
        '</div>'+
        '<div class="hint" style="margin-top:8px">Konum: /opt/zapret_backups/current/</div>'+
        '<div id="bkIpList" style="margin-top:8px"></div>'+
      '</div>'+

      '<div class="card"><h3>&#9850; IPSET Geri Y&#252;kle</h3>'+
        '<div class="sub">Current klas&#246;r&#252;ndeki dosyalar&#305; se&#231;erek geri y&#252;kle.</div>'+
        '<div id="bkIpRestore" style="margin-top:8px"><div class="sub">&#8593; Once Yedekleri G&#246;r\'e t&#305;klay&#305;n</div></div>'+
      '</div>'+

    '</div>';
  }}
};

function hlLoad(){
  getD('hl_get',function(r){
    var el=document.getElementById('hlL'),ec=document.getElementById('hlCnt');
    if(!el)return;
    if(!r.ok||!r.data||!r.data.length){el.innerHTML='<div class="empty">Liste bo&#351;</div>';if(ec)ec.textContent='0';return;}
    if(ec)ec.textContent=r.data.length;
    el.innerHTML=r.data.map(function(d){return '<div class="li"><span>'+d+'</span>'+
      '<button class="danger" style="padding:3px 8px;font-size:11px" onclick="hlDel(\''+d+'\',this)">Sil</button></div>';}).join('');
  });
  getD('auto_get',function(r){
    var el=document.getElementById('autoL'),ec=document.getElementById('autoCnt');if(!el)return;
    if(!r.ok||!r.data||!r.data.length){el.innerHTML='<div class="empty">Liste bo&#351;</div>';if(ec)ec.textContent='0';return;}
    if(ec)ec.textContent=r.data.length;
    el.innerHTML=r.data.map(function(d){return '<div class="li"><span>'+d+'</span></div>';}).join('');
  });
  getD('ex_get',function(r){
    var el=document.getElementById('exL');if(!el)return;
    if(!r.ok||!r.data||!r.data.length){el.innerHTML='<div class="empty">Liste bo&#351;</div>';return;}
    el.innerHTML=r.data.map(function(d){return '<div class="li"><span>'+d+'</span>'+
      '<button class="danger" style="padding:3px 8px;font-size:11px" onclick="exDel(\''+d+'\',this)">Sil</button></div>';}).join('');
  });
}
function hlAdd(){var v=(document.getElementById('hlIn').value||'').trim();if(!v)return;actD('hl_add','domain='+encodeURIComponent(v),null,'Eklendi');document.getElementById('hlIn').value='';setTimeout(hlLoad,1800);}
function hlDel(d,b){actD('hl_del','domain='+encodeURIComponent(d),b,'Silindi');setTimeout(hlLoad,1800);}
function exAdd(){var v=(document.getElementById('exIn').value||'').trim();if(!v)return;actD('ex_add','domain='+encodeURIComponent(v),null,'Eklendi');document.getElementById('exIn').value='';setTimeout(hlLoad,1800);}
function exDel(d,b){actD('ex_del','domain='+encodeURIComponent(d),b,'Silindi');setTimeout(hlLoad,1800);}
function ipLoad(){
  getD('ip_get',function(r){
    var el=document.getElementById('ipL'),ec=document.getElementById('ipCnt');if(!el)return;
    if(!r.ok||!r.data||!r.data.length){el.innerHTML='<div class="empty">Liste bo&#351;</div>';if(ec)ec.textContent='0';return;}
    if(ec)ec.textContent=r.data.length;
    el.innerHTML=r.data.map(function(ip){return '<div class="li"><span>'+ip+'</span>'+
      '<button class="danger" style="padding:3px 8px;font-size:11px" onclick="ipDel(\''+ip+'\',this)">Sil</button></div>';}).join('');
  });
  getD('nozapret_get',function(r){
    var el=document.getElementById('nzL'),ec=document.getElementById('nzCnt');if(!el)return;
    if(!r.ok||!r.data||!r.data.length){el.innerHTML='<div class="empty">Liste bo&#351;</div>';if(ec)ec.textContent='0';return;}
    if(ec)ec.textContent=r.data.length;
    el.innerHTML=r.data.map(function(ip){return '<div class="li"><span>'+ip+'</span></div>';}).join('');
  });
  getD('ipset_active_get',function(r){
    var el=document.getElementById('ipaL'),ec=document.getElementById('ipaCnt');if(!el)return;
    if(!r.ok||!r.data||!r.data.length){el.innerHTML='<div class="empty">Aktif &#252;ye yok</div>';if(ec)ec.textContent='0';return;}
    if(ec)ec.textContent=r.data.length;
    el.innerHTML=r.data.map(function(ip){return '<div class="li"><span>'+ip+'</span></div>';}).join('');
  });
}
function ipAdd(){var v=(document.getElementById('ipIn').value||'').trim();if(!v)return;actD('ip_add','ip='+encodeURIComponent(v),null,'Eklendi');document.getElementById('ipIn').value='';setTimeout(ipLoad,1800);}
function ipDel(ip,b){actD('ip_del','ip='+encodeURIComponent(ip),b,'Silindi');setTimeout(ipLoad,1800);}
function schedModeChange(){var m=document.getElementById('schedMode');var r=document.getElementById('schedDowRow');if(r)r.style.display=(m&&m.value==='weekly')?'':'none';}
function schedSet(){
  var v=(document.getElementById('schedT').value||'').trim();if(!v)return;
  var mode=document.getElementById('schedMode');
  var dow='*';
  if(mode&&mode.value==='weekly'){var d=document.getElementById('schedDow');dow=d?d.value:'1';}
  actD('sched_set','time='+encodeURIComponent(v)+'&dow='+encodeURIComponent(dow),null,'Zamanlama ayarlandi');
  setTimeout(function(){render('sched');},1800);
}
function schedDel(btn){act('sched_del',btn,'Kaldirildi');setTimeout(function(){render('sched');},1500);}

var _hcTimer=null;
var _hcAttempts=0;
var _hcMaxAttempts=60;
function hcRun(btn){
  var el=document.getElementById('hcResult');
  if(el)el.innerHTML='<div style="display:flex;align-items:center;gap:10px;color:var(--muted)"><span class="spinner"></span> Kontrol yapiliyor, lutfen bekleyin...</div>';
  if(btn){btn.disabled=true;}
  _hcAttempts=0;
  fetch('/cgi-bin/action.sh',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'action=health_run'})
  .then(function(r){return r.json();})
  .then(function(){clearInterval(_hcTimer);_hcTimer=setInterval(function(){hcPoll(btn);},2000);})
  .catch(function(){if(el)el.innerHTML='<div style="color:var(--bad)">Baglanti hatasi</div>';if(btn)btn.disabled=false;});
}
function hcPoll(btn){
  _hcAttempts++;
  if(_hcAttempts>_hcMaxAttempts){
    clearInterval(_hcTimer);
    if(btn)btn.disabled=false;
    var el=document.getElementById('hcResult');
    if(el)el.innerHTML='<div style="color:var(--bad)">Zaman asimi (120s). Kontrol tamamlanamadi.</div><div style="margin-top:12px"><button onclick="hcRun()">&#8635; Tekrar Dene</button></div>';
    return;
  }
  fetch('/cgi-bin/action.sh',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'action=health_get'})
  .then(function(r){return r.json();})
  .then(function(d){
    if(d.running){return;}
    clearInterval(_hcTimer);
    if(btn)btn.disabled=false;
    hcRender(d);
  }).catch(function(){clearInterval(_hcTimer);if(btn)btn.disabled=false;});
}
function hcRender(d){
  var el=document.getElementById('hcResult');
  if(!el)return;
  if(!d||!d.ok){el.innerHTML='<div style="color:var(--bad)">'+(d&&d.msg?d.msg:'Hata')+'</div>';return;}
  var sc=parseFloat(d.score||0);
  var scClr=sc>=9.5?'var(--good)':sc>=8.5?'var(--good)':sc>=7?'var(--warn)':sc>=5?'#e8a020':'var(--bad)';
  var scLbl=sc>=9.5?'MUKEMMEL':sc>=8.5?'COK IYI':sc>=7?'IYI':sc>=5?'ORTA':'KOTU';
  var h='<div style="background:var(--card);border:1px solid var(--border);border-radius:10px;padding:14px 16px;margin-bottom:16px">'+
    '<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px">'+
      '<span style="font-weight:600">Sistem Skoru</span>'+
      '<span style="font-size:1.4em;font-weight:700;color:'+scClr+'">'+d.score+' / 10 <span style="font-size:0.65em">'+scLbl+'</span></span>'+
    '</div>'+
    '<div style="background:var(--bg);border-radius:4px;height:8px;overflow:hidden">'+
      '<div style="height:100%;width:'+(sc*10)+'%;background:'+scClr+';border-radius:4px"></div>'+
    '</div>'+
    '<div style="display:flex;gap:16px;margin-top:8px;font-size:0.82em;color:var(--muted)">'+
      '<span style="color:var(--good)">&#10003; PASS: '+d.pass+'</span>'+
      '<span style="color:var(--warn)">&#9888; WARN: '+d.warn+'</span>'+
      '<span style="color:var(--bad)">&#10007; FAIL: '+d.fail+'</span>'+
      '<span>INFO: '+d.info+'</span>'+
      (d.dns_mode?'<span style="margin-left:auto">DNS: <b>'+d.dns_mode+'</b>'+(d.dns_providers?' \u2022 '+d.dns_providers:'')+'</span>':'')+
    '</div>'+
  '</div>';
  var secs={net:'\u{1F310} Ag & DNS',sys:'\u{1F4BB} Sistem',svc:'\u2699 Servisler'};
  var secOrder=['net','sys','svc'];
  var byS={net:[],sys:[],svc:[]};
  (d.items||[]).forEach(function(it){if(byS[it.sec])byS[it.sec].push(it);});
  secOrder.forEach(function(sk){
    var items=byS[sk]; if(!items||!items.length)return;
    h+='<div style="background:var(--card);border:1px solid var(--border);border-radius:10px;margin-bottom:12px;overflow:hidden">'+
      '<div style="padding:10px 16px;border-bottom:1px solid var(--border);font-weight:600;font-size:0.9em">'+secs[sk]+'</div>'+
      '<table style="width:100%;border-collapse:collapse;font-size:0.88em">';
    items.forEach(function(it,i){
      var stClr=it.st==='PASS'?'var(--good)':it.st==='FAIL'?'var(--bad)':it.st==='WARN'?'var(--warn)':'var(--muted)';
      var stIco=it.st==='PASS'?'&#10003;':it.st==='FAIL'?'&#10007;':it.st==='WARN'?'&#9888;':'&#8226;';
      h+='<tr style="border-top:'+(i?'1px solid var(--border)':'none')+'">'+
        '<td style="padding:7px 16px;color:var(--muted);width:45%">'+it.lbl+'</td>'+
        '<td style="padding:7px 8px;color:var(--fg)">'+it.val+'</td>'+
        '<td style="padding:7px 16px;text-align:right;color:'+stClr+';font-weight:600;white-space:nowrap">'+stIco+' '+it.st+'</td>'+
      '</tr>';
    });
    h+='</table></div>';
  });
  el.innerHTML=h+'<div style="margin-top:12px"><button onclick="hcRun()">&#8635; Yenile</button></div>';
}
function zapretAct(action,btn,msg){
  if(btn){btn._o=btn.innerHTML;btn.disabled=true;btn.innerHTML='<span class="spinner"></span>';}
  fetch('/cgi-bin/action.sh',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'action='+action})
  .then(function(r){return r.json();})
  .then(function(res){
    toast(res.msg||msg,!!res.ok);
    if(btn){btn.disabled=false;btn.innerHTML=btn._o;}
    fetch('/cgi-bin/action.sh',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'action=status_refresh'})
    .then(function(){return fetchS();})
    .then(function(){render(curV);});
  }).catch(function(){toast('Baglanti hatasi',false);if(btn){btn.disabled=false;btn.innerHTML=btn._o;}});
}
function tgStart(btn){
  if(btn){btn._o=btn.innerHTML;btn.disabled=true;btn.innerHTML='<span class="spinner"></span>';}
  fetch('/cgi-bin/action.sh',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'action=tg_start'})
  .then(function(r){return r.json();})
  .then(function(res){
    toast(res.msg||'Bot baslatildi',!!res.ok);
    if(btn){btn.disabled=false;btn.innerHTML=btn._o;}
    // status_refresh -> fetchS -> render
    fetch('/cgi-bin/action.sh',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'action=status_refresh'})
    .then(function(){return fetchS();})
    .then(function(){render('telegram');});
  }).catch(function(){toast('Baglanti hatasi',false);if(btn){btn.disabled=false;btn.innerHTML=btn._o;}});
}
function tgStop(btn){
  if(btn){btn._o=btn.innerHTML;btn.disabled=true;btn.innerHTML='<span class="spinner"></span>';}
  fetch('/cgi-bin/action.sh',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'action=tg_stop'})
  .then(function(r){return r.json();})
  .then(function(res){
    toast(res.msg||'Bot durduruldu',!!res.ok);
    if(btn){btn.disabled=false;btn.innerHTML=btn._o;}
    // status_refresh -> fetchS -> render
    fetch('/cgi-bin/action.sh',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'action=status_refresh'})
    .then(function(){return fetchS();})
    .then(function(){render('telegram');});
  }).catch(function(){toast('Baglanti hatasi',false);if(btn){btn.disabled=false;btn.innerHTML=btn._o;}});
}

function bkLoad(){bkSettingsList(null);bkIpsetList(null);}
function bkSettingsList(btn){
  if(btn)btn.disabled=true;
  getD('settings_list',function(r){
    if(btn)btn.disabled=false;
    var el=document.getElementById('bkSetList'),er=document.getElementById('bkSetRestore');
    if(!el)return;
    if(!r.ok||!r.data||!r.data.length){
      el.innerHTML='<div class="sub">Yedek bulunamadi</div>';
      if(er)er.innerHTML='<div class="sub">Yedek bulunamadi</div>';
      return;
    }
    var html='<div style="font-size:11px;color:#888;margin-bottom:4px">Son 10 yedek:</div>';
    var rhtml='';
    r.data.forEach(function(f){
      html+='<div class="li" style="font-size:11px"><span style="flex:1;word-break:break-all">'+f.name+'</span></div>';
      rhtml+='<div class="li" style="margin-bottom:4px"><span style="font-size:11px;flex:1;word-break:break-all">'+f.name+'</span>'+
        '<button style="padding:3px 8px;font-size:11px" onclick="bkSetRestore(\''+f.path.replace(/\'/g,"\\'")+'\'  ,this)">&#9850; Geri Y&#252;kle</button></div>';
    });
    el.innerHTML=html;
    if(er)er.innerHTML=rhtml;
  });
}
function bkSetRestore(path,btn){
  var scope=document.getElementById('bkScope');
  var s=scope?scope.value:'1';
  if(!confirm('Geri yuklensin mi? (Kapsam:'+s+')'))return;
  if(btn)btn.disabled=true;
  actD('settings_restore','file='+encodeURIComponent(path)+'&scope='+s,btn,'Geri yuklendi');
}
function bkIpsetList(btn){
  if(btn)btn.disabled=true;
  getD('ipset_list',function(r){
    if(btn)btn.disabled=false;
    var el=document.getElementById('bkIpList'),er=document.getElementById('bkIpRestore');
    if(!el)return;
    if(!r.ok||!r.files){
      el.innerHTML='<div class="sub">Yedek bulunamadi</div>';
      if(er)er.innerHTML='<div class="sub">Yedek bulunamadi</div>';
      return;
    }
    var files=r.files?r.files.split('|').filter(function(x){return x;}):[]; 
    if(!files.length){
      el.innerHTML='<div class="sub">Yedek bulunamadi</div>';
      if(er)er.innerHTML='<div class="sub">Yedek bulunamadi</div>';
      return;
    }
    var html='<div style="font-size:11px;color:#888;margin-bottom:4px">Current yedekler:</div>';
    var rhtml='';
    files.forEach(function(f){
      var parts=f.split(':');var name=parts[0];var cnt=parts[1]||'?';
      html+='<div class="li" style="font-size:11px"><span style="flex:1">'+name+'</span><span style="color:#888">'+cnt+' sat&#305;r</span></div>';
      rhtml+='<div class="li" style="margin-bottom:4px"><span style="font-size:11px;flex:1">'+name+'</span>'+
        '<button style="padding:3px 8px;font-size:11px" onclick="bkIpRestore(\''+name+'\',this)">&#9850; Geri Y&#252;kle</button></div>';
    });
    if(r.history){
      var hist=r.history.split('|').filter(function(x){return x;});
      if(hist.length){
        html+='<div style="font-size:11px;color:#888;margin-top:8px;margin-bottom:4px">History (son 5):</div>';
        hist.forEach(function(h){html+='<div style="font-size:11px;color:#666;padding:2px 0">'+h+'</div>';});
      }
    }
    el.innerHTML=html;
    if(er)er.innerHTML=rhtml;
  });
}
function bkIpRestore(fname,btn){
  if(!confirm(fname+' geri yuklensin mi?'))return;
  if(btn)btn.disabled=true;
  actD('ipset_restore','file='+encodeURIComponent(fname),btn,'Geri yuklendi');
}
function render(k){
  var v=V[k]||V.dash;
  document.getElementById('pTitle').innerHTML=v.title||k;
  document.getElementById('pSub').innerHTML=v.sub||'';
  document.getElementById('view').innerHTML=v.html?v.html():'<div class="empty">Yap&#305;m a&#351;amas&#305;nda...</div>';
}

document.querySelectorAll('.item').forEach(function(el){
  el.addEventListener('click',function(){
    document.querySelectorAll('.item').forEach(function(i){i.classList.remove('active');});
    el.classList.add('active');curV=el.getAttribute('data-view');render(curV);
  });
});

// Sayfa acilisinda: once eski JSON'u goster, arka planda taze uret, gelince yenile
fetchS();startAuto();
fetch('/cgi-bin/action.sh',{method:'POST',
  headers:{'Content-Type':'application/x-www-form-urlencoded'},
  body:'action=status_refresh'})
  .then(function(){return fetchS();})
  .catch(function(){});
</script>
</body>
</html>
HTMLEOF
    sed -i "s/__KZM_PORT__/${KZM_GUI_PORT}/g" "$KZM_GUI_HTML" 2>/dev/null
    sed -i "s/__KZM_VER__/${SCRIPT_VERSION}/g" "$KZM_GUI_HTML" 2>/dev/null
}

# ---------------------------------------------------------------------------
# kzm_gui_add_cron: status_gen.sh icin cron satiri ekle
# ---------------------------------------------------------------------------
kzm_gui_add_cron() {
    local _tmp="/tmp/kzm_cron_gui.$$"
    mkdir -p /opt/var/spool/cron/crontabs 2>/dev/null
    crontab -l 2>/dev/null | grep -v 'kzm_status_gen.sh' > "$_tmp"
    {
        cat "$_tmp"
        printf '*/1 * * * * /opt/bin/kzm_status_gen.sh >/dev/null 2>&1\n'
    } | crontab -
    rm -f "$_tmp"
}

# ---------------------------------------------------------------------------
# kzm_gui_save_hw_info: model ve firmware bilgisini dosyaya kaydet
# ---------------------------------------------------------------------------
kzm_gui_save_hw_info() {
    mkdir -p /opt/var/run 2>/dev/null
    zkm_banner_get_model  2>/dev/null > /opt/var/run/kzm_hw_model  || true
    zkm_banner_get_firmware 2>/dev/null > /opt/var/run/kzm_hw_firmware || true
}

# ---------------------------------------------------------------------------
# kzm_gui_remove_cron: status_gen cron satirini kaldir
# ---------------------------------------------------------------------------
kzm_gui_remove_cron() {
    local _tmp="/tmp/kzm_cron_gui.$$"
    crontab -l 2>/dev/null | grep -v 'kzm_status_gen.sh' > "$_tmp"
    crontab - < "$_tmp"
    rm -f "$_tmp"
}

# ---------------------------------------------------------------------------
# kzm_gui_install: Web Panel kurulumu
# ---------------------------------------------------------------------------
kzm_gui_install() {
    clear
    printf "\n %b%s%b\n" "${CLR_BOLD}${CLR_CYAN}" "$(T TXT_GUI_TITLE)" "${CLR_RESET}"
    print_line "="

    # /opt kontrolu
    if [ ! -d /opt ]; then
        print_status FAIL "$(T TXT_GUI_ERR_OPT)"
        press_enter_to_continue
        return 1
    fi

    print_status INFO "$(T TXT_GUI_OPKG_UPD)"
    opkg update >/dev/null 2>&1

    # lighttpd kur
    if ! command -v lighttpd >/dev/null 2>&1; then
        print_status INFO "$(T _ 'lighttpd kuruluyor...' 'Installing lighttpd...')"
        if ! opkg install lighttpd >/dev/null 2>&1; then
            print_status FAIL "$(T TXT_GUI_ERR_LIGHTTPD)"
            press_enter_to_continue
            return 1
        fi
    fi

    # lighttpd-mod-cgi kur
    if ! opkg list-installed 2>/dev/null | grep -q 'lighttpd-mod-cgi'; then
        print_status INFO "$(T _ 'lighttpd-mod-cgi kuruluyor...' 'Installing lighttpd-mod-cgi...')"
        if ! opkg install lighttpd-mod-cgi >/dev/null 2>&1; then
            print_status FAIL "$(T TXT_GUI_ERR_CGI)"
            press_enter_to_continue
            return 1
        fi
    fi

    # lighttpd-mod-setenv kur (Cache-Control header icin)
    if ! opkg list-installed 2>/dev/null | grep -q 'lighttpd-mod-setenv'; then
        print_status INFO "$(T _ 'lighttpd-mod-setenv kuruluyor...' 'Installing lighttpd-mod-setenv...')"
        opkg install lighttpd-mod-setenv >/dev/null 2>&1 || true
    fi

    print_status INFO "$(T _ 'Dosyalar olusturuluyor...' 'Creating files...')"

    # Dizinler
    mkdir -p "$KZM_GUI_DIR" "$KZM_GUI_CGI_DIR" /opt/var/run /opt/var/log 2>/dev/null

    # Dosyalar
    kzm_gui_write_lighttpd_conf
    kzm_gui_write_html
    kzm_gui_write_cgi
    kzm_gui_write_status_script

    # HW bilgisi kaydet
    kzm_gui_save_hw_info

    # Ilk status JSON uret
    kzm_gui_gen_status

    # Cron ekle
    kzm_gui_add_cron
    print_status PASS "$(T TXT_GUI_CRON_OK)"

    # Init.d autostart scripti olustur
    cat > /opt/etc/init.d/S80lighttpd << 'INITEOF'
#!/bin/sh
[ "$1" = "start" ] && lighttpd -f /opt/etc/lighttpd/lighttpd.conf >/dev/null 2>&1
[ "$1" = "stop"  ] && kill $(cat /opt/var/run/lighttpd.pid 2>/dev/null) 2>/dev/null; true
[ "$1" = "restart" ] && { kill $(cat /opt/var/run/lighttpd.pid 2>/dev/null) 2>/dev/null; sleep 1; lighttpd -f /opt/etc/lighttpd/lighttpd.conf >/dev/null 2>&1; }
INITEOF
    chmod +x /opt/etc/init.d/S80lighttpd

    # lighttpd baslat
    /opt/etc/init.d/S80lighttpd restart >/dev/null 2>&1 || \
        lighttpd -f "$KZM_GUI_CONF" >/dev/null 2>&1

    sleep 1
    if kzm_gui_is_running; then
        print_status PASS "$(T TXT_GUI_LIGHTTPD_OK)"
    else
        print_status WARN "$(T TXT_GUI_LIGHTTPD_OFF)"
    fi

    print_status PASS "$(T TXT_GUI_INSTALLED)"
    echo
    kzm_gui_show_url
    press_enter_to_continue
}

# ---------------------------------------------------------------------------
# kzm_gui_uninstall: Web Panel kaldirma
# ---------------------------------------------------------------------------
kzm_gui_uninstall() {
    clear
    printf "\n %b%s%b\n" "${CLR_BOLD}${CLR_CYAN}" "$(T TXT_GUI_TITLE)" "${CLR_RESET}"
    print_line "="

    if ! kzm_gui_is_installed; then
        print_status WARN "$(T TXT_GUI_NOT_INSTALLED)"
        press_enter_to_continue
        return 0
    fi

    printf "%b%s%b" "${CLR_ORANGE}" "$(T TXT_GUI_CONFIRM_REMOVE)" "${CLR_RESET}"
    local _ans
    read -r _ans
    case "$_ans" in
        e|E|y|Y) ;;
        *) printf '%s\n' "$(T _ 'Iptal edildi.' 'Cancelled.')"; press_enter_to_continue; return 0 ;;
    esac

    print_status INFO "$(T TXT_GUI_REMOVING)"

    # lighttpd durdur ve autostart kaldir
    kill $(pgrep lighttpd) 2>/dev/null
    /opt/etc/init.d/S80lighttpd stop >/dev/null 2>&1
    rm -f /opt/etc/init.d/S80lighttpd

    # Dosyalari kaldir
    rm -rf "$KZM_GUI_DIR"
    rm -rf /opt/etc/lighttpd
    rm -f  "$KZM_GUI_STATUS_SCRIPT"
    rm -f  "$KZM_GUI_STATUS_JSON"
    rm -f  /opt/var/run/kzm_hw_model
    rm -f  /opt/var/run/kzm_hw_firmware
    rm -f  /opt/var/log/lighttpd_error.log
    rm -f  /opt/var/log/lighttpd_access.log
    rm -f  /opt/var/run/lighttpd.pid

    # iptables kuralini kaldir
    iptables -D INPUT -p tcp --dport "$KZM_GUI_PORT" -j ACCEPT 2>/dev/null

    # opkg ile lighttpd paketlerini kaldir
    opkg remove lighttpd lighttpd-mod-cgi 2>/dev/null | grep -v "^$" || true

    # Cron kaldir
    kzm_gui_remove_cron
    rm -f "$KZM_GUI_CONF_CUSTOM"

    print_status PASS "$(T TXT_GUI_REMOVED)"
    press_enter_to_continue
}

# ---------------------------------------------------------------------------
# kzm_gui_update: Web Panel guncelle (dosyalari yeniden yaz + restart)
# ---------------------------------------------------------------------------
kzm_gui_update() {
    clear
    printf "\n %b%s%b\n" "${CLR_BOLD}${CLR_CYAN}" "$(T TXT_GUI_TITLE)" "${CLR_RESET}"
    print_line "="

    if ! kzm_gui_is_installed; then
        print_status WARN "$(T TXT_GUI_NOT_INSTALLED)"
        print_status INFO "$(T _ 'Once kurulum yapin (Secim 1).' 'Please install first (Option 1).')"
        press_enter_to_continue
        return 1
    fi

    print_status INFO "$(T _ 'Dosyalar guncelleniyor...' 'Updating files...')"
    kzm_gui_write_lighttpd_conf
    kzm_gui_write_html
    kzm_gui_write_cgi
    kzm_gui_write_status_script
    kzm_gui_save_hw_info
    kzm_gui_gen_status

    /opt/etc/init.d/S80lighttpd restart >/dev/null 2>&1

    print_status PASS "$(T TXT_GUI_UPDATED)"
    press_enter_to_continue
}

# ---------------------------------------------------------------------------
# kzm_gui_status: Durum goster
# ---------------------------------------------------------------------------
kzm_gui_status() {
    clear
    printf "\n %b%s%b\n" "${CLR_BOLD}${CLR_CYAN}" "$(T TXT_GUI_TITLE)" "${CLR_RESET}"
    print_line "="

    if kzm_gui_is_running; then
        print_status PASS "$(T TXT_GUI_STATUS_ON)"
    else
        print_status WARN "$(T TXT_GUI_STATUS_OFF)"
    fi

    if [ -f "$KZM_GUI_HTML" ]; then
        print_status PASS "$(T TXT_GUI_HTML_OK)"
    else
        print_status WARN "$(T TXT_GUI_HTML_MISS)"
    fi

    if [ -f "$KZM_GUI_CGI" ]; then
        print_status PASS "$(T TXT_GUI_CGI_OK)"
    else
        print_status WARN "$(T TXT_GUI_CGI_MISS)"
    fi

    if [ -f "$KZM_GUI_STATUS_JSON" ]; then
        print_status PASS "$(T TXT_GUI_JSON_OK)"
    else
        print_status WARN "$(T TXT_GUI_JSON_MISS)"
    fi

    echo
    if kzm_gui_is_running; then
        kzm_gui_show_url
    fi

    press_enter_to_continue
}

# ---------------------------------------------------------------------------
# kzm_gui_change_port: GUI portunu degistir
# ---------------------------------------------------------------------------
kzm_gui_change_port() {
    local _newport
    printf "%s" "$(T TXT_GUI_PORT_PROMPT)"
    read -r _newport
    [ -z "$_newport" ] && return 0
    # Sayi kontrolu ve aralik kontrolu
    case "$_newport" in
        *[!0-9]*) print_status FAIL "$(T TXT_GUI_PORT_INVALID)"; press_enter_to_continue; return 1 ;;
    esac
    if [ "$_newport" -lt 1024 ] || [ "$_newport" -gt 65535 ]; then
        print_status FAIL "$(T TXT_GUI_PORT_INVALID)"
        press_enter_to_continue
        return 1
    fi
    # Conf dosyasina yaz
    printf 'KZM_GUI_PORT=%s\n' "$_newport" > "$KZM_GUI_CONF_CUSTOM"
    KZM_GUI_PORT="$_newport"
    # lighttpd.conf yeniden olustur
    kzm_gui_write_lighttpd_conf
    # HTML'deki port bilgisini guncelle
    sed -i "s/Entware &bull; [0-9]*/Entware \&bull; ${KZM_GUI_PORT}/g" "$KZM_GUI_HTML" 2>/dev/null
    # lighttpd'yi yeniden baslat
    /opt/etc/init.d/S80lighttpd restart >/dev/null 2>&1 || {
        kill "$(cat /opt/var/run/lighttpd.pid 2>/dev/null)" 2>/dev/null
        sleep 1
        lighttpd -f "$KZM_GUI_CONF" >/dev/null 2>&1
    }
    sleep 1
    print_status PASS "$(T TXT_GUI_PORT_CHANGED)"
    kzm_gui_show_url
    press_enter_to_continue
}

# ---------------------------------------------------------------------------
# kzm_gui_show_url: URL goster
# ---------------------------------------------------------------------------
kzm_gui_show_url() {
    local _ip
    _ip="$(kzm_gui_get_lan_ip)"
    printf " %b%s%b : %b%s%b\n" \
        "${CLR_BOLD}" "$(T TXT_GUI_URL_LABEL)" "${CLR_RESET}" \
        "${CLR_CYAN}${CLR_BOLD}" "http://${_ip}:${KZM_GUI_PORT}/" "${CLR_RESET}"
}

# ---------------------------------------------------------------------------
# kzm_gui_toggle: lighttpd ac/kapat
# ---------------------------------------------------------------------------
kzm_gui_toggle() {
    if kzm_gui_is_running; then
        /opt/etc/init.d/S80lighttpd stop >/dev/null 2>&1 || \
            kill "$(cat /opt/var/run/lighttpd.pid 2>/dev/null)" 2>/dev/null || \
            kill "$(pgrep lighttpd | head -n1)" 2>/dev/null
        sleep 1
        print_status WARN "$(T TXT_GUI_DISABLED)"
    else
        if ! kzm_gui_is_installed; then
            print_status WARN "$(T TXT_GUI_NOT_INSTALLED)"
            press_enter_to_continue
            return 1
        fi
        /opt/etc/init.d/S80lighttpd start >/dev/null 2>&1 || \
            lighttpd -f "$KZM_GUI_CONF" >/dev/null 2>&1
        print_status PASS "$(T TXT_GUI_ENABLED)"
    fi
    press_enter_to_continue
}

# ---------------------------------------------------------------------------
# kzm_gui_menu: Ana GUI alt menusu
# ---------------------------------------------------------------------------
kzm_gui_menu() {
    local _gchoice
    while true; do
        clear
        printf "\n %b%s%b\n" "${CLR_BOLD}${CLR_CYAN}" "$(T TXT_GUI_TITLE)" "${CLR_RESET}"
        print_line "="

        # Durum satiri
        if kzm_gui_is_running; then
            printf " %b%s%b\n" "${CLR_GREEN}" "$(T TXT_GUI_STATUS_ON)" "${CLR_RESET}"
            echo
            kzm_gui_show_url
        else
            printf " %b%s%b\n" "${CLR_RED}" "$(T TXT_GUI_STATUS_OFF)" "${CLR_RESET}"
        fi

        print_line "-"
        printf " %b%s%b\n" "${CLR_BOLD}" "$(T TXT_GUI_OPT_1)" "${CLR_RESET}"
        printf " %b%s%b\n" "${CLR_BOLD}" "$(T TXT_GUI_OPT_2)" "${CLR_RESET}"
        printf " %b%s%b\n" "${CLR_BOLD}" "$(T TXT_GUI_OPT_3)" "${CLR_RESET}"
        printf " %b%s%b\n" "${CLR_BOLD}" "$(T TXT_GUI_OPT_4)" "${CLR_RESET}"
        printf " %b%s%b%s%b\n" "${CLR_BOLD}" "$(T _ '5) Port Degistir (Mevcut: ' '5) Change Port (Current: ')" "${CLR_CYAN}${CLR_BOLD}" "${KZM_GUI_PORT})" "${CLR_RESET}"
        printf " %b%s%b\n" "${CLR_BOLD}" "$(T TXT_GUI_OPT_6)" "${CLR_RESET}"
        printf " %b%s%b\n" "${CLR_DIM}"  "$(T TXT_GUI_OPT_0)" "${CLR_RESET}"
        print_line "-"
        printf "$(T _ 'Seciminiz: ' 'Your choice: ')"
        read -r _gchoice
        case "$_gchoice" in
            1) kzm_gui_install ;;
            2) kzm_gui_uninstall ;;
            3) kzm_gui_update ;;
            4) kzm_gui_status ;;
            5) kzm_gui_change_port ;;
            6) kzm_gui_toggle ;;
            0) break ;;
            *) printf '%s\n' "$(T _ 'Gecersiz secim.' 'Invalid choice.')" ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# --cgi-action argumani: CGI tarafindan cagrilir, dogrudan fonksiyon calistirir
# ---------------------------------------------------------------------------

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
			14) network_diag_menu ;;
			15) telegram_notifications_menu ;;
			16) health_monitor_menu ;;
			17) kzm_gui_menu ;;
B|b) blockcheck_test_menu ;;
L|l) toggle_lang ;;
R|r) scheduled_reboot_menu ;;
        U|u) zkm_full_uninstall ;;
            0) echo "Cikis yapiliyor..."; break ;;
            *) echo "$(T _ 'Gecersiz secim! Lutfen 0-17, B, L, R veya U girin.' 'Invalid choice! Please enter 0-17, B, L, R or U.')" ;;
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

if [ "$1" = "--telegram-daemon" ]; then
    trap '' HUP 2>/dev/null
    telegram_load_config 2>/dev/null
    telegram_bot_daemon
    exit 0
fi

# --- Betigin Baslangic Noktasi ---
# Kullanim: ./script.sh cleanup  -> Zapret kurulu olmasa bile kalintilari temizler
if [ "$1" = "cleanup" ]; then
    cleanup_only_leftovers
    exit 0
fi

# curl kontrolu (daemon ve cleanup modlarinda atla)
if [ "$1" != "--healthmon-daemon" ] && [ "$1" != "--telegram-daemon" ] && [ "$1" != "cleanup" ]; then
    if ! command -v curl >/dev/null 2>&1; then
        printf '%b\n' "$(T _ 'WARN: curl bulunamadi. Yukleniyor...' 'WARN: curl not found. Installing...')"
        if command -v opkg >/dev/null 2>&1; then
            opkg update >/dev/null 2>&1
            if opkg install curl >/dev/null 2>&1; then
                printf '%b\n' "$(T _ 'PASS: curl basariyla yuklendi.' 'PASS: curl installed successfully.')"
            else
                printf '%b\n' "$(T _ 'WARN: curl yuklenemedi. Bazi ozellikler calismayabilir.' 'WARN: curl install failed. Some features may not work.')"
            fi
        else
            printf '%b\n' "$(T _ 'WARN: opkg bulunamadi, curl yuklenemiyor.' 'WARN: opkg not found, cannot install curl.')"
        fi
    fi
fi

# Web GUI versiyon kontrolu: kurulu ise KZM surumuyle eslesmiyorsa sessizce guncelle
if [ -f "$KZM_GUI_HTML" ]; then
    _gui_ver="$(grep -o 'kzm-version" content="[^"]*"' "$KZM_GUI_HTML" 2>/dev/null | sed 's/.*content="//;s/"//')"
    if [ "$_gui_ver" != "$SCRIPT_VERSION" ]; then
        kzm_gui_write_html
        kzm_gui_write_cgi
    fi
fi

main_menu_loop

# WAN IP detection (best-effort)
WAN_IP="$(ip -4 addr show ppp0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)"
[ -z "$WAN_IP" ] && WAN_IP="$(ip -4 addr show eth0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)"
[ -z "$WAN_IP" ] && WAN_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -n1)"
[ -z "$WAN_IP" ] && WAN_IP="unknown"
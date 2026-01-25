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

# BETIK BILGILENDIRME
# Notepad++ da Duzen > Satir Sonunu Donustur > UNIX (LF)

# Zapret IPv6 destegi secimi (y/n). Varsayilan: n
ZAPRET_IPV6="n"

# -------------------------------------------------------------------
# Dil (TR/EN) Secimi ve Sozluk
# -------------------------------------------------------------------
LANG_FILE="/opt/zapret/lang"
LANG="tr"

# -------------------------------------------------------------------
# Script Kimligi (Repo/Surum)
# -------------------------------------------------------------------
SCRIPT_NAME="keenetic_zapret_otomasyon_ipv6_ipset.sh"
# Version scheme: vYY.M.D[.N]  (YY=year, M=month, D=day, N=daily revision)
SCRIPT_VERSION="v26.1.25"
SCRIPT_REPO="https://github.com/RevolutionTR/keenetic-zapret-manager"
SCRIPT_AUTHOR="RevolutionTR"


# Sozluk: TXT_*_TR / TXT_*_EN
TXT_MAIN_TITLE_TR="Keenetic icin Zapret Yonetim Scripti"
TXT_MAIN_TITLE_EN="Zapret Management Script for Keenetic"

TXT_OPTIMIZED_TR="Turk Telekom Icin Optimize Edilmistir !!!"
TXT_OPTIMIZED_EN="Optimized for Turk Telekom !!!"

TXT_DPI_WARNING_TR="Diger DPI Profillerinin Calismasi Garanti Edilemez"
TXT_DPI_WARNING_EN="Other DPI profiles are NOT guaranteed to work"

TXT_DEVELOPER_TR="Gelistirici : RevolutionTR"
TXT_DEVELOPER_EN="Developer  : RevolutionTR"

TXT_EDITOR_TR="Duzenleyen  : RevolutionTR"
TXT_EDITOR_EN="Maintainer : RevolutionTR"

TXT_VERSION_TR="Surum       : ${SCRIPT_VERSION}"
TXT_VERSION_EN="Version     : ${SCRIPT_VERSION}"

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

TXT_MENU_7_TR=" 7. Yeni Versiyon Sorgula (GitHub)"
TXT_MENU_7_EN=" 7. Check Latest Version (GitHub)"

TXT_MENU_8_TR=" 7. Zapret IPv6 Destegi (Sihirbaz)"
TXT_MENU_8_EN=" 7. Zapret IPv6 Support (Wizard)"

TXT_MENU_9_TR=" 8. IPSET (Yerel ağda sadece statik IP kullanan cihazlarla çalışır – DHCP desteklenmez!)"
TXT_MENU_9_EN=" 8. IPSET (Works only with static IP addresses on the local network – DHCP is NOT supported!))"
TXT_MENU_10_TR=" 9. DPI Profilini Degistir"
TXT_MENU_10_EN=" 9. Change DPI Profile"

TXT_MENU_11_TR="10. Betik Guncelleme Kontrolu (GitHub)"
TXT_MENU_11_EN="10. Script Update Check (GitHub)"

TXT_MENU_B_TR=" B. Blockcheck (DPI Test Raporu)"
TXT_MENU_B_EN=" B. Blockcheck (DPI Test Report)"


TXT_MENU_L_TR=" L. Dil Degistir (TR/EN)"
TXT_MENU_L_EN=" L. Switch Language (TR/EN)"

TXT_MENU_0_TR=" 0. Cikis"
TXT_MENU_0_EN=" 0. Exit"

TXT_MENU_FOOT_TR="--------------------------------------------------------------------------------------------"
TXT_MENU_FOOT_EN="--------------------------------------------------------------------------------------------"

TXT_PROMPT_MAIN_TR="Seciminizi yapin (0-10, L veya B): "
TXT_PROMPT_MAIN_EN="Select an option (0-10, L or B): "

TXT_LANG_NOW_TR="Dil: Turkce"
TXT_LANG_NOW_EN="Language: English"

# IPSET menu
TXT_IPSET_TITLE_TR=" Zapret IPSET (Istemci Secimi)"
TXT_IPSET_TITLE_EN=" Zapret IPSET (Client Selection)"

TXT_IPSET_1_TR=" 1. Tum Aga Uygula (client filtresi kapali)"
TXT_IPSET_1_EN=" 1. Apply to whole network (client filter off)"

TXT_IPSET_2_TR=" 2. Secili IP'lere Uygula (IP gir)"
TXT_IPSET_2_EN=" 2. Apply to selected IPs (enter IPs)"

TXT_IPSET_3_TR=" 3. Mevcut IP Listesini Goster"
TXT_IPSET_3_EN=" 3. Show current IP list"

TXT_IPSET_4_TR=" 4. Listeye Tek IP Ekle"
TXT_IPSET_4_EN=" 4. Add a single IP to list"

TXT_IPSET_5_TR=" 5. Listeden Tek IP Sil"
TXT_IPSET_5_EN=" 5. Remove a single IP from list"

TXT_IPSET_0_TR=" 0. Ana Menuye Don"
TXT_IPSET_0_EN=" 0. Back to main menu"

TXT_PROMPT_IPSET_TR=" Seciminizi Yapin (0-5): "
TXT_PROMPT_IPSET_EN=" Select an option (0-5): "

TXT_PROMPT_IPSET_BASIC_TR=" Seciminizi Yapin (0-2): "
TXT_PROMPT_IPSET_BASIC_EN=" Select an option (0-2): "

# Ceviri secici
# --- EK DIL METINLERI (TR/EN) ---
TXT_PRESS_ENTER_TR="Devam etmek icin Enter'a basin..."
TXT_PRESS_ENTER_EN="Press Enter to continue..."
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

TXT_IPSET_MODE_ALL_TR="Mod: Tum ag"
TXT_IPSET_MODE_ALL_EN="Mode: Whole network"

TXT_IP_LIST_FILE_TR="IP Listesi (dosya): "
TXT_IP_LIST_FILE_EN="IP List (file): "

TXT_IPSET_MEMBERS_TR="IPSET Uyeleri (aktif): "
TXT_IPSET_MEMBERS_EN="IPSET members (active): "

TXT_VERSION_INSTALLED_TR="Kurulu Surum: "
TXT_VERSION_INSTALLED_EN="Installed version: "

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


TXT_ADD_IP_TR="Eklenecek IP: "
TXT_ADD_IP_EN="IP to add: "

TXT_DEL_IP_TR="Silinecek IP: "
TXT_DEL_IP_EN="IP to remove: "
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
    # Not: read -p ile prompt yazdiriyoruz, sonra ekrani temizleyip menuye donuyoruz.
    read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")" _
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
    echo "--------------------------------------------------"
printf " \033[1;33mZapret cikis arayuzu secimi\033[0m\n"
    echo " (Ornek: ppp0 = WAN, wg0/wg1 = WireGuard)"
    echo " Su anki: $(get_wan_if)"
    echo " Onerilen: $rec"
    echo "--------------------------------------------------"
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


# --- DPI PROFIL SECIMI (NFQWS_OPT) ---
DPI_PROFILE_FILE="/opt/zapret/dpi_profile"

get_dpi_profile() {
    local p="tt_default"
    [ -f "$DPI_PROFILE_FILE" ] && p="$(cat "$DPI_PROFILE_FILE" 2>/dev/null)"
    case "$p" in
        tt_default|tt_fiber|tt_alt|sol|sol_alt|turkcell_mob|vodafone_mob) echo "$p" ;;
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
        tt_alt)     echo "Turk Telekom Alternatif (TTL3 fake)";;
        sol)        echo "Superonline (fake + m5sig)";;
        sol_alt)    echo "Superonline Alternatif (TTL3 fake + m5sig)";;
        turkcell_mob) echo "Turkcell Mobil (TTL1 + AutoTTL3 fake)";;
        vodafone_mob) echo "Vodafone Mobil (multisplit split-pos=2)";;
        *) echo "$1";;
    esac
}

dpi_profile_name_en() {
    case "$1" in
        tt_default) echo "Turk Telekom Fiber (TTL2 fake)";;
        tt_fiber)   echo "Turk Telekom Fiber (TTL4 fake)";;
        tt_alt)     echo "Turk Telekom Alternative (TTL3 fake)";;
        sol)        echo "Superonline (fake + m5sig)";;
        sol_alt)    echo "Superonline Alternative (TTL3 fake + m5sig)";;
        turkcell_mob) echo "Turkcell Mobile (TTL1 + AutoTTL3 fake)";;
        vodafone_mob) echo "Vodafone Mobile (multisplit split-pos=2)";;
        *) echo "$1";;
    esac
}

select_dpi_profile() {
    local cur="$(get_dpi_profile)"
    echo "--------------------------------------------------"
    echo "$(T dpi_title "DPI Profili Secimi" "DPI Profile Selection")"
    echo "--------------------------------------------------"
    printf "\033[1;32m%s: %s\033[0m\n" "$(T dpi_current 'Su anki' 'Current')" "$(T dpi_curp "$(dpi_profile_name_tr "$cur")" "$(dpi_profile_name_en "$cur")")"
    echo "--------------------------------------------------"
        # Menu satirlarinda:
    # - Varsayilan profil (tt_default) her zaman "Default/Varsayilan" olarak isaretlenir
    # - Kullanilan profil "ACTIVE/AKTIF" olarak isaretlenir
    for _id in tt_default tt_fiber tt_alt sol sol_alt turkcell_mob vodafone_mob; do
        _num=""
        case "$_id" in
            tt_default) _num="1" ;;
            tt_fiber)   _num="2" ;;
            tt_alt)     _num="3" ;;
            sol)        _num="4" ;;
            sol_alt)    _num="5" ;;
            turkcell_mob) _num="6" ;;
            vodafone_mob) _num="7" ;;
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

        # aktif isareti
        if [ "$cur" = "$_id" ]; then
            _suf_tr="${_suf_tr} (AKTIF)"
            _suf_en="${_suf_en} (ACTIVE)"
        fi

        echo " ${_num}. $(T dpi_prof_${_id} "${_name_tr}${_suf_tr}" "${_name_en}${_suf_en}")"
    done
    echo " 0. $(T back_main 'Ana Menuye Don' 'Back')"
    echo "--------------------------------------------------"
    read -r -p "$(T dpi_prompt "Seciminizi yapin (0-7): " "Select an option (0-7): ")" sel
    case "$sel" in
        1) set_dpi_profile tt_default ;;
        2) set_dpi_profile tt_fiber ;;
        3) set_dpi_profile tt_alt ;;
        4) set_dpi_profile sol ;;
        5) set_dpi_profile sol_alt ;;
        6) set_dpi_profile turkcell_mob ;;
        7) set_dpi_profile vodafone_mob ;;
        0|*) return 1 ;;
    esac

    # DPI profiline gore NFQWS parametrelerini guncelle
    update_nfqws_parameters >/dev/null 2>&1

    echo "--------------------------------------------------"
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
    /opt/zapret/init.d/sysv/zapret restart-fw >/dev/null 2>&1 || true
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

    # Profil parametreleri (varsayilanlar)
    local DESYNC="fake"
    local TTL=""
    local AUTOTTL=""
    local FOOLING=""
    local SPLITPOS=""

    case "$profile" in
        tt_default) DESYNC="fake"; TTL="2" ;;
        tt_fiber)   DESYNC="fake"; TTL="4" ;;
        tt_alt)     DESYNC="fake"; TTL="3" ;;
        sol)        DESYNC="fake"; FOOLING="m5sig" ;;
        sol_alt)    DESYNC="fake"; TTL="3"; FOOLING="m5sig" ;;
        turkcell_mob) DESYNC="fake"; TTL="1"; AUTOTTL="3" ;;
        vodafone_mob) DESYNC="multisplit"; SPLITPOS="2" ;;
        *) DESYNC="fake"; TTL="2"; profile="tt_default" ;;
    esac

    build_line() {
        # $1 proto(tcp/udp) $2 port(s) $3 extra endflag(--new or empty)
        local proto="$1" ports="$2" endflag="$3"
        local line="--filter-${proto}=${ports} --dpi-desync=${DESYNC}"

        [ -n "$FOOLING" ] && line="${line} --dpi-desync-fooling=${FOOLING}"
        [ -n "$SPLITPOS" ] && line="${line} --dpi-desync-split-pos=${SPLITPOS}"
        [ -n "$TTL" ] && line="${line} --dpi-desync-ttl=${TTL}"
        [ -n "$AUTOTTL" ] && line="${line} --dpi-desync-autottl=${AUTOTTL}"

        # IPv6 tarafinda TTL6 ekle (TTL varsa)
        if [ "$ipv6" = "y" ] || [ "$ipv6" = "Y" ]; then
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
    '\''start'\'')
        start
        ;;
    '\''stop'\'')
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
        echo "--------------------------------------------------"
        _LBL_LATEST="$(T lbl_latest 'Guncel' 'Latest')"
        _LBL_INSTALLED="$(T lbl_installed 'Kurulu' 'Installed')"
        printf "%-12s: [1;32m%s[0m
" "$_LBL_LATEST" "$REMOTE_VER"
        if [ -f "/opt/zapret/version" ]; then
            LOCAL_VER=$(cat /opt/zapret/version)
            printf "%-12s: [1;33m%s[0m
" "$_LBL_INSTALLED" "$LOCAL_VER"
            echo "--------------------------------------------------"
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
        echo "$(T ipv6_status_on 'Zapret IPv6 destegi: ACIK' 'Zapret IPv6 support: ON')"
    else
        echo "$(T ipv6_status_off 'Zapret IPv6 destegi: KAPALI' 'Zapret IPv6 support: OFF')"
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

    # FW kurallarini ve servisi tazele
    /opt/zapret/init.d/sysv/zapret restart-fw &> /dev/null
    restart_zapret
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
    iptables -t mangle -I POSTROUTING 1 -p tcp -m multiport --dports 80,443 \
        -m set --match-set "$IPSET_NAME" src \
        -j NFQUEUE --queue-num "$QNUM" --queue-bypass >/dev/null 2>&1

    iptables -t mangle -I POSTROUTING 1 -p udp -m multiport --dports 443 \
        -m set --match-set "$IPSET_NAME" src \
        -j NFQUEUE --queue-num "$QNUM" --queue-bypass >/dev/null 2>&1

    iptables -I INPUT 1 -p tcp -m multiport --sports 80,443 \
        -m set --match-set "$IPSET_NAME" dst \
        -j NFQUEUE --queue-num "$QNUM" --queue-bypass >/dev/null 2>&1

    iptables -I FORWARD 1 -p tcp -m multiport --sports 80,443 \
        -m set --match-set "$IPSET_NAME" dst \
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
        echo "$(T ipset_mode_list "$TXT_IPSET_MODE_LIST_TR" "$TXT_IPSET_MODE_LIST_EN")"
        if [ -f "$IPSET_CLIENT_FILE" ]; then
            echo "$(T ip_list_file "$TXT_IP_LIST_FILE_TR" "$TXT_IP_LIST_FILE_EN")$(tr '\n' ' ' < "$IPSET_CLIENT_FILE" | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')"
        else
            echo "$(T ip_list_file "$TXT_IP_LIST_FILE_TR" "$TXT_IP_LIST_FILE_EN")$(T empty "$TXT_EMPTY_TR" "$TXT_EMPTY_EN")"
        fi
        echo "$(T ipset_members "$TXT_IPSET_MEMBERS_TR" "$TXT_IPSET_MEMBERS_EN")$(ipset list "$IPSET_CLIENT_NAME" 2>/dev/null | sed -n '/^Members:/,$p' | tail -n +2 | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')"
    else
        echo "$(T ipset_mode_all "$TXT_IPSET_MODE_ALL_TR" "$TXT_IPSET_MODE_ALL_EN")"
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
        echo "--------------------------------------------------"
        echo "$(T TXT_IPSET_TITLE)"
        echo "--------------------------------------------------"
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
            echo "--------------------------------------------------"
            printf "$(T TXT_PROMPT_IPSET)"
        else
            echo "$(T TXT_IPSET_0)"
            echo "--------------------------------------------------"
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
                # Basit IPv4 dogrulama
                echo "$oneip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || { echo "Gecersiz IP!"; }
                if echo "$oneip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
                    touch "$IPSET_CLIENT_FILE" 2>/dev/null
                    grep -Fqx "$oneip" "$IPSET_CLIENT_FILE" 2>/dev/null || echo "$oneip" >> "$IPSET_CLIENT_FILE"
                    apply_ipset_client_settings
                    echo "Tamam: IP eklendi."
                fi
                fi
                ;;

            5)
                MODE="$(cat "$IPSET_CLIENT_MODE_FILE" 2>/dev/null)"
                [ -z "$MODE" ] && MODE="all"
                if [ "$MODE" != "list" ]; then
                    echo "Bu menu sadece \"Secili IP'lere Uygula\" (mod=list) acikken kullanilabilir. Once 2'yi secin."
                else
                read -r -p "$(T del_ip_prompt "$TXT_DEL_IP_TR" "$TXT_DEL_IP_EN")" oneip
                if [ -f "$IPSET_CLIENT_FILE" ]; then
                    tmpf="/tmp/ipset_clients.$$"
                    grep -Fvx "$oneip" "$IPSET_CLIENT_FILE" > "$tmpf" 2>/dev/null && mv "$tmpf" "$IPSET_CLIENT_FILE"
                    apply_ipset_client_settings
                    echo "Tamam: IP silindi."
                else
                    echo "IP listesi dosyasi yok."
                fi
                fi
                ;;
            0)
                echo "Ana menuye donuluyor..."
                break
                ;;
            *)
                echo "$(T invalid_main 'Gecersiz secim! Lutfen 0 ile 10 arasinda bir sayi veya L girin.' 'Invalid choice! Please enter a number between 0 and 10 or L.')"
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
    echo "--------------------------------------------------"
    echo " Kalinti Temizligi (Zapret olmasa da calisir)"
    echo "--------------------------------------------------"
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
    BACKUP_FILE="${TARGET_SCRIPT}.bak_${SCRIPT_VERSION#v}_$(date +%Y%m%d_%H%M%S 2>/dev/null)"

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

    echo "--------------------------------------------------"
    _LBL_SCRIPT="$(T lbl_script_ver 'Kurulu Betik Surumu' 'Installed Script Version')"
    _LBL_GH="$(T lbl_gh_ver 'GitHub Guncel Surum' 'GitHub Latest Version')"
    _LBL_REPO="$(T lbl_repo 'Repo' 'Repository')"

    # Kurulu betik surumu (sari)
    printf "%-22s: \033[1;33m%s\033[0m\n" "$_LBL_SCRIPT" "$SCRIPT_VERSION"

    if [ -z "$REMOTE_VER" ]; then
        # Bilgi alinamadi (kirmizi)
        printf "%-22s: \033[1;31m%s\033[0m\n" "$_LBL_GH" "$(T github_noinfo 'Bilgi alinamadi' 'Unable to fetch info')"
    else
        # GitHub surumu (yesil)
        printf "%-22s: \033[1;32m%s\033[0m\n" "$_LBL_GH" "$REMOTE_VER"
    fi

    # Repo (renksiz)
    printf "%-22s: %s\n" "$_LBL_REPO" "$SCRIPT_REPO"
    echo "--------------------------------------------------"

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
display_menu() {
    echo "=================================================="
    echo "$(T TXT_MAIN_TITLE)"
    echo "$(T TXT_OPTIMIZED)"
    _dpi_warn="$(T dpi_warn "$TXT_DPI_WARNING_TR" "$TXT_DPI_WARNING_EN")"
    echo "$_dpi_warn"
    echo "$(T TXT_DEVELOPER)"
    echo "$(T TXT_EDITOR)"
    echo "$(T TXT_VERSION)"
    echo "=================================================="
    echo " $(T TXT_DESC1)"
    echo " $(T TXT_DESC2)"
    echo " $(T TXT_DESC3)"
    echo
    echo "$(T TXT_MENU_HEADER)"
    echo "$(T TXT_MENU_1)"
    echo "$(T TXT_MENU_2)"
    echo "$(T TXT_MENU_3)"
    echo "$(T TXT_MENU_4)"
    echo "$(T TXT_MENU_5)"
    echo "$(T TXT_MENU_6)"
    echo "$(T TXT_MENU_8)"
    echo "$(T TXT_MENU_9)"
    echo "$(T TXT_MENU_10)"
    echo "$(T TXT_MENU_11)"
    echo "$(T TXT_MENU_B)"
    echo "$(T TXT_MENU_L)  ($(lang_label))"
    echo "$(T TXT_MENU_0)"
    echo "$(T TXT_MENU_FOOT)"
    echo
    printf "$(T TXT_PROMPT_MAIN)"

}

# --- BLOCKCHECK (DPI TEST) ---
run_blockcheck() {
    local BLOCKCHECK="/opt/zapret/blockcheck.sh"
    local DEF_DOMAIN="roblox.com"
    local domains report today was_running stop_ans do_stop stopped_by_us

    echo "--------------------------------------------------"
    echo "$(T blk_title 'Blockcheck (DPI Test Raporu)' 'Blockcheck (DPI Test Report)')"
    echo "--------------------------------------------------"

    if [ ! -x "$BLOCKCHECK" ]; then
        echo "$(T blk_missing 'HATA: /opt/zapret/blockcheck.sh bulunamadi veya calistirilabilir degil.' 'ERROR: /opt/zapret/blockcheck.sh not found or not executable.')"
        read -r -p "$(T press_enter "$TXT_PRESS_ENTER_TR" "$TXT_PRESS_ENTER_EN")" _tmp
        clear
        return 1
    fi

    # Domain(ler)
    read -r -p "$(T blk_domain 'Test edilecek domain(ler) (Enter=roblox.com, 0=Iptal): ' 'Domain(s) to test (Enter=roblox.com, 0=Cancel): ')" domains
    if [ "$domains" = "0" ]; then
        clear
        return 0
    fi
    [ -z "$domains" ] && domains="$DEF_DOMAIN"

    today="$(date +%Y%m%d 2>/dev/null)"
    [ -z "$today" ] && today="00000000"
    report="/opt/zapret/blockcheck_${today}.txt"

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
    echo "--------------------------------------------------"

    # blockcheck kendi icinde domain prompt'u aciyor; stdin'e domainleri basarak takilmasini engelliyoruz.
    # stdout+stderr rapora yazilsin diye tee kullan.
    # (tee yoksa sadece > ile yazar)
    if command -v tee >/dev/null 2>&1; then
        printf "%s\n" "$domains" | sh "$BLOCKCHECK" 2>&1 | tee "$report"
    else
        printf "%s\n" "$domains" | sh "$BLOCKCHECK" >"$report" 2>&1
        cat "$report" 2>/dev/null
    fi

    echo "--------------------------------------------------"
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


main_menu_loop() {
    while true; do
    clear  # clear_on_start_main_loop
        display_menu
        read -r choice
    clear  # clear_after_choice_main
        echo ""
        case "$choice" in
            1) install_zapret; press_enter_to_continue ;;
            2) uninstall_zapret ;;
            3) start_zapret; press_enter_to_continue ;;
            4) stop_zapret; press_enter_to_continue ;;
            5) restart_zapret; press_enter_to_continue ;;
            6) check_remote_update ;;
        10) check_manager_update ;;
        7) configure_zapret_ipv6_support ;;
        8) manage_ipset_clients ;;
        9)
            if select_dpi_profile; then
                apply_dpi_profile_now
            fi
            ;;
B|b) run_blockcheck ;;
L|l) toggle_lang ;; 
            0) echo "Cikis yapiliyor..."; break ;;
            *) echo "Gecersiz secim! Lutfen 0 ile 10 arasinda bir sayi girin." ;;
        esac
        echo ""
    done
}

# --- Betigin Baslangic Noktasi ---
# Kullanım: ./script.sh cleanup  -> Zapret kurulu olmasa bile kalıntıları temizler
if [ "$1" = "cleanup" ]; then
    cleanup_only_leftovers
    exit 0
fi

main_menu_loop

#!/usr/bin/env bash
set -euo pipefail

PING_TARGETS=("172.29.8.2" "172.29.8.10")
MACHINE_NO="${MACHINE_NO:-91}"
STATIC_IP="192.168.10.${MACHINE_NO}"
STATIC_GATEWAY="${STATIC_GATEWAY:-192.168.10.1}"
FINAL_HOSTNAME="${FINAL_HOSTNAME:-hang-2300191}"
OPENSSH_RPM="${OPENSSH_RPM:-OpenSSH-server.version.rpm}"
DHCP_RANGE_START="${DHCP_RANGE_START:-192.168.10.100}"
DHCP_RANGE_END="${DHCP_RANGE_END:-192.168.10.130}"

print_title() {
    printf '\n========== %s ==========\n' "$1"
}

require_root() {
    if [ "${EUID}" -ne 0 ]; then
        echo "Vui long chay script bang quyen root."
        exit 1
    fi
}

require_command() {
    local command_name="$1"

    if ! command -v "${command_name}" >/dev/null 2>&1; then
        echo "Thieu lenh ${command_name}. Hay cai goi phu hop truoc khi chay."
        exit 1
    fi
}

confirm_or_skip() {
    local variable_name="$1"
    local message="$2"

    if [ "${!variable_name:-no}" != "yes" ]; then
        echo "${message}"
        echo "Dat ${variable_name}=yes neu dang thuc hien tren may ao bai thi."
        return 1
    fi

    return 0
}

get_default_iface() {
    ip route show default | awk '{for (i = 1; i <= NF; i++) if ($i == "dev") {print $(i + 1); exit}}'
}

get_nmcli_connection() {
    local iface="$1"

    nmcli -t -f NAME,DEVICE connection show --active \
        | awk -F: -v iface="${iface}" '$2 == iface {print $1; exit}'
}

partition_path() {
    local disk="$1"
    local number="$2"

    case "${disk}" in
        *nvme*|*mmcblk*)
            printf '%sp%s\n' "${disk}" "${number}"
            ;;
        *)
            printf '%s%s\n' "${disk}" "${number}"
            ;;
    esac
}

ping_targets() {
    local label="$1"

    echo "${label}"
    for target in "${PING_TARGETS[@]}"; do
        echo "Kiem tra ${target}:"
        ping -c 4 "${target}" || true
    done
}

cau_1() {
    print_title "Cau 1: Chia dia thanh /, /var, /usr, swap, /home"

    if [ -z "${DISK:-}" ]; then
        echo "Dat DISK=/dev/<dia-can-chia> de tao phan vung."
        echo "So do de nghi: / 20G, /var 6G, /usr 10G, swap 2G, /home phan con lai."
        return
    fi

    confirm_or_skip "CONFIRM_PARTITION" "Thao tac nay se xoa bang phan vung tren ${DISK}." || return
    require_command "parted"
    require_command "mkfs.ext4"
    require_command "mkswap"

    parted -s "${DISK}" mklabel gpt
    parted -s "${DISK}" mkpart root ext4 1MiB 20GiB
    parted -s "${DISK}" mkpart var ext4 20GiB 26GiB
    parted -s "${DISK}" mkpart usr ext4 26GiB 36GiB
    parted -s "${DISK}" mkpart swap linux-swap 36GiB 38GiB
    parted -s "${DISK}" mkpart home ext4 38GiB 100%
    partprobe "${DISK}" || true

    mkfs.ext4 -F "$(partition_path "${DISK}" 1)"
    mkfs.ext4 -F "$(partition_path "${DISK}" 2)"
    mkfs.ext4 -F "$(partition_path "${DISK}" 3)"
    mkswap "$(partition_path "${DISK}" 4)"
    mkfs.ext4 -F "$(partition_path "${DISK}" 5)"
    lsblk -f "${DISK}"
}

cau_2() {
    print_title "Cau 2: Xem bang routing va xuat vao /root/routing"
    require_command "ip"
    require_command "route"

    {
        echo "Bang routing bang lenh route -n:"
        route -n
        echo
        echo "Bang routing bang lenh ip route:"
        ip route show
    } | tee /root/routing

    local default_gateway
    local network_address
    default_gateway="$(ip route show default | awk '{print $3; exit}')"
    network_address="$(ip route show scope link | awk '$1 ~ /\// {print $1; exit}')"

    echo "Default gateway: ${default_gateway:-khong-co}"
    echo "Dia chi duong mang: ${network_address:-khong-co}"
}

cau_3() {
    print_title "Cau 3: Tim tap tin ping va kiem tra ket noi"
    command -v ping || whereis ping || true
    ping_targets "Ping khi chua thay doi routing:"
}

cau_4() {
    print_title "Cau 4: Xoa default gateway bang route va so sanh"

    local default_gateway
    local default_iface
    default_gateway="$(ip route show default | awk '{print $3; exit}')"
    default_iface="$(get_default_iface)"

    if [ -z "${default_gateway}" ] || [ -z "${default_iface}" ]; then
        echo "Khong tim thay default gateway hien tai."
        return
    fi

    echo "Default gateway hien tai: ${default_gateway}, interface: ${default_iface}"
    confirm_or_skip "CONFIRM_ROUTE_CHANGE" "Xoa default gateway co the lam mat ket noi mang." || return

    ping_targets "Truoc khi xoa default gateway:"
    route del default gw "${default_gateway}"
    ping_targets "Sau khi xoa default gateway:"
    route add default gw "${default_gateway}" dev "${default_iface}"
    ping_targets "Sau khi them lai default gateway:"
}

cau_5() {
    print_title "Cau 5: Xoa dia chi duong mang bang route va so sanh"

    local route_line
    local network_address
    local netmask
    local iface
    route_line="$(route -n | awk '$1 != "0.0.0.0" && $2 == "0.0.0.0" && $4 ~ /U/ {print $1, $3, $8; exit}')"

    if [ -z "${route_line}" ]; then
        echo "Khong tim thay dia chi duong mang can xoa."
        return
    fi

    read -r network_address netmask iface <<< "${route_line}"
    echo "Duong mang hien tai: ${network_address}, netmask: ${netmask}, interface: ${iface}"
    confirm_or_skip "CONFIRM_ROUTE_CHANGE" "Xoa duong mang truc tiep co the lam mat ket noi mang." || return

    ping_targets "Truoc khi xoa dia chi duong mang:"
    route del -net "${network_address}" netmask "${netmask}" dev "${iface}"
    ping_targets "Sau khi xoa dia chi duong mang:"
    route add -net "${network_address}" netmask "${netmask}" dev "${iface}"
    ping_targets "Sau khi them lai dia chi duong mang:"
}

cau_6() {
    print_title "Cau 6: Doi ten may tinh bang cac cach khac nhau"
    confirm_or_skip "CONFIRM_HOSTNAME_CHANGE" "Doi hostname se thay doi cau hinh may hien tai." || return

    local old_hostname
    old_hostname="$(hostname)"

    hostname "hang-temp"
    hostname

    if command -v hostnamectl >/dev/null 2>&1; then
        hostnamectl set-hostname "hang-hostnamectl"
        hostnamectl status --static
    fi

    printf '%s\n' "hang-etc-hostname" > /etc/hostname
    hostname "hang-etc-hostname"
    hostname

    if command -v hostnamectl >/dev/null 2>&1; then
        hostnamectl set-hostname "${FINAL_HOSTNAME}"
    else
        hostname "${FINAL_HOSTNAME}"
        printf '%s\n' "${FINAL_HOSTNAME}" > /etc/hostname
    fi

    echo "Hostname ban dau: ${old_hostname}"
    echo "Hostname sau cung: $(hostname)"
}

cau_7() {
    print_title "Cau 7: Doi dia chi IP bang cac cach khac nhau"

    local iface
    iface="${IFACE:-$(get_default_iface)}"
    if [ -z "${iface}" ]; then
        echo "Khong tim thay interface mac dinh. Dat IFACE=<ten-card-mang> roi chay lai."
        return
    fi

    echo "Interface su dung: ${iface}"
    confirm_or_skip "CONFIRM_IP_CHANGE" "Doi dia chi IP co the lam mat ket noi SSH." || return

    ip addr add "192.168.10.70/24" dev "${iface}" || true
    ip addr show dev "${iface}"
    ip addr del "192.168.10.70/24" dev "${iface}" || true

    if command -v ifconfig >/dev/null 2>&1; then
        ifconfig "${iface}:1" 192.168.10.71 netmask 255.255.255.0 up
        ifconfig "${iface}:1"
        ifconfig "${iface}:1" down
    else
        echo "Khong co ifconfig, bo qua cach doi bang ifconfig."
    fi

    if command -v nmcli >/dev/null 2>&1; then
        local connection_name
        connection_name="$(get_nmcli_connection "${iface}")"
        if [ -n "${connection_name}" ]; then
            nmcli connection modify "${connection_name}" ipv4.method manual ipv4.addresses "192.168.10.72/24"
            nmcli connection show "${connection_name}" | grep -E 'ipv4.method|ipv4.addresses'
        fi
    else
        echo "Khong co nmcli, bo qua cach doi bang NetworkManager."
    fi
}

cau_8() {
    print_title "Cau 8: Thiet lap IP 192.168.10.xx va xem lai routing"

    local iface
    iface="${IFACE:-$(get_default_iface)}"
    if [ -z "${iface}" ]; then
        echo "Khong tim thay interface mac dinh. Dat IFACE=<ten-card-mang> roi chay lai."
        return
    fi

    echo "IP thiet lap: ${STATIC_IP}/24"
    ip route show | tee /root/routing_before_static_ip
    confirm_or_skip "CONFIRM_STATIC_IP" "Thao tac nay se dat IP tinh cho ${iface}." || return

    if command -v nmcli >/dev/null 2>&1; then
        local connection_name
        connection_name="$(get_nmcli_connection "${iface}")"
        if [ -z "${connection_name}" ]; then
            echo "Khong tim thay ket noi NetworkManager dang hoat dong cho ${iface}."
            return
        fi

        nmcli connection modify "${connection_name}" \
            ipv4.method manual \
            ipv4.addresses "${STATIC_IP}/24" \
            ipv4.gateway "${STATIC_GATEWAY}" \
            ipv4.dns "8.8.8.8"
        nmcli connection up "${connection_name}"
    else
        ip addr flush dev "${iface}"
        ip addr add "${STATIC_IP}/24" dev "${iface}"
        ip link set "${iface}" up
        ip route add default via "${STATIC_GATEWAY}" dev "${iface}" || true
    fi

    ip route show | tee /root/routing_after_static_ip
    echo "Sau khi khoi dong lai, neu cau hinh tinh duoc luu, bang routing van co mang 192.168.10.0/24."
}

cau_9() {
    print_title "Cau 9: Kiem tra va cai dich vu SSH"

    if rpm -q openssh-server >/dev/null 2>&1; then
        echo "Da co goi openssh-server."
    else
        echo "Chua co goi openssh-server."
        if [ -f "${OPENSSH_RPM}" ]; then
            rpm -Uvh "${OPENSSH_RPM}"
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y openssh-server
        elif command -v yum >/dev/null 2>&1; then
            yum install -y openssh-server
        else
            echo "Khong co file ${OPENSSH_RPM}, dnf hoac yum de cai openssh-server."
            return
        fi
    fi

    systemctl enable --now sshd
    systemctl status sshd --no-pager || true
}

cau_10() {
    print_title "Cau 10: Cau hinh DHCP server"
    confirm_or_skip "CONFIRM_DHCP_CONFIG" "Thao tac nay se ghi /etc/dhcp/dhcpd.conf." || return

    if ! rpm -q dhcp-server >/dev/null 2>&1; then
        if command -v dnf >/dev/null 2>&1; then
            dnf install -y dhcp-server
        elif command -v yum >/dev/null 2>&1; then
            yum install -y dhcp-server
        else
            echo "Khong co dnf hoac yum de cai dhcp-server."
            return
        fi
    fi

    mkdir -p /etc/dhcp
    cp -a /etc/dhcp/dhcpd.conf "/etc/dhcp/dhcpd.conf.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    cat > /etc/dhcp/dhcpd.conf << DHCP_CONF
default-lease-time 600;
max-lease-time 7200;
authoritative;

subnet 192.168.10.0 netmask 255.255.255.0 {
    range ${DHCP_RANGE_START} ${DHCP_RANGE_END};
    option routers ${STATIC_GATEWAY};
    option subnet-mask 255.255.255.0;
    option domain-name-servers 8.8.8.8, 1.1.1.1;
}
DHCP_CONF

    if [ -n "${IFACE:-}" ] && [ -f /etc/sysconfig/dhcpd ]; then
        printf 'DHCPDARGS=%s\n' "${IFACE}" > /etc/sysconfig/dhcpd
    fi

    systemctl enable --now dhcpd
    systemctl status dhcpd --no-pager || true
}

main() {
    require_root
    cau_1
    cau_2
    cau_3
    cau_4
    cau_5
    cau_6
    cau_7
    cau_8
    cau_9
    cau_10
}

main "$@"

#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être exécuté en root."
    exit 1
fi

mapfile -t INTERFACES < <(ip -o link show | awk -F': ' '{print $2}' | awk -F'@' '{print $1}' | grep -v '^lo$' | while read -r iface; do
    [[ "$iface" =~ ^veth ]] && continue
    [[ "$iface" =~ ^br- ]] && continue
    [[ "$iface" =~ ^docker ]] && continue
    ip link show "$iface" &>/dev/null || continue
    echo "$iface"
done)

if [[ ${#INTERFACES[@]} -eq 0 ]]; then
    echo "Aucune interface trouvée."
    exit 1
fi

echo ""
echo "Interfaces disponibles :"
echo ""
for i in "${!INTERFACES[@]}"; do
    IFACE="${INTERFACES[$i]}"
    MAC=$(ip link show "$IFACE" | awk '/link\/ether/{print $2}')
    STATE=$(ip link show "$IFACE" | grep -oP '(?<=state )\w+')
    printf "  [%d] %-12s MAC: %-20s Etat: %s\n" "$((i+1))" "$IFACE" "${MAC:--}" "${STATE:-?}"
done

echo ""
read -rp "Interface [1-${#INTERFACES[@]}] : " CHOIX

if ! [[ "$CHOIX" =~ ^[0-9]+$ ]] || (( CHOIX < 1 || CHOIX > ${#INTERFACES[@]} )); then
    echo "Choix invalide."
    exit 1
fi

IFACE="${INTERFACES[$((CHOIX-1))]}"
MAC_ACTUELLE=$(ip link show "$IFACE" | awk '/link\/ether/{print $2}')

echo ""
echo "$IFACE -> $MAC_ACTUELLE"
echo ""
echo "  [1] MAC aleatoire"
echo "  [2] MAC manuelle"
echo ""
read -rp "Choix : " MODE

case "$MODE" in
    1)
        NEW_MAC=$(printf '02:%02x:%02x:%02x:%02x:%02x' \
            $((RANDOM % 256)) $((RANDOM % 256)) \
            $((RANDOM % 256)) $((RANDOM % 256)) \
            $((RANDOM % 256)))
        ;;
    2)
        read -rp "Nouvelle MAC (xx:xx:xx:xx:xx:xx) : " NEW_MAC
        if ! [[ "$NEW_MAC" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]; then
            echo "Format invalide."
            exit 1
        fi
        ;;
    *)
        echo "Choix invalide."
        exit 1
        ;;
esac

echo ""
ip link set "$IFACE" down
ip link set "$IFACE" address "$NEW_MAC"
ip link set "$IFACE" up

MAC_VERIF=$(ip link show "$IFACE" | awk '/link\/ether/{print $2}')

if [[ "$MAC_VERIF" == "${NEW_MAC,,}" ]]; then
    echo "OK -> $MAC_VERIF"
else
    echo "Echec. MAC actuelle : $MAC_VERIF"
    exit 1
fi

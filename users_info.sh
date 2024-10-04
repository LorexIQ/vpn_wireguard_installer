#!/bin/bash

print_peers() {
    echo "Список пользователей:"
    for i in "${!users_list[@]}"; do
        echo "$((i+1)). ${users_list[$i]}"
    done
}

list_peers() {
    while IFS= read -r line; do
        if echo "$line" | grep -q "\[Peer\]"; then
            read -r username_line
            username=$(echo "$username_line" | awk -F' = ' '{print $2}')

            read -r public_key_line
            public_key=$(echo "$public_key_line" | awk -F' = ' '{print $2}')

            read -r allowed_ips_line
            allowed_ips=$(echo "$allowed_ips_line" | awk -F' = ' '{print $2}')

            users_list+=("$username")
        fi
    done < /etc/wireguard/wg0.conf

    if [ ${#users_list[@]} -eq 0 ]; then
        echo "Нет зарегистрированных пользователей."
        exit 1
    fi

    while true; do
        print_peers
        read -p "Выберите номер пользователя для получения конфигурации: " user_choice

        if [ "$user_choice" -ge 1 ] && [ "$user_choice" -le "${#users_list[@]}" ]; then
            username="${users_list[$((user_choice - 1))]}"
            break
        else
            echo "Ошибка: такого пользователя нет."
        fi
    done
}

get_download_link() {
    interface_address=$(awk -F'/' '{print $1}' "$rootVPN/interface")
    directory="$rootVPN/users/$username"

    echo "Ссылка для скачивания конфигурации:"
    echo "- Windown: scp root@$interface_address:$directory/$username.conf C:\\$username.conf"
    echo "- Linux: scp root@$interface_address:$directory/$username.conf /root/$username.conf"
}

rootVPN="/etc/wireguard"

users_list=()

list_peers
get_download_link

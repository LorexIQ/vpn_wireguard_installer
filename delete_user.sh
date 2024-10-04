#!/bin/bash

users_list=()


print_peers() {
    echo "Выберите пользователя для удаления:"
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
        echo "Нет доступных для удаления пользователей."
        exit 1
    fi

    while true; do
        print_peers
        read -p "Выберите номер пользователя для удаления: " user_choice

        if [ "$user_choice" -ge 1 ] && [ "$user_choice" -le "${#users_list[@]}" ]; then
            username="${users_list[$((user_choice - 1))]}"
            break
        else
            echo "Ошибка: такого пользователя нет."
        fi
    done
}

restart_server() {
    echo "Перезапуск сервера Wireguard..."
    systemctl restart wg-quick@wg0

    status=$(systemctl is-active wg-quick@wg0.service)

    if [ "$status" = "active" ]; then
        echo "Статус сервера: успешно перезапущен"
    else
        echo "Статус сервера: ошибка перезапуска"
        exit 1
    fi
}

remove_peer() {
    awk -v username="$username" '
        /^\[Peer\]$/ { 
            if (inBlock && !skip) {
                if (block !~ /^\n*$/) print block;
            }
            inBlock = 1; block = $0 "\n"; skip = 0; next
        }
        inBlock {
            block = block $0 "\n";
            if ($0 ~ "^# UserName = " username "$") skip = 1
            if ($0 ~ /^AllowedIPs = /) {
            if (!skip) print block;
                inBlock = 0; block = ""; skip = 0;
            }
            next
        }
        {
            if ($0 ~ /^$/ && prevEmpty) next;
            print;
            prevEmpty = ($0 ~ /^$/);
        }
        END {
            if (prevEmpty) {
                system("truncate -s -1 temp");
            }
        }
    ' /etc/wireguard/wg0.conf > temp && mv temp /etc/wireguard/wg0.conf

    user_directory="/etc/wireguard/users/$username"
    if [ -d "$user_directory" ]; then
        rm -rf "$user_directory"
        echo "Пользователь $username успешно удалён."
    else
        echo "Ключи пользователя $username не найдены."
    fi
}

list_peers
remove_peer
restart_server

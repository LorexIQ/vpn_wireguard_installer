#!/bin/bash

users_list=()


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

    print_peers
}

list_peers

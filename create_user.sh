#!/bin/bash

is_valid_username() {
    echo "$1" | grep -qE '^[a-zA-Z0-9_]+$'
}

create_users_folder() {
    users_directory="/etc/wireguard/users"
    if [ ! -d "$users_directory" ]; then
        mkdir "$users_directory"
    fi
}

get_ips() {
    interfaceAddress=$(awk -F'/' '{print $1}' /etc/wireguard/interface)
    last_allowed_ip=$(grep -A 1 "[Peer]" /etc/wireguard/wg0.conf | tail -n 2 | grep "AllowedIPs" | tail -n 1 | awk -F'.' '{print $NF}' | awk '{print $1}' | cut -d'/' -f1)
    last_octet=2

    if [ -n "$last_allowed_ip" ]; then
        last_octet=$((last_allowed_ip + 1))
    fi

    allowed_ip="10.0.0.${last_octet}"
}

add_peer() {
    client_public_key=$(cat "$directory/publickey")

    cat << EOF >> /etc/wireguard/wg0.conf

[Peer]
# UserName = $username
PublicKey = $client_public_key
AllowedIPs = $allowed_ip
EOF
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

create_client_config() {
    local client_private_key=$(cat "$directory/privatekey")
    local server_public_key=$(cat "/etc/wireguard/server_publickey")

    cat << EOF > "$directory/$username.conf"
[Interface]
PrivateKey = $client_private_key
Address = $allowed_ip
DNS = 8.8.8.8

[Peer]
PublicKey = $server_public_key
Endpoint = $interfaceAddress:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 20
EOF
}

get_download_link() {
    echo "Ссылка для скачивания конфигурации:"
    echo "- Windown: scp root@$interfaceAddress:$directory/$username.conf C:\\$username.conf"
    echo "- Linux: scp root@$interfaceAddress:$directory/$username.conf /root/$username.conf"
}

name_input() {
    while true; do
        read -p "Введите имя нового пользователя: " username

        if is_valid_username "$username"; then
            directory="$users_directory/$username"
            if [ ! -d "$directory" ]; then
                mkdir "$directory"

                wg genkey | tee "$directory/privatekey" | wg pubkey | tee "$directory/publickey" > /dev/null 2>&1

                get_ips
                add_peer
                create_client_config

                echo "Пользователь $username успешно создан."
                break
            else
                echo "Пользователь $username уже существует."
            fi
        else
            echo "Недопустимое имя пользователя. Доступны только a-z, 0-9 и _. Попробуйте снова."
        fi
    done
}

create_users_folder
name_input
restart_server
get_download_link


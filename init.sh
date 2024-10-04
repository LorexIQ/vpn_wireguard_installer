#!/bin/bash

wireguard_install() {
    sudo apt update -y > /dev/null 2>&1 &
    pid=$!
    echo "[PID: ${pid}] Обновление пакетов..."
    wait $pid
    if [ $? -eq 0 ]; then
        echo "Обновление успешно завершено."
    else
        echo "Ошибка обновления пакетов."
        exit 1
    fi

    sudo apt install wireguard -y > /dev/null 2>&1 &
    pid=$!
    echo "[PID: ${pid}] Установка WireGuard..."
    wait $pid
    if [ $? -eq 0 ]; then
        echo "Установка WireGuard успешно завершена."
    else
        echo "Ошибка при установке WireGuard."
        exit 1
    fi
}

wireguard_genkey() {
    echo "Генерация пары ключей..."
    cd /etc/wireguard/
    wg genkey | tee /etc/wireguard/server_privatekey | wg pubkey | tee /etc/wireguard/server_publickey > /dev/null 2>&1
    echo "Пара ключей успешно сгенерирована."
}

wireguard_create_config() {
    local private_key=$(cat "/etc/wireguard/server_privatekey")
    local address="10.0.0.1/24"
    local listen_port=51820
    local interface="${interfacesNames[interfaceIndex]}"

    echo "Создание файла конфигурации сервера..."
    cat << EOF > "/etc/wireguard/wg0.conf"
[Interface]
PrivateKey = $private_key
Address = $address
ListenPort = $listen_port
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $interface -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $interface -j MASQUERADE
EOF
    echo "Файл конфигурации успешно создан."
}

ip_forwarding_setting() {
    echo "Настройка IP Forwarding..."
    cat << EOF > "/etc/sysctl.conf"
net.ipv4.ip_forward=1
EOF
    echo "Настройка изменена. Новое значение $(sysctl -p)"
}

get_interfaces() {
    local current_iface=""
    while IFS= read -r line; do
        if [[ $line =~ ^[0-9]+:\ ([^:]+): ]]; then
            current_iface=${BASH_REMATCH[1]}
        elif [[ $line =~ inet\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+) ]]; then
            interfacesNames+=("$current_iface")
            interfacesIps+=("${BASH_REMATCH[1]}")
        fi
    done < <(ip a)
}

print_interfaces() {
    echo "Выберите сетевой интерфейс для доступа в интернет:"
    for i in "${!interfacesNames[@]}"; do
        echo "$((i+1)). ${interfacesNames[$i]} [${interfacesIps[$i]}]"
    done
}

choose_interface() {
    while true; do
        print_interfaces
        read -p "Введите номер интерфейса: " choice

        if [[ $choice =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#interfacesNames[@]} )); then
            interfaceIndex=$((choice-1))
            cat << EOF > "/etc/wireguard/interface"
${interfacesIps[interfaceIndex]}
EOF
            echo "Выбран интерфейс: ${interfacesNames[interfaceIndex]}"
            break
        else
            echo "Ошибка: такого интерфейса нет."
        fi
    done
}

run_server() {
    echo "Создание задачи автозапуска..."
    systemctl enable wg-quick@wg0.service > /dev/null 2>&1
    echo "Включение сервера Wireguard..."
    systemctl start wg-quick@wg0.service

    status=$(systemctl is-active wg-quick@wg0.service)

    if [ "$status" = "active" ]; then
        echo "Статус сервера: успешно запущен"
    else
        echo "Статус сервера: ошибка запуска"
        exit 1
    fi
}

interfacesNames=()
interfacesIps=()

wireguard_install
wireguard_genkey
get_interfaces
choose_interface
wireguard_create_config
ip_forwarding_setting
run_server

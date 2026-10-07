#!/usr/bin/env bash

set -Eeuo pipefail

LOG_FILE="/var/log/dev_setup.log"
BASE_DIR=""

if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: скрипт необходимо запускать от root или через sudo."
    exit 1
fi

exec > >(tee -a "$LOG_FILE") 2>&1

echo "| Запуск скрипта |"

# Обработка ключа -d
while getopts "d:" opt; do
    case "$opt" in
        d)
            BASE_DIR="$OPTARG"
            ;;
        *)
            echo "Использование: $0 [-d directory]"
            exit 1
            ;;
    esac
done

# Если -d не указан — запрашиваем путь
if [[ -z "$BASE_DIR" ]]; then
    read -rp "Введите путь для создания рабочих директорий: " BASE_DIR
fi

if [[ -z "$BASE_DIR" ]]; then
    echo "Ошибка: путь не может быть пустым."
    exit 1
fi

echo "Базовый каталог: $BASE_DIR"

# Создание базового каталога
if [[ ! -d "$BASE_DIR" ]]; then
    echo "Создание базового каталога $BASE_DIR"
    mkdir -p "$BASE_DIR"
fi

# Создание группы dev
if getent group dev > /dev/null 2>&1; then
    echo "Группа dev уже существует."
else
    echo "Создание группы dev."
    groupadd dev
fi

# Настройка sudo без пароля для группы dev
SUDOERS_FILE="/etc/sudoers.d/dev"

echo "%dev ALL=(ALL:ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"
chmod 440 "$SUDOERS_FILE"

if visudo -cf "$SUDOERS_FILE"; then
    echo "Конфигурация sudo для группы dev корректна."
else
    echo "Ошибка в конфигурации sudo."
    rm -f "$SUDOERS_FILE"
    exit 1
fi

# Определяем минимальный UID обычных пользователей
UID_MIN=$(awk '/^[[:space:]]*UID_MIN[[:space:]]+/ {print $2}' /etc/login.defs)

if [[ -z "$UID_MIN" ]]; then
    UID_MIN=1000
    echo "UID_MIN не найден. Используется значение по умолчанию: $UID_MIN"
fi

echo "UID_MIN: $UID_MIN"

# Получаем список несистемных пользователей
mapfile -t USERS < <(
    awk -F: -v uid_min="$UID_MIN" \
        '$3 >= uid_min && $3 < 65534 {print $1}' /etc/passwd
)

if [[ ${#USERS[@]} -eq 0 ]]; then
    echo "Несистемные пользователи не найдены."
    exit 0
fi

echo "Найдены пользователи: ${USERS[*]}"

for USERNAME in "${USERS[@]}"; do
    echo
    echo "Обработка пользователя: $USERNAME"

    # Добавляем пользователя в группу dev
    if id -nG "$USERNAME" | tr ' ' '\n' | grep -qx "dev"; then
        echo "$USERNAME уже состоит в группе dev."
    else
        usermod -aG dev "$USERNAME"
        echo "$USERNAME добавлен в группу dev."
    fi

    # Определяем основную группу пользователя
    PRIMARY_GROUP=$(id -gn "$USERNAME")

    WORKDIR="${BASE_DIR}/${USERNAME}_workdir"

    # Создание рабочей директории
    if [[ ! -d "$WORKDIR" ]]; then
        mkdir -p "$WORKDIR"
        echo "Создан каталог: $WORKDIR"
    else
        echo "Каталог уже существует: $WORKDIR"
    fi

    # Назначение владельца и группы
    chown "$USERNAME:$PRIMARY_GROUP" "$WORKDIR"

    # Права 660
    chmod 660 "$WORKDIR"

    echo "Установлен владелец: $USERNAME:$PRIMARY_GROUP"
    echo "Установлены права: 660"

    # Предоставляем группе dev права только на чтение
    if command -v setfacl > /dev/null 2>&1; then
        setfacl -m g:dev:r-- "$WORKDIR"
        echo "Группе dev выданы ACL-права r-- на $WORKDIR"
    else
        echo "Предупреждение: setfacl не установлен."
        echo "Установите пакет acl: sudo apt install acl"
    fi

    # Проверочный вывод
    ls -ld "$WORKDIR"

    if command -v getfacl > /dev/null 2>&1; then
        getfacl "$WORKDIR"
    fi
done

echo
echo "| Скрипт успешно завершен |"

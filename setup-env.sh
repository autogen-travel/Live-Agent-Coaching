#!/bin/bash

# Скрипт для настройки переменных окружения
echo "=== Настройка переменных окружения ==="

# 1. Очищаем существующие переменные окружения
echo "Очищаем существующие переменные окружения..."
unset OPENAI_API_KEY
unset DASHA_API_KEY
unset DASHA_ENDPOINT

# 2. Проверяем, что .env файл существует
if [ ! -f ".env" ]; then
    echo "ОШИБКА: Файл .env не найден!"
    echo "Создайте файл .env на основе config.example:"
    echo "cp config.example .env"
    echo "Затем отредактируйте .env файл с вашими реальными ключами"
    exit 1
fi

# 3. Загружаем переменные из .env файла
echo "Загружаем переменные из .env файла..."
export $(cat .env | grep -v '^#' | xargs)

# 4. Проверяем, что переменные загружены
echo "Проверяем загруженные переменные:"
echo "OPENAI_API_KEY: ${OPENAI_API_KEY:0:10}..."
echo "DASHA_API_KEY: ${DASHA_API_KEY:0:10}..."
echo "DASHA_ENDPOINT: $DASHA_ENDPOINT"

# 5. Запускаем приложение
echo "Запускаем приложение..."
node index.js

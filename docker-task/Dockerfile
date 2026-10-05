# Базовый образ Ubuntu
FROM ubuntu:24.04

# Информация об авторе образа
MAINTAINER Student

# Переменные окружения
ENV DEBIAN_FRONTEND=noninteractive
ENV DB_NAME=appdb
ENV DB_USER=appuser
ENV DB_PASSWORD=app_password

# Рабочая директория
WORKDIR /app

# Устанавливаем Nginx, PostgreSQL и Supervisor
RUN apt-get update && \
    apt-get install -y \
        nginx \
        postgresql \
        postgresql-client \
        supervisor && \
    rm -rf /var/lib/apt/lists/*

# Разрешаем PostgreSQL принимать внешние подключения
RUN sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/" \
    /etc/postgresql/16/main/postgresql.conf && \
    echo "host all all 0.0.0.0/0 scram-sha-256" \
    >> /etc/postgresql/16/main/pg_hba.conf

# Копируем HTML-страницу
COPY index.html /var/www/html/index.html

# Копируем конфигурацию Nginx
COPY nginx.conf /etc/nginx/sites-available/default

# Копируем конфигурацию Supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Копируем стартовый скрипт
COPY start.sh /usr/local/bin/start.sh

# Используем ADD согласно требованиям задания
ADD README-container.txt /app/README-container.txt

# Делаем стартовый скрипт исполняемым
RUN chmod +x /usr/local/bin/start.sh

# Каталог с данными PostgreSQL
VOLUME ["/var/lib/postgresql"]

# Контейнер запускается от root.
# PostgreSQL запускается Supervisor от пользователя postgres.
USER root

# Порты Nginx и PostgreSQL
EXPOSE 80 5432

# Команда запуска
CMD ["/usr/local/bin/start.sh"]
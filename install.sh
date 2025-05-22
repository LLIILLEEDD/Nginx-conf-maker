#!/bin/bash

set -e

# Проверка на запуск от root
if [[ "$EUID" -ne 0 ]]; then
  echo "Запуск только через sudo"
  exit 1
fi

# Создаём директорию для скрипта
mkdir -p /opt/nginx-conf-maker

# Копируем файлы
cp script.py /opt/nginx-conf-maker
cp params.ini /opt/nginx-conf-maker
cp template.conf /opt/nginx-conf-maker

# Делаем скрипт исполняемым
chmod +x /opt/nginx-conf-maker/script.py

# Назначаем группу nginx для /storage/www и файлов внутри
chown -R :nginx /storage/www
chmod -R 775 /storage/www

# Назначаем группу nginx для conf.d для создания файлов
chown -R :nginx /etc/nginx/conf.d/
chmod 775 /etc/nginx/conf.d/

# Создаем отдельный файл в /etc/sudoers.d/ (безопаснее, чем редактировать основной sudoers)
NGINX_SUDOERS_FILE="/etc/sudoers.d/nginx-reload"

# Добавляем правило для группы nginx
echo '%nginx ALL=(root) NOPASSWD: /bin/systemctl reload nginx' | tee "$NGINX_SUDOERS_FILE" >/dev/null

# Устанавливаем строгие права (только root может читать/редактировать)
chmod 440 "$NGINX_SUDOERS_FILE"

# Проверяем синтаксис (если ошибка - скрипт упадет благодаря set -e)
visudo -cf "$NGINX_SUDOERS_FILE"

# Создаем отдельный sudoers-файл для проверки конфигурации
NGINX_TEST_SUDOERS="/etc/sudoers.d/nginx-test"

# Добавляем правило: разрешаем nginx -t
echo '%nginx ALL=(root) NOPASSWD: /usr/sbin/nginx -t' | tee "$NGINX_TEST_SUDOERS" >/dev/null

# Устанавливаем строгие права
chmod 440 "$NGINX_TEST_SUDOERS"

# Проверяем синтаксис
visudo -cf "$NGINX_TEST_SUDOERS"

# Создаём systemd unit-файл
tee /etc/systemd/system/nginx-conf-maker.service > /dev/null <<EOF
[Unit]
Description=Generating nginx configs from a template

[Service]
Type=oneshot
User=nginx
Group=nginx
ExecStart=/usr/bin/python3 /opt/nginx-conf-maker/script.py
EOF

# Создаём systemd timer-файл
tee /etc/systemd/system/nginx-conf-maker.timer > /dev/null <<EOF
[Unit]
Description=Run nginx config generation once a day

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Перезагружаем systemd и включаем таймер
systemctl daemon-reload
systemctl enable --now nginx-conf-maker.timer

echo ""
echo "Installation complete. Script and templates moved to /opt/nginx-conf-maker/"
echo "Systemd unit and timer created and activated"
echo "The script will run with the nginx group and have write permissions to /etc/nginx/conf.d/"

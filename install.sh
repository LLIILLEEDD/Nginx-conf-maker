#!/bin/bash

set -e

# Создаём директорию для скрипта
sudo mkdir -p /opt/nginx-conf-maker

# Копируем файлы
sudo cp script.py /opt/nginx-conf-maker
sudo cp params.ini /opt/nginx-conf-maker
sudo cp template.conf /opt/nginx-conf-maker

# Делаем скрипт исполняемым
sudo chmod +x /opt/nginx-conf-maker/script.py

# Назначаем группу nginx для /opt/nginx-conf-maker и файлов внутри
sudo chown -R :nginx /opt/nginx-conf-maker
sudo chmod  775 /opt/nginx-conf-maker
sudo chmod  775 /opt/nginx-conf-maker/script.py
sudo chmod  664 /opt/nginx-conf-maker/params.ini
sudo chmod  664 /opt/nginx-conf-maker/template.conf

# Назначаем группу nginx для /storage/www и файлов внутри
sudo chown -R :nginx /storage/www
sudo chmod -R 775 /storage/www

# Меняем права на директории и файлы которые нужны для проверки конфигурации nginx -t
sudo chown -R :nginx /var/log/nginx/
sudo chmod -R 771 /var/log/nginx/

sudo chown -R :nginx /etc/nginx/
sudo chmod 775 /etc/nginx/
sudo chmod 775 /etc/nginx/conf.d/

sudo chown  :nginx /run/nginx.pid 
sudo chmod 774 /run/nginx.pid 

sudo chown -R :nginx /var/lib/nginx
sudo chmod -R 750 /var/lib/nginx

sudo chown :nginx /run/nginx.pid
sudo chmod 662 /run/nginx.pid

# Снимаем ограничение по портам для группы nginx
sudo setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx

# Создаем отдельный файл в /etc/sudoers.d/ (безопаснее, чем редактировать основной sudoers)
NGINX_SUDOERS_FILE="/etc/sudoers.d/nginx-reload"

# Добавляем правило для группы nginx
echo '%nginx ALL=(root) NOPASSWD: /bin/systemctl reload nginx' | sudo tee "$NGINX_SUDOERS_FILE" >/dev/null

# Устанавливаем строгие права (только root может читать/редактировать)
sudo chmod 440 "$NGINX_SUDOERS_FILE"

# Проверяем синтаксис (если ошибка - скрипт упадет благодаря set -e)
sudo visudo -cf "$NGINX_SUDOERS_FILE"

# Создаём systemd unit-файл
sudo tee /etc/systemd/system/nginx-conf-maker.service > /dev/null <<EOF
[Unit]
Description=Generating nginx configs from a template

[Service]
Type=oneshot
User=nginx
Group=nginx
ExecStart=/usr/bin/python3 /opt/nginx-conf-maker/script.py
EOF

# Создаём systemd timer-файл
sudo tee /etc/systemd/system/nginx-conf-maker.timer > /dev/null <<EOF
[Unit]
Description=Run nginx config generation once a day

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Перезагружаем systemd и включаем таймер
sudo systemctl daemon-reload
sudo systemctl enable --now nginx-conf-maker.timer

echo ""
echo "Installation complete. Script and templates moved to /opt/nginx-conf-maker/"
echo "Systemd unit and timer created and activated"
echo "The script will run with the nginx group and have write permissions to /etc/nginx/conf.d/"

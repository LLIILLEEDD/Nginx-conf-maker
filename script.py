#!/usr/bin/env python3

import os
import subprocess
import configparser
import sys

OUTPUT_DIR = "/etc/nginx/conf.d"
TEMPLATE = "/opt/nginx-conf-maker/template.conf"
CONFIG_INI = "/opt/nginx-conf-maker/params.ini"
SITE_DIR = "/storage/www"

def error_exit(message):
    sys.stderr.write(f'Error: {message}\n')
    sys.exit(1)

def check_paths():
    if not os.path.isdir(OUTPUT_DIR):
        error_exit(f"Directory does not exist: {OUTPUT_DIR}")
    if not os.path.isfile(TEMPLATE):
        error_exit(f"Template file not found: {TEMPLATE}")
    if not os.path.isfile(CONFIG_INI):
        error_exit(f"Config file not found: {CONFIG_INI}")

def nginx_template(template_path):  # Функция для считывания .ini файла
    with open(template_path, 'r') as f:
        return f.read()
    
def validate_section(section, options):
    required_keys = ['listen', 'server_name', 'root']

    for key in required_keys:
        if key not in options:
            error_exit(f'In section [{section}]\nA required key is missing: "{key}"')  # Проверка на отсуствие ключа
    for key, value in options.items():
        if not value.strip():
            error_exit(f'In section [{section}]\nEmpty value for key: "{key}"')  # Проверка на пустое значение
    
def compare_files(old_file, new_file):
    with open(old_file, 'r') as f:
        exist_file = f.read()
    return exist_file == new_file

def reload_nginx(count):
    if count == 0:
        return f"Nginx did not reload, because {count} files were updated"
    else:
        try:
            check_conf = subprocess.run(["sudo", "nginx", "-t"], 
                                        text=True, 
                                        capture_output=True)
            if check_conf.returncode == 0:
                reload_proc = subprocess.run(["sudo", "systemctl", "reload", "nginx"], 
                                             text=True, 
                                             capture_output=True)
                if reload_proc.returncode == 0:
                    return f"Nginx reloaded. {count} files updated/created"
                else:
                    return f"Failed to reload nginx: {reload_proc.stderr}"
            else:
                return f"Nginx configuration test failed: {check_conf.stderr}"   
        except Exception as e: 
            return f"Error checking or restarting nginx. Nginx did not reload. Exception: {e}"

def generate_configs(conf_path, template_str, site_dir, output_dir): # Основная функция: парсинг и генерация конфига
    count_new_files = 0
    config = configparser.ConfigParser()
    config.read(conf_path)  # Читаем ini файл

    for section in config.sections():
        options = config[section]  # option - клю-значение внутри секции (как в dict)
        validate_section(section, options)
        rendered_conf = str(template_str).format(  
            listen = options['listen'],
            server_name = options['server_name'],
            root = options['root']
        )

        output_path_for_conf = os.path.join(output_dir, f"{section}.conf")  # Запись рендера в файл
        
        if os.path.exists(output_path_for_conf) and compare_files(output_path_for_conf, rendered_conf):
            print(f"Already exist and identical {output_path_for_conf}")
            continue
        
        try:
            with open(output_path_for_conf, 'w') as f:
                f.write(rendered_conf)
                print(f'Created file {output_path_for_conf}')
        except Exception:
            error_exit(f"{output_path_for_conf} not created")
        
        try:
            path_site_dir = os.path.join(site_dir, options['server_name'])
            os.makedirs(path_site_dir, exist_ok=True)  # Создание папки в storage/www/server_name
            print(f"Created path {path_site_dir}")
        except Exception:
            error_exit(f"{path_site_dir} not created")
        
        count_new_files += 1
    print (reload_nginx(count_new_files))

def main():
    check_paths()

    template_str = nginx_template(TEMPLATE)
    generate_configs(CONFIG_INI, template_str, SITE_DIR, OUTPUT_DIR)

main()
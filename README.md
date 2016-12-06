# Docker Nginx with PHP5 FPM
Installed Packages:

- curl, wget, vim, apt-utils
- nginx, php5

Configured as:

- Timezone:                      Asia\Jakarta
- Upload max filesize:           250M
- Memory limit:                  385M
- Post max size:                 250M
- PHP5 FPM User:                 root
- PHP5 FPM Process Manager:      ondemand
- PHP5 FPM Max children:         50
- PHP5 FPM Process Idle Timeout: 10s

Workdir in [/home/projects]

Entrypoint from https://github.com/IndraGunawan/docker-nginx-php/blob/master/entrypoint.sh

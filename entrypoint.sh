#!/bin/bash

# base on https://github.com/IndraGunawan/docker-nginx-php/blob/master/entrypoint.sh
#
# Environment
# - DOMAIN_(1,2,3,...)=domain_name|domain_path|type
# - TIMEZONE=Asia/Jakarta
# - PHP_FPM_SERVER=php-host:9000

# Nginx Configuration
NGINX_DIR=/etc/nginx
CONF_DIR="$NGINX_DIR/conf.d"
NGINX_WORKER=$(grep -c "processor" /proc/cpuinfo)

cat > "$NGINX_DIR/nginx.conf" <<END
user root;
worker_processes $NGINX_WORKER;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections 1024;
    multi_accept on;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    include /etc/nginx/upstream.conf;
    include /etc/nginx/conf.d/*.conf;
}

END

if [ -z $PHP_FPM_SERVER ]; then
    FPM_SERVER="unix:/var/run/php5-fpm.sock;"
else
    FPM_SERVER="$PHP_FPM_SERVER;"
fi

cat > "$NGINX_DIR/upstream.conf" <<END
upstream upstream {
    server $FPM_SERVER
}

gzip on;
gzip_disable "msie6";
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_min_length 1100;
gzip_buffers 16 8k;
gzip_http_version 1.1;
gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;

client_max_body_size 50M;
client_body_buffer_size 1m;
client_body_timeout 15;
client_header_timeout 15;
keepalive_timeout 15;
send_timeout 15;
sendfile on;
tcp_nopush on;
tcp_nodelay on;

open_file_cache max=2000 inactive=20s;
open_file_cache_valid 60s;
open_file_cache_min_uses 5;
open_file_cache_errors off;

fastcgi_buffers 256 16k;
fastcgi_buffer_size 128k;
fastcgi_connect_timeout 3s;
fastcgi_send_timeout 120s;
fastcgi_read_timeout 120s;
fastcgi_busy_buffers_size 256k;
fastcgi_temp_file_write_size 256k;
reset_timedout_connection on;
END

# Create virtualhost directory if not exists
[ -d $CONF_DIR ] || mkdir -p $CONF_DIR

# Creating virtualhost
count="0"

while [ true ]
do
    (( count++ ))
    DOMAIN="DOMAIN_$count"
    DOMAIN=${!DOMAIN}
    # Check total domain
    if [ -z ${DOMAIN} ]; then
        break
    fi

    # Check domain format
    DETAIL=(${DOMAIN//|/ })
    if [ ! ${#DETAIL[@]}  -eq 3 ]; then
        echo "Invalid format DOMAIN_$count, format: domain_name|path|type" >&2
    fi

    DOMAIN_NAME=${DETAIL[0]}
    DOMAIN_PATH=${DETAIL[1]}
    DOMAIN_TYPE=${DETAIL[2]}

    # Continue if vhost exists
    [ -f "$CONF_DIR/$DOMAIN_NAME.conf" ] && continue

    if [ $DOMAIN_TYPE = "php" ]; then
        cat > "$CONF_DIR/$DOMAIN_NAME.conf" <<END
server {
    listen 80;
    server_name $DOMAIN_NAME;
    root $DOMAIN_PATH;
    index index.php;

    location ~ /\.ht {
        deny all;
    }

    location ~ \.php\$ {
        fastcgi_keep_conn on;
        fastcgi_pass upstream;
        fastcgi_index app.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;

        include fastcgi_params;
    }
}
END
    elif [ $DOMAIN_TYPE = "static" ]; then
        cat > "$CONF_DIR/$DOMAIN_NAME.conf" <<END
server {
    listen 80;
    server_name $DOMAIN_NAME;
    root $DOMAIN_PATH;
    index index.html;

    add_header Access-Control-Allow-Origin *;

    location ~ /\.ht {
        deny all;
    }
}
END
    elif [ $DOMAIN_TYPE = "symfony" ]; then
        cat > "$CONF_DIR/$DOMAIN_NAME.conf" <<END
server {
    listen 80;
    server_name $DOMAIN_NAME;
    root $DOMAIN_PATH/web;
    index app.php;

    location / {
        # try to serve file directly, fallback to app.php
        try_files \$uri /app.php\$is_args\$args;
    }

    # PROD
    location ~ ^/app\.php(/|\$) {
        fastcgi_max_temp_file_size 1M;
        fastcgi_pass_header Set-Cookie;
        fastcgi_pass_header Cookie;
        fastcgi_ignore_headers Cache-Control Expires Set-Cookie;
        fastcgi_index app.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param  PATH_INFO          \$fastcgi_path_info;
        fastcgi_param  PATH_TRANSLATED    \$document_root\$fastcgi_path_info;

        fastcgi_pass upstream;
        fastcgi_split_path_info ^(.+\.php)(/.*)\\\$;
        include fastcgi_params;
        # When you are using symlinks to link the document root to the
        # current version of your application, you should pass the real
        # application path instead of the path to the symlink to PHP
        # FPM.
        # Otherwise, PHP's OPcache may not properly detect changes to
        # your PHP files (see https://github.com/zendtech/ZendOptimizerPlus/issues/126
        # for more information).
        fastcgi_param  SCRIPT_FILENAME  \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;
        # Prevents URIs that include the front controller. This will 404:
        # http://domain.tld/app.php/some-path
        # Remove the internal directive to allow URIs like this
        internal;
    }

    # DEV
    # This rule should only be placed on your development environment
    # In production, don't include this and don't deploy app_dev.php or config.php
    location ~ ^/(app_dev|config)\.php(/|\$) {
        fastcgi_max_temp_file_size 1M;
        fastcgi_pass_header Set-Cookie;
        fastcgi_pass_header Cookie;
        fastcgi_ignore_headers Cache-Control Expires Set-Cookie;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param  PATH_INFO          \$fastcgi_path_info;
        fastcgi_param  PATH_TRANSLATED    \$document_root\$fastcgi_path_info;

        fastcgi_pass upstream;
        fastcgi_split_path_info ^(.+\.php)(/.*)\$;
        include fastcgi_params;
        # When you are using symlinks to link the document root to the
        # current version of your application, you should pass the real
        # application path instead of the path to the symlink to PHP
        # FPM.
        # Otherwise, PHP's OPcache may not properly detect changes to
        # your PHP files (see https://github.com/zendtech/ZendOptimizerPlus/issues/126
        # for more information).
        fastcgi_param  SCRIPT_FILENAME  \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;
    }

    location ~ /\.ht {
        deny all;
    }

    location ~ \.php$ {
        fastcgi_keep_conn on;
        fastcgi_pass upstream;
        fastcgi_index app.php;
        fastcgi_param  SCRIPT_FILENAME  \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;

        include fastcgi_params;
    }
}
END
    elif [ $DOMAIN_TYPE = "rewrite_index" ]; then
        cat > "$CONF_DIR/$DOMAIN_NAME.conf" <<END
server {
    listen 80;
    server_name $DOMAIN_NAME;
    root $DOMAIN_PATH;
    index index.php;

    location / {
        # try to serve file directly, fallback to index.php
        try_files \$uri /index.php\$is_args\$args;
    }

    location ~ /\.ht {
        deny all;
    }

    location ~ \.php\$ {
        fastcgi_keep_conn on;
        fastcgi_pass upstream;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;

        include fastcgi_params;
    }
}
END
    elif [ $DOMAIN_TYPE = "prestashop" ]; then
        cat > "$CONF_DIR/$DOMAIN_NAME.conf" <<END
server {
    listen 80;
    server_name $DOMAIN_NAME;
    root $DOMAIN_PATH;

    index index.php index.html; # Letting nginx know which files to try when requesting a folder


    location = /favicon.ico {
        log_not_found off;      # PrestaShop by default does not provide a favicon.ico
        access_log off;         # Disable logging to prevent excessive log sizes
    }


     location = /robots.txt {
         auth_basic off;        # Whatever happens, always let bots know about your policy
         allow all;
         log_not_found off;     # Prevent excessive log size
         access_log off;
    }

    # Deny all attempts to access hidden files such as .htaccess, .htpasswd, .DS_Store (Mac).
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    ##
    # Gzip Settings
    ##

    gzip on;
    gzip_disable "msie6";                                             # Do people still use Internet Explorer 6? In that case, disable gzip and hope for the best!
    gzip_vary on;                                                     # Also compress content with other MIME types than "text/html"
    gzip_types application/json text/css application/javascript;      # We only want to compress json, css and js. Compressing images and such isn't worth it
    gzip_proxied any;
    gzip_comp_level 6;                                                # Set desired compression ratio, higher is better compression, but slower
    gzip_buffers 16 8k;                                               # Gzip buffer size
    gzip_http_version 1.0;                                            # Compress every type of HTTP request

    rewrite ^/api/?(.*)$ /webservice/dispatcher.php?url=$1 last;
    rewrite ^/([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\.jpg$ /img/p/$1/$1$2.jpg last;
    rewrite ^/([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\.jpg$ /img/p/$1/$2/$1$2$3.jpg last;
    rewrite ^/([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\.jpg$ /img/p/$1/$2/$3/$1$2$3$4.jpg last;
    rewrite ^/([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\.jpg$ /img/p/$1/$2/$3/$4/$1$2$3$4$5.jpg last;
    rewrite ^/([0-9])([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\.jpg$ /img/p/$1/$2/$3/$4/$5/$1$2$3$4$5$6.jpg last;
    rewrite ^/([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\.jpg$ /img/p/$1/$2/$3/$4/$5/$6/$1$2$3$4$5$6$7.jpg last;
    rewrite ^/([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\.jpg$ /img/p/$1/$2/$3/$4/$5/$6/$7/$1$2$3$4$5$6$7$8.jpg last;
    rewrite ^/([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\.jpg$ /img/p/$1/$2/$3/$4/$5/$6/$7/$8/$1$2$3$4$5$6$7$8$9.jpg last;
    rewrite ^/c/([0-9]+)(-[_a-zA-Z0-9-]*)(-[0-9]+)?/.+\.jpg$ /img/c/$1$2.jpg last;
    rewrite ^/c/([a-zA-Z-]+)(-[0-9]+)?/.+\.jpg$ /img/c/$1.jpg last;
    rewrite ^/([0-9]+)(-[_a-zA-Z0-9-]*)(-[0-9]+)?/.+\.jpg$ /img/c/$1$2.jpg last;
    try_files $uri $uri/ /index.php?$args;

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_keep_conn on;
        fastcgi_pass upstream;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;

        include fastcgi_params;
    }
}
END
    else
        echo "Invalid type DOMAIN_$count = $DOMAIN_TYPE, available type (php|static|symfony|rewrite_index|prestashop)" >&2
    fi

done

# Start PHP and NGINX
php5-fpm -R && nginx -g 'daemon off;'

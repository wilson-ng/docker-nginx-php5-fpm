FROM debian:jessie

MAINTAINER Wilson <frozalid.wilson@gmail.com>

ENV DEBIAN_FRONTEND noninteractive

# Create Project Directory
RUN mkdir -p /home/projects
VOLUME /home/projects
WORKDIR /home/projects

# Install Tools
RUN \
    apt-get update \
    && apt-get install -y --force-yes --no-install-recommends \
        curl wget vim apt-utils

# Install nginx & php5 fpm
RUN \
    apt-get install -y --force-yes --no-install-recommends \
        nginx \
        php5-apcu \
        php5-cli \
        php5-fpm \
        php5-imagick \
        php5-sqlite \
        php5-xdebug \
        php5-common \
        php5-curl \
        php5-dev \
        php5-gd \
        php5-intl \
        php5-json \
        php5-mcrypt \
        php5-mysql \
        php5-pgsql \
        php5-redis \
        php5-sqlite \
        php5-xmlrpc \
        php-pclzip

# Configuration of php5 fpm and nginx
RUN \
    echo "Asia/Jakarta" > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata \
    && sed -i "s/;date.timezone =.*/date.timezone = Asia\/Jakarta/g" /etc/php5/fpm/php.ini \
    && sed -i "s/;date.timezone =.*/date.timezone = Asia\/Jakarta/g" /etc/php5/cli/php.ini \
    && sed -i "s/upload_max_filesize =.*/upload_max_filesize = 250M/g" /etc/php5/fpm/php.ini \
    && sed -i "s/memory_limit = 128M/memory_limit = 385M/g" /etc/php5/fpm/php.ini \
    && sed -i "s/post_max_size =.*/post_max_size = 250M/g" /etc/php5/fpm/php.ini \
    && sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini \
    && sed -i "s/listen = 127.0.0.1:9000/listen = \/var\/run\/php5-fpm.sock/g" /etc/php5/fpm/pool.d/www.conf \
    && sed -i "s/user = www-data/user = root/g" /etc/php5/fpm/pool.d/www.conf \
    && sed -i "s/group = www-data/group = root/g" /etc/php5/fpm/pool.d/www.conf \
    && sed -i "s/listen.owner = www-data/listen.owner = root/g" /etc/php5/fpm/pool.d/www.conf \
    && sed -i "s/listen.group = www-data/listen.group = root/g" /etc/php5/fpm/pool.d/www.conf \
    && sed -i "s/pm.max_children = 5/pm.max_children = 50/g" /etc/php5/fpm/pool.d/www.conf \
    && sed -i "s/pm.start_servers = 2/pm.start_servers = 10/g" /etc/php5/fpm/pool.d/www.conf \
    && sed -i "s/pm.max_spare_servers = 3/pm.max_spare_servers = 15/g" /etc/php5/fpm/pool.d/www.conf

# Clear cache
RUN \
    apt-get clean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

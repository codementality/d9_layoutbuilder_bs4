FROM php:7.3-fpm

COPY conf.d/* /usr/local/etc/php/conf.d/

RUN apt-get update -qq && \
    apt-get install wget mariadb-client -yq && \
# install the PHP extensions we need
    apt-get update && apt-get install -y libpng-dev libjpeg-dev libpq-dev libzip-dev zip && \
    rm -rf /var/lib/apt/lists/* && \
    docker-php-ext-configure zip --with-libzip && \
    docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr && \
    docker-php-ext-install gd mbstring opcache pdo pdo_mysql pdo_pgsql zip mysqli && \
# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
    { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=0'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'opcache.enable_cli=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini && \
# Install MailHog Sendmail support.
    apt-get update -qq && apt-get install -yq git golang-go && \
    mkdir -p /opt/go && \
    export GOPATH=/opt/go && \
    go get github.com/mailhog/mhsendmail && \
# Copy PHP configs.
    chmod 644 /usr/local/etc/php/conf.d/* && \
# Install drush.
    curl -OL https://github.com/drush-ops/drush-launcher/releases/latest/download/drush.phar && \
    chmod +x drush.phar && \
    mv drush.phar /usr/local/bin/drush && \
# Install Composer
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    composer --version && \
# Create working directory
    mkdir -p /var/www/docroot

WORKDIR /var/www/docroot

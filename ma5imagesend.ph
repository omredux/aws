#!/bin/bash
sudo apt-get -y update  1>/tmp/01.out 2>/tmp/01.err

sudo apt-get -y install apache2 php5 wget php5-curl php5-mysql curl  git 1>/tmp/02.out 2>/tmp/02.err
sudo service apache2 restart 

sudo mkdir /var/www/html/uploads
sudo chmod 777 /var/www/html/uploads

curl -sS https://getcomposer.org/installer | php

wget http://ec2-54-165-241-56.compute-1.amazonaws.com/composer.json

sudo php composer.phar install

sudo wget  http://ec2-54-165-241-56.compute-1.amazonaws.com/result.php.gz
wget http://ec2-54-165-241-56.compute-1.amazonaws.com/index.php
wget http://ec2-54-165-241-56.compute-1.amazonaws.com/gallery.php


sudo mv composer.phar /var/www/html
sudo mv composer.json /var/www/html
sudo mv composer.lock /var/www/html
sudo mv index.php /var/www/html
sudo mv result.php.gz /var/www/html
sudo mv gallery.php /var/www/html
sudo mv vendor /var/www/html

sudo gunzip /var/www/html/result.php.gz




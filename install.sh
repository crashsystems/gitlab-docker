#!/bin/bash

# Script is based on https://github.com/gitlabhq/gitlabhq/blob/5-4-stable/doc/install/installation.md

# === Configuration ===
# Edit these variables

mysqlRoot=RootPassword
mysqlGitlab=SomePassword
hostname=example.com

# =====================

### Do not edit below this line ###

# Function to print current stage
print () {
  echo
  echo === $1 ===
  echo
}

print "1. Packages / Dependencies: Running updates"
echo deb http://us.archive.ubuntu.com/ubuntu/ precise universe multiverse >> \
  /etc/apt/sources.list
apt-get update
apt-get -y upgrade

print "1. Packages / Dependencies: Install the required packages"
apt-get install -y build-essential zlib1g-dev libyaml-dev libssl-dev \
  libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl \
  openssh-server redis-server checkinstall libxml2-dev libxslt-dev \
  libcurl4-openssl-dev libicu-dev sudo python-software-properties

# Get a more recent version of Git
add-apt-repository -y ppa:git-core/ppa
apt-get update
apt-get -y install git

# Manually create /var/run/sshd
mkdir /var/run/sshd

print "1. Packages / Dependencies: Install Python"
apt-get install -y python python-docutils

print "2. Ruby: Download Ruby and compile it"
mkdir /tmp/ruby && cd /tmp/ruby
curl --progress \
  ftp://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p247.tar.gz | tar xz
cd ruby-2.0.0-p247
chmod +x configure
./configure
make
make install

print "2. Ruby: Installing bundler gem"
gem install bundler --no-ri --no-rdoc

print "3. System Users: Create a git user for Gitlab"
adduser --disabled-login --gecos 'GitLab' git

print "4. GitLab shell"
cd /home/git
sudo -u git -H git clone https://github.com/gitlabhq/gitlab-shell.git
cd gitlab-shell
sudo -u git -H git checkout v1.7.0
sudo -u git -H cp config.yml.example config.yml
sed -i -e "s/localhost/127.0.0.1/g" config.yml
sudo -u git -H ./bin/install

print "5. Database: Install the database packages"
echo mysql-server mysql-server/root_password password $mysqlRoot | \
  debconf-set-selections
echo mysql-server mysql-server/root_password_again password $mysqlRoot | \
  debconf-set-selections
apt-get install -y mysql-server mysql-client libmysqlclient-dev

# Need to start manually so DB config will work
/usr/bin/mysqld_safe &
sleep 5

print "5. Database: Create a user for GitLab"
echo "CREATE USER 'gitlab'@'localhost' IDENTIFIED BY '$mysqlGitlab';" | \
  mysql --user=root --password=$mysqlRoot

print "5. Database: Create the GitLab production database"
echo "CREATE DATABASE IF NOT EXISTS gitlabhq_production DEFAULT CHARACTER SET \
  'utf8' COLLATE 'utf8_unicode_ci';" | mysql --user=root --password=$mysqlRoot

print "5. Database: Grant the GitLab user necessary permissions on the table"
echo "GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, \
  ALTER ON gitlabhq_production.* TO 'gitlab'@'localhost';" | mysql \
  --user=root --password=$mysqlRoot

print "6. GitLab: Clone from source"
cd /home/git
sudo -u git -H git clone https://github.com/gitlabhq/gitlabhq.git gitlab
cd /home/git/gitlab
sudo -u git -H git checkout 6-1-stable

print "6. GitLab: Configure it"
cd /home/git/gitlab
sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml
sed -i -e "s/localhost/$hostname/g" config/gitlab.yml
chown -R git log/
chown -R git tmp/
chmod -R u+rwX  log/
chmod -R u+rwX  tmp/
sudo -u git -H mkdir /home/git/gitlab-satellites
sudo -u git -H mkdir tmp/pids/
sudo -u git -H mkdir tmp/sockets/
chmod -R u+rwX  tmp/pids/
chmod -R u+rwX  tmp/sockets/
sudo -u git -H mkdir public/uploads
chmod -R u+rwX  public/uploads
sudo -u git -H cp config/unicorn.rb.example config/unicorn.rb
sudo -u git -H git config --global user.name "GitLab"
sudo -u git -H git config --global user.email "gitlab@localhost"
sudo -u git -H git config --global core.autocrlf input

print "6. GitLab: Configure GitLab DB settings"
sudo -u git -H cp config/database.yml.mysql config/database.yml
sed -i -e "s/root/gitlab/g" config/database.yml
sed -i -e "s/secure password/$mysqlGitlab/g" config/database.yml
sudo -u git -H chmod o-rwx config/database.yml

print "6. GitLab: Install Gems"
cd /home/git/gitlab
gem install charlock_holmes --version '0.6.9.4'
sudo -u git -H bundle install --deployment --without \
  development test postgres aws
# Redis must be up when the rake task runs
redis-server & > /dev/null  2>&1 &
sleep 3

print "6. GitLab: Initialize Database and Activate Advanced Features"
# Note: the force=yes sets a rake env var that bypasses manual db
# population prompt
sudo -u git -H bundle exec rake gitlab:setup force=yes RAILS_ENV=production

print "6. GitLab: Install init scripts"
cp lib/support/init.d/gitlab /etc/init.d/gitlab
chmod +x /etc/init.d/gitlab
update-rc.d gitlab defaults 21

print "7. Nginx: Installation"
apt-get install -y nginx

print "7. Nginx: Site Configuration"
cp lib/support/nginx/gitlab /etc/nginx/sites-available/gitlab
ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab
sed -i -e "s/YOUR_SERVER_FQDN/$hostname/g" /etc/nginx/sites-available/gitlab

print "Make Run script execuitable"
chmod +x /src/build/start.sh

print "Install script self-destruct"
rm /src/build/install.sh

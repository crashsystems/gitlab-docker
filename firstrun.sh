#!/bin/bash

# Set these parameters
mysqlRoot=RootPassword

# ==== Do not edit below this line ===

# Copy over config files
mv /srv/gitlab/config/nginx /etc/nginx/sites-available/gitlab
ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab
mv /srv/gitlab/config/gitlab.yml /home/git/gitlab/config/gitlab.yml

password=$(cat /srv/gitlab/config/database.yml | grep -m 1 password | sed -e 's/  password: "//g' | sed -e 's/"//g')
sed -i -e "s/root/gitlab/g" /srv/gitlab/config/database.yml
sed -i -e "s/secure password/$password/g" /srv/gitlab/config/database.yml
mv /srv/gitlab/config/database.yml /home/git/gitlab/config/database.yml
chown git:git /home/git/gitlab/config/database.yml && chmod o-rwx /home/git/gitlab/config/database.yml

# Move mysql data dir to /srv/gitlab
mv /var/lib/mysql /srv/gitlab
ln -s /srv/gitlab/mysql /var/lib/mysql
mysqld_safe &
sleep 5

# Initialize MySQL
mysqladmin -u root --password=temprootpass password $mysqlRoot
echo "CREATE USER 'gitlab'@'localhost' IDENTIFIED BY '$password';" | \
  mysql --user=root --password=$mysqlRoot
echo "CREATE DATABASE IF NOT EXISTS gitlabhq_production DEFAULT CHARACTER SET \
  'utf8' COLLATE 'utf8_unicode_ci';" | mysql --user=root --password=$mysqlRoot
echo "GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, \
  ALTER ON gitlabhq_production.* TO 'gitlab'@'localhost';" | mysql \
    --user=root --password=$mysqlRoot

cd /home/git/gitlab
su git -c "bundle exec rake gitlab:setup force=yes RAILS_ENV=production"
sleep 5
su git -c "bundle exec rake db:seed_fu RAILS_ENV=production"

# Manually create /var/run/sshd
mkdir /var/run/sshd

# Delete firstrun script
rm /srv/gitlab/firstrun.sh

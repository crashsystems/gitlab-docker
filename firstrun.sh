#!/bin/bash

# Set these parameters
mysqlRoot=RootPassword

# === Do not modify anything in this section ===

# Regenerate the SSH host key
/bin/rm /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

password=$(cat /srv/gitlab/config/database.yml | grep -m 1 password | sed -e 's/  password: "//g' | sed -e 's/"//g')

# ==============================================

# === Delete this section if restoring data from previous build ===

rm -R /srv/gitlab/data/mysql
mv /var/lib/mysql-tmp /srv/gitlab/data/mysql

# Start MySQL
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

# ================================================================

# Delete firstrun script
rm /srv/gitlab/firstrun.sh

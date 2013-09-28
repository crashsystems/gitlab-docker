#!/bin/bash

# Set these parameters
mysqlRoot=RootPassword

# === Do not modify anything in this section ===

# Copy over config files
mv /srv/gitlab/config/nginx /etc/nginx/sites-available/gitlab
ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab
mv /srv/gitlab/config/gitlab.yml /home/git/gitlab/config/gitlab.yml

password=$(cat /srv/gitlab/config/database.yml | grep -m 1 password | sed -e 's/  password: "//g' | sed -e 's/"//g')
mv /srv/gitlab/config/database.yml /home/git/gitlab/config/database.yml
chown git:git /home/git/gitlab/config/database.yml && chmod o-rwx /home/git/gitlab/config/database.yml

# Link data directories to /srv/gitlab/data
rm -R /home/git/gitlab/tmp && ln -s /srv/gitlab/data/tmp /home/git/gitlab/tmp && chown -R git /srv/gitlab/data/tmp/ && chmod -R u+rwX  /srv/gitlab/data/tmp/
rm -R /home/git/.ssh && ln -s /srv/gitlab/data/ssh /home/git/.ssh && chown -R git:git /srv/gitlab/data/ssh && chmod -R 0777 /srv/gitlab/data/ssh
rm -R /home/git/gitlab-satellites && ln -s /srv/gitlab/data/gitlab-satellites /home/git/gitlab-satellites && chown -R git:git /srv/gitlab/data/gitlab-satellites
rm -R /home/git/repositories && ln -s /srv/gitlab/data/repositories /home/git/repositories && chown -R git:git /srv/gitlab/data/repositories && chmod -R ug+rwX,o-rwx /srv/gitlab/data/repositories

# Link MySQL dir to /srv/gitlab/data
mv /var/lib/mysql /var/lib/mysql-tmp
ln -s /srv/gitlab/data/mysql /var/lib/mysql

# ==============================================

# === Delete this section if resoring data from previous build ===

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

# Manually create /var/run/sshd
mkdir /var/run/sshd

# Delete firstrun script
rm /srv/gitlab/firstrun.sh

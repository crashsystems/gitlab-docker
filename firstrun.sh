#!/bin/bash

# Set these parameters
mysqlRoot=RootPassword

# === Do not modify anything in this section ===

# Regenerate the SSH host key
/bin/rm /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

# Copy over config files
cp /srv/gitlab/config/nginx /etc/nginx/sites-available/gitlab
ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab
cp /srv/gitlab/config/gitlab.yml /home/git/gitlab/config/gitlab.yml

password=$(cat /srv/gitlab/config/database.yml | grep -m 1 password | sed -e 's/  password: "//g' | sed -e 's/"//g')
cp /srv/gitlab/config/database.yml /home/git/gitlab/config/database.yml
chown git:git /home/git/gitlab/config/database.yml && chmod o-rwx /home/git/gitlab/config/database.yml

# Link data directories to /srv/gitlab/data
rm -R /home/git/gitlab/tmp && ln -s /srv/gitlab/data/tmp /home/git/gitlab/tmp && chown -R git /srv/gitlab/data/tmp/ && chmod -R u+rwX  /srv/gitlab/data/tmp/
rm -R /home/git/.ssh && ln -s /srv/gitlab/data/ssh /home/git/.ssh && chown -R git:git /srv/gitlab/data/ssh && chmod -R 0700 /srv/gitlab/data/ssh && chmod 0700 /home/git/.ssh
chown -R git:git /srv/gitlab/data/gitlab-satellites
chown -R git:git /srv/gitlab/data/repositories && chmod -R ug+rwX,o-rwx /srv/gitlab/data/repositories && chmod -R ug-s /srv/gitlab/data/repositories/
find /srv/gitlab/data/repositories/ -type d -print0 | xargs -0 chmod g+s

# Change repo path in gitlab-shell config
sed -i -e 's/\/home\/git\/repositories/\/srv\/gitlab\/data\/repositories/g' /home/git/gitlab-shell/config.yml

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

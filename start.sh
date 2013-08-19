#!/bin/bash

# start SSH
/usr/sbin/sshd

# start mysql
mysqld_safe &

# start redis
redis-server > /dev/null 2>&1 &

sleep 5

# remove PIDs created by GitLab init script
rm /home/git/gitlab/tmp/pids/*

# start gitlab
service gitlab start

# start nginx
service nginx start

# keep script in foreground
while(true) do
  sleep 60
done

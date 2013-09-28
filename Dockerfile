FROM ubuntu:12.04
ENV MYSQLTMPROOT temprootpass

# Run upgrades
RUN (echo deb http://us.archive.ubuntu.com/ubuntu/ precise universe multiverse >> /etc/apt/sources.list && apt-get update && apt-get -y upgrade)

# Install dependencies
RUN (apt-get install -y build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl openssh-server redis-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev sudo python python-docutils python-software-properties nginx)

# Install Git
RUN (add-apt-repository -y ppa:git-core/ppa && apt-get update && apt-get -y install git)

# Install Ruby
RUN (mkdir /tmp/ruby && cd /tmp/ruby && curl ftp://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p247.tar.gz | tar xz && cd ruby-2.0.0-p247 && chmod +x configure && ./configure && make && make install)
RUN (gem install bundler --no-ri --no-rdoc)

# Create Git user
RUN (adduser --disabled-login --gecos 'GitLab' git)

# Install GitLab Shell
RUN (su git -c "cd /home/git && git clone https://github.com/gitlabhq/gitlab-shell.git && cd gitlab-shell && git checkout v1.7.1 && cp config.yml.example config.yml && sed -i -e 's/localhost/127.0.0.1/g' config.yml && ./bin/install")

# Install MySQL
RUN (echo mysql-server mysql-server/root_password password $MYSQLTMPROOT | debconf-set-selections && echo mysql-server mysql-server/root_password_again password $MYSQLTMPROOT | debconf-set-selections && apt-get install -y mysql-server mysql-client libmysqlclient-dev)

# Install GitLab
RUN (su git -c "cd /home/git && git clone https://github.com/gitlabhq/gitlabhq.git gitlab && cd /home/git/gitlab && git checkout 6-1-stable")

RUN (cd /home/git/gitlab && chown -R git tmp/ && chown -R git log/ && su git -c "chmod -R u+rwX log/ && chmod -R u+rwX tmp/ && mkdir /home/git/gitlab-satellites && mkdir tmp/pids/ && mkdir tmp/sockets/ && chmod -R u+rwX tmp/pids/ && chmod -R u+rwX tmp/sockets/ && mkdir public/uploads && chmod -R u+rwX public/uploads && cp config/unicorn.rb.example config/unicorn.rb && git config --global user.name 'GitLab' && git config --global user.email 'gitlab@localhost' && git config --global core.autocrlf input")

RUN (cd /home/git/gitlab && gem install charlock_holmes --version '0.6.9.4' && su git -c "bundle install --deployment --without development test postgres aws")

# Install init scripts
RUN (cd /home/git/gitlab && cp lib/support/init.d/gitlab /etc/init.d/gitlab && chmod +x /etc/init.d/gitlab && update-rc.d gitlab defaults 21)

ADD . /srv/gitlab
RUN (chmod +x /srv/gitlab/start.sh && chmod +x /srv/gitlab/firstrun.sh)

EXPOSE 80
EXPOSE 22

CMD ["/srv/gitlab/start.sh"]

FROM debian:bullseye
RUN  sed -i s@/deb.debian.org/@/mirrors.aliyun.com/@g /etc/apt/sources.list \
     && sed -i s@/security.debian.org/@/mirrors.aliyun.com/@g /etc/apt/sources.list \
     && python-docutils \
     && apt-get update -y \
     && apt-get upgrade -y \
     && apt-get install sudo -y \
     && sudo apt-get install -y runit build-essential git zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl openssh-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev logrotate python-docutils pkg-config cmake nodejs graphviz jq \
     && sudo apt-get install -y runit-systemd libssl1.0-dev \
     && mkdir /tmp/ruby && cd /tmp/ruby \
     && curl -L --progress-bar https://cache.ruby-lang.org/pub/ruby/2.6/ruby-2.6.9.tar.bz2 | tar xj \
     && cd ruby-2.6.9 \
     && ./configure --disable-install-rdoc \
     && make -j`nproc` \
     && sudo make install \
     && sudo gem update --system --no-document \
     && sudo gem install foreman --no-document
     
COPY docker/scripts/prepare /scripts/
RUN /scripts/prepare

COPY docker/multi-process/scripts/standalone-packages /scripts/
RUN /scripts/standalone-packages

WORKDIR /app

COPY ["Gemfile", "Gemfile.lock", "/app/"]
COPY lib/gemfile_helper.rb /app/lib/
COPY vendor/gems/ /app/vendor/gems/

# Get rid of annoying "fatal: Not a git repository (or any of the parent directories): .git" messages
RUN umask 002 && git init && \
    export LC_ALL=en_US.UTF-8 RAILS_ENV=production APP_SECRET_TOKEN=secret DATABASE_ADAPTER=mysql2 ON_HEROKU=true && \
    bundle config set --local path vendor/bundle && \
    bundle config set --local without 'test development' && \
    bundle install -j 4

COPY ./ /app/

ARG OUTDATED_DOCKER_IMAGE_NAMESPACE=false
ENV OUTDATED_DOCKER_IMAGE_NAMESPACE ${OUTDATED_DOCKER_IMAGE_NAMESPACE}

RUN umask 002 && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production APP_SECRET_TOKEN=secret DATABASE_ADAPTER=mysql2 ON_HEROKU=true bundle exec rake assets:clean assets:precompile && \
    chmod g=u /app/.env.example /app/Gemfile.lock /app/config/ /app/tmp/


EXPOSE 3000

COPY docker/multi-process/scripts/supervisord.conf /etc/supervisor/
COPY ["docker/multi-process/scripts/bootstrap.conf", \
      "docker/multi-process/scripts/foreman.conf", \
      "docker/multi-process/scripts/mysqld.conf", "/etc/supervisor/conf.d/"]
COPY ["docker/multi-process/scripts/bootstrap.sh", \
      "docker/multi-process/scripts/foreman.sh", \
      "docker/multi-process/scripts/init", \
      "docker/scripts/setup_env", "/scripts/"]
CMD ["/scripts/init"]

USER 1001

VOLUME /var/lib/mysql

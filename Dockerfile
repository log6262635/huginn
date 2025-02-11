FROM ubuntu:18.04
RUN  sed -i s@/archive.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list \
     && apt-get clean \
     && apt-get update -y \
     && apt-get upgrade -y \
     && apt-get install sudo -y \
     && sudo apt-get install -y runit build-essential git zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl openssh-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev logrotate python-docutils pkg-config cmake nodejs graphviz jq \
     && sudo apt-get install -y runit-systemd \
     && sudo apt-get remove -y ruby1.8 ruby1.9 \
     && mkdir /tmp/ruby && cd /tmp/ruby \
     && curl -L --progress-bar https://cache.ruby-lang.org/pub/ruby/2.6/ruby-2.6.9.tar.bz2 | tar xj \
     && cd ruby-2.6.9 \
     && ./configure --disable-install-rdoc \
     && make -j`nproc` \
     && sudo make install \

COPY docker/scripts/prepare /scripts/
RUN /scripts/prepare

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

COPY ["docker/scripts/setup_env", "docker/single-process/scripts/init", "/scripts/"]
CMD ["/scripts/init"]

USER 1001

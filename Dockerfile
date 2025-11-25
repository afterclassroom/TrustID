FROM ruby:3.2.8-alpine
ENV LANG C.UTF-8
ENV LIBV8_VERSION 7.3.492.27.1

RUN apk add --no-cache nodejs yarn git build-base \
    libstdc++ make python3 git bash yaml-dev && \
    gem install libv8 -v ${LIBV8_VERSION} && \
    gem install therubyracer

RUN apk add --no-cache build-base mariadb-dev \
    libzbar poppler-utils libpng-dev jpeg-dev \
    libjpeg-turbo-dev tiff-dev imagemagick imagemagick-dev imagemagick-libs \
    curl-dev tzdata

# RUN gem install rubygems-update
RUN gem install rubygems-update -v 3.4.22
RUN update_rubygems
RUN gem update --system

#Cache bundle install
RUN gem install bundle
WORKDIR /tmp
ADD ./Gemfile Gemfile
# ADD ./Gemfile.lock Gemfile.lock
RUN bundle install

ENV APP_ROOT /var/www/app
RUN mkdir -p $APP_ROOT
WORKDIR $APP_ROOT
COPY . $APP_ROOT

EXPOSE 3000
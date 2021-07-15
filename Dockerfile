# Dockerfile development version
FROM ruby:3.0.0

ARG USER_ID
ARG GROUP_ID

# if running using superuser, these would fail while building the image
RUN addgroup --gid $GROUP_ID user
RUN adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID user

# install essentials
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg -o /root/yarn-pubkey.gpg && apt-key add /root/yarn-pubkey.gpg
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install -y --no-install-recommends nodejs yarn

# create a folder inside the image
ENV INSTALL_PATH /opt/dockerapps/app
RUN mkdir -p $INSTALL_PATH
WORKDIR $INSTALL_PATH

# while building, the directory should contain a benchmarkit/ folder which will be copied to the image
COPY benchmarkit/ .
RUN rm -rf node_modules vendor
RUN gem install rails bundler
RUN bundle install
RUN yarn install
RUN chown -R user:user /opt/dockerapps/app

USER $USER_ID
# since we're using puma server by default
CMD bundle exec puma

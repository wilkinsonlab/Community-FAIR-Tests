FROM ruby:3.3.0

ENV LANG="en_US.UTF-8" LANGUAGE="en_US:UTF-8" LC_ALL="C.UTF-8"
ENV RACK_ENV=production
# RUN apt-get update -q
# RUN apt-get -y dist-upgrade --fix-missing -q
RUN apt-get update -q && apt-get install build-essential -y
RUN apt-get install -y --no-install-recommends lighttpd && \
  apt-get install -y --no-install-recommends libxml++2.6-dev  libraptor2-0 && \
  apt-get install -y --no-install-recommends libxslt1-dev locales software-properties-common cron python3-pip python3-extruct && \
  apt-get clean
RUN mkdir /server
WORKDIR /server
RUN gem update --system
RUN gem install bundler:2.3.12
COPY Gemfile Gemfile.lock community-fair-tests.gemspec ./
RUN bundle install
COPY . .

EXPOSE 8282

CMD ["ruby", "/server/app/controllers/application_controller.rb", "-o", "0.0.0.0", "-p", "8282"]

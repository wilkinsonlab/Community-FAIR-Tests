# Use a more explicit tag for reproducibility (ruby:3.2-bookworm is Debian 12)
FROM ruby:3.2-bookworm

# Set locale (good practice, prevents some encoding issues)
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:UTF-8 \
    LC_ALL=C.UTF-8 \
    RACK_ENV=production

# Combine ALL apt operations into ONE RUN to avoid layer caching issues
# and clean up in the same layer to keep image small
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      lighttpd \
      libxml++2.6-dev \
      libraptor2-0 \
      libxslt1-dev \
      locales \
      software-properties-common \
      cron \
      python3-pip \
      python3-extruct \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create app directory
RUN mkdir -p /server
WORKDIR /server

# Update RubyGems + install specific Bundler version
RUN gem update --system \
    && gem install bundler -v 2.3.12

# Install gems first (leverage Docker cache)
COPY Gemfile Gemfile.lock community-fair-tests.gemspec ./
RUN bundle install --jobs 4 --retry 3

# Copy the rest of the application
COPY . .

# Expose port (optional but good practice)
EXPOSE 8282

# Start the app
CMD ["ruby", "/server/app/controllers/application_controller.rb", "-o", "0.0.0.0", "-p", "8282"]
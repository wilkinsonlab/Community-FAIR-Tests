
# Use explicit tag for reproducibility (Debian 12 / Bookworm)
FROM ruby:3.2-bookworm

# Set locale (prevents encoding issues in many gems / tools)
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:utf8 \
    LC_ALL=en_US.UTF-8 \
    RACK_ENV=production


# Combine all apt installs + cleanup in ONE layer for smaller image & better caching
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libxml++2.6-dev \
        libraptor2-0 \
        libxslt1-dev \
        locales \
        cron \
        python3-pip \
        python3-extruct \
    && apt-get clean && \
       rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create app directory
RUN mkdir -p /server
WORKDIR /server

# Update RubyGems + pin Bundler version (good for reproducibility)
RUN gem update --system \
    && gem install bundler -v 2.3.12

# Install gems first (cache layer — only rebuild if Gemfile changes)
COPY Gemfile Gemfile.lock community-fair-tests.gemspec ./

# Clean any previous partial installs + install
RUN rm -rf /usr/local/bundle/gems/debase-ruby_core_source* \
           /usr/local/bundle/specifications/debase-ruby_core_source* \
    && bundle install --jobs 4 --retry 3

# Copy the rest of the application code
COPY . .

# Expose the port your app listens on
EXPOSE 8282

# Start the app (adjust if run.rb needs different flags)
CMD ["ruby", "/server/run.rb", "-o", "0.0.0.0", "-p", "8282"]
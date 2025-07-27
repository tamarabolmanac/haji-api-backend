FROM ruby:3.3.6-slim

WORKDIR /app

# Install both runtime and build dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    curl \
    git \
    libpq-dev \
    libvips \
    postgresql-client && \
    rm -rf /var/lib/apt/lists/*

# Configure bundler
ENV RAILS_ENV="development" \
    BUNDLE_PATH="/gems" \
    BUNDLE_JOBS=4 \
    PATH="/app/bin:${PATH}"

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

# Precompile assets
RUN bundle exec rake assets:precompile

RUN chmod +x /app/bin/*

# Standard Rails port
EXPOSE 3000

# Default command
CMD ["bin/rails", "s", "-b", "0.0.0.0"]
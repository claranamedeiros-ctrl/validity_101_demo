source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.4.5"

gem "rails", "~> 8.0.3"
gem "sqlite3", ">= 2.1", group: :development
gem "pg", "~> 1.1", group: :production
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "bootsnap", require: false

# Asset pipeline
gem "sprockets-rails"
gem "sassc-rails"

gem "ruby_llm", "~> 1.6"
gem "ruby-openai", "~> 7.4"
gem "prompt_engine"
gem "csv"
gem "dotenv-rails"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ]
end

group :development do
  gem "web-console"
end
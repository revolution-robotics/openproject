# frozen_string_literal: true

namespace :db do
  desc 'Exit with status 0 if Rails database exists, otherwise 1'
  task exists?: :environment do
    ActiveRecord::Base.connection
  rescue ActiveRecord::NoDatabaseError
    exit 1
  else
    exit 0
  end
end

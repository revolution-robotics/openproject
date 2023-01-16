# frozen_string_literal: true

namespace :csp do
  desc 'Print configured endpoint for CSP Violation Reports'
  task report_uri: :environment do
    puts Rails.application.config.content_security_policy.directives['report-uri']
  end
end

# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20251001130713_backfill_token_status_in_vulnerabilities.rb')

RSpec.describe BackfillTokenStatusInVulnerabilities, feature_category: :vulnerability_management do
  it_behaves_like 'a deprecated Advanced Search migration', 20251001130713
end

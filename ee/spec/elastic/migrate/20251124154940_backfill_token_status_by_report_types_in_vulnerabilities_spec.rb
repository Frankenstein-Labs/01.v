# frozen_string_literal: true

require 'spec_helper'
require File.expand_path(
  'ee/elastic/migrate/20251124154940_backfill_token_status_by_report_types_in_vulnerabilities.rb'
)

RSpec.describe BackfillTokenStatusByReportTypesInVulnerabilities, feature_category: :vulnerability_management do
  it_behaves_like 'a deprecated Advanced Search migration', 20251124154940
end

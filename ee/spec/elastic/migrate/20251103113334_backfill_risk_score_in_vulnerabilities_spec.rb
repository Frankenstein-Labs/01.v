# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20251103113334_backfill_risk_score_in_vulnerabilities.rb')

RSpec.describe BackfillRiskScoreInVulnerabilities, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20251103113334
end

# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20251202111253_backfill_risk_score_in_vulnerabilities_no_saas.rb')

RSpec.describe BackfillRiskScoreInVulnerabilitiesNoSaas, feature_category: :vulnerability_management do
  it_behaves_like 'a deprecated Advanced Search migration', 20251202111253
end

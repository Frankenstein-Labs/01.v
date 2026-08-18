# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250702131958_backfill_reachability_in_vulnerabilities.rb')

RSpec.describe BackfillReachabilityInVulnerabilities, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250702131958
end

# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20251127090000_backfill_vulnerabilities_for_self_managed.rb')

RSpec.describe BackfillVulnerabilitiesForSelfManaged, feature_category: :vulnerability_management do
  it_behaves_like 'a deprecated Advanced Search migration', 20251127090000
end

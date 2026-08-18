# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250611135718_re_introduce_backfill_vulnerabilities.rb')

RSpec.describe ReIntroduceBackfillVulnerabilities, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250611135718
end

# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250408180015_create_vulnerabilities_index.rb')

RSpec.describe CreateVulnerabilitiesIndex, feature_category: :vulnerability_management do
  it_behaves_like 'a deprecated Advanced Search migration', 20250408180015
end

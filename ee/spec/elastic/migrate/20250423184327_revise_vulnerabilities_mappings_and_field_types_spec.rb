# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250423184327_revise_vulnerabilities_mappings_and_field_types.rb')

# See https://docs.gitlab.com/ee/development/testing_guide/best_practices.html#elasticsearch-specs
# for more information on how to write search migration specs for GitLab.
RSpec.describe ReviseVulnerabilitiesMappingsAndFieldTypes, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250423184327
end

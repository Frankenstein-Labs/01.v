# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ProjectStatistics'], feature_category: :consumables_cost_management do
  it 'includes the EE specific fields' do
    expected_fields = [
      :cost_factored_storage_size, :cost_factored_repository_size, :cost_factored_build_artifacts_size,
      :cost_factored_lfs_objects_size, :cost_factored_packages_size, :cost_factored_snippets_size,
      :cost_factored_wiki_size
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end

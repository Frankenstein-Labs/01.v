# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe API::Helpers::SearchHelpers, feature_category: :global_search do
  describe '.global_search_scopes' do
    it 'returns the expected scopes' do
      expect(described_class.global_search_scopes).to match_array(
        %w[wiki_blobs blobs commits notes projects issues work_items merge_requests milestones snippet_titles users])
    end
  end

  describe '.group_search_scopes' do
    it 'returns the expected scopes' do
      expect(described_class.group_search_scopes)
        .to match_array(%w[wiki_blobs blobs commits notes projects issues work_items merge_requests milestones users])
    end
  end

  describe '.search_param_keys' do
    it 'returns param keys with fields' do
      expect(described_class.search_param_keys).to match_array(
        %i[
          confidential exclude_forks fields include_archived num_context_lines order_by page per_page regex scope search
          search_type sort state type
        ]
      )
    end
  end
end

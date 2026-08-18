# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elasticsearch::Model::Adapter::ActiveRecord::Records, :elastic, feature_category: :global_search do
  before do
    stub_ee_application_setting(elasticsearch_indexing: true)
  end

  describe '#records' do
    let(:user) { create(:user) }
    let(:search_options) do
      {
        options: {
          search_level: 'global',
          current_user: user,
          project_ids: :any,
          order_by: 'created_at',
          sort: 'desc'
        }
      }
    end

    let(:results) { MergeRequest.elastic_search('*', **search_options).records.to_a }

    it 'returns results in the same sorted order as they come back from Elasticsearch' do
      project = create(:project, :public)
      new_merge_request = create(:merge_request, :unique_branches, source_project: project)
      recent_merge_request = create(:merge_request, :unique_branches, source_project: project, created_at: 1.hour.ago)
      old_merge_request = create(:merge_request, :unique_branches, source_project: project, created_at: 7.days.ago)

      ensure_elasticsearch_index!

      expect(results).to eq([new_merge_request, recent_merge_request, old_merge_request])
    end
  end
end

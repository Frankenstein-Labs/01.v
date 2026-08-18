# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::InstrumentationHelper do
  describe '.add_instrumentation_data', :request_store, feature_category: :global_search do
    let(:payload) { {} }

    subject { described_class.add_instrumentation_data(payload) }

    # We don't want to interact with Elasticsearch in GitLab FOSS so we test
    # this in ee/ only. The code exists in FOSS and won't do anything.
    context 'when Elasticsearch calls are made', :elastic do
      it 'adds Elasticsearch data' do
        ensure_elasticsearch_index!

        subject

        expect(payload[:elasticsearch_calls]).to be > 0
        expect(payload[:elasticsearch_duration_s]).to be > 0
        expect(payload[:elasticsearch_timed_out_count]).to be_kind_of(Integer)
      end
    end

    context 'when Zoekt calls are made', :zoekt_settings_enabled, :zoekt_cache_disabled do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, :public, :small_repo, group: group) }
      let(:node_id) { ::Search::Zoekt::Node.last.id }

      before_all do
        zoekt_ensure_project_indexed!(project)
      end

      it 'adds Zoekt data' do
        search_results = Search::Zoekt::SearchResults.new(nil, 'query', nil, group_id: group.id, node_id: node_id)
        search_results.objects('blobs')

        subject

        expect(payload[:zoekt_calls]).to be > 0
        expect(payload[:zoekt_duration_s]).to be > 0
      end
    end
  end
end

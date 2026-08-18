# frozen_string_literal: true

require 'spec_helper'

# We don't want to interact with Zoekt in GitLab FOSS so we test
# this in ee/ only. The code exists in FOSS and won't do anything.

RSpec.describe Peek::Views::Zoekt, :zoekt_settings_enabled, :request_store, feature_category: :global_search do
  before do
    ::Gitlab::Instrumentation::Zoekt.detail_store # Create store in redis
    allow(::Gitlab::PerformanceBar).to receive(:enabled_for_request?).and_return(true)
  end

  describe '#results' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :public, :repository, group: group) }
    let(:node_id) { ::Search::Zoekt::Node.last.id }

    let(:results) { described_class.new.results }
    let(:timeout) { '30s' }

    before do
      zoekt_ensure_namespace_indexed!(group)
    end

    it 'includes performance details' do
      ::Gitlab::SafeRequestStore.clear!

      search_results = Search::Zoekt::SearchResults.new(nil, 'query', nil, group_id: group.id,
        node_id: node_id)
      search_results.objects('blobs')

      expect(results[:calls]).to be > 0
      expect(results[:duration]).to be_kind_of(String)
      expect(results[:details].last[:method]).to eq('POST')
      expect(results[:details].last[:path]).to eq('/webserver/api/v2/search')
      expect(results[:details].last[:request]).to eq("POST /webserver/api/v2/search?")
    end
  end
end

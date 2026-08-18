# frozen_string_literal: true

require 'spec_helper'

# We don't want to interact with Elasticsearch in GitLab FOSS so we test
# this in ee/ only. The code exists in FOSS and won't do anything.

RSpec.describe Peek::Views::Elasticsearch, :elastic, :request_store, feature_category: :global_search do
  before do
    ::Gitlab::Instrumentation::ElasticsearchTransport.detail_store # Create store in redis
    allow(::Gitlab::PerformanceBar).to receive(:enabled_for_request?).and_return(true)
    ensure_elasticsearch_index!
  end

  describe '#results' do
    let(:results) { described_class.new.results }
    let(:project) { create(:project, :repository) }
    let(:timeout) { '30s' }

    it 'includes performance details' do
      ::Gitlab::SafeRequestStore.clear!
      project.repository.__elasticsearch__.elastic_search_as_found_blob('hello world',
        options: { search_level: 'global' })

      expect(results[:calls]).to be > 0
      expect(results[:duration]).to be_kind_of(String)
      expect(results[:details]).to include(hash_including({
        method: 'POST',
        path: 'gitlab-test/_search',
        params: { routing: "project_#{project.id}", timeout: timeout },
        request: "POST gitlab-test/_search?routing=project_#{project.id}&timeout=#{timeout}"
      }))
    end
  end
end

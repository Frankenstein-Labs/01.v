# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Elastic Ingestion Pipeline', :sidekiq_inline, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: user) }

  let(:project_routing) { "project_#{project.id}" }
  let(:group_routing) { "group_#{project.root_ancestor.id}" }
  let(:logger) { ::Gitlab::Elasticsearch::Logger.build }
  let(:bulk_indexer) { ::Search::Elastic::BulkIndexer.new(logger: logger) }
  let(:bookkeeping_service) { ::Elastic::ProcessBookkeepingService }
  let(:client) { Search::Elastic::Helper.default.client }
  let(:embedding) { Array.new(768, 1.0) }

  before do
    allow(::Search::Elastic::BulkIndexer).to receive(:new).and_return(bulk_indexer)
    allow(::Gitlab::Elasticsearch::Logger).to receive(:build).and_return(logger)
    allow(::Search::Elastic::Client).to receive(:build).and_return(client)
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    ensure_elasticsearch_index!
  end

  context 'for legacy references', :elastic_delete_by_query do
    it 'adds the document to the index' do
      merge_request = create(:merge_request, source_project: project, target_project: project)

      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(merge_request).and_call_original
      expect(::Search::Elastic::Reference).to receive(:serialize).with(merge_request).and_call_original
      expect(::Search::Elastic::References::Legacy).to receive(:serialize).with(merge_request).and_call_original
      expect(Search::Elastic::DocumentReference).to receive(:serialize_record).with(merge_request).and_call_original

      merge_request.save!

      serialized_merge_request = "MergeRequest #{merge_request.id} #{merge_request.es_id} #{project_routing}"

      expect(::Search::Elastic::Reference).to receive(:deserialize).with(serialized_merge_request).and_call_original
      expect(::Search::Elastic::References::Legacy).to receive(:instantiate).with(
        serialized_merge_request).and_call_original
      expect(Search::Elastic::DocumentReference).to receive(:deserialize).with(
        serialized_merge_request).and_call_original

      expect(Search::Elastic::Reference).to receive(:preload_database_records).and_call_original
      expect(bulk_indexer).to receive(:process).and_call_original

      ensure_elasticsearch_index!

      expect(docs_in_index('gitlab-test-merge_requests')).to match_array([{ 'id' => merge_request.es_id.to_s,
                                                                            'routing' => project_routing }])
    end

    context 'when a manual reference exists in the queue' do
      it 'serializes, deserializes and indexes the reference correctly' do
        merge_request = create(:merge_request, source_project: project, target_project: project)
        serialized_merge_request = "MergeRequest #{merge_request.id} #{merge_request.es_id} #{project_routing}"

        ensure_elasticsearch_index!

        ref = Search::Elastic::DocumentReference.new(MergeRequest, merge_request.id, merge_request.es_id,
          merge_request.es_parent)
        ::Elastic::ProcessBookkeepingService.track!(ref)
        expect(bookkeeping_service.queued_items.values.flatten).to match_array([serialized_merge_request, Float])

        merge_request.update!(title: 'My title 2')
        expect(bookkeeping_service.queued_items.values.flatten).to match_array([serialized_merge_request, Float])

        ensure_elasticsearch_index!

        expect(bookkeeping_service.queued_items).to eq({})
        expect(docs_in_index('gitlab-test-merge_requests').last).to eq({ 'id' => merge_request.es_id.to_s,
                                                                         'routing' => project_routing })
      end
    end

    context 'when a string reference exists in the queue' do
      it 'serializes, deserializes and indexes the reference correctly' do
        merge_request = create(:merge_request, source_project: project, target_project: project)
        serialized_merge_request = "MergeRequest #{merge_request.id} #{merge_request.es_id} #{project_routing}"

        ensure_elasticsearch_index!

        ref = Search::Elastic::DocumentReference.new(MergeRequest, merge_request.id, merge_request.es_id,
          merge_request.es_parent).serialize
        ::Elastic::ProcessBookkeepingService.track!(ref)
        expect(bookkeeping_service.queued_items.values.flatten).to match_array([serialized_merge_request, Float])

        merge_request.update!(title: 'My title 2')
        expect(bookkeeping_service.queued_items.values.flatten).to match_array([serialized_merge_request, Float])

        ensure_elasticsearch_index!

        expect(bookkeeping_service.queued_items).to eq({})
        expect(docs_in_index('gitlab-test-merge_requests').last).to eq({ 'id' => merge_request.es_id.to_s,
                                                                         'routing' => project_routing })
      end
    end

    context 'if a manually created ref fails to be deserialized' do
      it 'bookkeeping does not fail' do
        ::Elastic::ProcessBookkeepingService.track!('1')

        expect(logger).to receive(:error).with(hash_including('message' => 'submit_document_failed'))

        expect { ensure_elasticsearch_index! }.not_to raise_error
      end
    end

    context 'if a ref fails to be indexed' do
      it 'bookkeeping does not fail' do
        merge_request = create(:merge_request, source_project: project, target_project: project)
        serialized_merge_request = "MergeRequest #{merge_request.id} #{merge_request.es_id} #{project_routing}"

        allow(client).to receive(:bulk).and_raise(StandardError)

        expect { ensure_elasticsearch_index! }.not_to raise_error

        expect(docs_in_index('gitlab-test-merge_requests')).to be_empty
        # After the first failure, items are routed to the retry queue
        expect(Search::Elastic::RetryQueue.queued_items.values.flatten).to match_array([serialized_merge_request,
          Float])

        # Process the retry queue - items will fail again and move to dead queue
        expect { Search::Elastic::RetryQueue.new.execute }.not_to raise_error

        # After the second failure from retry queue, items are routed to the dead queue
        expect(Search::Elastic::DeadQueue.queued_items.values.flatten).to match_array([serialized_merge_request, Float])
      end
    end
  end

  context 'for User references', :elastic_delete_by_query do
    let_it_be_with_reload(:indexed_user) { create(:user) }

    let(:new_format) { ::Search::Elastic::References::User.serialize(indexed_user) }
    let(:users_index) { ::Search::Elastic::References::User.index }
    let(:user_es_id) { ::Search::Elastic::References::User.new(indexed_user.id).identifier }

    it 'serializes using the new reference format' do
      expect(indexed_user.elastic_reference).to eq(new_format)
    end

    it 'indexes a user through the new reference path', :aggregate_failures do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(indexed_user).and_call_original
      expect(::Search::Elastic::References::User).to receive(:serialize).with(indexed_user).at_least(:once)
        .and_call_original

      indexed_user.update!(name: 'Updated Name')

      expect(::Search::Elastic::Reference).to receive(:deserialize).with(new_format).and_call_original
      expect(::Search::Elastic::References::User).to receive(:instantiate).with(new_format).and_call_original

      ensure_elasticsearch_index!

      expect(docs_in_index(users_index)).to include(a_hash_including('id' => user_es_id))
    end

    context 'when a legacy reference string is already in the queue' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, namespace: group, developers: indexed_user) }

      let(:legacy_format) { "User #{indexed_user.id} user_#{indexed_user.id}" }

      it 'converts the legacy ref and indexes the document with full attributes', :aggregate_failures do
        ::Elastic::ProcessBookkeepingService.track!(legacy_format)

        expect(::Search::Elastic::Reference).to receive(:deserialize).with(legacy_format).and_call_original
        expect(::Search::Elastic::References::Legacy).to receive(:instantiate).with(legacy_format).and_call_original
        expect(::Search::Elastic::References::User).to receive(:for_indexing).and_call_original

        ensure_elasticsearch_index!

        expect(docs_in_index(users_index, include_source: true)).to include(
          a_hash_including(
            'id' => indexed_user.id,
            'namespace_ancestry_ids' => ["#{group.id}-p#{project.id}-"]
          )
        )
      end
    end
  end

  def docs_in_index(index, include_source: false)
    body = { query: { match_all: {} } }

    body[:_source] = { includes: ['*'] + dense_vector_fields_in_index(index) } if include_source

    client
      .search(index: index, body: body)
      .dig('hits', 'hits')
      .map do |hit|
        hash = { id: hit['_id'], routing: hit['_routing'] }
        hash.merge!(hit['_source']) if include_source
        hash.with_indifferent_access
      end
  end

  def dense_vector_fields_in_index(index)
    mapping = client.indices.get_mapping(index: index)
    index_name = mapping.each_key.first
    properties = mapping.dig(index_name, 'mappings', 'properties') || {}

    properties.select { |_field, config| config['type'] == 'dense_vector' }.keys
  end
end

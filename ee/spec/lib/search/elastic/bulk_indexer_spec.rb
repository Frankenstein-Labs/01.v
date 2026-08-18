# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::BulkIndexer, :elastic, :clean_gitlab_redis_shared_state,
  feature_category: :global_search do
  let_it_be_with_reload(:work_item) { create(:work_item) }
  let_it_be(:other_work_item) { create(:work_item, project: work_item.project) }

  let(:project) { work_item.project }
  let(:logger) { ::Gitlab::Elasticsearch::Logger.build }
  let(:es_client) { indexer.client }
  let(:work_item_as_ref) { ref(work_item) }
  let(:work_item_as_json_with_times) { work_item_as_ref.as_indexed_json }
  let(:work_item_as_json) { work_item_as_json_with_times.except('created_at', 'updated_at') }
  let(:other_work_item_as_ref) { ref(other_work_item) }

  # Whatever the json payload bytesize is, it will ultimately be multiplied
  # by the total number of indices. We add an additional 0.5 to the overflow
  # factor to simulate the bulk_limit being exceeded in tests.
  let(:bulk_limit_overflow_factor) do
    helper = Search::Elastic::Helper.default
    helper.target_index_names(target: nil).count + 0.5
  end

  subject(:indexer) { described_class.new(logger: logger) }

  RSpec::Matchers.define :valid_request do |op, expected_op_hash, expected_json|
    match do |actual|
      op_hash, doc_hash = actual[:body].map { |hash| Gitlab::Json.parse(hash) }

      doc_hash = doc_hash['doc'] if op == :update
      doc_without_timestamps = doc_hash.except('created_at', 'updated_at')

      op_hash == expected_op_hash && doc_without_timestamps == expected_json
    end
  end

  describe '#process' do
    it 'returns bytesize for the indexing operation and data' do
      bytesize = instance_double(Integer)
      allow(indexer).to receive(:submit).and_return(bytesize)

      expect(indexer.process(work_item_as_ref)).to eq(bytesize)
    end

    it 'returns bytesize when DocumentShouldBeDeletedFromIndexException is raised' do
      bytesize = instance_double(Integer)
      allow(indexer).to receive(:submit).and_return(bytesize)

      rec = work_item_as_ref.database_record
      allow(rec.__elasticsearch__)
        .to receive(:as_indexed_json)
        .and_raise ::Elastic::Latest::DocumentShouldBeDeletedFromIndexError.new(rec.class.name, rec.id)

      expect(indexer.process(work_item_as_ref)).to eq(bytesize)
    end

    it 'does not send a bulk request per call' do
      expect(es_client).not_to receive(:bulk)

      indexer.process(work_item_as_ref)
    end

    it 'sends the action and source in the same request' do
      set_bulk_limit(indexer, 1)
      indexer.process(work_item_as_ref)
      allow(es_client).to receive(:bulk).and_return({})

      indexer.process(work_item_as_ref)

      expect(es_client)
        .to have_received(:bulk)
        .with(body: [kind_of(String), kind_of(String)])
      expect(indexer.failures).to be_empty
    end

    it 'sends a bulk request before adding an item that exceeds the bulk limit' do
      bulk_limit_bytes = (work_item_as_json_with_times.to_json.bytesize * bulk_limit_overflow_factor).to_i
      set_bulk_limit(indexer, bulk_limit_bytes)
      indexer.process(work_item_as_ref)
      allow(es_client).to receive(:bulk).and_return({})

      indexer.process(work_item_as_ref)

      expect(es_client).to have_received(:bulk) do |args|
        body_bytesize = args[:body].sum(&:bytesize)
        expect(body_bytesize).to be <= bulk_limit_bytes
      end

      expect(indexer.failures).to be_empty
    end

    it 'calls bulk with an upsert request' do
      set_bulk_limit(indexer, 1)
      indexer.process(work_item_as_ref)
      allow(es_client).to receive(:bulk).and_return({})

      indexer.process(work_item_as_ref)

      expected_op_hash = {
        update: {
          _index: work_item_as_ref.index_name,
          _type: nil,
          _id: work_item.id,
          routing: work_item.es_parent
        }
      }.with_indifferent_access

      expect(es_client).to have_received(:bulk).with(valid_request(:update, expected_op_hash, work_item_as_json))
    end

    context 'when routing is not set in as_indexed_json' do
      before do
        original_as_indexed_json = work_item_as_ref.as_indexed_json
        allow(work_item_as_ref).to receive(:as_indexed_json).and_return(original_as_indexed_json.except('routing'))
      end

      it 'tracks an exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
          .with(Search::Elastic::BulkIndexer::RoutingMissingError, ref: work_item_as_ref.serialize)

        indexer.process(work_item_as_ref)
      end

      context 'when reference does not have routing' do
        it 'does not track an exception' do
          allow(work_item_as_ref).to receive(:routing).and_return(nil)

          expect(Gitlab::ErrorTracking).not_to receive(:track_and_raise_for_dev_exception)

          indexer.process(work_item_as_ref)
        end
      end
    end

    it 'returns 0 and adds ref to failures if ReferenceFailure is raised' do
      work_item_as_ref.database_record
      allow(work_item_as_ref)
        .to receive(:as_indexed_json)
        .and_raise ::Search::Elastic::Reference::ReferenceFailure

      expect(indexer.process(work_item_as_ref)).to eq(0)
      expect(indexer.failures).to contain_exactly(work_item_as_ref)
    end

    context 'when ref operation is index' do
      before do
        allow(work_item_as_ref).to receive(:operation).and_return(:index)
      end

      it 'calls bulk with an index request' do
        set_bulk_limit(indexer, 1)

        indexer.process(work_item_as_ref)
        allow(es_client).to receive(:bulk).and_return({})

        indexer.process(work_item_as_ref)

        expected_op_hash = {
          index: {
            _index: work_item_as_ref.index_name,
            _type: nil,
            _id: work_item.id,
            routing: work_item.es_parent
          }
        }.with_indifferent_access

        expect(es_client).to have_received(:bulk).with(valid_request(:index, expected_op_hash, work_item_as_json))
      end

      it 'returns bytesize when DocumentShouldBeDeletedFromIndexException is raised' do
        bytesize = instance_double(Integer)
        allow(indexer).to receive(:submit).and_return(bytesize)

        rec = work_item_as_ref.database_record
        allow(rec.__elasticsearch__)
          .to receive(:as_indexed_json)
          .and_raise ::Elastic::Latest::DocumentShouldBeDeletedFromIndexError.new(rec.class.name, rec.id)

        expect(indexer.process(work_item_as_ref)).to eq(bytesize)
      end

      context 'when as_indexed_json is blank' do
        before do
          allow(work_item_as_ref).to receive_messages(as_indexed_json: {}, routing: nil)
        end

        it 'logs a warning' do
          expect(es_client).not_to receive(:bulk)

          message = 'Reference as_indexed_json is blank, removing from the queue'
          expect(logger).to receive(:warn).with(message: message, ref: work_item_as_ref.serialize)

          indexer.process(work_item_as_ref)
        end
      end
    end

    describe 'when the operation is invalid' do
      before do
        allow(work_item_as_ref).to receive(:operation).and_return('Invalid')
      end

      it 'raises an error' do
        expect { indexer.process(work_item_as_ref) }.to raise_error(StandardError, 'Operation Invalid is not supported')
      end
    end
  end

  describe '#flush' do
    context 'when curation has not occurred' do
      it 'completes a bulk' do
        indexer.process(work_item_as_ref)

        # The es_client will receive three items in bulk request for a single ref:
        # 1) The bulk index header, ie: { "index" => { "_index": "gitlab-work_items" } }
        # 2) The payload of the actual document to write index
        expect(es_client)
          .to receive(:bulk)
            .with(body: [kind_of(String), kind_of(String)])
            .and_return({})

        expect(indexer.flush).to be_empty
      end

      it 'fails all documents on exception' do
        expect(es_client).to receive(:bulk) { raise 'An exception' }

        indexer.process(work_item_as_ref)
        indexer.process(other_work_item_as_ref)

        expect(indexer.flush).to contain_exactly(work_item_as_ref, other_work_item_as_ref)
        expect(indexer.failures).to contain_exactly(work_item_as_ref, other_work_item_as_ref)
      end

      it 'fails a document correctly on exception after adding an item that exceeded the bulk limit' do
        bulk_limit_bytes = (work_item_as_json_with_times.to_json.bytesize * bulk_limit_overflow_factor).to_i
        set_bulk_limit(indexer, bulk_limit_bytes)
        indexer.process(work_item_as_ref)
        allow(es_client).to receive(:bulk).and_return({})

        indexer.process(work_item_as_ref)

        expect(es_client).to have_received(:bulk) do |args|
          body_bytesize = args[:body].sum(&:bytesize)
          expect(body_bytesize).to be <= bulk_limit_bytes
        end

        expect(es_client).to receive(:bulk) { raise 'An exception' }

        expect(indexer.flush).to contain_exactly(work_item_as_ref)
        expect(indexer.failures).to contain_exactly(work_item_as_ref)
      end
    end

    it 'fails documents that elasticsearch refuses to accept' do
      # Indexes with uppercase characters are invalid
      ensure_elasticsearch_index!

      allow(other_work_item_as_ref)
        .to receive(:index_name)
        .and_return('Invalid')

      indexer.process(work_item_as_ref)
      indexer.process(other_work_item_as_ref)

      expect(indexer.flush).to contain_exactly(other_work_item_as_ref)
      expect(indexer.failures).to contain_exactly(other_work_item_as_ref)

      refresh_index!

      expect(search_one(work_item_as_ref.index_name)).to include(work_item_as_json)
    end

    context 'when indexing an work_item' do
      it 'adds the work_item to the index' do
        indexer.process(work_item_as_ref)

        expect(indexer.flush).to be_empty

        refresh_index!

        expect(search_one(work_item_as_ref.index_name)).to include(work_item_as_json)
      end

      it 'reindexes an unchanged work_item' do
        ensure_elasticsearch_index!

        expect(es_client).to receive(:bulk).and_call_original

        indexer.process(work_item_as_ref)

        expect(indexer.flush).to be_empty
      end

      it 'reindexes a changed work_item' do
        ensure_elasticsearch_index!
        work_item.update!(title: 'new title')

        expect(work_item_as_json['title']).to eq('new title')

        indexer.process(work_item_as_ref)

        expect(indexer.flush).to be_empty

        refresh_index!

        expect(search_one(work_item_as_ref.index_name)).to include(work_item_as_json)
      end

      it 'deletes the work_item from the index if DocumentShouldBeDeletedFromIndexException is raised' do
        db_record = work_item_as_ref.database_record
        allow(work_item_as_ref)
          .to receive(:as_indexed_json)
            .and_raise(::Elastic::Latest::DocumentShouldBeDeletedFromIndexError.new(db_record.class.name, db_record.id))

        indexer.process(work_item_as_ref)

        expect(indexer.flush).to be_empty

        refresh_index!

        expect(search(work_item_as_ref.index_name, '*').size).to eq(0)
      end

      context 'when there has not been a alias rollover yet' do
        let(:alias_name) { "gitlab-test-work_items" }
        let(:single_index) { "gitlab-test-work_items-20220915-0822" }

        before do
          allow(es_client).to receive_message_chain(:indices, :get_alias)
            .with(index: alias_name).and_return(
              { single_index => { "aliases" => { alias_name => {} } } }
            )
        end

        it 'does not do any delete ops' do
          expect(indexer).not_to receive(:delete)

          indexer.process(work_item_as_ref)

          expect(indexer.flush).to be_empty
        end
      end

      it 'does not check for alias info or add any delete ops' do
        expect(es_client).not_to receive(:indices)
        expect(indexer).not_to receive(:delete)

        indexer.process(work_item_as_ref)

        expect(indexer.flush).to be_empty
      end
    end

    context 'when deleting an work_item' do
      it 'removes the work_item from the index' do
        ensure_elasticsearch_index!

        expect(work_item_as_ref).to receive(:database_record).and_return(nil)

        indexer.process(work_item_as_ref)

        expect(indexer.flush).to be_empty

        refresh_index!

        expect(search(work_item_as_ref.index_name, '*').size).to eq(0)
      end

      it 'succeeds even if the work_item is not present' do
        expect(work_item_as_ref).to receive(:database_record).and_return(nil)

        indexer.process(work_item_as_ref)

        expect(indexer.flush).to be_empty

        refresh_index!

        expect(search(work_item_as_ref.index_name, '*').size).to eq(0)
      end
    end
  end

  def ref(record)
    ::Search::Elastic::Reference.build(record, ::Search::Elastic::References::WorkItem)
  end

  def stub_es_client(indexer, client)
    allow(indexer).to receive(:client) { client }
  end

  def set_bulk_limit(indexer, bytes)
    allow(indexer).to receive(:bulk_limit_bytes) { bytes }
  end

  def search(index_name, _text)
    items_in_index(index_name, source: true)
  end

  def search_one(index_name)
    results = search(index_name, '*')

    expect(results.size).to eq(1)

    results.first
  end
end

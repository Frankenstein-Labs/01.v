# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Delete::AllBlobsService, feature_category: :global_search do
  let(:main_index) { Elastic::Latest::Config.index_name }

  describe 'integration', :elasticsearch_settings_enabled do
    context 'when blobs are present in index', :elastic_delete_by_query, :sidekiq_inline do
      let_it_be(:project) { create(:project, :small_repo) }
      let_it_be_with_reload(:setting) { create(:application_setting) }

      before do
        Search::Elastic::CommitIndexerWorker.perform_async(project.id, force: true)
        create(:personal_snippet)
        ensure_elasticsearch_index!
      end

      context 'when setting elasticsearch_code_scope is disabled' do
        before do
          stub_ee_application_setting(elasticsearch_code_scope: false)
        end

        it 'only deletes all blob documents from the main index' do
          # Verify index has documents
          initial_blob_docs, initial_non_blob_docs = docs_in_index_partition_by_type_blobs
          expect(initial_blob_docs).not_to be_empty
          expect(initial_non_blob_docs).not_to be_empty

          described_class.execute({})

          # Refresh the index to make deletions visible
          es_helper.refresh_index(index_name: main_index)

          # Verify only blob documents are deleted
          final_blob_docs, final_non_blob_docs = docs_in_index_partition_by_type_blobs
          expect(final_blob_docs).to be_empty
          expect(final_non_blob_docs).not_to be_empty
        end
      end

      context 'when setting elasticsearch_code_scope is enabled' do
        before do
          stub_ee_application_setting(elasticsearch_code_scope: true)
        end

        it 'does not delete any document' do
          # Verify index has documents
          initial_blob_docs, initial_non_blob_docs = docs_in_index_partition_by_type_blobs
          expect(initial_blob_docs).not_to be_empty
          expect(initial_non_blob_docs).not_to be_empty

          described_class.execute({})

          # Refresh the index to make deletions visible
          es_helper.refresh_index(index_name: main_index)

          # Verify index still has documents
          initial_blob_docs, initial_non_blob_docs = docs_in_index_partition_by_type_blobs
          expect(initial_blob_docs).not_to be_empty
          expect(initial_non_blob_docs).not_to be_empty
        end
      end
    end

    context 'when no blobs are present in index', :elastic do
      it 'completes successfully without errors' do
        # Verify index has no documents
        initial_blobs_docs, initial_non_blobs_docs = docs_in_index_partition_by_type_blobs
        expect(initial_blobs_docs).to be_empty
        expect(initial_non_blobs_docs).to be_empty

        expect { described_class.execute({}) }.not_to raise_error
      end
    end

    def docs_in_index_partition_by_type_blobs
      items_in_index(main_index, source: true).partition { |doc| doc['type'] == 'blob' }
    end
  end
end

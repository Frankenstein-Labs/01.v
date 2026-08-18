# frozen_string_literal: true

module Search
  module Elastic
    module MigrationBackfillHelper
      include Search::Elastic::IndexName
      include Gitlab::Utils::StrongMemoize

      UPDATE_BATCH_SIZE = 100

      def migrate
        if completed?
          log "Skipping migration since it is already applied", field_names: field_names, index_name: index_name

          return
        end

        log "Start backfilling fields", field_names: field_names, index_name: index_name, batch_size: query_batch_size

        document_references = process_batch!

        clear_memoization(:remaining_documents_count)

        log "Backfilling batch has been processed", field_names: field_names, index_name: index_name,
          documents_count: document_references.size
      rescue StandardError => e
        log_raise "migrate failed with error: #{e.class}:#{e.message}"
      end

      def completed?
        doc_count = remaining_documents_count

        log "Checking the number of documents without fields", field_names: field_names, documents_remaining: doc_count

        doc_count == 0
      end

      private

      def remaining_documents_count
        helper.refresh_index(index_name: index_name)

        query = {
          size: 0,
          aggs: {
            documents: {
              filter: missing_field_filter
            }
          }
        }

        results = client.search(index: index_name, body: query)
        count = results.dig('aggregations', 'documents', 'doc_count')

        set_migration_state(documents_remaining: count)

        count
      end
      strong_memoize_attr :remaining_documents_count

      def field_names
        Array.wrap(field_name)
      end

      def field_name
        raise NotImplementedError
      end

      def fields_exist_query
        field_names.map do |field|
          {
            bool: {
              must_not: {
                exists: {
                  field: field
                }
              }
            }
          }
        end
      end

      def missing_field_filter
        {
          bool: {
            minimum_should_match: 1,
            should: fields_exist_query,
            filter: {
              term: {
                type: {
                  value: self.class::DOCUMENT_TYPE.es_type
                }
              }
            }
          }
        }
      end

      def process_batch!
        query = {
          size: query_batch_size,
          query: {
            bool: {
              filter: missing_field_filter
            }
          }
        }

        results = client.search(index: index_name, body: query)
        hits = results.dig('hits', 'hits') || []

        document_references = hits.map! do |hit|
          id = hit.dig('_source', reference_primary_key)
          es_id = hit['_id']

          # es_parent attribute is used for routing but is nil for some records, e.g., projects, users
          es_parent = hit['_routing']

          build_reference(self.class::DOCUMENT_TYPE, id, es_id, es_parent)
        end

        document_references.each_slice(update_batch_size) do |refs|
          bookkeeping_service.track!(*refs)
        end

        document_references
      end

      def build_reference(document_type, id, es_id, es_parent)
        Search::Elastic::Reference.init(document_type, id, es_id, es_parent)
      end

      def bookkeeping_service
        ::Elastic::ProcessInitialBookkeepingService
      end

      def query_batch_size
        return batch_size if respond_to?(:batch_size)

        raise NotImplementedError
      end

      def update_batch_size
        return self.class::UPDATE_BATCH_SIZE if self.class.const_defined?(:UPDATE_BATCH_SIZE)

        UPDATE_BATCH_SIZE
      end

      def ref_klass
        Search::Elastic::Helper.ref_class(self.class::DOCUMENT_TYPE)
      end

      def reference_primary_key
        return ref_klass.model_klass.primary_key if ref_klass

        self.class::DOCUMENT_TYPE.primary_key
      end
      strong_memoize_attr :reference_primary_key
    end
  end
end

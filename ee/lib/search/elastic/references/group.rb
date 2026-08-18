# frozen_string_literal: true

module Search
  module Elastic
    module References
      class Group < Reference
        include Search::Elastic::Concerns::DatabaseReference
        include Search::Elastic::Concerns::SchemaVersionedReference

        DOC_TYPE = 'group'
        INDEX_NAME = 'groups'

        # Maps schema versions to their corresponding migration names.
        # Set migration to nil for baseline versions that don't require migration completion.
        SCHEMA_VERSIONS = {
          26_01 => nil
        }.freeze
        SCHEMA_VERSION = SCHEMA_VERSIONS.keys.max.freeze

        DIRECT_FIELDS = %w[
          id
          name
          path
          description
          parent_id
          visibility_level
          created_at
          updated_at
          organization_id
        ].freeze

        class << self
          extend ::Gitlab::Utils::Override

          override :serialize
          def serialize(record)
            new(record.id, record.es_parent).serialize
          end

          override :instantiate
          def instantiate(string)
            _, id, routing = delimit(string)
            new(id, routing)
          end

          override :preload_indexing_data
          def preload_indexing_data(refs)
            ids = refs.map(&:identifier)
            records = model_klass.id_in(ids).preload_indexing_data

            records_by_id = records.index_by(&:id)
            refs.each do |ref|
              ref.database_record = records_by_id[ref.identifier]
            end

            refs
          end

          def index
            environment_specific_index_name(INDEX_NAME)
          end

          def model_klass
            ::Group
          end
        end

        attr_reader :identifier, :routing

        def initialize(identifier, routing)
          @identifier = identifier.to_i
          @routing = routing
        end

        override :serialize
        def serialize
          self.class.join_delimited([klass, identifier, routing].compact)
        end

        override :as_indexed_json
        def as_indexed_json
          internal_es_fields.tap do |fields|
            add_direct_fields(fields)
            add_computed_fields(fields)
          end
        end

        override :index_name
        def index_name
          self.class.index
        end

        private

        def add_direct_fields(fields)
          DIRECT_FIELDS.each do |name|
            set_field(fields, name) { safely_read_attribute_for_elasticsearch(database_record, name) }
          end
        end

        def add_computed_fields(fields)
          fields.merge!(
            full_name: database_record.full_name,
            full_path: database_record.full_path,
            traversal_ids: database_record.elastic_namespace_ancestry,
            archived: database_record.archived?
          )
        end
      end
    end
  end
end

# frozen_string_literal: true

module Search
  module Elastic
    module References
      module Sbom
        class OccurrenceRef < Reference
          include Search::Elastic::Concerns::DatabaseReference
          include Search::Elastic::Concerns::SchemaVersionedReference
          include ::Gitlab::Utils::StrongMemoize

          DOC_TYPE = 'sbom_occurrence_ref'
          INDEX_NAME = 'sbom_occurrence_refs'

          # Fields that need a migration to be finished. Use #set_field to conditionally set a field value
          # depending on if the migration has completed.
          FIELDS_WITH_MIGRATIONS = {}.freeze

          # Maps schema versions to their corresponding migration names.
          # Set migration to nil for baseline versions that don't require migration completion.
          # The schema_version method dynamically selects the highest version whose migration
          # has completed.
          SCHEMA_VERSIONS = {
            26_01 => nil
          }.freeze
          SCHEMA_VERSION = SCHEMA_VERSIONS.keys.max.freeze

          # Fields read directly from the sbom_occurrence_refs row.
          DIRECT_FIELDS = %w[
            project_id
            sbom_occurrence_id
            security_project_tracked_context_id
            pipeline_id
            commit_sha
          ].freeze

          # Fields read directly from the associated sbom_occurrences row.
          OCCURRENCE_FIELDS = %w[
            component_name
            component_id
            component_version_id
            source_id
            package_manager
            input_file_path
            vulnerability_count
            archived
            uuid
            created_at
            updated_at
          ].freeze

          # Enum fields indexed as their integer value via `#{field}_before_type_cast`.
          ENUM_TYPECAST_FIELDS = {
            'highest_severity' => :occurrence,
            'reachability' => :occurrence,
            'source_type' => :source,
            'purl_type' => :component,
            'component_type' => :component
          }.freeze

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
              ::Sbom::OccurrenceRef
            end
          end

          attr_reader :identifier, :routing

          def initialize(identifier, routing)
            @identifier = identifier.to_i
            @routing = routing
          end

          override :klass
          def klass
            'Sbom::OccurrenceRef'
          end

          override :serialize
          def serialize
            self.class.join_delimited([klass, identifier, routing].compact)
          end

          override :as_indexed_json
          def as_indexed_json
            internal_es_fields.tap do |fields|
              add_direct_fields(fields)
              add_occurrence_fields(fields)
              add_enum_typecast_fields(fields)
              add_fields_from_associations(fields)
            end
          end

          override :index_name
          def index_name
            self.class.index
          end

          private

          def occurrence
            database_record.occurrence
          end
          strong_memoize_attr :occurrence

          def component
            occurrence.component
          end
          strong_memoize_attr :component

          def component_version
            occurrence.component_version
          end
          strong_memoize_attr :component_version

          def source
            occurrence.source
          end
          strong_memoize_attr :source

          def add_direct_fields(fields)
            DIRECT_FIELDS.each do |name|
              set_field(fields, name) { database_record.read_attribute(name) }
            end
          end

          def add_occurrence_fields(fields)
            OCCURRENCE_FIELDS.each do |name|
              set_field(fields, name) { occurrence.read_attribute(name) }
            end
          end

          def add_enum_typecast_fields(fields)
            ENUM_TYPECAST_FIELDS.each do |name, target|
              set_field(fields, name) do
                __send__(target)&.public_send(:"#{name}_before_type_cast") # rubocop:disable GitlabSecurity/PublicSend -- target/field names are from a frozen constant
              end
            end
          end

          def add_fields_from_associations(fields)
            primary, secondary = occurrence_licenses

            fields.merge!({
              is_default: database_record.tracked_context.is_default,
              traversal_ids: database_record.project.namespace.elastic_namespace_ancestry,
              component_version: component_version&.version,
              primary_license_spdx_identifier: primary&.fetch(:spdx_identifier, nil),
              primary_license_name: primary&.fetch(:name, nil),
              secondary_license_spdx_identifier: secondary&.fetch(:spdx_identifier, nil),
              secondary_license_name: secondary&.fetch(:name, nil),
              source_package_name: component_version&.source_package_name,
              malware: occurrence.malware_status
            })
          end

          def occurrence_licenses
            Array(occurrence.licenses).first(2).map do |license|
              {
                spdx_identifier: license['spdx_identifier'],
                name: license['name']
              }
            end
          end
        end
      end
    end
  end
end

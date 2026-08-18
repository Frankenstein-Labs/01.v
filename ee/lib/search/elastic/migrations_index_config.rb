# frozen_string_literal: true

# Compatibility alias for old MigrationsIndexConfig location
# This maintains backwards compatibility while the refactoring is rolled out
# TODO: Remove this file after the elasticsearch_migrations_type_class feature flag is fully rolled out
module Search
  module Elastic
    class MigrationsIndexConfig
      class << self
        def alias_name
          if Feature.enabled?(:elasticsearch_migrations_type_class, :instance)
            Types::MigrationsIndexConfig.index_name
          else
            Search::Elastic::Helper.default.migrations_index_name
          end
        end

        def mappings
          if Feature.enabled?(:elasticsearch_migrations_type_class, :instance)
            Types::MigrationsIndexConfig.mappings
          else
            {
              properties: {
                completed: { type: 'boolean' },
                state: { type: 'object' },
                started_at: { type: 'date' },
                completed_at: { type: 'date' },
                name: { type: 'keyword' }
              }
            }
          end
        end

        def settings
          if Feature.enabled?(:elasticsearch_migrations_type_class, :instance)
            Types::MigrationsIndexConfig.settings
          else
            { number_of_shards: 1 }
          end
        end

        def ready?
          if Feature.enabled?(:elasticsearch_migrations_type_class, :instance)
            Types::MigrationsIndexConfig.ready?
          else
            ::Elastic::DataMigrationService.migration_has_finished?(:delete_legacy_migrations_index)
          end
        end
      end
    end
  end
end

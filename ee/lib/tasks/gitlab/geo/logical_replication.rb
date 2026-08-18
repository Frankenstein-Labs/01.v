# frozen_string_literal: true

module Tasks
  module Gitlab
    module Geo
      module LogicalReplication
        EXCLUDED_TABLES = %w[
          ar_internal_metadata
          detached_partitions
          schema_migrations
        ].freeze

        def publication_name
          ENV.fetch("GEO_PUBLICATION", "geo_publication")
        end

        def subscription_name
          ENV.fetch("GEO_SUBSCRIPTION", "geo_subscription")
        end

        def db_connection
          ApplicationRecord.connection
        end

        def excluded_tables
          EXCLUDED_TABLES
        end

        def publication_tables(publication)
          return [] if publication.empty?

          db_connection.execute(<<~SQL.squish).values.flatten
            SELECT c.relname
            FROM pg_publication p
            JOIN pg_publication_rel pr ON pr.prpubid = p.oid
            JOIN pg_class c ON c.oid = pr.prrelid
            WHERE p.pubname IN (#{db_connection.quote(publication)})
          SQL
        end

        def alter_publication(action, table)
          raise ArgumentError, "action must be ADD or DROP" unless %w[ADD DROP].include?(action)

          db_connection.execute(
            "ALTER PUBLICATION #{publication_name} #{action} TABLE #{db_connection.quote_table_name(table)}"
          )
        end
      end
    end
  end
end

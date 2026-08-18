# frozen_string_literal: true

namespace :gitlab do
  namespace :geo do
    namespace :logical_replication do
      namespace :publication do
        desc 'GitLab | Geo | Logical Replication | Create the publication on the Geo primary'
        task create: :gitlab_environment do
          extend Tasks::Gitlab::Geo::LogicalReplication

          abort "This is only available on the primary node" unless ::Gitlab::Geo.primary?

          db_connection.execute("CREATE PUBLICATION #{publication_name};")
        rescue ActiveRecord::StatementInvalid => si
          raise unless si.cause.is_a?(PG::DuplicateObject)

          puts "Publication already exists. Not doing anything"
        end

        desc 'GitLab | Geo | Logical Replication | Delete the publication on the Geo primary'
        task delete: :gitlab_environment do
          extend Tasks::Gitlab::Geo::LogicalReplication

          abort "This is only available on the primary node" unless ::Gitlab::Geo.primary?

          db_connection.execute("DROP PUBLICATION #{publication_name};")
        rescue ActiveRecord::StatementInvalid => si
          raise unless si.cause.is_a?(PG::UndefinedObject)

          puts "publication does not exist"
        end

        desc 'GitLab | Geo | Logical Replication | Add and remove tables on the Geo primary publication'
        task set_tables: :create do
          extend Tasks::Gitlab::Geo::LogicalReplication

          current_tables = publication_tables(publication_name)

          db_connection.tables.each do |table|
            if excluded_tables.include?(table)
              next unless current_tables.include?(table)

              puts "Removing #{table}"
              alter_publication("DROP", table)
            else
              next if current_tables.include?(table)

              puts "Adding #{table}"
              alter_publication("ADD", table)
            end
          end
        end
      end

      namespace :subscription do
        desc 'GitLab | Geo | Logical Replication | Subscription | Refresh the subscription on the Geo secondary'
        task refresh: :gitlab_environment do
          extend Tasks::Gitlab::Geo::LogicalReplication

          abort "This is only available on secondary nodes" unless ::Gitlab::Geo.secondary?
          db_connection.execute("ALTER SUBSCRIPTION #{subscription_name} REFRESH PUBLICATION")
        rescue ActiveRecord::StatementInvalid => si
          abort "Error refreshing the subscription: #{si}"
        end
      end
    end
  end
end

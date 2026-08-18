# frozen_string_literal: true

module Gitlab
  module Geo
    class LogicalReplication
      # This is a singleton class that allows to query the state of replication on a Geo secondary
      class << self
        include Gitlab::Utils::StrongMemoize

        def active?
          configured? && database_subscribed?
        end

        def configured?
          Gitlab::Geo.secondary? && Gitlab::Geo.postgresql_replication_agnostic_enabled?
        end

        def database_subscribed?
          # rubocop:disable Gitlab/StrongMemoizeAttr -- rescue must be outside the memoized block
          # so transient or fixable failures are retried rather than permanently memoized
          # Note that to enable LR users must Rails and Sidekiq, so it is safe to memoize this method
          # in this singleton class (once per process)
          strong_memoize(:database_subscribed) do
            # Check whether the current database has any logical replication subscriptions.
            # pg_subscription is readable by unprivileged users. Only subconninfo (the connection string)
            # is restricted, which we don't select here.
            query = <<~SQL
            SELECT EXISTS (
              SELECT 1 FROM pg_catalog.pg_subscription s
              JOIN pg_catalog.pg_database d ON d.oid = s.subdbid
              WHERE d.datname = current_database()
            )
            SQL
            ApplicationRecord.connection.select_value(query)
          end
        rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished,
          ActiveRecord::ConnectionFailed => e
          # not memoized as the failures can be recovered from without a Rails restart by addressing the database
          # configuration issues directly
          Gitlab::Geo::Logger.error(
            message: "database_subscribed? failed",
            error_class: e.class.name,
            error_message: e.message
          )
          false
        end
        # rubocop:enable Gitlab/StrongMemoizeAttr
      end
    end
  end
end

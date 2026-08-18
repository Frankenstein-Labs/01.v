# frozen_string_literal: true

module Gitlab
  module Usage
    module Metrics
      module Instrumentations
        # Counts AI audit events stored in ClickHouse. Instances using ClickHouse
        # analytics write events there instead of PostgreSQL, so this is the
        # GitLab.com-relevant counterpart to CountAiAuditEventsMetric (PostgreSQL).
        # Service Ping has no ClickHouse data source, so this runs inline during
        # generation; ClickHouse count() is cheap, so the statement-timeout concern
        # that motivates batched/deferred PostgreSQL counting does not apply.
        class CountAiAuditEventsClickhouseMetric < GenericMetric
          # Only instances using ClickHouse analytics write audit events to
          # ClickHouse, so skip this metric elsewhere. Without this gate the query
          # below would run during every Service Ping generation (and the SQL-dump
          # path) and fail/return the fallback on instances without ClickHouse.
          available? { ::Gitlab::ClickHouse.globally_enabled_for_analytics? }

          def value
            # Re-check the available? condition: Service Ping validation specs force
            # every metric available, bypassing the gate above.
            return self.class.fallback unless ::Gitlab::ClickHouse.globally_enabled_for_analytics?

            alt_usage_data(fallback: self.class.fallback) do
              ::ClickHouse::Client.select(
                "SELECT count() AS c FROM ai_audit_events#{time_constraint}", :main
              ).first&.fetch('c', 0).to_i
            end
          end

          private

          def time_constraint
            return '' if time_frame == 'all'
            return ' WHERE created_at >= now() - INTERVAL 28 DAY' if time_frame == '28d'

            raise ArgumentError, "Unsupported time_frame: #{time_frame}"
          end
        end
      end
    end
  end
end

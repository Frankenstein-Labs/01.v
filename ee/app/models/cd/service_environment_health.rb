# frozen_string_literal: true

module Cd
  class ServiceEnvironmentHealth < ApplicationRecord
    self.table_name = 'cd_service_environment_healths'

    belongs_to :service, class_name: 'Cd::Service', inverse_of: :service_environment_healths, optional: false
    belongs_to :environment, class_name: 'Cd::Environment', inverse_of: :service_environment_healths, optional: false
    belongs_to :organization, class_name: '::Organizations::Organization', optional: false

    populate_sharding_key :organization_id, source: :service

    validates :environment_id, uniqueness: { scope: :service_id }
    validates :observed_at, presence: true

    enum :health, {
      unknown: 0,
      healthy: 1,
      degraded: 2,
      failed: 3
    }

    # Worst-to-best severity order. Any degraded/failed signal takes
    # precedence over a healthy one, so problems are never hidden behind a
    # healthy result elsewhere.
    HEALTH_SEVERITY_ORDER = %w[failed degraded healthy unknown].freeze

    # Orders records from worst to best health, per HEALTH_SEVERITY_ORDER. A
    # health value not present in HEALTH_SEVERITY_ORDER (for example, if this
    # enum gains a new value in the future) sorts after all known values,
    # since array_position returns NULL for it and we order nulls last below.
    #
    # Uses a Gitlab::Pagination::Keyset::Order (rather than a plain `order`)
    # because this scope backs the serviceEnvironmentHealths GraphQL
    # connection, which uses keyset pagination; a raw computed expression
    # like array_position can't be paginated without describing it this way.
    # `id` is included as a tiebreaker so the order is fully deterministic.
    scope :ordered_by_severity, -> {
      severity_rank = Arel::Nodes::NamedFunction.new(
        'array_position', [Arel.sql(severity_array_sql), arel_table[:health]]
      )

      keyset_order = Gitlab::Pagination::Keyset::Order.build([
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'severity_rank',
          order_expression: severity_rank.asc,
          nullable: :nulls_last,
          add_to_projections: true
        ),
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'id',
          order_expression: arel_table[:id].asc,
          nullable: :not_nullable
        )
      ])

      reorder(keyset_order)
    }

    # Worst (most severe) health reported for each of the given applications,
    # rolled up across all of that application's services and keyed by
    # application id. Applications with no reported health are omitted, so the
    # caller can distinguish "no signal yet" (absent) from an observed
    # `unknown` signal (present, mapped to :unknown).
    #
    # `unknown` is ranked least severe (see HEALTH_SEVERITY_ORDER), so it never
    # overrides a real signal: an application rolls up to `unknown` only when
    # every one of its services is `unknown`, while any degraded/failed service
    # still wins over a healthy or unknown one.
    def self.worst_health_by_application(application_ids)
      severity_array = severity_array_sql
      worst_health = "(#{severity_array})[MIN(array_position(#{severity_array}, " \
        "cd_service_environment_healths.health))]"

      # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- bounded by caller's connection page size
      joins(:service)
        .where(cd_services: { application_id: application_ids })
        .group('cd_services.application_id')
        .pluck('cd_services.application_id', Arel.sql(worst_health))
        .to_h
        .transform_values { |value| healths.key(value) }
      # rubocop:enable Database/AvoidUsingPluckWithoutLimit
    end

    # Distinct applications with services in each environment, keyed by environment
    # id. Derived from the live per-service inventory (cd_service_environment_healths).
    def self.applications_count_by_environment(environment_ids)
      joins(:service)
        .where(environment_id: environment_ids)
        .group('cd_service_environment_healths.environment_id')
        .distinct
        .count('cd_services.application_id')
    end

    # Service health rows in the environment grouped by application, keyed by
    # application id and ordered by application name then service name. The
    # service, application, and organization are preloaded so grouping and
    # authorizing each row (ServicePolicy delegates to application, then
    # organization) add no queries.
    def self.service_environment_healths_by_application(environment)
      joins(service: :application)
        .where(environment_id: environment.id)
        .order('cd_applications.name ASC', 'cd_services.name ASC')
        .preload(service: { application: :organization })
        .group_by { |health| health.service.application_id }
    end

    # Services in each environment, keyed by environment id. The table is unique on
    # (service_id, environment_id), so a grouped count is already the distinct service
    # count -- no join or DISTINCT needed (unlike applications_count_by_environment).
    def self.services_count_by_environment(environment_ids)
      where(environment_id: environment_ids)
        .group(:environment_id)
        .count
    end

    def self.severity_array_sql
      "ARRAY[#{healths.values_at(*HEALTH_SEVERITY_ORDER).join(',')}]"
    end

    def self.application_ids_with_health(healths, organization:)
      joins(:service).where(health: healths, organization_id: organization).select('cd_services.application_id')
    end
  end
end

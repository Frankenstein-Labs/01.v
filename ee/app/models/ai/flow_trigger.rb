# frozen_string_literal: true

module Ai
  class FlowTrigger < ApplicationRecord
    include FromUnion
    include Gitlab::Utils::StrongMemoize

    self.table_name = :ai_flow_triggers

    # Values match FLOW_TRIGGER_TYPES in ee/app/assets/javascripts/ai/duo_agents_platform/constants.js:
    # https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/app/assets/javascripts/ai/duo_agents_platform/constants.js#L186
    EVENT_TYPES = {
      mention: 0,
      assign: 1,
      assign_reviewer: 2,
      pipeline_hooks: 3,
      merge_request_ready: 4,
      merge_request_code_conflict: 5,
      merge_request: 6,
      work_item: 7,
      commit_to_default_branch: 8
    }.freeze

    EVENT_TYPES_BY_ID = EVENT_TYPES.invert.freeze

    ALLOWED_FILTER_ACTIONS = {
      'merge_request' => %w[approved merged].freeze,
      'work_item' => %w[created status_changed].freeze
    }.freeze

    belongs_to :project, optional: false
    belongs_to :user
    belongs_to :ai_catalog_item_consumer, class_name: 'Ai::Catalog::ItemConsumer'

    has_one :parent_item_consumer, through: :ai_catalog_item_consumer

    scope :triggered_on, ->(event_type) { where("event_types @> ('{?}')", EVENT_TYPES[event_type]) }
    scope :by_service_accounts, ->(service_accounts) {
      service_accounts = service_accounts.compact if service_accounts.is_a?(Array)

      from_union(
        [
          unscoped.where(user_id: service_accounts),
          unscoped.joins(:parent_item_consumer).where(parent_item_consumer: { service_account_id: service_accounts })
        ]
      )
    }
    scope :by_item_consumer_ids, ->(item_ids) { where(ai_catalog_item_consumer_id: item_ids) }
    scope :for_projects, ->(project_ids) { where(project_id: project_ids) }

    def self.registered_for?(project_id, event_type)
      return false unless project_id

      for_projects(project_id).triggered_on(event_type).exists?
    end

    validates :user, presence: true, unless: :ai_catalog_item_consumer
    validates :user, absence: true, if: :ai_catalog_item_consumer

    validates :project, presence: true
    validates :event_types, presence: true

    validates :description, length: { maximum: 255 }, presence: true
    validates :config_path, length: { maximum: 255 }, presence: true, unless: -> { ai_catalog_item_consumer.present? }

    validates :filter,
      json_schema: { filename: 'filter', size_limit: 8.kilobytes }

    validates :ai_catalog_item_consumer, presence: true, unless: :config_path?

    validate :event_types_are_valid
    validate :filter_keys_match_event_types
    validate :filter_action_values_allowed
    validate :user_is_service_account, if: :user
    validates_with ExactlyOnePresentValidator, fields: [:config_path, :ai_catalog_item_consumer]
    validate :catalog_item_valid, if: -> { ai_catalog_item_consumer.present? }
    validate :supported_events_match_foundational_flow, if: -> { ai_catalog_item_consumer.present? }
    validate :consumer_must_have_active_service_account, if: :ai_catalog_item_consumer

    scope :with_ids, ->(ids) { where(id: ids) }

    scope :include_parent_item_consumer, -> {
      includes(:parent_item_consumer)
    }

    def self.event_type_from_id(id)
      EVENT_TYPES_BY_ID[id]
    end

    def service_account_id
      if for_ai_catalog_item_consumer?
        parent_item_consumer&.service_account_id
      else
        user_id
      end
    end

    def service_account
      if for_ai_catalog_item_consumer?
        ai_catalog_item_consumer.active_service_account
      else
        user
      end
    end

    def foundational_flow
      ai_catalog_item_consumer&.item&.foundational_flow
    end
    strong_memoize_attr :foundational_flow

    def foundational_flow_precondition
      foundational_flow&.precondition.presence
    end
    strong_memoize_attr :foundational_flow_precondition

    private

    def for_ai_catalog_item_consumer?
      ai_catalog_item_consumer_id.present? || ai_catalog_item_consumer.present?
    end

    def consumer_must_have_active_service_account
      return if ai_catalog_item_consumer.active_service_account.present?

      errors.add(:ai_catalog_item_consumer_id, "must have an active service account")
    end

    def event_types_are_valid
      return if event_types.blank?

      invalid_types = event_types - EVENT_TYPES.values
      return if invalid_types.empty?

      errors.add(:event_types, "contains invalid event types: #{invalid_types.join(', ')}")
    end

    # Checks filter top-level keys against event_types; nested rule shape and the object type are covered by the JSON
    # schema validator, so non-hash values fall through to that error rather than getting a duplicate one here.
    def filter_keys_match_event_types
      return if filter.blank?
      return unless filter.is_a?(Hash)

      active_event_keys = (event_types || []).filter_map { |id| EVENT_TYPES_BY_ID[id]&.to_s }
      unsupported_filter_keys = filter.keys - active_event_keys

      return if unsupported_filter_keys.empty?

      errors.add(:filter, "contains filters for event types not in event_types: #{unsupported_filter_keys.join(', ')}")
    end

    def filter_action_values_allowed
      return unless Feature.enabled?(:validate_flow_trigger_filter_actions, project)
      return if filter.blank?
      return unless filter.is_a?(Hash)

      filter.each do |event_type_key, group|
        allowed = ALLOWED_FILTER_ACTIONS[event_type_key]
        next unless allowed

        invalid_values = collect_action_values(group) - allowed
        next if invalid_values.empty?

        errors.add(:filter,
          "contains invalid action values for #{event_type_key}: #{invalid_values.join(', ')}. " \
            "Allowed values are: #{allowed.join(', ')}")
      end
    end

    def collect_action_values(group, depth = 1)
      return [] unless group.is_a?(Hash)
      return [] if depth > Gitlab::FilterEvaluator::MAX_DEPTH

      Array(group['rules']).flat_map do |rule|
        next [] unless rule.is_a?(Hash)

        if rule['type'] == 'group'
          collect_action_values(rule, depth + 1)
        elsif rule['field'] == 'action'
          rule['value'].nil? ? [nil] : Array(rule['value'])
        else
          []
        end
      end
    end

    def user_is_service_account
      return if user.service_account?

      errors.add(:user, 'user must be a service account')
    end

    def catalog_item_valid
      if ai_catalog_item_consumer.project != project
        errors.add(:base, 'ai_catalog_item_consumer project does not match project')
      end

      return if ai_catalog_item_consumer.item.flow? || ai_catalog_item_consumer.item.third_party_flow?

      errors.add(:base, 'ai_catalog_item_consumer is not a flow')
    end

    def supported_events_match_foundational_flow
      supported = foundational_flow&.supported_events
      # A nil value means the flow has no event restrictions (any event is allowed). An empty array means the
      # flow explicitly supports no trigger events.
      return unless supported

      unsupported_event_types = event_types - supported
      if unsupported_event_types.any?
        errors.add(:event_types, "contains event types not supported by this foundational flow")
        return
      end

      return unless filter.is_a?(Hash)

      supported_keys = supported.map { |e| EVENT_TYPES.key(e).to_s }
      unsupported_filter_keys = filter.keys - supported_keys

      return unless unsupported_filter_keys.any?

      errors.add(:filter, "contains filters for unsupported event types: #{unsupported_filter_keys.join(', ')}")
    end
  end
end

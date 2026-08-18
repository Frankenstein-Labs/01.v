# frozen_string_literal: true

module Cd
  class RolloutEnvironment < ApplicationRecord
    self.table_name = 'cd_rollout_environments'

    # degraded is a finished deploy whose service is unhealthy; health is tracked
    # separately, so it counts as completed here.
    COMPLETED_DEPLOYMENT_STATES = %w[healthy degraded].freeze

    TERMINAL_STATES = %w[completed failed cancelled].freeze

    belongs_to :rollout, class_name: 'Cd::Rollout', inverse_of: :rollout_environments, optional: false
    belongs_to :environment, class_name: 'Cd::Environment', inverse_of: :rollout_environments, optional: false
    belongs_to :driver_binding, class_name: 'Cd::EnvironmentDriverBinding', inverse_of: :rollout_environments,
      optional: false
    belongs_to :previous_version_set, class_name: 'Cd::VersionSet', inverse_of: :rollout_environments, optional: true
    belongs_to :organization, class_name: '::Organizations::Organization', optional: false
    has_many :deployments, class_name: 'Cd::Deployment', inverse_of: :rollout_environment
    has_many :rollout_steps, class_name: 'Cd::RolloutStep', inverse_of: :rollout_environment

    populate_sharding_key :organization_id, source: :rollout

    scope :ordered, -> { order(position: :asc) }
    scope :preload_environment_and_driver_binding, -> { preload(:environment, :driver_binding) }
    scope :with_environment_name, ->(name) { joins(:environment).where(cd_environments: { name: name }) }

    validates :position, presence: true
    validates :environment_id, uniqueness: { scope: :rollout_id,
                                             message: ->(*) { _('already has a rollout environment in this rollout') } }

    enum :state, {
      pending: 0,
      in_progress: 1,
      paused: 2,
      completed: 3,
      failed: 4,
      cancelled: 5
    }

    # Batched form of GraphQL environment resolution: maps each of the given
    # rollout_environment ids to its environment_id, without loading full rows.
    def self.environment_ids_by_id(ids)
      # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- bounded by the GraphQL batch calling this
      id_in(ids).pluck(:id, :environment_id).to_h
      # rubocop:enable Database/AvoidUsingPluckWithoutLimit
    end

    def self.state_from_deployment_states(deployment_states)
      return :pending if deployment_states.empty?
      return :failed if deployment_states.include?('failed')
      return :cancelled if deployment_states.include?('cancelled')
      return :completed if deployment_states.all? { |s| COMPLETED_DEPLOYMENT_STATES.include?(s) }
      return :pending if deployment_states.all?('pending')

      :in_progress
    end

    def sync_state_from_deployments!
      return if paused?

      new_state = self.class.state_from_deployment_states(deployments.reset.map(&:state))
      update!(state: new_state) unless state == new_state.to_s
    end
  end
end

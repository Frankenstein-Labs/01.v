# frozen_string_literal: true

module Cd
  class Environment < ApplicationRecord
    include Gitlab::SQL::Pattern

    self.table_name = 'cd_environments'

    ignore_column :cluster_agent_id, remove_with: '19.3', remove_after: '2026-08-15'
    ignore_column :platform_type, remove_with: '19.3', remove_after: '2026-08-15'
    ignore_column :region, remove_with: '19.3', remove_after: '2026-08-15'

    belongs_to :organization, class_name: '::Organizations::Organization', optional: false
    has_many :environment_driver_bindings, class_name: 'Cd::EnvironmentDriverBinding', inverse_of: :environment
    has_many :rollout_environments, class_name: 'Cd::RolloutEnvironment', inverse_of: :environment
    has_many :service_environment_healths, class_name: 'Cd::ServiceEnvironmentHealth', inverse_of: :environment

    validates :name, presence: true, length: { maximum: 255 }, uniqueness: { scope: :organization_id },
      format: { with: Gitlab::Regex.cd_name_regex, message: Gitlab::Regex.cd_name_regex_message }
    validates :description, length: { maximum: 1024 }
    validates :tier, presence: true

    enum :tier, { development: 0, qa: 1, staging: 2, production: 3 }

    scope :for_organization, ->(organization_id) { where(organization_id: organization_id) }
    scope :in_organization, ->(organization) { where(organization_id: organization) }
    scope :with_tier, ->(tier) { where(tier: tier) }
    scope :with_name, ->(name) { where(name: name) }
    scope :order_by_name_asc, -> { order(name: :asc) }
    scope :preload_environment_driver_bindings, -> { preload(:environment_driver_bindings) }
    scope :search, ->(query) { fuzzy_search(query, [:name, :description]) }
  end
end

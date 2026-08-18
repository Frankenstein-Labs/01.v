# frozen_string_literal: true

module Ai
  class ToolRule < ApplicationRecord
    self.table_name = 'ai_tool_rules'

    WEB_SURFACES = %w[web ambient].freeze

    belongs_to :namespace
    belongs_to :project, optional: true

    ACCESS_LEVELS = {
      ::Ai::ToolRules::Permissions::ALLOW => 0,
      ::Ai::ToolRules::Permissions::ASK => 1,
      ::Ai::ToolRules::Permissions::DENY => 2
    }.freeze

    BACKGROUND_ACCESS_LEVELS = ACCESS_LEVELS.except(::Ai::ToolRules::Permissions::ASK).freeze

    enum :web_access, ACCESS_LEVELS, prefix: true
    enum :local_access, ACCESS_LEVELS, prefix: true
    enum :background_access, BACKGROUND_ACCESS_LEVELS, prefix: true

    validates :tool_name,
      presence: true,
      inclusion: {
        in: ->(_) { Ai::ToolRules::Registry.all_tool_names },
        message: "%{value} is not a known tool name"
      },
      uniqueness: { scope: [:namespace_id, :project_id] }

    validates :tool_arguments, json_schema: { filename: 'ai_tool_rule_tool_arguments', size_limit: 64.kilobytes },
      allow_nil: true
    validates :namespace, presence: true

    validate :validate_access_permissions_present
    validate :project_belongs_to_namespace, if: -> { project_id.present? }
    validate :project_rule_not_looser_than_namespace, if: -> { project_id.present? }

    before_validation :set_tool_source

    scope :for_namespace, ->(namespace_id) { where(namespace_id: namespace_id, project_id: nil) }
    scope :for_project, ->(project_id) { where(project_id: project_id) }
    scope :for_tool_names, ->(tool_names) { where(tool_name: tool_names) }

    def self.find_or_initialize_for_namespace(namespace_id:, tool_name:, project_id: nil)
      find_or_initialize_by(namespace_id: namespace_id, tool_name: tool_name, project_id: project_id)
    end

    def access_for(surface)
      return background_access if surface.to_s == ::Ai::ToolRules::GovernanceSurface::BACKGROUND.to_s

      WEB_SURFACES.include?(surface.to_s) ? web_access : local_access
    end

    private

    def validate_access_permissions_present
      return if web_access.present? || local_access.present? || background_access.present?

      errors.add(:base, 'must have at least one of web_access, local_access, or background_access set')
    end

    def set_tool_source
      self.tool_source ||= Ai::ToolRules::Registry.source_for(tool_name) if tool_name.present?
    end

    def project_belongs_to_namespace
      return unless project && namespace

      return if project.root_namespace.id == namespace.id

      errors.add(:project, 'must belong to the namespace')
    end

    def project_rule_not_looser_than_namespace
      return unless project && namespace

      namespace_rule = ::Ai::ToolRule.for_namespace(namespace_id).find_by(tool_name: tool_name)
      return unless namespace_rule

      validate_web_access_strictness(namespace_rule)
      validate_local_access_strictness(namespace_rule)
      validate_background_access_strictness(namespace_rule)
    end

    def validate_web_access_strictness(namespace_rule)
      return unless web_access && namespace_rule.web_access
      return unless self.class.web_accesses[web_access] < self.class.web_accesses[namespace_rule.web_access]

      errors.add(:web_access, "cannot be less restrictive than the namespace rule (#{namespace_rule.web_access})")
    end

    def validate_local_access_strictness(namespace_rule)
      return unless local_access && namespace_rule.local_access
      return unless self.class.local_accesses[local_access] < self.class.local_accesses[namespace_rule.local_access]

      errors.add(:local_access, "cannot be less restrictive than the namespace rule (#{namespace_rule.local_access})")
    end

    def validate_background_access_strictness(namespace_rule)
      return unless background_access && namespace_rule.background_access

      levels = self.class.background_accesses
      return unless levels[background_access] < levels[namespace_rule.background_access]

      errors.add(:background_access,
        "cannot be less restrictive than the namespace rule (#{namespace_rule.background_access})")
    end
  end
end

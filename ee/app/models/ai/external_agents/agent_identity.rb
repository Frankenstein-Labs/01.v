# frozen_string_literal: true

module Ai
  module ExternalAgents
    class AgentIdentity < ApplicationRecord
      AGENT_TYPES = %w[claude-code opencode].freeze

      self.table_name = 'ai_agent_identities'

      belongs_to :user
      belongs_to :project

      validates :agent_type, presence: true, inclusion: { in: AGENT_TYPES }
      validates :machine_fingerprint, presence: true,
        format: { with: /\A\h{64}\z/, message: 'must be a 64-character hex string' }

      scope :active, -> { where(revoked_at: nil) }
      scope :revoked, -> { where.not(revoked_at: nil) }
      scope :for_project, ->(project) { where(project: project) }
      scope :for_user, ->(user) { where(user: user) }

      def self.register(user:, project:, agent_type:, machine_fingerprint:)
        safe_find_or_create_by!( # rubocop:disable Performance/ActiveRecordSubtransactionMethods -- identity registration is low-traffic and write-once per machine per project
          user: user,
          project: project,
          agent_type: agent_type,
          machine_fingerprint: machine_fingerprint
        )
      end

      def self.owned_by?(id:, user:, project:, agent_type:)
        active.where(id: id, user: user, project: project, agent_type: agent_type).exists?
      end

      def revoked?
        revoked_at.present?
      end

      def revoke!
        update!(revoked_at: Time.current)
      end
    end
  end
end

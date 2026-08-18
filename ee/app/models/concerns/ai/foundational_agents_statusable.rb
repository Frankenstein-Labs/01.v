# frozen_string_literal: true

module Ai
  module FoundationalAgentsStatusable
    extend ActiveSupport::Concern

    included do
      def foundational_agents_statuses=(values)
        return unless values

        self.class.transaction do
          foundational_agents_status_records.delete_all(:delete_all)

          values.each do |status|
            record = foundational_agents_status_records.build(status)

            errors.add(:foundational_agents_statuses, record.errors.full_messages.join(', ')) unless record.save
          end

          raise ActiveRecord::Rollback if errors.any?
        end
      end

      def foundational_agents_statuses
        statuses = foundational_agents_status_records.index_by(&:reference)

        ::Ai::FoundationalChatAgent.except_duo_chat_agent.map do |agent|
          status_record = statuses[agent.reference]

          {
            reference: agent.reference,
            name: agent.name,
            description: agent.description,
            enabled: status_record&.enabled
          }
        end
      end

      def enabled_foundational_agents
        statuses = foundational_agents_status_records.index_by(&:reference)

        ::Ai::FoundationalChatAgent.all.select do |agent|
          agent_enabled?(agent, statuses)
        end
      end

      def foundational_agent_enabled?(reference)
        return true if reference == 'chat'

        record = foundational_agents_status_records.find_by(reference: reference)

        return foundational_agents_default_enabled unless record

        record.enabled
      end

      private

      def agent_enabled?(agent, statuses)
        # Duo Chat is always enabled
        return true if agent.duo_chat?

        # If there's an explicit status record, use it
        return statuses[agent.reference].enabled if statuses.key?(agent.reference)

        # Otherwise, use the default setting
        foundational_agents_default_enabled
      end
    end
  end
end

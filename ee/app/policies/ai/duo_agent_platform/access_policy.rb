# frozen_string_literal: true

module Ai
  module DuoAgentPlatform
    module AccessPolicy
      extend ActiveSupport::Concern

      included do
        condition(:duo_agent_platform_enabled, scope: :subject) do
          ::Ai::DuoWorkflow.duo_agent_platform_available?(@subject)
        end

        condition(:duo_workflow_available) do
          next false unless user_is_user?

          @subject.duo_features_enabled &&
            ::Gitlab::Llm::StageCheck.available?(@subject, :duo_workflow) &&
            @user.allowed_to_use?(:duo_agent_platform, root_namespace: @subject.root_ancestor)
        end
      end
    end
  end
end

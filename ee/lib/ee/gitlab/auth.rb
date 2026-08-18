# frozen_string_literal: true

module EE
  module Gitlab
    module Auth
      private

      def unavailable_ai_features_scopes
        scopes = super
        scopes += ::Gitlab::Auth::AI_FEATURES_SCOPES unless ::Gitlab::CurrentSettings.duo_features_enabled
        scopes
      end
    end
  end
end

# frozen_string_literal: true

module EE
  module Projects
    module TreeController
      extend ActiveSupport::Concern

      prepended do
        before_action do
          push_licensed_feature(:remote_development)
          push_licensed_feature(:orbit, @project)
          push_frontend_feature_flag(:orbit_code_intelligence, current_user)
          push_frontend_feature_flag(:repository_lock_information, @project)
        end
      end
    end
  end
end

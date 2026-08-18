# frozen_string_literal: true

module EE
  module API
    module Invitations
      extend ActiveSupport::Concern

      prepended do
        helpers do
          params :invitation_params_ee do
            optional :member_role_id, type: Integer, desc: 'The ID of a member role for the invited user'
          end
        end
      end
    end
  end
end

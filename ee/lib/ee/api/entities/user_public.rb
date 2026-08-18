# frozen_string_literal: true

module EE
  module API
    module Entities
      module UserPublic
        extend ActiveSupport::Concern

        prepended do
          expose :shared_runners_minutes_limit
          expose :extra_shared_runners_minutes_limit
          expose :scim_identities, using: ::API::Entities::ScimIdentity

          private

          def scim_identities
            object.instance_scim_identities + object.group_scim_identities
          end
        end
      end
    end
  end
end

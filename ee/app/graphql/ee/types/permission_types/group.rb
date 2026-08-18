# frozen_string_literal: true

# rubocop:disable Gitlab/BoundedContexts -- the PermissionTypes::Group already exists in CE, this is just the EE extension
module EE
  module Types
    module PermissionTypes
      module Group
        extend ActiveSupport::Concern

        prepended do
          abilities :generate_description, :admin_work_item_lifecycle, :admin_ai_catalog_item_consumer

          ability_field :read_runner_cloud_provisioning_info,
            experiment: { milestone: '18.8' }
        end
      end
    end
  end
end
# rubocop:enable Gitlab/BoundedContexts

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::PermissionTypes::Project, feature_category: :groups_and_projects do
  specify do
    expected_permissions = %i[
      create_path_lock
      read_path_locks
      admin_path_locks
      generate_description
      admin_work_item_lifecycle
      manage_ai_flow_triggers
      read_ai_catalog_item
      read_ai_catalog_item_consumer
      admin_ai_catalog_item
      admin_ai_catalog_item_consumer
      create_ai_catalog_item_consumer
      read_runner_cloud_provisioning_info
      read_project_component_usages
    ]

    expected_permissions.each do |permission|
      expect(described_class).to have_graphql_field(permission)
    end
  end
end

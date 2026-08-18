# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::PermissionTypes::Cd::Application, feature_category: :continuous_delivery do
  specify do
    expected_permissions = %i[
      read_cd_application
      update_cd_application
      create_cd_service
      update_cd_service
      create_cd_version_set
      create_cd_rollout
      resolve_cd_rollout_gate
      create_cd_application_flow_definition
      create_cd_application_link
    ]

    expected_permissions.each do |permission|
      expect(described_class).to have_graphql_field(permission)
    end
  end
end

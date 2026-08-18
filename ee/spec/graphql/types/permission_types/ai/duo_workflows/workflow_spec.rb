# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::PermissionTypes::Ai::DuoWorkflows::Workflow, feature_category: :duo_agent_platform do
  specify do
    expected_permissions = %i[
      read_duo_workflow
      update_duo_workflow
      delete_duo_workflow
      resume_duo_workflow
    ]

    expected_permissions.each do |permission|
      expect(described_class).to have_graphql_field(permission)
    end
  end
end

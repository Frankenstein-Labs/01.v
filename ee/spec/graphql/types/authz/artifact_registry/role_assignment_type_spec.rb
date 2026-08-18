# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Authz::ArtifactRegistry::RoleAssignmentType, feature_category: :system_access do
  specify { expect(described_class.graphql_name).to eq('ArtifactRegistryRoleAssignment') }

  it 'exposes the expected fields' do
    expect(described_class).to have_graphql_fields(:resource_id, :role, :assignee, :created_at)
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::PermissionTypes::WorkItem, feature_category: :portfolio_management do
  it 'includes the ee specific permissions' do
    expected_permissions = %i[blocked_work_items]

    expect(described_class).to include_graphql_fields(*expected_permissions)
  end
end

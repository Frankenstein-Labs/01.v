# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CustomizableStandardPermission'], feature_category: :permissions do
  include GraphqlHelpers

  let(:permissions) do
    {
      read_code: { description: 'permission definition 1' },
      read_admin_users: { description: 'admin permission definition' }
    }
  end

  it { expect(described_class.graphql_name).to eq('CustomizableStandardPermission') }

  it 'has the expected fields' do
    expected_fields = %i[
      available_for
      description
      name
      requirements
      value
      enabled_for_group_access_levels
      enabled_for_project_access_levels
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  it 'returns correct description for a permission' do
    allow(MemberRole).to receive(:all_customizable_standard_permissions).and_return(permissions)

    expect(
      resolve_field(:description, :read_code)
    ).to eq('permission definition 1')
  end
end

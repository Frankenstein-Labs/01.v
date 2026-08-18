# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.member_role_permissions', feature_category: :permissions do
  include GraphqlHelpers

  let(:fields) do
    <<~QUERY
      nodes {
        availableFor
        description
        name
        requirements
        value
        enabledForGroupAccessLevels
        enabledForProjectAccessLevels
      }
    QUERY
  end

  let(:mock_standard_permissions) do
    {
      admin_ability_one: {
        title: 'Admin something',
        description: 'Allows admin access to do something.',
        project_ability: true,
        enabled_for_project_access_levels: [50],
        milestone: '17.0'
      },
      admin_ability_two: {
        title: 'Admin something else',
        description: 'Allows admin access to do something else.',
        requirements: [:read_ability_two],
        group_ability: true,
        enabled_for_group_access_levels: [40, 50],
        milestone: '17.0'
      },
      read_ability_two: {
        title: 'Read something else',
        description: 'Allows read access to do something else.',
        group_ability: true,
        project_ability: true,
        enabled_for_group_access_levels: [20, 30, 40, 50],
        enabled_for_project_access_levels: [20, 30, 40, 50],
        milestone: '17.0'
      }
    }
  end

  let(:mock_admin_permissions) do
    {
      admin_permission: {
        title: 'Admin permission',
        description: 'Allows admin area access to something.',
        milestone: '17.0'
      }
    }
  end

  let(:query_for) { 'memberRolePermissions' }

  let(:query) do
    graphql_query_for(query_for, fields)
  end

  let(:enum_types) do
    [
      Types::Members::CustomizableStandardPermissionsEnum,
      Types::Members::CustomizableAdminPermissionsEnum
    ]
  end

  def redefine_enum!
    # We need to override the enum values, because they are defined at boot time
    # and stubbing the permissions won't have an effect.
    enum_types.each do |enum|
      enum.class_eval do
        def self.enum_values(_)
          MemberRole.all_customizable_permissions.map do |key, _|
            enum_value_class.new(key.upcase, value: key, owner: self)
          end
        end
      end
    end
  end

  def reset_enum!
    # Remove the override
    enum_types.each do |enum|
      enum.singleton_class.remove_method(:enum_values)
    end
  end

  before do
    allow(MemberRole).to receive_messages(
      all_customizable_permissions: mock_standard_permissions.merge(mock_admin_permissions),
      all_customizable_standard_permissions: mock_standard_permissions,
      all_customizable_admin_permissions: mock_admin_permissions,
      all_customizable_admin_permission_keys: mock_admin_permissions.keys
    )

    redefine_enum!

    post_graphql(query)
  end

  after do
    reset_enum!
  end

  it_behaves_like 'a working graphql query'

  context 'for memberRolePermissions query' do
    subject(:permissions_nodes) { graphql_data.dig('memberRolePermissions', 'nodes') }

    it 'returns all standard customizable abilities' do
      expected_result = [
        {
          'availableFor' => ['project'],
          'description' => 'Allows admin access to do something.',
          'name' => 'Admin something',
          'requirements' => nil,
          'value' => 'ADMIN_ABILITY_ONE',
          'enabledForGroupAccessLevels' => nil,
          'enabledForProjectAccessLevels' => ['OWNER']
        },
        {
          'availableFor' => %w[project group],
          'description' => 'Allows read access to do something else.',
          'name' => 'Read something else',
          'requirements' => nil,
          'value' => 'READ_ABILITY_TWO',
          'enabledForGroupAccessLevels' => %w[REPORTER DEVELOPER MAINTAINER OWNER],
          'enabledForProjectAccessLevels' => %w[REPORTER DEVELOPER MAINTAINER OWNER]
        },
        {
          'availableFor' => ['group'],
          'description' => 'Allows admin access to do something else.',
          'requirements' => ['READ_ABILITY_TWO'],
          'name' => 'Admin something else',
          'value' => 'ADMIN_ABILITY_TWO',
          'enabledForGroupAccessLevels' => %w[MAINTAINER OWNER],
          'enabledForProjectAccessLevels' => nil
        }
      ]

      expect(permissions_nodes).to match_array(expected_result)
    end
  end

  context 'for adminMemberRolePermissions query' do
    subject(:admin_permissions_nodes) { graphql_data.dig('adminMemberRolePermissions', 'nodes') }

    let(:query_for) { 'adminMemberRolePermissions' }
    let(:fields) do
      <<~QUERY
        nodes {
          description
          name
          requirements
          value
        }
      QUERY
    end

    it 'returns all admin customizable abilities' do
      expected_result = [
        {
          'description' => 'Allows admin area access to something.',
          'name' => 'Admin permission',
          'requirements' => nil,
          'value' => 'ADMIN_PERMISSION'
        }
      ]

      expect(admin_permissions_nodes).to match_array(expected_result)
    end
  end
end

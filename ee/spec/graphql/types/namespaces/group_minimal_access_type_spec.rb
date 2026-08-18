# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Namespaces::GroupMinimalAccessType, feature_category: :groups_and_projects do
  include GraphqlHelpers

  let(:type) { described_class }

  it 'has the correct name' do
    expect(type.graphql_name).to eq('GroupMinimalAccess')
  end

  specify { expect(type).to require_graphql_authorizations(:read_group_metadata) }

  it 'implements the Types::Namespaces::GroupInterface' do
    expect(type.interfaces).to include(Types::Namespaces::GroupInterface)
  end

  describe 'fields', :enable_admin_mode, feature_category: :permissions do
    let_it_be(:role) { create(:admin_member_role, :read_admin_cicd) }
    let_it_be(:current_user) { role.user }
    let_it_be(:group) { create(:group, :private, :with_avatar) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    it 'only the defined fields resolve to non-nil values', :aggregate_failures do
      defined_fields = %w[avatar_url full_name full_path id name user_permissions web_url]

      expect(described_class.own_fields.keys.map(&:underscore)).to match_array(defined_fields)

      defined_fields.each do |field|
        field_value = resolve_field(field, group, current_user: current_user)
        expect(field_value).not_to be_nil
      end
    end

    describe 'inherited fields' do
      where(:field) do
        (described_class.fields.keys - described_class.own_fields.keys).map(&:underscore)
      end

      with_them do
        it 'resolves to nil' do
          expect(resolve_field(field, group, current_user: current_user)).to be_nil
        end
      end
    end
  end
end

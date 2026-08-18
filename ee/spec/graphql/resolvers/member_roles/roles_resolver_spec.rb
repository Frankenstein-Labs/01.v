# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::MemberRoles::RolesResolver, feature_category: :api do
  include GraphqlHelpers

  describe '#resolve' do
    subject(:result) do
      resolve(described_class, ctx: { current_user: user }, obj: group, args: args, lookahead: positive_lookahead,
        arg_style: :internal)
    end

    let_it_be(:group) { create(:group) }

    let_it_be(:user) { create(:user) }

    let_it_be(:admin_runners_role) do
      create(:member_role, :admin_runners, name: 'Role C', namespace: nil, organization: user.organization)
    end

    let_it_be(:read_code_role) do
      create(:member_role, :read_code, name: 'Role A', namespace: nil, organization: user.organization)
    end

    let_it_be(:read_runners_role) do
      create(:member_role, :read_runners, name: 'Role B', namespace: nil, organization: user.organization)
    end

    before_all do
      group.add_developer(user)
    end

    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'without any args' do
      let(:args) { nil }

      it 'returns all custom roles' do
        expect(result).to contain_exactly(read_code_role, read_runners_role, admin_runners_role)
      end
    end

    context 'with specified order' do
      let(:args) { { order_by: :name, sort: :desc } }

      it 'returns all custom roles' do
        expect(result).to match([admin_runners_role, read_runners_role, read_code_role])
      end
    end

    context 'with id as arg' do
      let(:args) { { id: read_runners_role.id } }

      it 'returns all custom roles' do
        expect(result).to contain_exactly(read_runners_role)
      end
    end

    context 'with ids as arg' do
      let(:args) { { ids: [read_runners_role.id, admin_runners_role.id] } }

      it 'returns all custom roles' do
        expect(result).to contain_exactly(read_runners_role, admin_runners_role)
      end
    end

    context 'with assignable arg' do
      let(:args) { { assignable: true } }

      it 'returns all assignable custom roles' do
        expect(result).to contain_exactly(read_code_role)
      end
    end
  end
end

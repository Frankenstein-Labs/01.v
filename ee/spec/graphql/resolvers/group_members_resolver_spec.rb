# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Resolvers::GroupMembersResolver', feature_category: :groups_and_projects do
  include GraphqlHelpers

  let(:described_class) { Resolvers::GroupMembersResolver }

  specify do
    expect(described_class).to have_nullable_graphql_type(Types::GroupMemberType.connection_type)
  end

  shared_examples 'all users' do
    it 'returns all users' do
      expect(group_members).to contain_exactly(resource_member, enterprise_user_member)
    end
  end

  it_behaves_like 'querying members with a group' do
    let_it_be(:resource_member) { create(:group_member, user: user_1, group: group_1) }
    let_it_be(:resource) { group_1 }
  end

  context 'when filtering by enterprise users' do
    let_it_be(:group) { create(:group, :private, :nested) }
    let_it_be(:user) { create(:user, name: 'test user') }
    let_it_be(:resource_member) { create(:group_member, user: user, group: group) }

    let_it_be(:enterprise_user) { create(:enterprise_user, enterprise_group: group) }
    let_it_be(:enterprise_user_member) { group.add_developer(enterprise_user) }

    subject(:group_members) do
      resolve(described_class, obj: group, args: args, ctx: { current_user: user }, arg_style: :internal)
    end

    context 'when domain verification is available' do
      before do
        allow(group).to receive(:domain_verification_available?).and_return(true)
      end

      context 'with enterprise filter set as true' do
        let(:args) { { relations: described_class.arguments['relations'].default_value, enterprise: true } }

        it 'returns only enterprise users members' do
          expect(group_members).to contain_exactly(enterprise_user_member)
        end
      end

      context 'with enterprise filter set as false' do
        let(:args) { { relations: described_class.arguments['relations'].default_value, enterprise: false } }

        it 'returns only non-enterprise users' do
          expect(group_members).to contain_exactly(resource_member)
        end
      end

      context 'without enterprise filter' do
        let(:args) { { relations: described_class.arguments['relations'].default_value } }

        it_behaves_like 'all users'
      end
    end

    context 'when domain verification is not available' do
      context 'with enterprise filter set as true' do
        let(:args) { { relations: described_class.arguments['relations'].default_value, enterprise: true } }

        it_behaves_like 'all users'
      end

      context 'with enterprise filter set as false' do
        let(:args) { { relations: described_class.arguments['relations'].default_value, enterprise: false } }

        it_behaves_like 'all users'
      end

      context 'without enterprise filter' do
        let(:args) { { relations: described_class.arguments['relations'].default_value } }

        it_behaves_like 'all users'
      end
    end
  end
end

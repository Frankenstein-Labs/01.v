# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::WebHooks::GroupHooksResolver, feature_category: :webhooks do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:group_hooks) { create_list(:group_hook, 3, group: group) }
  let_it_be(:subgroup_hook) { create(:group_hook, group: subgroup) }
  let(:current_user) { user }

  specify do
    expect(described_class).to have_nullable_graphql_type(Types::WebHooks::GroupHookType.connection_type)
  end

  describe '#resolve' do
    context 'when the user is authorized' do
      before_all do
        group.add_owner(user)
      end

      context 'when resolving a single group hook' do
        it 'returns the group hook with the given id' do
          expected_group_hook = group_hooks.first
          args = { id: global_id_of(expected_group_hook) }

          expect(resolve_single_group_hook(args)).to eq(expected_group_hook)
        end

        it 'does not return group hook belonging other groups' do
          args = { id: global_id_of(subgroup_hook) }

          expect(resolve_single_group_hook(args)).to be_nil
        end
      end

      context 'when resolving multiple group hooks' do
        it 'returns all group hooks on the group' do
          expect(resolve_group_hooks).to match_array(group_hooks)
        end
      end
    end

    context 'when user is not authorized' do
      before_all do
        group.add_maintainer(user)
      end

      it { expect(resolve_group_hooks).to be_nil }
      it { expect(resolve_single_group_hook(id: global_id_of(group_hooks.first))).to be_nil }
    end
  end

  def resolve_group_hooks
    resolve(described_class, obj: group, ctx: { current_user: current_user })
  end

  def resolve_single_group_hook(args = {})
    resolve(described_class.single, obj: group, args: args, ctx: { current_user: current_user })
  end
end

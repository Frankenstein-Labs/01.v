# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::SecurityPolicyProjectLinkedGroupsResolver, feature_category: :security_policy_management do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:user) { create(:user) }
    let_it_be(:top_level_group) { create(:group, name: 'top-level-group') }
    let_it_be(:group) { create(:group, name: 'group', parent: top_level_group) }
    let_it_be(:group2) { create(:group, name: 'group2') }
    let_it_be(:security_project) do
      create(:project, security_policy_project_linked_groups: [top_level_group, group, group2])
    end

    let(:params) { {} }

    subject { resolve(described_class, args: params, ctx: { current_user: user }, obj: security_project) }

    context 'when feature is not licensed' do
      it { is_expected.to be_empty }
    end

    context 'when feature is licensed' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it 'includes all groups' do
        is_expected.to contain_exactly(top_level_group, group, group2)
      end

      context 'with `ids` argument' do
        let(:params) { { ids: [group.to_global_id.to_s, group2.to_global_id.to_s] } }

        it 'filters groups by gid' do
          is_expected.to contain_exactly(group, group2)
        end
      end

      context 'with `search` argument' do
        let(:params) { { search: 'group2' } }

        it 'filters groups by full path' do
          is_expected.to contain_exactly(group2)
        end
      end

      context 'with `top_level_only` argument' do
        context 'with `top_level_only` argument provided' do
          let(:params) { { top_level_only: true } }

          it 'return only top level groups' do
            is_expected.to contain_exactly(top_level_group, group2)
          end
        end
      end

      context 'with multiple params' do
        let_it_be(:params) { { ids: [group2.to_global_id.to_s], top_level_only: true, search: group2.full_path } }

        it 'returns expected groups' do
          is_expected.to contain_exactly(group2)
        end
      end
    end
  end
end

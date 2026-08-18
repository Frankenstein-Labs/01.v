# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityProjectGroupFinder, feature_category: :security_policy_management do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:top_level_group) { create(:group, name: 'top-level-group') }
    let_it_be(:group) { create(:group, name: 'group', parent: top_level_group) }
    let_it_be(:group2) { create(:group, name: 'group2') }
    let_it_be(:security_project) do
      create(:project, security_policy_project_linked_groups: [top_level_group, group, group2])
    end

    let(:params) { {} }

    subject { described_class.new(security_project, params).execute }

    it 'includes all groups' do
      is_expected.to contain_exactly(top_level_group, group, group2)
    end

    context 'when there no linked groups' do
      let_it_be(:security_project) { create(:project, security_policy_project_linked_groups: []) }

      it 'returns empty array if there are no linked groups in project' do
        is_expected.to eq([])
      end
    end

    context 'when project is nil' do
      let_it_be(:security_project) { nil }

      it 'returns empty array if there are no linked groups in project' do
        is_expected.to eq(Group.none)
      end
    end

    context 'with `ids` argument' do
      let_it_be(:params) { { ids: [group.id, group2.id] } }

      it 'filters groups by gid' do
        is_expected.to contain_exactly(group, group2)
      end
    end

    context 'with `search` argument' do
      let_it_be(:params) { { search: group2.full_path } }

      it 'filters groups by search' do
        is_expected.to contain_exactly(group2)
      end
    end

    context 'with top level groups only' do
      let_it_be(:params) { { top_level_only: true } }

      it 'returns only top level groups' do
        is_expected.to contain_exactly(top_level_group, group2)
      end
    end
  end
end

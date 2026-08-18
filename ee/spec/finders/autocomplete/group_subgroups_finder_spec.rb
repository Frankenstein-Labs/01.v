# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Autocomplete::GroupSubgroupsFinder, feature_category: :groups_and_projects do
  describe '#execute' do
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:subgroup_1) { create(:group, :private, parent: group) }
    let_it_be(:subgroup_2) { create(:group, :private, parent: group) }
    let_it_be(:grandchild_1) { create(:group, :private, parent: subgroup_1) }
    let_it_be(:member_in_group) { create(:user, reporter_of: group) }
    let_it_be(:member_in_subgroup) { create(:user, reporter_of: subgroup_1) }
    let_it_be(:invited_to_group) { create(:group, :public) }
    let_it_be(:invited_to_subgroup) { create(:group, :public) }

    let(:params) { { group_id: group.id } }
    let(:current_user) { member_in_group }

    before do
      group.shared_with_groups << invited_to_group
      grandchild_1.shared_with_groups << invited_to_subgroup
    end

    subject { described_class.new(current_user, params).execute }

    it 'returns subgroups', :aggregate_failures do
      expect(subject.count).to eq(2)
      expect(subject).to contain_exactly(subgroup_1, subgroup_2)
    end

    context 'when include_parent_shared_groups parameter is true' do
      before do
        params[:include_parent_shared_groups] = true
        params[:include_parent_descendants] = true
      end

      it 'returns subgroups and shared groups' do
        expect(subject.count).to eq(4)
        expect(subject).to contain_exactly(
          subgroup_1,
          subgroup_2,
          grandchild_1,
          invited_to_group)
      end
    end

    context 'when include_parent_descendants parameter is true' do
      before do
        params[:include_parent_descendants] = true
      end

      it 'returns subgroups and their descendants', :aggregate_failures do
        expect(subject.count).to eq(3)
        expect(subject).to contain_exactly(subgroup_1, subgroup_2, grandchild_1)
      end
    end

    context 'when a search param is added' do
      before do
        params[:search] = subgroup_1.name
      end

      it 'returns only the searched for subgroups' do
        expect(subject.count).to eq(1)
        expect(subject).to contain_exactly(subgroup_1)
      end
    end

    context 'when the number of groups exceeds the limit' do
      before do
        stub_const("#{described_class}::LIMIT", 1)
      end

      it 'limits the result' do
        expect(subject.count).to eq(1)
      end
    end

    context 'when user does not have an access to the group' do
      let(:current_user) { member_in_subgroup }

      it 'raises an error' do
        expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end

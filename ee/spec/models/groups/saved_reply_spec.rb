# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::SavedReply, feature_category: :code_review_workflow do
  let_it_be(:saved_reply) { create(:group_saved_reply) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:group_id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to([:group_id]) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:content).is_at_most(10000) }
  end

  describe '#for_groups' do
    let_it_be(:group) { create(:group) }
    let_it_be(:saved_reply) { create(:group_saved_reply, group: group) }

    it { expect(described_class.for_groups([group.id])).to eq([saved_reply]) }

    context 'with subgroup' do
      let_it_be(:subgroup) { create(:group, parent: group) }
      let_it_be(:subgroup_saved_reply) { create(:group_saved_reply, group: subgroup) }

      it do
        expect(described_class.for_groups([subgroup.id, group.id])).to match_array([saved_reply, subgroup_saved_reply])
      end
    end
  end
end

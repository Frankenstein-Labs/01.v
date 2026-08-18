# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::SavedRepliesFinder, feature_category: :code_review_workflow do
  describe '#execute' do
    let(:include_ancestor_groups) { false }

    subject(:execute) do
      described_class.new(group, { include_ancestor_groups: include_ancestor_groups }).execute
    end

    context 'when inside a group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:saved_reply) { create(:group_saved_reply, group: group) }

      it { expect(execute).to contain_exactly(saved_reply) }

      context 'when include_ancestor_groups is true' do
        let(:include_ancestor_groups) { true }

        it { expect(execute).to contain_exactly(saved_reply) }
      end
    end

    context 'when inside a subgroup' do
      let_it_be(:parent) { create(:group) }
      let_it_be(:group) { create(:group, parent: parent) }
      let_it_be(:saved_reply) { create(:group_saved_reply, group: parent) }

      context 'when include_ancestor_groups is true' do
        let(:include_ancestor_groups) { true }

        it { expect(execute).to contain_exactly(saved_reply) }
      end

      context 'when include_ancestor_groups is false' do
        it { expect(execute).to be_empty }
      end
    end
  end
end

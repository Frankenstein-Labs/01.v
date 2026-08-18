# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::EnabledFoundationalFlowsAuditor, feature_category: :duo_setting do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  describe '#execute' do
    subject(:execute) do
      described_class.new(
        current_user: user,
        group: group,
        previous_flow_refs: previous_flow_refs,
        new_flow_refs: new_flow_refs
      ).execute
    end

    context 'when flows change from empty to populated' do
      let(:previous_flow_refs) { [] }
      let(:new_flow_refs) { ['code_review/v1', 'chat/v1'] }

      it 'calls auditor with correct parameters' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'enabled_foundational_flows_updated',
            author: user,
            scope: group,
            target: group,
            message: 'Changed enabled foundational flows from none to chat/v1, code_review/v1'
          )
        )

        execute
      end
    end

    context 'when flows change from populated to empty' do
      let(:previous_flow_refs) { ['code_review/v1'] }
      let(:new_flow_refs) { [] }

      it 'calls auditor with correct parameters' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'enabled_foundational_flows_updated',
            author: user,
            scope: group,
            target: group,
            message: 'Changed enabled foundational flows from code_review/v1 to none'
          )
        )

        execute
      end
    end

    context 'when flows change between different sets' do
      let(:previous_flow_refs) { ['chat/v1'] }
      let(:new_flow_refs) { ['code_review/v1', 'chat/v1'] }

      it 'calls auditor with correct parameters' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'enabled_foundational_flows_updated',
            author: user,
            scope: group,
            target: group,
            message: 'Changed enabled foundational flows from chat/v1 to chat/v1, code_review/v1'
          )
        )

        execute
      end
    end

    context 'when flows do not change' do
      let(:previous_flow_refs) { ['code_review/v1'] }
      let(:new_flow_refs) { ['code_review/v1'] }

      it 'does not call auditor' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        execute
      end
    end

    context 'when only the order differs' do
      let(:previous_flow_refs) { ['code_review/v1', 'chat/v1'] }
      let(:new_flow_refs) { ['chat/v1', 'code_review/v1'] }

      it 'does not call auditor' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        execute
      end
    end

    context 'when previous_flow_refs is nil' do
      let(:previous_flow_refs) { nil }
      let(:new_flow_refs) { ['code_review/v1'] }

      it 'calls auditor treating nil as empty' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'enabled_foundational_flows_updated',
            message: 'Changed enabled foundational flows from none to code_review/v1'
          )
        )

        execute
      end
    end

    context 'when new_flow_refs is nil' do
      let(:previous_flow_refs) { ['code_review/v1'] }
      let(:new_flow_refs) { nil }

      it 'calls auditor treating nil as empty' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'enabled_foundational_flows_updated',
            message: 'Changed enabled foundational flows from code_review/v1 to none'
          )
        )

        execute
      end
    end

    context 'when both are nil' do
      let(:previous_flow_refs) { nil }
      let(:new_flow_refs) { nil }

      it 'does not call auditor' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        execute
      end
    end
  end
end

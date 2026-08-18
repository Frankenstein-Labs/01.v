# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FoundationalAgentStatusAuditor, feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:previous_statuses) { [] }
  let(:new_statuses) { [] }

  subject(:execute) do
    described_class.new(
      current_user: user,
      scope: group,
      previous_statuses: previous_statuses,
      new_statuses: new_statuses
    ).execute
  end

  describe '#execute' do
    context 'when an agent is newly enabled' do
      let(:previous_statuses) { [] }
      let(:new_statuses) { [{ reference: 'agent_1', enabled: true }] }

      it 'emits one audit event for the changed agent' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).once.with(
          hash_including(
            name: 'foundational_agent_status_updated',
            author: user,
            scope: group,
            target: group,
            message: "Changed foundational agent 'agent_1' status from nil to true"
          )
        )

        execute
      end
    end

    context 'when an agent is disabled' do
      let(:previous_statuses) { [{ reference: 'agent_1', enabled: true }] }
      let(:new_statuses) { [{ reference: 'agent_1', enabled: false }] }

      it 'emits one audit event with the before/after values' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).once.with(
          hash_including(
            name: 'foundational_agent_status_updated',
            message: "Changed foundational agent 'agent_1' status from true to false"
          )
        )

        execute
      end
    end

    context 'when multiple agents change status' do
      let(:previous_statuses) do
        [
          { reference: 'agent_1', enabled: true },
          { reference: 'agent_2', enabled: false }
        ]
      end

      let(:new_statuses) do
        [
          { reference: 'agent_1', enabled: false },
          { reference: 'agent_2', enabled: true }
        ]
      end

      it 'emits one audit event per changed agent' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).twice

        execute
      end
    end

    context 'when no statuses change' do
      let(:previous_statuses) { [{ reference: 'agent_1', enabled: true }] }
      let(:new_statuses) { [{ reference: 'agent_1', enabled: true }] }

      it 'does not emit any audit events' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        execute
      end
    end

    context 'when both previous and new statuses are empty' do
      it 'does not emit any audit events' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        execute
      end
    end

    context 'when statuses use string keys' do
      let(:previous_statuses) { [{ 'reference' => 'agent_1', 'enabled' => true }] }
      let(:new_statuses) { [{ 'reference' => 'agent_1', 'enabled' => false }] }

      it 'handles string-keyed hashes correctly' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).once.with(
          hash_including(name: 'foundational_agent_status_updated')
        )

        execute
      end
    end

    context 'when nil enabled values are resolved via default_enabled' do
      context 'when previous nil resolves to the same value as the explicit new status' do
        let(:previous_statuses) { [{ reference: 'agent_1', enabled: nil }] }
        let(:new_statuses) { [{ reference: 'agent_1', enabled: true }] }

        it 'does not emit an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          described_class.new(
            current_user: user, scope: group,
            previous_statuses: previous_statuses, new_statuses: new_statuses,
            default_enabled: true
          ).execute
        end
      end

      context 'when previous nil resolves to a different value than the explicit new status' do
        let(:previous_statuses) { [{ reference: 'agent_1', enabled: nil }] }
        let(:new_statuses) { [{ reference: 'agent_1', enabled: true }] }

        it 'emits an audit event' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).once.with(
            hash_including(
              name: 'foundational_agent_status_updated',
              message: "Changed foundational agent 'agent_1' status from false to true"
            )
          )

          described_class.new(
            current_user: user, scope: group,
            previous_statuses: previous_statuses, new_statuses: new_statuses,
            default_enabled: false
          ).execute
        end
      end

      context 'when both previous and new have nil enabled and default_enabled is provided' do
        let(:previous_statuses) { [{ reference: 'agent_1', enabled: nil }] }
        let(:new_statuses) { [{ reference: 'agent_1', enabled: nil }] }

        it 'does not emit an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          described_class.new(
            current_user: user, scope: group,
            previous_statuses: previous_statuses, new_statuses: new_statuses,
            default_enabled: true
          ).execute
        end
      end

      context 'when default_enabled is not provided and scope responds to foundational_agents_default_enabled' do
        let(:previous_statuses) { [{ reference: 'agent_1', enabled: nil }] }
        let(:new_statuses) { [{ reference: 'agent_1', enabled: true }] }

        before do
          allow(group).to receive(:foundational_agents_default_enabled).and_return(true)
        end

        it 'resolves nil via the scope and does not emit an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          described_class.new(
            current_user: user, scope: group,
            previous_statuses: previous_statuses, new_statuses: new_statuses
          ).execute
        end
      end
    end
  end
end

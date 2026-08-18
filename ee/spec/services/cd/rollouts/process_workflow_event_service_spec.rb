# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::Rollouts::ProcessWorkflowEventService, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:version_set) { create(:cd_version_set, application: application) }

  let(:rollout) do
    create(:cd_rollout, application: application, version_set: version_set, state: :in_progress,
      workflow_ref: 'wf-1')
  end

  subject(:service) { described_class.new(rollout, params: params) }

  describe '#execute' do
    context 'with a step_started event naming the approval step type' do
      let(:params) do
        { type: 'com.gitlab.cd.step_started',
          data: { position: [0, 0], step_type: Cd::RolloutStep::APPROVAL_STEP_TYPE } }
      end

      it 'opens an approval gate under a row lock on the rollout' do
        expect(rollout).to receive(:with_lock).and_call_original

        expect { service.execute }.to change { rollout.reload.open_approval_gate? }.from(false).to(true)
      end

      it 'checks the gate state after acquiring the lock, not before' do
        # A concurrent caller could have opened the gate between an earlier,
        # unlocked check and this call's create!. Asserting the check happens
        # only inside #with_lock (not before it) is what rules that window out.
        call_order = []

        allow(rollout).to receive(:with_lock).and_wrap_original do |method, &block|
          call_order << :with_lock
          method.call(&block)
        end
        allow(rollout).to receive(:open_approval_gate?).and_wrap_original do |method|
          call_order << :open_approval_gate?
          method.call
        end

        service.execute

        expect(call_order).to eq([:with_lock, :open_approval_gate?])
      end
    end
  end
end

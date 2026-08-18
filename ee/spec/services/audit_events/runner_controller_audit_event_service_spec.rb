# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::RunnerControllerAuditEventService, :aggregate_failures, feature_category: :continuous_integration do
  let_it_be(:user) { create(:user) }
  let_it_be(:runner_controller) { create(:ci_runner_controller) }

  let(:target) { runner_controller }
  let(:author) { user }
  let(:name) { 'runner_controller_created' }
  let(:message) { 'Created runner controller' }
  let(:additional_details) { {} }
  let(:service) do
    described_class.new(
      target, author,
      name: name,
      message: message,
      additional_details: additional_details
    )
  end

  describe '#initialize' do
    context 'with missing target' do
      let(:target) { nil }

      it 'raises ArgumentError' do
        expect { service }.to raise_error(ArgumentError, 'Missing target')
      end
    end

    context 'with missing author' do
      let(:author) { nil }

      it 'raises ArgumentError' do
        expect { service }.to raise_error(ArgumentError, 'Missing author')
      end
    end

    context 'with missing message' do
      let(:message) { nil }

      it 'raises ArgumentError' do
        expect { service }.to raise_error(ArgumentError, 'Missing message')
      end
    end

    context 'with blank message' do
      let(:message) { '' }

      it 'raises ArgumentError' do
        expect { service }.to raise_error(ArgumentError, 'Missing message')
      end
    end
  end

  describe '#track_event' do
    subject(:track_event) { service.track_event }

    shared_examples 'audits the event' do
      it 'calls Gitlab::Audit::Auditor with expected attributes' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: name,
            author: user,
            scope: an_instance_of(::Gitlab::Audit::InstanceScope),
            target: target,
            target_details: expected_target_details,
            message: message
          )
        )

        track_event
      end

      context 'with additional_details' do
        let(:additional_details) { { state: 'enabled' } }

        it 'includes additional_details in audit context' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(additional_details: { state: 'enabled' })
          )

          track_event
        end
      end

      context 'with empty additional_details' do
        let(:additional_details) { {} }

        it 'does not include additional_details key' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_not_including(:additional_details)
          )

          track_event
        end
      end
    end

    context 'when target is a RunnerController' do
      let(:expected_target_details) { "Runner controller ##{runner_controller.id}" }

      it_behaves_like 'audits the event'
    end

    context 'when target is a RunnerControllerToken' do
      let_it_be(:runner_controller_token) { create(:ci_runner_controller_token, runner_controller: runner_controller) }

      let(:target) { runner_controller_token }
      let(:name) { 'runner_controller_token_created' }
      let(:message) { 'Created runner controller token' }
      let(:expected_target_details) { "Runner controller token ##{runner_controller_token.id}" }

      it_behaves_like 'audits the event'
    end

    context 'when target is a RunnerControllerInstanceLevelScoping' do
      let_it_be(:instance_scoping) do
        create(:ci_runner_controller_instance_level_scoping, runner_controller: runner_controller)
      end

      let(:target) { instance_scoping }
      let(:name) { 'runner_controller_instance_scope_added' }
      let(:message) { 'Added instance-level scope to runner controller' }
      let(:expected_target_details) { "Instance scope for runner controller ##{runner_controller.id}" }

      it_behaves_like 'audits the event'
    end

    context 'when target is a RunnerControllerRunnerLevelScoping' do
      let_it_be(:instance_runner) { create(:ci_runner, :instance) }
      let_it_be(:runner_scoping) do
        create(:ci_runner_controller_runner_level_scoping,
          runner_controller: runner_controller,
          runner: instance_runner)
      end

      let(:target) { runner_scoping }
      let(:name) { 'runner_controller_runner_scope_added' }
      let(:message) { 'Added runner scope' }
      let(:expected_target_details) do
        "Runner scope for runner ##{instance_runner.id} on runner controller ##{runner_controller.id}"
      end

      it_behaves_like 'audits the event'
    end

    context 'when target is an unknown type' do
      let(:target) { 'unknown_target' }
      let(:expected_target_details) { 'unknown_target' }

      it_behaves_like 'audits the event'
    end
  end
end

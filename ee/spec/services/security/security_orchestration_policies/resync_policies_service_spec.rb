# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::ResyncPoliciesService, feature_category: :security_policy_management do
  let_it_be(:management_project) { create(:project) }

  describe '#execute' do
    let(:params) { {} }

    subject(:execute) { described_class.new(container: container, params: params).execute }

    shared_examples 'policy configuration does not exist' do
      it 'does not enqueue the worker and returns an error' do
        expect(Security::SyncScanPoliciesWorker).not_to receive(:perform_async)

        result = execute
        expect(result[:status]).to eq(:error)
      end
    end

    context 'when relationship is direct' do
      let(:params) { { relationship: :direct } }

      context 'when container is project' do
        let_it_be_with_reload(:container) { create(:project, group: create(:group)) }

        context 'when policy configuration exists for a project' do
          let!(:policy_configuration) do
            create(:security_orchestration_policy_configuration, project: container,
              security_policy_management_project: management_project)
          end

          it 'enqueues the SyncScanPoliciesWorker with force_resync: true and returns success' do
            expect(Security::SyncScanPoliciesWorker).to receive(:perform_async)
              .with(policy_configuration.id, { 'force_resync' => true })

            result = execute
            expect(result[:status]).to eq(:success)
          end
        end

        it_behaves_like 'policy configuration does not exist'
      end

      context 'when container is group' do
        let_it_be_with_reload(:container) { create(:namespace) }

        context 'when policy configuration exists' do
          let!(:policy_configuration) do
            create(:security_orchestration_policy_configuration, :namespace,
              namespace: container, security_policy_management_project: management_project)
          end

          it 'enqueues the SyncScanPoliciesWorker with force_resync: true and returns success' do
            expect(Security::SyncScanPoliciesWorker).to receive(:perform_async)
              .with(policy_configuration.id, { 'force_resync' => true })

            result = execute
            expect(result[:status]).to eq(:success)
          end
        end

        it_behaves_like 'policy configuration does not exist'
      end
    end

    context 'when relationship is inherited' do
      let(:params) { { relationship: :inherited } }

      context 'when container is project' do
        let_it_be_with_reload(:container) { create(:project, group: create(:group)) }
        let!(:config1) do
          create(:security_orchestration_policy_configuration, :namespace, project: nil,
            namespace: container.group, security_policy_management_project: management_project)
        end

        let!(:config2) do
          create(:security_orchestration_policy_configuration, project: container,
            namespace: nil, security_policy_management_project: management_project)
        end

        before do
          allow_next_found_instances_of(Security::OrchestrationPolicyConfiguration, 2) do |configuration|
            allow(configuration).to receive(:policy_configuration_valid?).and_return(true)
          end
        end

        it 'enqueues SyncProjectPoliciesWorker for each configuration and returns success' do
          expect(Security::SyncProjectPoliciesWorker).to receive(:perform_async)
            .with(container.id, config1.id, { 'force_resync' => true })
          expect(Security::SyncProjectPoliciesWorker).to receive(:perform_async)
            .with(container.id, config2.id, { 'force_resync' => true })

          result = execute
          expect(result[:status]).to eq(:success)
        end
      end

      context 'when container is group' do
        let_it_be_with_reload(:container) { create(:namespace) }

        # TODO: The expectation should change when https://gitlab.com/gitlab-org/gitlab/-/issues/545805 is implemented
        it 'does not enqueue workers and returns success' do
          expect(Security::SyncProjectPoliciesWorker).not_to receive(:perform_async)
          expect(Security::SyncScanPoliciesWorker).not_to receive(:perform_async)

          result = execute
          expect(result[:status]).to eq(:success)
        end
      end
    end
  end
end

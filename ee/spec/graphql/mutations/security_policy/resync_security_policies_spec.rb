# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::SecurityPolicy::ResyncSecurityPolicies, feature_category: :security_policy_management do
  include GraphqlHelpers
  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  describe '#resolve' do
    let_it_be(:owner) { create(:user) }
    let_it_be(:maintainer) { create(:user) }
    let_it_be_with_reload(:namespace) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, namespace: namespace) }
    let(:current_user) { owner }
    let(:relationship) { :direct }

    subject(:resolve_mutation) { mutation.resolve(full_path: container.full_path, relationship: relationship) }

    shared_examples 'does not resync policies for failing cases' do
      context 'when licensed feature is available' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        context 'when user is not an owner' do
          let(:current_user) { maintainer }

          before do
            container.add_maintainer(maintainer)
          end

          it 'raises exception' do
            expect { resolve_mutation }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
          end
        end
      end

      context 'when feature is not licensed' do
        before do
          container.add_owner(current_user)
          stub_licensed_features(security_orchestration_policies: false)
        end

        it 'raises exception' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end

    shared_examples 'resync policies for valid cases' do |container_type:|
      let_it_be(:sub_group) { create(:group, parent: namespace) }
      let!(:namespace_config) do
        create(:security_orchestration_policy_configuration, :namespace, namespace: namespace)
      end

      let!(:direct_config) do
        if container_type == :project
          create(:security_orchestration_policy_configuration, project: project)
        else
          namespace_config
        end
      end

      let!(:subgroup_config) do
        create(:security_orchestration_policy_configuration, :namespace, namespace: sub_group)
      end

      before do
        stub_licensed_features(security_orchestration_policies: true)

        container.add_owner(owner)
        container.update!(group: sub_group) if container_type == :project

        allow_next_found_instances_of(Security::OrchestrationPolicyConfiguration, 6) do |configuration|
          allow(configuration).to receive(:policy_configuration_valid?).and_return(true)
        end
      end

      context 'when relationship is inherited' do
        let(:relationship) { :inherited }

        if container_type == :project
          it 'enqueues workers as expected' do
            container.all_security_orchestration_policy_configurations.each do |configuration|
              expect(Security::SyncProjectPoliciesWorker).to receive(:perform_async)
                .with(container.id, configuration.id, { 'force_resync' => true })
            end

            result = resolve_mutation
            expect(result[:errors]).to be_empty
          end
        else
          it 'does not enqueue workers as expected' do
            expect(Security::SyncProjectPoliciesWorker).not_to receive(:perform_async)
            expect(Security::SyncScanPoliciesWorker).not_to receive(:perform_async)

            result = resolve_mutation
            expect(result[:errors]).to be_empty
          end
        end
      end

      context 'when relationship is direct' do
        let(:relationship) { :direct }

        if container_type == :project
          it 'enqueues SyncScanPoliciesWorker for projects' do
            expect(Security::SyncScanPoliciesWorker).to receive(:perform_async)
              .with(direct_config.id, { 'force_resync' => true })

            result = resolve_mutation
            expect(result[:errors]).to be_empty
          end
        else
          it 'does not enqueue SyncScanPoliciesWorker for groups' do
            expect(Security::SyncScanPoliciesWorker).to receive(:perform_async)
              .with(namespace_config.id, { 'force_resync' => true })

            result = resolve_mutation
            expect(result[:errors]).to be_empty
          end
        end
      end
    end

    context 'when full_path is not provided' do
      subject(:resolve_mutation) { mutation.resolve({}) }

      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it 'raises exception' do
        expect { resolve_mutation }.to raise_error(Gitlab::Graphql::Errors::ArgumentError)
      end
    end

    context 'for project' do
      let(:container) { project }

      it_behaves_like 'does not resync policies for failing cases'
      it_behaves_like 'resync policies for valid cases', container_type: :project
    end

    context 'for namespace' do
      let(:container) { namespace }

      it_behaves_like 'does not resync policies for failing cases'
      it_behaves_like 'resync policies for valid cases', container_type: :namespace
    end
  end
end

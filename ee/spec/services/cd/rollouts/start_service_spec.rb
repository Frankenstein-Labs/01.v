# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::Rollouts::StartService, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }

  let(:flow_definition) do
    create(:cd_application_flow_definition, application: application, definition: <<~YAML)
      environments: {}
      steps:
        - type: com.gitlab.cd.steps.wait
          seconds: 0
    YAML
  end

  let(:version_set) { create(:cd_version_set, application: application) }
  let(:rollout) do
    create(:cd_rollout, application: application, version_set: version_set,
      application_flow_definition: flow_definition, state: :pending)
  end

  let!(:rollout_environment) { create(:cd_rollout_environment, rollout: rollout) }

  let(:kas_client) { instance_double(Gitlab::Kas::Client) }
  let(:response) { Gitlab::Agent::AutoFlow::Rpc::StartWorkflowResponse.new(workflow_key: 'wk:1/abc') }

  subject(:result) { described_class.new(rollout).execute }

  before do
    allow(Gitlab::Kas::Client).to receive(:new).and_return(kas_client)
    allow(kas_client).to receive(:start_workflow).and_return(response)
  end

  describe '#execute' do
    it 'transitions the rollout to in_progress' do
      expect { result }.to change { rollout.reload.state }.from('pending').to('in_progress')
    end

    it 'starts the workflow with the rollout idempotency key, namespace, deploy program and built kwargs',
      :aggregate_failures do
      built_kwargs = { 'environments' => {}, 'flow_definition' => {}, 'version_set' => { 'services' => [] } }
      expect_next_instance_of(Cd::Rollouts::WorkflowKwargs, rollout) do |workflow_kwargs|
        expect(workflow_kwargs).to receive(:to_h).and_return(built_kwargs)
      end

      driver = Cd::DeployDrivers::Registry.find('argo-rollouts')

      expect(kas_client).to receive(:start_workflow) do |idempotency_key:, workflow_definition:, namespace_id:, kwargs:|
        expect(idempotency_key).to eq("cd-rollout-#{rollout.id}")
        expect(namespace_id).to eq(rollout.organization_id)
        # The real engine assembled around the real fragment, not either alone.
        expect(workflow_definition).to eq(
          Cd::DeployDrivers::Registry.orchestrator.assemble(
            driver_scripts: { driver.gem_name => driver.deploy_fragment }
          )
        )
        expect(kwargs.except('callback_token')).to eq(built_kwargs)
        # Wrapped so ValueConverter emits a sensitive_string, not a plain string_value.
        expect(kwargs['callback_token']).to be_a(Gitlab::Kas::Autoflow::ValueConverter::SensitiveString)
        # The deploy driver relays this back on its workflow-event callbacks (see
        # API::Cd::Rollouts), so it must verify as this rollout's own token.
        expect(Cd::Rollouts::CallbackToken.matches?(kwargs['callback_token'].value, rollout)).to be(true)
        response
      end

      result
    end

    context 'when the rollout has no flow definition' do
      let(:rollout) do
        create(:cd_rollout, application: application, version_set: version_set, state: :pending)
      end

      it 'does not call KAS and returns an error' do
        expect(kas_client).not_to receive(:start_workflow)

        expect(result).to be_error
        expect(result.message).to include(a_string_matching(/no flow definition/i))
      end
    end

    context 'when the rollout has no environments bound to a deploy driver' do
      let!(:rollout_environment) { nil }

      it 'does not call KAS and returns an error' do
        expect(kas_client).not_to receive(:start_workflow)

        expect(result).to be_error
        expect(result.message).to include(a_string_matching(/no environments bound to a deploy driver/i))
      end
    end

    context 'when the rollout environments use different deploy drivers' do
      before do
        other_binding = create(:cd_environment_driver_binding).tap { |b| b.update_column(:driver_ref, 'other-driver') }
        create(:cd_rollout_environment, rollout: rollout, driver_binding: other_binding,
          environment: other_binding.environment, position: rollout_environment.position + 1)
      end

      it 'does not call KAS and returns an error' do
        expect(kas_client).not_to receive(:start_workflow)

        expect(result).to be_error
        expect(result.message).to include(a_string_matching(/different deploy drivers/i))
      end
    end

    context 'when the rollout environment uses an unregistered deploy driver' do
      let!(:rollout_environment) do
        binding = create(:cd_environment_driver_binding).tap { |b| b.update_column(:driver_ref, 'retired-driver') }
        create(:cd_rollout_environment, rollout: rollout, driver_binding: binding, environment: binding.environment)
      end

      it 'does not call KAS and returns an error naming the driver_ref' do
        expect(kas_client).not_to receive(:start_workflow)

        expect(result).to be_error
        expect(result.message).to include(a_string_matching(/retired-driver.*not registered/i))
      end
    end

    context "when the flow definition's embedded config does not match the driver schema" do
      let(:flow_definition) do
        create(:cd_application_flow_definition, application: application).tap do |fd|
          fd.file.store!(CarrierWaveStringFile.new(<<~YAML))
            environments:
              production:
                services:
                  web:
                    namespace: argocd
            steps:
              - type: com.gitlab.cd.steps.wait
                seconds: 0
          YAML
          fd.remove_instance_variable(:@definition)
        end
      end

      it 'does not call KAS and returns an error naming the schema violation' do
        expect(kas_client).not_to receive(:start_workflow)

        expect(result).to be_error
        expect(result.message).to include(a_string_matching(/service 'web'.*missing required properties/))
      end
    end

    it 'calls KAS start_workflow' do
      expect(kas_client).to receive(:start_workflow).and_return(response)

      result
    end

    it 'sends the engine and the driver fragment as one program, not either alone', :aggregate_failures do
      expect(kas_client).to receive(:start_workflow) do |workflow_definition:, **|
        expect(workflow_definition).to include('def main(')
        expect(workflow_definition).to match(/^gitlab_ddeploy_ddriver_dargo_drollouts_deploy\(\)$/)
        response
      end

      result
    end

    context 'when only some environments are bound to a driver already assembled' do
      let!(:second_rollout_environment) do
        binding = create(:cd_environment_driver_binding)
        create(:cd_rollout_environment, rollout: rollout, driver_binding: binding,
          environment: binding.environment, position: rollout_environment.position + 1)
      end

      it 'assembles each distinct driver once' do
        expect(kas_client).to receive(:start_workflow) do |workflow_definition:, **|
          expect(workflow_definition.scan('def gitlab_ddeploy_ddriver_dargo_drollouts_deploy(').size).to eq(1)
          response
        end

        result
      end
    end

    it 'persists the returned workflow_key as the rollout workflow_ref' do
      expect { result }.to change { rollout.reload.workflow_ref }.from(nil).to('wk:1/abc')
    end

    it 'returns a success response with the rollout' do
      expect(result).to be_success
      expect(result.payload[:rollout]).to eq(rollout)
    end

    context 'when the rollout is in a terminal state with a workflow_ref' do
      let(:rollout) { create(:cd_rollout, state: :completed, workflow_ref: 'wk:1/done') }
      let!(:rollout_environment) { nil }

      it 'does not call KAS and returns success (idempotent no-op)' do
        expect(kas_client).not_to receive(:start_workflow)

        expect(result).to be_success
        expect(rollout.reload.workflow_ref).to eq('wk:1/done')
      end
    end

    context 'when the rollout is not pending and has no workflow_ref' do
      # Not reachable through the normal flow (a non-pending rollout always has a
      # workflow_ref), but guards the startable? check defensively.
      let(:rollout) do
        create(:cd_rollout, state: :in_progress, workflow_ref: 'wk:1/x').tap do |r|
          r.update_column(:workflow_ref, nil)
        end
      end

      let!(:rollout_environment) { nil }

      it 'does not call KAS and returns an error' do
        expect(kas_client).not_to receive(:start_workflow)

        expect(result).to be_error
        expect(result.message).to include(a_string_matching(/cannot be started/i))
      end
    end

    context 'when the KAS call fails' do
      before do
        allow(kas_client).to receive(:start_workflow).and_raise(GRPC::Unavailable.new('kas down'))
      end

      it 'propagates the error so the worker can retry' do
        expect { result }.to raise_error(GRPC::Unavailable)
      end

      it 'rolls back the state transition so the rollout stays pending for retry' do
        expect { result }.to raise_error(GRPC::Unavailable)
          .and not_change { rollout.reload.state }.from('pending')
      end

      it 'does not persist a workflow_ref' do
        expect { result }.to raise_error(GRPC::Unavailable)
        expect(rollout.reload.workflow_ref).to be_nil
      end
    end

    context 'when retried after a previous KAS failure left the rollout pending' do
      it 'proceeds with the KAS call and transitions while persisting the workflow_ref' do
        expect(kas_client).to receive(:start_workflow).and_return(response)

        expect { result }
          .to change { rollout.reload.workflow_ref }.from(nil).to('wk:1/abc')
          .and change { rollout.reload.state }.from('pending').to('in_progress')

        expect(result).to be_success
      end
    end

    context 'when the rollout is already in progress with a workflow_ref' do
      let(:rollout) { create(:cd_rollout, state: :in_progress, workflow_ref: 'wk:1/existing') }
      let!(:rollout_environment) { nil }

      it 'does not call KAS again and returns success' do
        expect(kas_client).not_to receive(:start_workflow)

        expect(result).to be_success
        expect(rollout.reload.workflow_ref).to eq('wk:1/existing')
      end
    end
  end
end

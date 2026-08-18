# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::FlowExecutionAuthorizer, feature_category: :duo_agent_platform do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, developer_of: [group, project]) }

  let_it_be(:catalog_item) do
    create(:ai_catalog_item, :flow, :public, foundational_flow_reference: 'developer/v1')
  end

  let(:workflow_definition) { 'developer/v1' }
  let(:container) { group }
  let(:start_workflow) { false }
  let(:item_consumer_id) { nil }
  let(:caller_can_execute) { true }
  let(:resolve_service_account) { true }

  subject(:result) do
    described_class.new(
      current_user: user,
      container: container,
      workflow_definition: workflow_definition,
      start_workflow: start_workflow,
      item_consumer_id: item_consumer_id,
      caller_can_execute: caller_can_execute,
      resolve_service_account: resolve_service_account
    ).execute
  end

  before do
    stub_feature_flags(duo_client_executed_flow_governance: true)

    # The shared FoundationalFlow instance memoizes #catalog_item, which would leak
    # across spec files.
    allow(::Ai::Catalog::FoundationalFlow['developer/v1']).to receive(:catalog_item)
      .and_return(catalog_item)

    stub_licensed_features(ai_features: true)
    project.project_setting.update!(duo_features_enabled: true)

    # Access, stubbed so these examples isolate the classification from chat policy.
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(user, :access_duo_agentic_chat, group).and_return(true)
    allow(Ability).to receive(:allowed?).with(user, :access_duo_agentic_chat, project).and_return(true)
  end

  shared_examples 'a background run' do
    it 'applies AI catalog governance' do
      expect(result).to be_error
      expect(result.reason).to eq(:forbidden)
    end

    it 'does not fall back to the client-executed checks' do
      expect(Ability).not_to receive(:allowed?).with(user, :access_duo_agentic_chat, anything)

      expect(result).to be_error
    end
  end

  shared_examples 'a client-executed run' do
    it 'does not apply AI catalog governance' do
      expect(Ability).not_to receive(:allowed?).with(user, :execute_ai_catalog_item, anything)

      expect(result).to be_success
    end

    it 'does not resolve a service account' do
      expect(::Ai::Catalog::ItemConsumers::ResolveServiceAccountService).not_to receive(:new)

      expect(result.payload[:service_account]).to be_nil
    end
  end

  describe '#execute' do
    context 'when the workflow definition is not a catalog flow' do
      where(:definition) { ['chat', 'agentic_chat/v1', 'custom_flow', nil] }

      with_them do
        let(:workflow_definition) { definition }

        it 'is not governed here and leaves the checks to CreateWorkflowService' do
          expect(Ability).not_to receive(:allowed?).with(user, :execute_ai_catalog_item, anything)
          expect(Ability).not_to receive(:allowed?).with(user, :access_duo_agentic_chat, anything)

          expect(result).to be_success
          expect(result.payload[:execution]).to be_nil
        end
      end
    end

    context 'when the flow has no catalog item yet' do
      before do
        allow(::Ai::Catalog::FoundationalFlow['developer/v1']).to receive(:catalog_item)
          .and_return(nil)
      end

      it 'skips governance entirely and logs a warning' do
        expect(Ability).not_to receive(:allowed?).with(user, :execute_ai_catalog_item, anything)
        expect(Ability).not_to receive(:allowed?).with(user, :access_duo_agentic_chat, anything)

        expect(::Gitlab::AppLogger).to receive(:warn).with(
          hash_including(
            'class_name' => described_class.name,
            'duo_workflow_definition' => workflow_definition,
            'message' => 'Foundational flow has no catalog item, skipping flow execution authorization'
          )
        )

        expect(result).to be_success
        expect(result.payload[:execution]).to be_nil
        expect(result.payload[:service_account]).to be_nil
      end
    end

    context 'with a run that the client executes' do
      where(:container_description) { %w[group project] }

      with_them do
        let(:container) { container_description == 'group' ? group : project }

        it_behaves_like 'a client-executed run'

        it 'reports the classification' do
          expect(result.payload[:execution]).to be_client_executed
        end

        it 'requires agentic chat access on the container' do
          allow(Ability).to receive(:allowed?)
            .with(user, :access_duo_agentic_chat, container).and_return(false)

          expect(result).to be_error
          expect(result.message).to eq('GitLab Duo Agent Platform is not available for this namespace')
        end
      end
    end

    context 'with a group-scoped run that the client executes' do
      it 'is not subject to the owner foundational flows switch' do
        group.namespace_settings.update!(duo_foundational_flows_enabled: false)

        expect(result).to be_success
        expect(result.payload[:execution]).to be_client_executed
      end

      # Delegated to Ai::Catalog::FoundationalFlow#available_for?, so these assert the
      # delegation, not the rules. The generic message avoids disclosing flow maturity.
      it 'requires Ultimate for an Ultimate-only flow' do
        stub_flow(ultimate_only?: true)
        stub_licensed_features(ai_features: false)

        expect(result).to be_error
        expect(result.message).to eq('This flow is not available')
      end

      it 'requires beta consent for a beta flow' do
        stub_flow(beta?: true)
        stub_application_setting(instance_level_ai_beta_features_enabled: false)

        expect(result).to be_error
        expect(result.message).to eq('This flow is not available')
      end

      it 'honours the per-flow feature flag without naming it' do
        stub_flow(blocked_by_feature_flag?: true)

        expect(result).to be_error
        expect(result.message).to eq('This flow is not available')
      end

      it 'asks the flow whether the root ancestor is entitled to it' do
        stub_flow(available_for?: false)

        expect(::Ai::Catalog::FoundationalFlow['developer/v1']).to receive(:available_for?).with(group)

        expect(result).to be_error
      end
    end

    context 'when the caller asked GitLab to execute the run' do
      let(:start_workflow) { true }

      it_behaves_like 'a background run'
    end

    context 'when the caller named a catalog item consumer' do
      let(:item_consumer_id) { 1 }

      it_behaves_like 'a background run'
    end

    context 'when the caller cannot perform the run itself' do
      let(:caller_can_execute) { false }

      it_behaves_like 'a background run'
    end

    context 'when the run is project-scoped' do
      let(:container) { project }

      it 'is client-executed, and the project flow allowlist does not apply' do
        expect(Ability).not_to receive(:allowed?).with(user, :execute_ai_catalog_item, anything)

        expect(result).to be_success
        expect(result.payload[:execution]).to be_client_executed
        expect(result.payload[:service_account]).to be_nil
      end

      it 'is not subject to the owner foundational flows switch on the project' do
        project.update!(duo_foundational_flows_enabled: false)

        expect(result).to be_success
        expect(result.payload[:execution]).to be_client_executed
      end
    end

    context 'when the container is a user namespace' do
      let(:container) { create(:namespace) }

      it 'is refused' do
        expect(result).to be_error
        expect(result.reason).to eq(:forbidden)
      end

      context 'when the caller asked GitLab to execute it' do
        let(:start_workflow) { true }

        it_behaves_like 'a background run'
      end
    end

    context 'when the feature flag is off' do
      before do
        stub_feature_flags(duo_client_executed_flow_governance: false)
      end

      # 'a background run' is not used here: the client-executed checks are evaluated for
      # the log line, so only the outcome shows they did not decide it.
      it 'applies AI catalog governance' do
        expect(result).to be_error
        expect(result.reason).to eq(:forbidden)
      end

      # While the flag is off, this line is the only signal for whether a run that would
      # reclassify would also lose access.
      it 'records the classification and the checks it would have applied' do
        expect(::Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            'class_name' => described_class.name,
            'execution' => :background,
            'client_executable' => true,
            'feature_flag_enabled' => false,
            'agentic_chat_allowed' => true,
            'flow_available' => true,
            'root_namespace_id' => group.id,
            'gl_user_id' => user.id
          )
        )

        expect(result).to be_error
      end

      it 'reports a run that would lose access' do
        allow(Ability).to receive(:allowed?)
          .with(user, :access_duo_agentic_chat, group).and_return(false)

        expect(::Gitlab::AppLogger).to receive(:info).with(
          hash_including('agentic_chat_allowed' => false)
        )

        expect(result).to be_error
      end
    end

    context 'with a background run that is allowed' do
      let(:start_workflow) { true }
      let(:container) { project }
      let(:service_account) { create(:user, :service_account) }

      before do
        allow(Ability).to receive(:allowed?).with(user, :execute_ai_catalog_item, anything).and_return(true)
        allow_next_instance_of(::Ai::Catalog::ItemConsumers::ResolveServiceAccountService) do |service|
          allow(service).to receive(:execute)
            .and_return(ServiceResponse.success(payload: { service_account: service_account }))
        end
      end

      it 'returns the service account the run executes as' do
        expect(result).to be_success
        expect(result.payload[:service_account]).to eq(service_account)
        expect(result.payload[:execution]).to be_background
      end

      context 'when the service account cannot be resolved' do
        before do
          allow_next_instance_of(::Ai::Catalog::ItemConsumers::ResolveServiceAccountService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'No item consumer found'))
          end
        end

        it 'is forbidden' do
          expect(result).to be_error
          expect(result.message).to eq('No item consumer found')
        end
      end

      context 'when the caller does not need a service account' do
        let(:resolve_service_account) { false }

        it 'does not resolve one' do
          expect(::Ai::Catalog::ItemConsumers::ResolveServiceAccountService).not_to receive(:new)

          expect(result).to be_success
        end
      end
    end
  end

  describe 'the sealed classification' do
    it 'cannot be constructed outside the authorizer' do
      expect { described_class::Classification.new(:client) }
        .to raise_error(NoMethodError, /private method/)
    end
  end

  describe 'entitlement conditions declared by Ai::Catalog::ItemConsumerPolicy' do
    # A client-executed run has no item consumer, so the policy cannot be evaluated and
    # the entitlement half is applied against the container instead. If the policy grows
    # a condition of its own, it must be accounted for in one of three ways, or this
    # fails.
    #
    # Scope: conditions the policy declares itself. Conditions it delegates to, such as
    # the AI catalog entitlement behind :execute_ai_catalog_item, are waived as a class
    # and are not enumerated here. See WAIVED_ITEM_CONSUMER_CONDITIONS.

    # Applied by the client-executed branch, through FoundationalFlow#available_for?.
    let(:applied) do
      %i[
        foundational_flow
        beta_foundational_flow
        beta_features_enabled
        ultimate_only_item
        ultimate_license_available
        foundational_flow_feature_flag_disabled
      ]
    end

    # Cannot apply to a foundational flow at all, so not a governance decision. Kept in
    # the spec rather than in the class, which documents only deliberate waivers.
    let(:not_applicable) do
      %i[
        custom_flow
        custom_flows_available
        duo_custom_flows_enabled
        custom_agent
        duo_custom_agents_enabled
        third_party_flow
        third_party_flows_available
        duo_external_agents_enabled
        item_blocked_by_namespace_restriction
        outside_restricted_hierarchy
        internal_visibility_enabled
      ]
    end

    it 'accounts for every condition the policy declares itself' do
      accounted_for = applied + not_applicable + described_class::WAIVED_ITEM_CONSUMER_CONDITIONS.keys
      unaccounted = ::Ai::Catalog::ItemConsumerPolicy.own_conditions.keys.map(&:to_sym) - accounted_for

      expect(unaccounted).to be_empty, <<~MESSAGE
        Ai::Catalog::ItemConsumerPolicy declares conditions that #{described_class} does
        not account for: #{unaccounted.join(', ')}.

        Apply the condition to the client-executed branch, or add it to
        #{described_class}::WAIVED_ITEM_CONSUMER_CONDITIONS with the reason a
        client-executed run is deliberately not subject to it, or list it above as unable
        to apply to a foundational flow.
      MESSAGE
    end
  end

  def stub_flow(**stubs)
    flow = ::Ai::Catalog::FoundationalFlow['developer/v1']
    stubs.each { |method, value| allow(flow).to receive(method).and_return(value) }
    allow(::Ai::Catalog::FoundationalFlow).to receive(:[]).and_call_original
    allow(::Ai::Catalog::FoundationalFlow).to receive(:[]).with('developer/v1').and_return(flow)
  end
end

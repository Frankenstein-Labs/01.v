# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::FlowTriggers::Delete, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: maintainer) }
  let_it_be_with_reload(:trigger) { create(:ai_flow_trigger, project: project) }
  let_it_be(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_core, :self_managed) }

  let(:current_user) { maintainer }
  let(:mutation) { graphql_mutation(:ai_flow_trigger_delete, params) }
  let(:params) do
    {
      id: trigger.to_global_id
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
    stub_ee_application_setting(duo_features_enabled: true)
    ::Ai::Setting.for_organization(current_organization).update!(duo_core_features_enabled: true)
  end

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not delete the flow trigger' do
      expect { execute }.not_to change { Ai::FlowTrigger.count }
    end
  end

  context 'when user is a developer' do
    let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

    it_behaves_like 'an authorization failure'
  end

  context 'when the flow trigger does not exist' do
    let(:params) do
      {
        id: Gitlab::GlobalId.build(model_name: 'Ai::FlowTrigger', id: non_existing_record_id)
      }
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when destroy fails' do
    before do
      allow_next_instance_of(::Ai::FlowTriggers::DestroyService) do |instance|
        allow(instance).to receive(:execute)
          .and_return(ServiceResponse.error(message: 'Failed to delete the flow trigger'))
      end
    end

    it 'returns the service error message' do
      execute

      expect(graphql_data_at(:ai_flow_trigger_delete, :errors))
        .to contain_exactly('Failed to delete the flow trigger')
    end
  end

  it 'destroys the flow trigger and emits an audit event' do
    expect { execute }.to change { Ai::FlowTrigger.count }.by(-1)
      .and change { AuditEventReader.count }.by(1)

    audit_event = AuditEventReader.last
    expect(audit_event.details).to include(event_name: 'flow_trigger_deleted')
  end
end

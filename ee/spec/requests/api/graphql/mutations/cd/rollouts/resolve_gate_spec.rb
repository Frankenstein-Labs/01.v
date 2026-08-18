# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Resolve a continuous deployment rollout approval gate', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:version_set) { create(:cd_version_set, application: application) }
  let_it_be_with_reload(:rollout) do
    create(:cd_rollout, version_set: version_set, application: application, state: :in_progress, workflow_ref: 'wf-1')
  end

  let(:current_user) { organization_owner }
  let(:input) do
    {
      id: rollout.to_global_id.to_s,
      status: 'APPROVED',
      reason: 'Ship it'
    }
  end

  let(:mutation) { graphql_mutation(:cd_rollout_gate_resolve, input) }
  let(:mutation_response) { graphql_mutation_response(:cd_rollout_gate_resolve) }

  before_all do
    create(:cd_rollout_transition, rollout: rollout, event: 'request_approval',
      from_state: 'in_progress', to_state: 'in_progress')
  end

  context 'when the user is an organization owner' do
    it 'records an approve transition' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to change { ::Cd::RolloutTransition.count }.by(1)

      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['rolloutTransition']).to include(
        'event' => 'approve',
        'reason' => 'Ship it'
      )
      expect(::Cd::RolloutTransition.order(:id).last).to have_attributes(
        rollout: rollout,
        event: 'approve',
        principal: "user:#{current_user.id}"
      )
    end

    context 'when rejecting' do
      let(:input) { super().merge(status: 'REJECTED', reason: nil) }

      it 'records a reject transition' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .to change { ::Cd::RolloutTransition.count }.by(1)

        expect(mutation_response['rolloutTransition']).to include('event' => 'reject')
      end
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :resolve_cd_rollout_gate do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:cd_rollout_gate_resolve, input, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when the rollout has no open approval gate' do
      before do
        create(:cd_rollout_transition, rollout: rollout, event: 'approve')
      end

      it 'returns errors and does not create a transition' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { ::Cd::RolloutTransition.count }

        expect(mutation_response['rolloutTransition']).to be_nil
        expect(mutation_response['errors']).to include(a_string_matching(/no open approval gate/i))
      end
    end
  end

  context 'when the user is an organization member' do
    let(:current_user) { organization_member }

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when the user is not a member of the organization' do
    let(:current_user) { create(:user) }

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when the ai_native_deploy feature flag is disabled' do
    before do
      stub_feature_flags(ai_native_deploy: false)
    end

    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create a transition' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { ::Cd::RolloutTransition.count }
    end
  end
end

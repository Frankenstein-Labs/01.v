# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Start a Secrets Manager trial', feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be(:owner) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:non_member) { create(:user) }
  let_it_be_with_reload(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }

  let(:client) { ::Gitlab::SubscriptionPortal::Client }
  let(:current_user) { owner }
  let(:target_group) { root_group }
  let(:mutation_name) { :secrets_manager_start_trial }

  let(:mutation) { graphql_mutation(mutation_name, group_path: target_group.full_path) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before_all do
    root_group.add_owner(owner)
    root_group.add_maintainer(maintainer)
    subgroup.add_owner(owner)
  end

  before do
    stub_saas_features(gitlab_com_subscriptions: true)
  end

  context 'when the current user is the group owner' do
    context 'when CDot starts the trial successfully', :saas do
      before do
        allow(client).to receive(:start_secrets_manager_trial)
          .with(namespace_id: root_group.id)
          .and_return(::Gitlab::SubscriptionPortal::SecretsManagerStartTrialResponse.new(success: true))
        allow(::SecretsManagement::Entitlement).to receive(:for)
          .with(root_group, user: owner)
          .and_return(::SecretsManagement::Entitlement.new(state: :trial, credits_remaining: 1000))
      end

      it 'starts the trial and returns the post-trial entitlement', :aggregate_failures do
        post_mutation

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty
        expect(mutation_response['entitlement']).to include(
          'state' => 'TRIAL',
          'creditsRemaining' => 1000
        )
      end

      it 'tracks the secrets_manager_trial_started event' do
        expect { post_mutation }
          .to trigger_internal_events('secrets_manager_trial_started')
          .with(namespace: root_group, user: owner, category: 'Mutations::SecretsManagement::StartTrial')
          .and not_trigger_internal_events('secrets_manager_trial_start_failed')
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :read_secrets_manager do
        let(:user) { owner }
        let(:boundary_object) { root_group }
        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end
    end

    context 'when CDot rejects the request as already trialing', :saas do
      before do
        allow(client).to receive(:start_secrets_manager_trial).and_return(
          ::Gitlab::SubscriptionPortal::SecretsManagerStartTrialResponse.new(
            success: false, error_code: :trial_already_active
          )
        )
      end

      it 'returns the mapped error and a nil entitlement', :aggregate_failures do
        post_mutation

        expect(mutation_response['errors']).to contain_exactly(
          'A Secrets Manager trial is already active for this group.'
        )
        expect(mutation_response['entitlement']).to be_nil
      end

      it 'tracks the trial start failure with the failure reason as label' do
        expect { post_mutation }
          .to trigger_internal_events('secrets_manager_trial_start_failed')
          .with(
            namespace: root_group,
            user: owner,
            category: 'Mutations::SecretsManagement::StartTrial',
            additional_properties: { label: 'trial_already_active' }
          )
          .and not_trigger_internal_events('secrets_manager_trial_started')
      end
    end

    context 'when CDot is unreachable', :saas do
      before do
        allow(client).to receive(:start_secrets_manager_trial)
          .and_raise(::Gitlab::SubscriptionPortal::SecretsManagerStartTrialResponse::Error, 'boom')
      end

      it 'returns a generic unavailable error' do
        post_mutation

        expect(mutation_response['errors']).to contain_exactly(
          Mutations::SecretsManagement::StartTrial::UNAVAILABLE_ERROR
        )
      end
    end

    context 'when targeting a subgroup' do
      let(:target_group) { subgroup }

      it 'returns an argument error and never calls CDot' do
        expect(client).not_to receive(:start_secrets_manager_trial)

        post_mutation

        expect_graphql_errors_to_include(/top-level groups/)
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(secrets_manager_paid_experience: false)
      end

      it 'returns a resource not available error and never calls CDot' do
        expect(client).not_to receive(:start_secrets_manager_trial)

        post_mutation

        expect_graphql_errors_to_include("you don't have permission")
      end
    end

    context 'on a self-managed offline (air-gapped) install' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        allow(::License).to receive(:current).and_return(
          instance_double(License, online_cloud_license?: false, feature_available?: false, plan: nil)
        )
      end

      it 'rejects with the offline error and never calls CDot', :aggregate_failures do
        expect(client).not_to receive(:start_secrets_manager_trial)

        post_mutation

        expect(mutation_response['errors']).to contain_exactly(
          Mutations::SecretsManagement::StartTrial::OFFLINE_ERROR
        )
      end
    end

    context 'on a self-managed install with no license' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        allow(::License).to receive(:current).and_return(nil)
      end

      it 'rejects as ineligible and never calls CDot', :aggregate_failures do
        expect(client).not_to receive(:start_secrets_manager_trial)

        post_mutation

        expect(mutation_response['errors']).to contain_exactly(
          Mutations::SecretsManagement::StartTrial::ERROR_MESSAGES.fetch(:ineligible)
        )
      end
    end

    context 'on a self-managed install with an online cloud license' do
      let(:instance_id) { ::Gitlab::CurrentSettings.uuid }

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        allow(::License).to receive(:current).and_return(
          instance_double(License, online_cloud_license?: true, feature_available?: false, plan: nil)
        )
        allow(client).to receive(:start_secrets_manager_trial)
          .with(instance_id: instance_id)
          .and_return(::Gitlab::SubscriptionPortal::SecretsManagerStartTrialResponse.new(success: true))
        allow(::SecretsManagement::Entitlement).to receive(:for)
          .with(root_group, user: owner)
          .and_return(::SecretsManagement::Entitlement.new(state: :trial, credits_remaining: 1000))
      end

      it 'starts the trial via instance_id and returns the post-trial entitlement', :aggregate_failures do
        post_mutation

        expect(client).to have_received(:start_secrets_manager_trial).with(instance_id: instance_id)
        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty
        expect(mutation_response['entitlement']).to include(
          'state' => 'TRIAL',
          'creditsRemaining' => 1000
        )
      end
    end
  end

  context 'when the current user is only a maintainer' do
    let(:current_user) { maintainer }

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when the current user is not a member' do
    let(:current_user) { non_member }

    it_behaves_like 'a mutation on an unauthorized resource'
  end
end

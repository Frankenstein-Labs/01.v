# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'UpsertFlatUserCap mutation',
  feature_category: :consumables_cost_management do
  include GraphqlHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:non_owner) { create(:user) }
  let_it_be(:root_group) { create(:group, owners: owner) }

  let(:namespace_path) { root_group.full_path }
  let(:flat_user_cap) { 50.0 }
  let(:flat_user_cap_enabled) { true }

  let(:mutation_input) do
    {
      namespace_path: namespace_path,
      flat_user_cap: flat_user_cap,
      flat_user_cap_enabled: flat_user_cap_enabled
    }
  end

  let(:mutation) do
    graphql_mutation(
      :upsert_flat_user_cap,
      mutation_input,
      <<~FIELDS
        flatUserCap
        flatUserCapEnabled
        errors
      FIELDS
    )
  end

  let(:cdot_success_response) do
    {
      success: true,
      subscriptionBudgetCap: {
        flatUserCap: 50.0,
        flatUserCapEnabled: true
      }
    }
  end

  let(:cdot_error_response) do
    {
      success: false,
      errors: ["CDot internal error"]
    }
  end

  shared_examples 'unauthorized user' do
    it 'returns a resource not available error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect_graphql_errors_to_include(
        /does not exist or you don't have permission/
      )
    end
  end

  context 'when namespace path does not exist' do
    let(:current_user) { owner }
    let(:namespace_path) { 'nonexistent-group' }

    it 'returns a resource not available error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect_graphql_errors_to_include(
        /does not exist or you don't have permission/
      )
    end
  end

  context 'when namespace path is a subgroup' do
    let_it_be(:subgroup) { create(:group, parent: root_group) }

    let(:current_user) { owner }
    let(:namespace_path) { subgroup.full_path }

    it 'returns a resource not available error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect_graphql_errors_to_include(
        /does not exist or you don't have permission/
      )
    end
  end

  context 'when SaaS (namespace scope)' do
    let(:current_user) { owner }

    context 'when user is a namespace owner' do
      before do
        allow_next_instance_of(
          Gitlab::SubscriptionPortal::SubscriptionUsageClient
        ) do |client|
          allow(client).to receive(
            :upsert_flat_user_cap
          ).and_return(cdot_success_response)
        end
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :update_subscription_usage_cap do
        let(:user) { owner }
        let(:boundary_object) { root_group }
        let(:mutation) { graphql_mutation(:upsert_flat_user_cap, mutation_input, 'errors') }
        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      it 'returns updated flat user cap values' do
        post_graphql_mutation(mutation, current_user: current_user)

        mutation_response = graphql_mutation_response(
          :upsert_flat_user_cap
        )

        expect(mutation_response['errors']).to be_empty
        expect(mutation_response['flatUserCap']).to eq(50.0)
        expect(mutation_response['flatUserCapEnabled']).to be(true)
      end

      it 'passes correct arguments to CDot client' do
        expect_next_instance_of(
          Gitlab::SubscriptionPortal::SubscriptionUsageClient
        ) do |client|
          expect(client).to receive(
            :upsert_flat_user_cap
          ).with(
            flat_user_cap: 50.0,
            flat_user_cap_enabled: true
          ).and_return(cdot_success_response)
        end

        post_graphql_mutation(mutation, current_user: current_user)
      end

      context 'when CDot returns an error' do
        before do
          allow_next_instance_of(
            Gitlab::SubscriptionPortal::SubscriptionUsageClient
          ) do |client|
            allow(client).to receive(
              :upsert_flat_user_cap
            ).and_return(cdot_error_response)
          end
        end

        it 'propagates CDot errors' do
          post_graphql_mutation(mutation, current_user: current_user)

          mutation_response = graphql_mutation_response(
            :upsert_flat_user_cap
          )

          expect(mutation_response['flatUserCap']).to be_nil
          expect(mutation_response['flatUserCapEnabled']).to be_nil
          expect(mutation_response['errors']).to include(
            "CDot internal error"
          )
        end
      end
    end

    context 'when user is not a namespace owner' do
      let(:current_user) { non_owner }

      it_behaves_like 'unauthorized user'
    end
  end

  context 'when self-managed (instance scope)' do
    let(:mutation_input) do
      {
        flat_user_cap: flat_user_cap,
        flat_user_cap_enabled: flat_user_cap_enabled
      }
    end

    context 'when user is an instance admin', :enable_admin_mode do
      let(:current_user) { admin }

      before do
        allow_next_instance_of(
          Gitlab::SubscriptionPortal::SubscriptionUsageClient
        ) do |client|
          allow(client).to receive(
            :upsert_flat_user_cap
          ).and_return(cdot_success_response)
        end
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :update_subscription_usage_cap do
        let(:user) { admin }
        let(:boundary_object) { :instance }
        let(:mutation) { graphql_mutation(:upsert_flat_user_cap, mutation_input, 'errors') }
        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      it 'returns updated flat user cap values' do
        post_graphql_mutation(mutation, current_user: current_user)

        mutation_response = graphql_mutation_response(
          :upsert_flat_user_cap
        )

        expect(mutation_response['errors']).to be_empty
        expect(mutation_response['flatUserCap']).to eq(50.0)
        expect(mutation_response['flatUserCapEnabled']).to be(true)
      end

      it 'passes correct arguments to CDot client' do
        license = create(:license)
        allow(License).to receive_messages(billable_license: license, current: license)

        expect_next_instance_of(
          Gitlab::SubscriptionPortal::SubscriptionUsageClient,
          license_key: license.data,
          namespace_id: nil
        ) do |client|
          expect(client).to receive(
            :upsert_flat_user_cap
          ).with(
            flat_user_cap: 50.0,
            flat_user_cap_enabled: true
          ).and_return(cdot_success_response)
        end

        post_graphql_mutation(mutation, current_user: current_user)
      end

      context 'when the current license is a trial with an active prior paid license' do
        let(:paid_license) { build(:license, plan: License::PREMIUM_PLAN) }
        let(:trial_license) { build(:license, :ultimate_trial) }

        before do
          allow(License).to receive_messages(billable_license: paid_license, current: trial_license)
        end

        it 'builds the client with the prior paid license key, not the trial key' do
          expect_next_instance_of(
            Gitlab::SubscriptionPortal::SubscriptionUsageClient,
            license_key: paid_license.data,
            namespace_id: nil
          ) do |client|
            expect(client).to receive(
              :upsert_flat_user_cap
            ).and_return(cdot_success_response)
          end

          post_graphql_mutation(mutation, current_user: current_user)
        end
      end

      context 'when the current license is a trial with no prior paid license (trial-only)' do
        let(:trial_license) { build(:license, :ultimate_trial) }

        before do
          allow(License).to receive_messages(billable_license: nil, current: trial_license)
        end

        it 'builds the client with the current trial license key' do
          expect_next_instance_of(
            Gitlab::SubscriptionPortal::SubscriptionUsageClient,
            license_key: trial_license.data,
            namespace_id: nil
          ) do |client|
            expect(client).to receive(
              :upsert_flat_user_cap
            ).and_return(cdot_success_response)
          end

          post_graphql_mutation(mutation, current_user: current_user)
        end
      end

      context 'when no license is present' do
        before do
          allow(License).to receive_messages(billable_license: nil, current: nil)
        end

        it 'returns a resource not available error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect_graphql_errors_to_include(
            /does not exist or you don't have permission/
          )
        end
      end
    end

    context 'when user is not an admin' do
      let(:current_user) { non_owner }

      it_behaves_like 'unauthorized user'
    end
  end

  context 'with negative flat_user_cap value' do
    let(:current_user) { owner }
    let(:flat_user_cap) { -10.0 }

    it 'returns a validation error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect_graphql_errors_to_include(/greater than or equal to 0/)
    end
  end
end

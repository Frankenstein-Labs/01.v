# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'UpsertUserBudgetCapOverrides mutation',
  feature_category: :consumables_cost_management do
  include GraphqlHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:non_owner) { create(:user) }
  let_it_be(:target_user1) { create(:user) }
  let_it_be(:target_user2) { create(:user) }
  let_it_be(:root_group) { create(:group, owners: owner) }
  let_it_be(:non_member_user) { create(:user) }
  let(:namespace_path) { root_group.full_path }
  let(:overrides_input) do
    [
      {
        userId: target_user1.to_global_id.to_s,
        cap: 300.0,
        enabled: true
      },
      {
        userId: target_user2.to_global_id.to_s,
        cap: 150.0,
        enabled: false
      }
    ]
  end

  let(:mutation_input) do
    { namespace_path: namespace_path, overrides: overrides_input }
  end

  let(:mutation) do
    graphql_mutation(
      :upsert_user_budget_cap_overrides,
      mutation_input,
      <<~FIELDS
        userOverrides {
          user { id username }
          cap
          capEnabled
        }
        errors
      FIELDS
    )
  end

  let(:cdot_success_response) do
    {
      success: true,
      userBudgetCapOverrides: [
        {
          entityId: target_user1.id.to_s,
          cap: 300.0,
          capEnabled: true,
          selfManagedInstanceActivationId: nil
        },
        {
          entityId: target_user2.id.to_s,
          cap: 150.0,
          capEnabled: false,
          selfManagedInstanceActivationId: nil
        }
      ]
    }
  end

  let(:cdot_error_response) do
    {
      success: false,
      errors: ["CDot internal error"]
    }
  end

  before_all do
    root_group.add_developer(target_user1)
    root_group.add_developer(target_user2)
  end

  shared_examples 'unauthorized user' do
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
            :upsert_user_budget_cap_overrides
          ).and_return(cdot_success_response)
        end
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :update_subscription_usage_cap do
        let(:user) { owner }
        let(:boundary_object) { root_group }
        let(:mutation) { graphql_mutation(:upsert_user_budget_cap_overrides, mutation_input, 'errors') }
        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      it 'returns updated user overrides' do
        post_graphql_mutation(mutation, current_user: current_user)

        mutation_response = graphql_mutation_response(
          :upsert_user_budget_cap_overrides
        )

        expect(mutation_response['errors']).to be_empty
        expect(mutation_response['userOverrides']).to contain_exactly(
          a_hash_including(
            'cap' => 300.0,
            'capEnabled' => true,
            'user' => a_hash_including(
              'id' => target_user1.to_global_id.to_s,
              'username' => target_user1.username
            )
          ),
          a_hash_including(
            'cap' => 150.0,
            'capEnabled' => false,
            'user' => a_hash_including(
              'id' => target_user2.to_global_id.to_s,
              'username' => target_user2.username
            )
          )
        )
      end

      it 'passes correctly formatted overrides to CDot client' do
        expected_overrides = [
          { entityId: target_user1.id.to_s, capAmount: 300.0, enabled: true },
          { entityId: target_user2.id.to_s, capAmount: 150.0, enabled: false }
        ]

        expect_next_instance_of(
          Gitlab::SubscriptionPortal::SubscriptionUsageClient
        ) do |client|
          expect(client).to receive(
            :upsert_user_budget_cap_overrides
          ).with(overrides: expected_overrides).and_return(
            cdot_success_response
          )
        end

        post_graphql_mutation(mutation, current_user: current_user)
      end

      context 'when CDot returns an error' do
        before do
          allow_next_instance_of(
            Gitlab::SubscriptionPortal::SubscriptionUsageClient
          ) do |client|
            allow(client).to receive(
              :upsert_user_budget_cap_overrides
            ).and_return(cdot_error_response)
          end
        end

        it 'propagates CDot errors' do
          post_graphql_mutation(mutation, current_user: current_user)

          mutation_response = graphql_mutation_response(
            :upsert_user_budget_cap_overrides
          )

          expect(mutation_response['userOverrides']).to be_nil
          expect(mutation_response['errors']).to include(
            "CDot internal error"
          )
        end
      end
    end

    context 'when all userIds are non-existent' do
      let(:overrides_input) do
        [
          {
            userId: "gid://gitlab/User/#{non_existing_record_id}",
            cap: 100.0,
            enabled: true
          }
        ]
      end

      it 'returns an argument error with the missing user IDs' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect_graphql_errors_to_include(
          "Users not found: gid://gitlab/User/#{non_existing_record_id}"
        )
      end

      it 'does not call CDot' do
        expect(
          Gitlab::SubscriptionPortal::SubscriptionUsageClient
        ).not_to receive(:new)

        post_graphql_mutation(mutation, current_user: current_user)
      end
    end

    context 'when some userIds are valid and one is not' do
      let(:overrides_input) do
        [
          {
            userId: target_user1.to_global_id.to_s,
            cap: 300.0,
            enabled: true
          },
          {
            userId: "gid://gitlab/User/#{non_existing_record_id}",
            cap: 100.0,
            enabled: true
          }
        ]
      end

      it 'rejects the entire batch with the missing user IDs' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect_graphql_errors_to_include(
          "Users not found: gid://gitlab/User/#{non_existing_record_id}"
        )
      end
    end

    context 'when user is not a member of the namespace' do
      let(:overrides_input) do
        [
          {
            userId: non_member_user.to_global_id.to_s,
            cap: 100.0,
            enabled: true
          }
        ]
      end

      it 'returns an argument error' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect_graphql_errors_to_include(
          /Users are not part of the namespace/
        )
      end

      it 'does not call CDot' do
        expect(
          Gitlab::SubscriptionPortal::SubscriptionUsageClient
        ).not_to receive(:new)

        post_graphql_mutation(mutation, current_user: current_user)
      end
    end

    context 'when overrides exceed the maximum limit' do
      let(:overrides_input) do
        Array.new(201) do |i|
          {
            userId: target_user1.to_global_id.to_s,
            cap: i.to_f,
            enabled: true
          }
        end
      end

      it 'returns an argument error' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect_graphql_errors_to_include(
          "Cannot upsert more than 200 overrides at once"
        )
      end
    end

    context 'when user is not a namespace owner' do
      let(:current_user) { non_owner }

      it_behaves_like 'unauthorized user'
    end

    context 'with empty overrides array' do
      let(:overrides_input) { [] }

      before do
        allow_next_instance_of(
          Gitlab::SubscriptionPortal::SubscriptionUsageClient
        ) do |client|
          allow(client).to receive(
            :upsert_user_budget_cap_overrides
          ).and_return({ success: true, userBudgetCapOverrides: [] })
        end
      end

      it 'succeeds with empty result' do
        post_graphql_mutation(mutation, current_user: current_user)

        mutation_response = graphql_mutation_response(
          :upsert_user_budget_cap_overrides
        )

        expect(mutation_response['errors']).to be_empty
        expect(mutation_response['userOverrides']).to eq([])
      end
    end

    context 'with duplicate userIds in same batch' do
      let(:overrides_input) do
        [
          {
            userId: target_user1.to_global_id.to_s,
            cap: 300.0,
            enabled: true
          },
          {
            userId: target_user1.to_global_id.to_s,
            cap: 500.0,
            enabled: false
          }
        ]
      end

      before do
        allow_next_instance_of(
          Gitlab::SubscriptionPortal::SubscriptionUsageClient
        ) do |client|
          allow(client).to receive(
            :upsert_user_budget_cap_overrides
          ).and_return(cdot_success_response)
        end
      end

      it 'passes through to CDot without dedup' do
        expect_next_instance_of(
          Gitlab::SubscriptionPortal::SubscriptionUsageClient
        ) do |client|
          expect(client).to receive(
            :upsert_user_budget_cap_overrides
          ).with(
            overrides: [
              {
                entityId: target_user1.id.to_s,
                capAmount: 300.0,
                enabled: true
              },
              {
                entityId: target_user1.id.to_s,
                capAmount: 500.0,
                enabled: false
              }
            ]
          ).and_return(cdot_success_response)
        end

        post_graphql_mutation(mutation, current_user: current_user)
      end
    end
  end

  context 'when self-managed (instance scope)' do
    let(:mutation_input) { { overrides: overrides_input } }
    let(:namespace_path) { nil }

    context 'when user is an instance admin', :enable_admin_mode do
      let(:current_user) { admin }

      before do
        allow_next_instance_of(
          Gitlab::SubscriptionPortal::SubscriptionUsageClient
        ) do |client|
          allow(client).to receive(
            :upsert_user_budget_cap_overrides
          ).and_return(cdot_success_response)
        end
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :update_subscription_usage_cap do
        let(:user) { admin }
        let(:boundary_object) { :instance }
        let(:mutation) { graphql_mutation(:upsert_user_budget_cap_overrides, mutation_input, 'errors') }
        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      it 'returns updated user overrides' do
        post_graphql_mutation(mutation, current_user: current_user)

        mutation_response = graphql_mutation_response(
          :upsert_user_budget_cap_overrides
        )

        expect(mutation_response['errors']).to be_empty
        expect(mutation_response['userOverrides']).to contain_exactly(
          a_hash_including(
            'cap' => 300.0,
            'capEnabled' => true
          ),
          a_hash_including(
            'cap' => 150.0,
            'capEnabled' => false
          )
        )
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
            :upsert_user_budget_cap_overrides
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
              :upsert_user_budget_cap_overrides
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
              :upsert_user_budget_cap_overrides
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

  context 'with negative cap value' do
    let(:current_user) { owner }
    let(:overrides_input) do
      [
        {
          userId: target_user1.to_global_id.to_s,
          cap: -10.0,
          enabled: true
        }
      ]
    end

    it 'returns a validation error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect_graphql_errors_to_include(/greater than or equal to 0/)
    end
  end
end

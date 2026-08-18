# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Upsert a virtual registries cleanup policy', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:params) do
    {
      full_path: group.full_path,
      enabled: true,
      keep_n_days_after_download: 56,
      cadence: 30,
      notify_on_success: true,
      notify_on_failure: true
    }
  end

  let(:mutation_response) { graphql_mutation_response(:virtual_registries_cleanup_policy_upsert) }

  def cleanup_policy_mutation(mutation_params = params)
    graphql_mutation(:virtualRegistriesCleanupPolicyUpsert, mutation_params,
      <<~FIELDS
        errors
        virtualRegistriesCleanupPolicy {
          enabled
          keepNDaysAfterDownload
          cadence
          notifyOnSuccess
          notifyOnFailure
        }
      FIELDS
    )
  end

  before_all do
    group.add_owner(current_user)
  end

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :update_virtual_registry_cleanup_policy do
    let(:user) { current_user }
    let(:boundary_object) { group }
    let(:mutation) { cleanup_policy_mutation }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  it 'creates the virtual registries cleanup policy' do
    expect do
      post_graphql_mutation(cleanup_policy_mutation, current_user: current_user)
    end.to change { ::VirtualRegistries::Cleanup::Policy.for_group(group).count }.from(0).to(1)

    expect(response).to have_gitlab_http_status(:success)
    expect(mutation_response['errors']).to be_empty
    expect(mutation_response['virtualRegistriesCleanupPolicy']).to match(
      a_hash_including(
        'enabled' => true,
        'keepNDaysAfterDownload' => 56,
        'cadence' => 30,
        'notifyOnSuccess' => true,
        'notifyOnFailure' => true
      )
    )
  end
end

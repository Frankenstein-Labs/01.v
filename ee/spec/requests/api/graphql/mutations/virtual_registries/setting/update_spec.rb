# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update the virtual registries setting', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:params) do
    {
      full_path: group.full_path,
      enabled: true
    }
  end

  let(:mutation_response) { graphql_mutation_response(:update_virtual_registries_setting) }

  def setting_mutation(mutation_params = params)
    graphql_mutation(:updateVirtualRegistriesSetting, mutation_params,
      <<~FIELDS
        errors
        virtualRegistriesSetting {
          enabled
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

  it_behaves_like 'authorizing granular token permissions for GraphQL', :update_virtual_registry_setting do
    let(:user) { current_user }
    let(:boundary_object) { group }
    let(:mutation) { setting_mutation }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  it 'updates the virtual registries setting' do
    post_graphql_mutation(setting_mutation, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(mutation_response['errors']).to be_empty
    expect(mutation_response['virtualRegistriesSetting']).to match(
      a_hash_including('enabled' => true)
    )
  end
end

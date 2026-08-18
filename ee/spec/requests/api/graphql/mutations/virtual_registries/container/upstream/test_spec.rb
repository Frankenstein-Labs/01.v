# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Tests a container upstream registry', feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax
  include GraphqlHelpers

  let_it_be(:owner) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be(:upstream) { create(:virtual_registries_container_upstream, registries: [registry]) }

  let(:current_user) { owner }

  let(:mutation_params) do
    {
      group_path: group.full_path,
      url: 'http://example.com'
    }
  end

  let(:mutation_response) { graphql_mutation_response(:container_upstream_test) }

  def container_upstream_test_mutation(params = mutation_params)
    graphql_mutation(:containerUpstreamTest, params)
  end

  before_all do
    group.add_owner(owner)
  end

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(container_virtual_registry: true)
    allow_next_instance_of(::VirtualRegistries::Container::Upstream) do |upstream_instance|
      allow(upstream_instance).to receive(:test).and_return({ success: true })
    end
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL',
    :test_container_virtual_registry_upstream do
    let(:user) { current_user }
    let(:boundary_object) { group }
    let(:mutation) { graphql_mutation(:containerUpstreamTest, mutation_params, 'errors') }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  context 'when identifying the upstream by ID' do
    before do
      allow(Gitlab::HTTP).to receive(:head)
        .and_return(instance_double(HTTParty::Response, code: 200, success?: true, unauthorized?: false))
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL',
      :test_container_virtual_registry_upstream do
      let(:user) { current_user }
      let(:boundary_object) { group }
      let(:mutation_params) { { id: global_id_of(upstream) } }
      let(:mutation) { graphql_mutation(:containerUpstreamTest, mutation_params, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when the granular token is scoped to a group other than the upstream group' do
      let_it_be(:other_group) { create(:group) }

      let(:assignables) do
        ::Authz::PermissionGroups::Assignable
          .for_permission(:test_container_virtual_registry_upstream).map(&:name).uniq
      end

      let(:pat) do
        create(:granular_pat, user: owner, boundary: ::Authz::Boundary.for(other_group), permissions: assignables)
      end

      let(:mutation) do
        graphql_mutation(:containerUpstreamTest, { id: global_id_of(upstream) }, 'errors')
      end

      before_all do
        other_group.add_owner(owner)
      end

      it 'denies access even though the user is a member of both groups' do
        post_graphql_mutation(mutation, token: { personal_access_token: pat })

        expect(graphql_errors).to include(
          a_hash_including('message' => include('requires a fine-grained personal access token'))
        )
      end

      context 'when the groupPath of the token group is passed alongside id' do
        let(:mutation) do
          graphql_mutation(
            :containerUpstreamTest,
            { id: global_id_of(upstream), group_path: other_group.full_path, url: 'http://example.com' },
            'errors'
          )
        end

        it 'still derives the boundary from id and denies access' do
          post_graphql_mutation(mutation, token: { personal_access_token: pat })

          expect(graphql_errors).to include(
            a_hash_including('message' => include('requires a fine-grained personal access token'))
          )
        end
      end
    end
  end

  shared_examples 'returning error message' do
    let(:mutation) { container_upstream_test_mutation }
    let(:error_msg) do
      "The resource that you are attempting to access does " \
        "not exist or you don't have permission to perform this action"
    end

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors).to include(a_hash_including('message' => error_msg))
    end
  end

  it 'returns a successful response' do
    post_graphql_mutation(container_upstream_test_mutation, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(mutation_response).to match(
      a_hash_including(
        'success' => true
      )
    )
  end

  context 'with username and password params' do
    let(:mutation_params) do
      {
        group_path: group.full_path,
        url: 'http://new-example.com',
        username: 'user',
        password: 'test'
      }
    end

    it 'returns a successful response' do
      post_graphql_mutation(container_upstream_test_mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response).to match(
        a_hash_including(
          'success' => true
        )
      )
    end
  end

  context 'when neither id nor group_path and url are provided' do
    let(:mutation_params) { {} }

    it 'returns an argument error' do
      post_graphql_mutation(container_upstream_test_mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors[0]['message']).to eq('Either id or groupPath and url are required')
    end
  end

  context 'when only group_path is provided without url' do
    let(:mutation_params) { { group_path: group.full_path } }

    it 'returns an argument error' do
      post_graphql_mutation(container_upstream_test_mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors[0]['message']).to eq('Either id or groupPath and url are required')
    end
  end

  context 'with missing credentials pair' do
    where(:params, :error_msg) do
      [
        [{ url: 'http://example.com', username: 'user' }, "Password can't be blank"],
        [{ url: 'http://example.com', password: 'test' }, "Username can't be blank"]
      ]
    end

    with_them do
      let(:mutation) { container_upstream_test_mutation(params.merge(group_path: group.full_path)) }

      it 'returns an error' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response).to match(
          a_hash_including(
            'errors' => [error_msg]
          )
        )
      end
    end
  end

  context 'with an existing upstream ID' do
    let(:mutation_params) { { id: global_id_of(upstream) } }

    before do
      allow(Gitlab::HTTP).to receive(:head)
        .and_return(instance_double(HTTParty::Response, code: 200, success?: true, unauthorized?: false))
    end

    it 'returns a successful response' do
      post_graphql_mutation(container_upstream_test_mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response).to match(
        a_hash_including(
          'success' => true
        )
      )
    end

    context 'when the user does not have permission' do
      let(:current_user) { create(:user) }

      it_behaves_like 'returning error message'
    end
  end

  context 'with a non-existent upstream ID' do
    let(:mutation_params) do
      { id: global_id_of(id: non_existing_record_id, model_name: 'VirtualRegistries::Container::Upstream') }
    end

    it_behaves_like 'returning error message'
  end

  context 'when the group does not exist' do
    let(:mutation_params) do
      { group_path: 'missing/group', url: 'http://example.com' }
    end

    it_behaves_like 'returning error message'
  end

  context 'when the user does not have permission to test upstreams' do
    let(:current_user) { create(:user) }

    it_behaves_like 'returning error message'
  end

  context 'with container_virtual_registries feature flag turned off' do
    before do
      stub_feature_flags(container_virtual_registries: false)
    end

    it_behaves_like 'returning error message'
  end

  context 'when container_virtual_registry licensed feature is unavailable' do
    before do
      stub_licensed_features(container_virtual_registry: false)
    end

    it_behaves_like 'returning error message'
  end
end

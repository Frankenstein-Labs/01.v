# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Mutation.securityCategoryCreate', feature_category: :security_asset_inventories do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user) }

  let(:name) { 'Test name' }
  let(:description) { 'Category for testing' }
  let(:multiple_selection) { false }

  let(:arguments) do
    {
      namespace_id: namespace.to_global_id.to_s,
      name: name,
      description: description,
      multiple_selection: multiple_selection
    }
  end

  subject(:mutation) { graphql_mutation(:security_category_create, arguments) }

  def mutation_response
    graphql_mutation_response(:security_category_create)
  end

  before do
    stub_licensed_features(security_attributes: true)
  end

  context 'when the user does not have access' do
    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when the user has access' do
    before_all do
      namespace.add_maintainer(current_user)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_security_category do
      let(:user) { current_user }
      let(:boundary_object) { namespace }
      let(:mutation) { graphql_mutation(:security_category_create, arguments, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when a granular token is scoped to a subgroup but the category is created on the root' do
      let_it_be(:subgroup) { create(:group, parent: namespace) }

      let(:arguments) do
        {
          namespace_id: subgroup.to_global_id.to_s,
          name: name,
          description: description,
          multiple_selection: multiple_selection
        }
      end

      let(:pat) do
        create(:granular_pat, user: current_user, boundary: ::Authz::Boundary.for(subgroup),
          permissions: [::Authz::PermissionGroups::Assignable.for_permission(:create_security_category).first.name])
      end

      it 'denies access because the boundary resolves to the root ancestor' do
        expect do
          post_graphql_mutation(mutation, token: { personal_access_token: pat })
        end.not_to change { Security::Category.count }

        expect(graphql_errors).to be_present
      end
    end

    it 'creates the security category successfully' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to change { Security::Category.count }.by(1 + Security::DefaultCategoriesHelper.default_categories.length)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty

      category = mutation_response['securityCategory']
      expect(category).to include(
        'name' => name,
        'description' => description,
        'multipleSelection' => multiple_selection
      )
      expect(category['id']).to be_present
    end

    context 'with minimal parameters' do
      let(:arguments) do
        {
          namespace_id: namespace.to_global_id.to_s,
          name: name
        }
      end

      it 'creates the category with defaults' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        category = mutation_response['securityCategory']
        expect(category['name']).to eq(name)
        expect(category['description']).to be_blank
        expect(category['multipleSelection']).to be(false)
      end
    end

    context 'when name is missing' do
      let(:arguments) do
        {
          namespace_id: namespace.to_global_id.to_s,
          description: description
        }
      end

      it_behaves_like 'a mutation that returns top-level errors',
        errors: [/Expected value to not be null/]
    end

    context 'when namespace_id is nil' do
      let(:arguments) do
        {
          namespace_id: nil,
          name: name
        }
      end

      it_behaves_like 'a mutation that returns top-level errors',
        errors: [/Expected value to not be null/]
    end

    context 'when namespace does not exist' do
      let(:arguments) do
        {
          namespace_id: "gid://gitlab/Group/#{non_existing_record_id}",
          name: name
        }
      end

      it_behaves_like 'a mutation that returns top-level errors',
        errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
    end

    context 'when namespace is a project' do
      let_it_be(:project) { create(:project) }

      let(:arguments) do
        {
          namespace_id: project.to_global_id.to_s,
          name: name
        }
      end

      before_all do
        project.add_maintainer(current_user)
      end

      it_behaves_like 'an invalid argument to the mutation', argument_name: :namespace_id
    end

    context 'when a category with the same name already exists' do
      before do
        create(:security_category, namespace: namespace, name: name)
      end

      it 'returns error' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['securityCategory']).to be_nil
        expect(mutation_response['errors']).to include(/Failed to create security category/)
      end
    end

    it 'ensures predefined categories are created' do
      expect_next_instance_of(Security::Categories::CreatePredefinedService) do |service|
        expect(service).to receive(:execute).and_call_original
      end

      post_graphql_mutation(mutation, current_user: current_user)
    end
  end

  context 'with different user roles' do
    context 'when user is owner' do
      before_all do
        namespace.add_owner(current_user)
      end

      it 'creates the category successfully' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty
        expect(mutation_response['securityCategory']).to be_present
      end
    end

    context 'when user is developer' do
      before_all do
        namespace.add_developer(current_user)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'when user is guest' do
      before_all do
        namespace.add_guest(current_user)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end
  end
end

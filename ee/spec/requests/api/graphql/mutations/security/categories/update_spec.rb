# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Mutation.securityCategoryUpdate', feature_category: :security_asset_inventories do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:existing_category) do
    create(:security_category, namespace: namespace, name: 'Original Name', editable_state: :editable)
  end

  let_it_be(:predefined_category) do
    create(:security_category, namespace: namespace, template_type: :business_unit, name: 'Business Unit')
  end

  let(:name) { 'Updated name' }
  let(:description) { 'Updated description' }

  let(:arguments) do
    {
      id: existing_category.to_global_id.to_s,
      namespace_id: namespace.to_global_id.to_s,
      name: name,
      description: description
    }
  end

  subject(:mutation) { graphql_mutation(:security_category_update, arguments) }

  def mutation_response
    graphql_mutation_response(:security_category_update)
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

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_security_category do
      let(:user) { current_user }
      let(:boundary_object) { namespace }
      let(:mutation) { graphql_mutation(:security_category_update, arguments, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when the category belongs to a different namespace than the boundary argument' do
      let_it_be(:other_namespace) { create(:group) }
      let_it_be(:other_category) do
        create(:security_category, namespace: other_namespace, name: 'Other Name', editable_state: :editable)
      end

      let(:arguments) do
        {
          id: other_category.to_global_id.to_s,
          namespace_id: namespace.to_global_id.to_s,
          name: name
        }
      end

      it 'does not update the category from the other namespace' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.not_to change { other_category.reload.name }

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to include('Category not found')
        expect(mutation_response['securityCategory']).to be_nil
      end
    end

    context 'when updating by id' do
      it 'updates the security category successfully' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        category = mutation_response['securityCategory']
        expect(category).to include(
          'id' => existing_category.to_global_id.to_s,
          'name' => name,
          'description' => description
        )
      end

      context 'with minimal parameters' do
        let(:arguments) do
          {
            id: existing_category.to_global_id.to_s,
            namespace_id: namespace.to_global_id.to_s,
            description: description
          }
        end

        it 'updates only provided fields' do
          post_graphql_mutation(mutation, current_user: current_user)

          category = mutation_response['securityCategory']
          expect(category['description']).to eq(description)
          expect(category['name']).to eq('Original Name')
        end
      end

      context 'when category does not exist' do
        let(:arguments) do
          {
            id: "gid://gitlab/Security::Category/#{non_existing_record_id}",
            namespace_id: namespace.to_global_id.to_s,
            name: name
          }
        end

        it 'returns error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to include('Category not found')
          expect(mutation_response['securityCategory']).to be_nil
        end
      end
    end

    context 'when updating by template type' do
      let(:arguments) do
        {
          id: 'gid://gitlab/Security::Category/business_unit',
          namespace_id: namespace.to_global_id.to_s,
          name: name
        }
      end

      it 'returns error when trying to update non editable predefined category' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to include('This category is not editable')
        expect(mutation_response['securityCategory']).to be_nil
      end

      it 'ensures predefined categories are created' do
        expect_next_instance_of(Security::Categories::CreatePredefinedService) do |service|
          expect(service).to receive(:execute).and_call_original
        end

        post_graphql_mutation(mutation, current_user: current_user)
      end
    end

    context 'when namespace does not exist' do
      let(:arguments) do
        {
          id: 'gid://gitlab/Security::Category/business_unit',
          namespace_id: "gid://gitlab/Group/#{non_existing_record_id}",
          name: name
        }
      end

      it_behaves_like 'a mutation that returns top-level errors',
        errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
    end

    context 'when updating with invalid data' do
      let(:arguments) do
        {
          id: existing_category.to_global_id.to_s,
          namespace_id: namespace.to_global_id.to_s,
          name: ''
        }
      end

      it 'returns validation error' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['securityCategory']).to be_nil
        expect(mutation_response['errors']).to include(/Failed to update security category/)
      end
    end
  end

  context 'with different user roles' do
    context 'when user is owner' do
      before_all do
        namespace.add_owner(current_user)
      end

      let(:arguments) do
        {
          id: existing_category.to_global_id.to_s,
          namespace_id: namespace.to_global_id.to_s,
          name: name
        }
      end

      it 'updates the category successfully' do
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

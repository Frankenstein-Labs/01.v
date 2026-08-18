# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Mutation.securityAttributeUpdate', feature_category: :security_asset_inventories do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:category) { create(:security_category, namespace: namespace, editable_state: :editable) }
  let_it_be(:attribute) do
    create(:security_attribute,
      security_category: category,
      namespace: namespace,
      name: 'Original Name',
      description: 'Original Description',
      color: '#FF0000',
      editable_state: :editable
    )
  end

  let(:name) { 'Updated Name' }
  let(:description) { 'Updated Description' }
  let(:color) { '#00FF00' }

  let(:arguments) do
    {
      id: attribute.to_global_id.to_s,
      name: name,
      description: description,
      color: color
    }
  end

  subject(:mutation) { graphql_mutation(:security_attribute_update, arguments) }

  def mutation_response
    graphql_mutation_response(:security_attribute_update)
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

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_security_attribute do
      let(:user) { current_user }
      let(:boundary_object) { namespace }
      let(:mutation) { graphql_mutation(:security_attribute_update, arguments, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    it 'updates the security attribute successfully' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty

      updated_attribute = mutation_response['securityAttribute']
      expect(updated_attribute).to include(
        'id' => attribute.to_global_id.to_s,
        'name' => name,
        'description' => description,
        'color' => color
      )
    end

    context 'with minimal parameters' do
      let(:arguments) do
        {
          id: attribute.to_global_id.to_s,
          description: description
        }
      end

      it 'updates only provided fields' do
        post_graphql_mutation(mutation, current_user: current_user)

        updated_attribute = mutation_response['securityAttribute']
        expect(updated_attribute['description']).to eq(description)
        expect(updated_attribute['name']).to eq('Original Name')
        expect(updated_attribute['color']).to eq('#FF0000')
      end
    end

    context 'when attribute does not exist' do
      let(:arguments) do
        {
          id: "gid://gitlab/Security::Attribute/#{non_existing_record_id}",
          name: name
        }
      end

      it_behaves_like 'a mutation that returns top-level errors',
        errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
    end

    context 'when attribute is not editable' do
      let(:locked_attribute) do
        create(:security_attribute,
          security_category: category,
          namespace: namespace,
          editable_state: :locked
        )
      end

      let(:arguments) do
        {
          id: locked_attribute.to_global_id.to_s,
          name: name
        }
      end

      it 'does not update the attribute' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response['errors']).to match_array(['Cannot update non editable attribute'])
        expect(mutation_response['securityAttribute']).to be_nil

        locked_attribute.reload
        expect(locked_attribute.name).not_to eq(name)
      end
    end

    context 'when updating with invalid data' do
      context 'with empty name' do
        let(:arguments) do
          {
            id: attribute.to_global_id.to_s,
            name: ''
          }
        end

        it 'returns validation error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['securityAttribute']).to be_nil
          expect(mutation_response['errors']).to include(/Failed to update security attribute/)
          expect(mutation_response['errors'].join).to include("Name can't be blank")
        end
      end

      context 'with invalid color' do
        let(:arguments) do
          {
            id: attribute.to_global_id.to_s,
            color: 'invalid-color'
          }
        end

        it_behaves_like 'a mutation that returns top-level errors', errors: [/Not a color/]
      end

      context 'with duplicate name within category' do
        let!(:other_attribute) do
          create(:security_attribute,
            security_category: category,
            namespace: namespace,
            name: 'Existing Name'
          )
        end

        let(:arguments) do
          {
            id: attribute.to_global_id.to_s,
            name: 'Existing Name'
          }
        end

        it 'returns uniqueness error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_response['securityAttribute']).to be_nil
          expect(mutation_response['errors']).to include(/Failed to update security attribute/)
          expect(mutation_response['errors'].join).to include('has already been taken')
        end
      end

      context 'with description too long' do
        let(:arguments) do
          {
            id: attribute.to_global_id.to_s,
            description: 'a' * 256
          }
        end

        it 'returns length validation error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_response['securityAttribute']).to be_nil
          expect(mutation_response['errors']).to include(/Failed to update security attribute/)
          expect(mutation_response['errors'].join).to include('Description is too long')
        end
      end
    end
  end

  context 'with different user roles' do
    context 'when user is owner' do
      before_all do
        namespace.add_owner(current_user)
      end

      it 'updates the attribute successfully' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty
        expect(mutation_response['securityAttribute']).to be_present
      end
    end

    context 'when user is maintainer' do
      before_all do
        namespace.add_maintainer(current_user)
      end

      it 'updates the attribute successfully' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response['errors']).to be_empty
        expect(mutation_response['securityAttribute']).to be_present
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

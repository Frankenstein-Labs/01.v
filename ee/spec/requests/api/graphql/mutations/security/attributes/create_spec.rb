# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Mutation.securityAttributeCreate', feature_category: :security_asset_inventories do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:category) { create(:security_category, namespace: namespace, editable_state: :editable) }

  let(:attributes_input) do
    [
      {
        name: 'Critical',
        description: 'Critical security level requiring immediate attention',
        color: '#FF0000'
      },
      {
        name: 'High',
        description: 'High security level with significant risk',
        color: '#FF8C00'
      }
    ]
  end

  let(:arguments) do
    {
      category_id: category.to_global_id.to_s,
      namespace_id: namespace.to_global_id.to_s,
      attributes: attributes_input
    }
  end

  subject(:mutation) { graphql_mutation(:security_attribute_create, arguments) }

  def mutation_response
    graphql_mutation_response(:security_attribute_create)
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

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_security_attribute do
      let(:user) { current_user }
      let(:boundary_object) { namespace }
      let(:mutation) { graphql_mutation(:security_attribute_create, arguments, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when the category belongs to a different namespace than the boundary argument' do
      let_it_be(:other_namespace) { create(:group) }
      let_it_be(:other_category) do
        create(:security_category, namespace: other_namespace, editable_state: :editable)
      end

      let(:arguments) do
        {
          category_id: other_category.to_global_id.to_s,
          namespace_id: namespace.to_global_id.to_s,
          attributes: attributes_input
        }
      end

      it 'does not create attributes under the category from the other namespace' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.not_to change { Security::Attribute.count }
      end

      it_behaves_like 'a mutation that returns top-level errors',
        errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
    end

    context 'when creating with category_id' do
      it 'creates security attributes successfully' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { Security::Attribute.count }.by(2)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        attributes = mutation_response['securityAttributes']
        expect(attributes).to have_attributes(size: 2)

        expect(attributes.first).to include(
          'name' => 'Critical',
          'description' => 'Critical security level requiring immediate attention',
          'color' => '#FF0000',
          'editableState' => 'EDITABLE'
        )

        expect(attributes.first['securityCategory']).to include(
          'id' => category.to_global_id.to_s,
          'name' => category.name
        )
      end

      context 'when category does not exist' do
        let(:arguments) do
          {
            category_id: "gid://gitlab/Security::Category/#{non_existing_record_id}",
            namespace_id: namespace.to_global_id.to_s,
            attributes: attributes_input
          }
        end

        it_behaves_like 'a mutation that returns top-level errors',
          errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
      end

      context 'when category is not editable' do
        let(:locked_category) { create(:security_category, namespace: namespace, editable_state: :locked, name: "abc") }
        let(:arguments) do
          {
            category_id: locked_category.to_global_id.to_s,
            namespace_id: namespace.to_global_id.to_s,
            attributes: attributes_input
          }
        end

        it 'does not create attributes' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.not_to change { Security::Attribute.count }

          expect(mutation_response['errors']).to match_array(["You can not edit this category's attributes."])
        end
      end
    end

    context 'when creating with template_type embedded in category_id' do
      let(:arguments) do
        {
          category_id: "gid://gitlab/Security::Category/application",
          namespace_id: namespace.to_global_id.to_s,
          attributes: attributes_input
        }
      end

      before do
        allow(Security::Category).to receive_message_chain(:by_namespace, :exists?).and_return(false)
      end

      it 'creates security attributes successfully' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { Security::Attribute.count }
          .by(2 +
          Security::DefaultCategoriesHelper.default_categories.sum { |category| category.security_attributes.size })

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        attributes = mutation_response['securityAttributes']
        expect(attributes).to have_attributes(size: 2)

        expect(attributes.first).to include(
          'name' => 'Critical',
          'description' => 'Critical security level requiring immediate attention',
          'color' => '#FF0000',
          'editableState' => 'EDITABLE'
        )

        expect(attributes.first['securityCategory']).to be_present
        expect(attributes.first['securityCategory']['name']).to be_present
      end

      context 'when namespace does not exist' do
        let(:arguments) do
          {
            category_id: "gid://gitlab/Security::Category/application",
            namespace_id: "gid://gitlab/Group/#{non_existing_record_id}",
            attributes: attributes_input
          }
        end

        it_behaves_like 'a mutation that returns top-level errors',
          errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
      end
    end

    context 'when creating with invalid attribute data' do
      context 'with empty name' do
        let(:attributes_input) do
          [
            {
              name: '',
              description: 'Test description',
              color: '#FF0000'
            }
          ]
        end

        it 'returns validation error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['securityAttributes']).to be_nil
          expect(mutation_response['errors']).to include(/Failed to create security attributes/)
          expect(mutation_response['errors'].join).to include("Name can't be blank")
        end
      end

      context 'with invalid color' do
        let(:attributes_input) do
          [
            {
              name: 'Test',
              description: 'Test description',
              color: 'invalid-color'
            }
          ]
        end

        it_behaves_like 'a mutation that returns top-level errors', errors: [/Not a color/]
      end

      context 'with duplicate name within category' do
        let!(:existing_attribute) do
          create(:security_attribute,
            security_category: category,
            name: 'Critical',
            namespace: namespace
          )
        end

        it 'returns uniqueness error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_response['securityAttributes']).to be_nil
          expect(mutation_response['errors']).to include(/Failed to create security attributes/)
          expect(mutation_response['errors'].join).to include('has already been taken')
        end
      end

      context 'with missing description' do
        let(:attributes_input) do
          [
            {
              name: 'Test',
              color: '#FF0000'
            }
          ]
        end

        it_behaves_like 'a mutation that returns top-level errors',
          errors: [/invalid value for attributes/]
      end
    end

    context 'when exceeding attribute limit' do
      let(:stubbed_limit) { 5 }
      let(:attributes_input) do
        [
          {
            name: 'Extra Attribute',
            description: 'Should not be allowed',
            color: '#123456'
          },
          {
            name: 'Another One',
            description: 'Also too much',
            color: '#654321'
          }
        ]
      end

      before do
        stub_const('Security::Category::MAX_ATTRIBUTES', stubbed_limit)
        create_list(:security_attribute, stubbed_limit - 1, security_category: category, namespace: namespace)
      end

      it_behaves_like 'a mutation that returns top-level errors',
        errors: ["Category cannot have more than 5 attributes."]
    end

    context 'when the category has soft-deleted attributes' do
      let(:stubbed_limit) { 2 }

      before do
        stub_const('Security::Category::MAX_ATTRIBUTES', stubbed_limit)
        create_list(:security_attribute, stubbed_limit, security_category: category, namespace: namespace,
          deleted_at: Time.current)
      end

      it 'does not count soft-deleted attributes towards the limit' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { Security::Attribute.not_deleted.count }.by(2)

        expect(mutation_response['errors']).to be_empty
      end
    end
  end

  context 'with different user roles' do
    context 'when user is owner' do
      before_all do
        namespace.add_owner(current_user)
      end

      it 'creates attributes successfully' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { Security::Attribute.count }.by(2)

        expect(mutation_response['errors']).to be_empty
        expect(mutation_response['securityAttributes']).to be_present
      end
    end

    context 'when user is maintainer' do
      before_all do
        namespace.add_maintainer(current_user)
      end

      it 'creates attributes successfully' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { Security::Attribute.count }.by(2)

        expect(mutation_response['errors']).to be_empty
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

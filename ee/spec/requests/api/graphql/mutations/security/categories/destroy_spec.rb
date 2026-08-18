# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Mutation.securityCategoryDestroy', feature_category: :security_asset_inventories do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:category) { create(:security_category, namespace: namespace, editable_state: :editable) }

  let_it_be(:editable_attribute) do
    create(:security_attribute,
      security_category: category,
      namespace: namespace,
      editable_state: :editable,
      name: 'Critical Attribute')
  end

  let_it_be(:locked_category) do
    create(:security_category,
      namespace: namespace,
      editable_state: :locked,
      name: 'Locked Category')
  end

  let(:category_id) { category.to_global_id.to_s }
  let(:arguments) do
    {
      id: category_id
    }
  end

  let(:mutation) { graphql_mutation(:security_category_destroy, arguments) }

  def mutation_response
    graphql_mutation_response(:security_category_destroy)
  end

  shared_examples 'successfully destroys category' do |category_method = :category|
    it 'destroys category successfully' do
      test_category = send(category_method)
      expected_category_gid = test_category.to_global_id.to_s

      # Get attribute GIDs before deletion
      expected_attribute_gids = test_category.security_attributes.map { |attr| attr.to_global_id.to_s }

      mutation = graphql_mutation(:security_category_destroy, { id: test_category.to_global_id })

      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['deletedCategoryGid']).to eq(expected_category_gid)
      expect(mutation_response['deletedAttributesGid']).to match_array(expected_attribute_gids)

      test_category.reload
      expect(test_category.deleted_at).to be_present
      expect(test_category.deleted?).to be true

      expected_attribute_gids.each do |attr_gid|
        attr_id = GlobalID.parse(attr_gid).model_id
        attribute = Security::Attribute.unscoped.find_by(id: attr_id)
        expect(attribute).to be_present
        expect(attribute.deleted_at).to be_present
        expect(attribute.deleted?).to be true
      end
    end
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

    it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_security_category do
      let(:user) { current_user }
      let(:boundary_object) { namespace }
      let(:mutation) { graphql_mutation(:security_category_destroy, arguments, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when destroying an editable category' do
      it_behaves_like 'successfully destroys category'
    end

    context 'when trying to destroy a locked category' do
      let(:category_id) { locked_category.to_global_id.to_s }

      it 'returns an error and does not destroy the category' do
        mutation = graphql_mutation(:security_category_destroy, arguments)

        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.not_to change { Security::Category.count }

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['deletedCategoryGid']).to be_nil
        expect(mutation_response['deletedAttributesGid']).to be_nil
        expect(mutation_response['errors']).to include('Cannot delete non-editable category')

        # Verify category was not deleted
        expect(Security::Category.exists?(locked_category.id)).to be_truthy
      end
    end

    context 'when category belongs to inaccessible namespace' do
      let_it_be(:other_namespace) { create(:group) }
      let_it_be(:other_category) { create(:security_category, namespace: other_namespace, editable_state: :editable) }

      let(:category_id) { other_category.to_global_id.to_s }

      it_behaves_like 'a mutation that returns top-level errors',
        errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
    end

    context 'when category ID does not exist' do
      let(:category_id) { "gid://gitlab/Security::Category/#{non_existing_record_id}" }

      it_behaves_like 'a mutation that returns top-level errors',
        errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
    end

    context 'with categories from different namespaces' do
      let_it_be(:other_namespace) { create(:group) }
      let(:category_id) { other_category.to_global_id.to_s }
      let_it_be(:other_category) do
        create(:security_category, namespace: other_namespace, name: 'Other Namespace Category',
          editable_state: :editable)
      end

      before_all do
        other_namespace.add_maintainer(current_user)
      end

      it_behaves_like 'successfully destroys category', :other_category
    end

    context 'with different category types' do
      let_it_be(:editable_attributes_category) do
        create(:security_category,
          namespace: namespace,
          editable_state: :editable_attributes,
          name: 'Editable Attributes Category')
      end

      let(:category_id) { editable_attributes_category.to_global_id.to_s }

      it_behaves_like 'successfully destroys category', :editable_attributes_category
    end

    context 'when category has multiple attributes' do
      let_it_be_with_reload(:category_with_multiple_attrs) do
        create(:security_category, namespace: namespace, name: 'Multi Attr Category', editable_state: :editable)
      end

      let_it_be(:first_attribute) do
        create(:security_attribute,
          security_category: category_with_multiple_attrs,
          namespace: namespace,
          editable_state: :editable,
          name: 'First Attribute')
      end

      let_it_be(:second_attribute) do
        create(:security_attribute,
          security_category: category_with_multiple_attrs,
          namespace: namespace,
          editable_state: :editable,
          name: 'Second Attribute')
      end

      let(:category_id) { category_with_multiple_attrs.to_global_id.to_s }

      it_behaves_like 'successfully destroys category', :category_with_multiple_attrs
    end

    context 'when category has no attributes' do
      let_it_be(:empty_category) do
        create(:security_category, namespace: namespace, name: 'Empty Category', editable_state: :editable)
      end

      let(:category_id) { empty_category.to_global_id.to_s }

      it_behaves_like 'successfully destroys category', :empty_category
    end
  end

  context 'with different user roles' do
    context 'when user is owner' do
      before_all do
        namespace.add_owner(current_user)
      end

      it_behaves_like 'successfully destroys category'
    end

    context 'when user is maintainer' do
      before_all do
        namespace.add_maintainer(current_user)
      end

      it_behaves_like 'successfully destroys category'
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

  context 'when deletion fails due to database constraints' do
    before_all do
      namespace.add_owner(current_user)
    end

    before do
      allow_next_instance_of(Security::Categories::DestroyService) do |service|
        allow(service).to receive(:execute).and_return(
          ServiceResponse.error(
            message: 'Failed to delete category: Database constraint violation',
            payload: ['Failed to delete category: Database constraint violation']
          )
        )
      end
    end

    it 'returns an error with the failure message' do
      mutation = graphql_mutation(:security_category_destroy, arguments)

      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.not_to change { Security::Category.count }

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['deletedCategoryGid']).to be_nil
      expect(mutation_response['deletedAttributesGid']).to be_nil
      expect(mutation_response['errors']).to include('Failed to delete category: Database constraint violation')
    end
  end

  context 'when attribute deletion fails' do
    before_all do
      namespace.add_owner(current_user)
    end

    before do
      allow_next_instance_of(Security::Categories::DestroyService) do |service|
        allow(service).to receive(:execute).and_return(
          ServiceResponse.error(
            message: 'Failed to delete category: Attribute deletion failed',
            payload: ['Failed to delete category: Attribute deletion failed']
          )
        )
      end
    end

    it 'returns an error with the failure message' do
      mutation = graphql_mutation(:security_category_destroy, arguments)

      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.not_to change { Security::Category.count }

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['deletedCategoryGid']).to be_nil
      expect(mutation_response['deletedAttributesGid']).to be_nil
      expect(mutation_response['errors']).to include('Failed to delete category: Attribute deletion failed')
    end
  end
end

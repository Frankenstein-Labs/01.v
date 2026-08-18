# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Mutation.securityAttributeDestroy', feature_category: :security_asset_inventories do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:category) { create(:security_category, namespace: namespace, editable_state: :editable) }

  let_it_be(:editable_attribute) do
    create(:security_attribute,
      security_category: category,
      namespace: namespace,
      editable_state: :editable,
      name: 'Critical')
  end

  let_it_be(:locked_attribute) do
    create(:security_attribute,
      security_category: category,
      namespace: namespace,
      editable_state: :locked,
      name: 'Locked')
  end

  let(:attribute_id) { editable_attribute.to_global_id.to_s }

  let(:arguments) do
    {
      id: attribute_id
    }
  end

  let(:mutation) { graphql_mutation(:security_attribute_destroy, arguments) }

  def mutation_response
    graphql_mutation_response(:security_attribute_destroy)
  end

  shared_examples 'successfully destroys attribute' do |attribute_method = :editable_attribute|
    it 'destroys attribute successfully' do
      attribute = send(attribute_method)
      expected_gid = attribute.to_global_id.to_s

      mutation = graphql_mutation(:security_attribute_destroy, arguments)

      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { Security::Attribute.not_deleted.count }.by(-1)
                                                             .and not_change { Security::Attribute.unscoped.count }

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['deletedAttributeGid'].to_s).to eq(expected_gid)

      attribute.reload
      expect(attribute.deleted_at).to be_present
      expect(attribute.deleted?).to be true
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

    it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_security_attribute do
      let(:user) { current_user }
      let(:boundary_object) { namespace }
      let(:mutation) { graphql_mutation(:security_attribute_destroy, arguments, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when destroying an editable attribute' do
      it_behaves_like 'successfully destroys attribute'
    end

    context 'when trying to destroy a locked attribute' do
      let(:attribute_id) { locked_attribute.to_global_id.to_s }

      it 'returns an error and does not destroy the attribute' do
        mutation = graphql_mutation(:security_attribute_destroy, arguments)

        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.not_to change { Security::Attribute.count }

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['deletedAttributeGid']).to be_nil
        expect(mutation_response['errors']).to include('Cannot delete non-editable attribute')

        # Verify attribute was not deleted
        expect(Security::Attribute.exists?(locked_attribute.id)).to be_truthy
      end
    end

    context 'when attribute belongs to inaccessible namespace' do
      let_it_be(:other_namespace) { create(:group) }
      let_it_be(:other_category) { create(:security_category, namespace: other_namespace, editable_state: :editable) }
      let_it_be(:other_attribute) do
        create(:security_attribute,
          security_category: other_category,
          namespace: other_namespace,
          editable_state: :editable,
          name: 'Other Namespace Attribute')
      end

      let(:attribute_id) { other_attribute.to_global_id.to_s }

      it_behaves_like 'a mutation that returns top-level errors',
        errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
    end

    context 'when attribute ID does not exist' do
      let(:attribute_id) { "gid://gitlab/Security::Attribute/#{non_existing_record_id}" }

      it_behaves_like 'a mutation that returns top-level errors',
        errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
    end

    context 'with attributes from different categories' do
      let_it_be(:other_category) { create(:security_category, namespace: namespace, name: 'Other Category') }
      let_it_be(:other_attribute) do
        create(:security_attribute,
          security_category: other_category,
          namespace: namespace,
          editable_state: :editable,
          name: 'Other Category Attribute')
      end

      let(:attribute_id) { other_attribute.to_global_id.to_s }

      it_behaves_like 'successfully destroys attribute', :other_attribute
    end

    context 'with different editable states' do
      let_it_be(:editable_attributes_attribute) do
        create(:security_attribute,
          security_category: category,
          namespace: namespace,
          editable_state: :editable_attributes,
          name: 'Editable Attributes')
      end

      let(:attribute_id) { editable_attributes_attribute.to_global_id.to_s }

      it_behaves_like 'successfully destroys attribute', :editable_attributes_attribute
    end
  end

  context 'with different user roles' do
    context 'when user is owner' do
      before_all do
        namespace.add_owner(current_user)
      end

      it_behaves_like 'successfully destroys attribute'
    end

    context 'when user is maintainer' do
      before_all do
        namespace.add_maintainer(current_user)
      end

      it_behaves_like 'successfully destroys attribute'
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
      allow_next_instance_of(Security::Attributes::DestroyService) do |service|
        allow(service).to receive(:execute).and_return(
          ServiceResponse.error(
            message: 'Failed to delete attributes: Database constraint violation',
            payload: ['Failed to delete attributes: Database constraint violation']
          )
        )
      end
    end

    it 'returns an error with the failure message' do
      mutation = graphql_mutation(:security_attribute_destroy, arguments)

      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.not_to change { Security::Attribute.count }

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['deletedAttributeGid']).to be_nil
      expect(mutation_response['errors']).to include('Failed to delete attributes: Database constraint violation')
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Security::Attributes::ProjectUpdate, feature_category: :security_asset_inventories do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:other_project) { create(:project, namespace: namespace) }
  let_it_be(:root_namespace) { namespace.root_ancestor }
  let_it_be(:arguments) { mutation_args }

  def create_category(name, multi: false)
    category_selection = multi ? :multi_selection : :single_selection
    create(:security_category, category_selection, namespace: root_namespace, name: name)
  end

  def create_attribute(category, name)
    create(:security_attribute, security_category: category, name: name, namespace: root_namespace)
  end

  def mutation_args(**overrides)
    { project_id: project.to_global_id.to_s }.merge(overrides)
  end

  def mutation_result
    graphql_mutation_response(:security_attribute_project_update)
  end

  subject(:mutation) { graphql_mutation(:security_attribute_project_update, arguments) }

  before do
    stub_licensed_features(security_attributes: true)
  end

  describe '#resolve' do
    context 'when user does not have permission' do
      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'when user has permission' do
      before_all do
        namespace.add_maintainer(current_user)
      end

      describe 'adding and removing attributes by id' do
        let_it_be(:single_category) { create_category("single_selection") }
        let_it_be(:critical_attr) { create_attribute(single_category, 'Critical') }
        let_it_be(:high_attr) { create_attribute(single_category, 'High') }
        let_it_be(:medium_attr) { create_attribute(single_category, 'Medium') }

        let_it_be(:multi_category) { create_category("multi_selection", multi: true) }
        let_it_be(:tag1_attr) { create_attribute(multi_category, 'Tag1') }
        let_it_be(:tag2_attr) { create_attribute(multi_category, 'Tag2') }

        let_it_be(:other_category) { create_category("other") }
        let_it_be(:other_attr) { create_attribute(other_category, 'Other') }

        it_behaves_like 'authorizing granular token permissions for GraphQL', :update_security_attribute do
          let(:user) { current_user }
          let(:boundary_object) { project }
          let(:arguments) { mutation_args(add_attribute_ids: [critical_attr.to_global_id.to_s]) }
          let(:mutation) { graphql_mutation(:security_attribute_project_update, arguments, 'errors') }
          let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
        end

        context 'when adding single attribute from single-selection category' do
          let(:arguments) { mutation_args(add_attribute_ids: [critical_attr.to_global_id.to_s]) }

          it 'adds attribute successfully' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { project.reload.security_attribute_ids.count }.by(1)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_result).not_to be_nil
            expect(mutation_result['project']['id']).to eq(project.to_global_id.to_s)
            expect(mutation_result['addedCount']).to eq(1)
            expect(mutation_result['removedCount']).to eq(0)
            expect(mutation_result['errors']).to be_empty

            expect(project.security_attribute_ids).to include(critical_attr.id)
          end

          context 'when attribute is already attached' do
            before do
              create(:project_to_security_attribute, project: project, security_attribute: critical_attr)
            end

            it 'does not add duplicate attributes' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
              end.not_to change { project.reload.security_attribute_ids.count }

              expect(mutation_result['addedCount']).to eq(0)
              expect(project.security_attribute_ids).to include(critical_attr.id)
            end
          end
        end

        context 'when adding multiple attributes from single-selection category' do
          let(:arguments) do
            mutation_args(add_attribute_ids: [critical_attr.to_global_id.to_s, high_attr.to_global_id.to_s])
          end

          it 'fails with category constraint error' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_result['errors']).to include('Invalid attributes')
            expect(project.reload.security_attribute_ids).to be_empty
          end
        end

        context 'when adding multiple attributes from multiple selection category' do
          let(:arguments) do
            mutation_args(add_attribute_ids: [tag1_attr.to_global_id.to_s, tag2_attr.to_global_id.to_s])
          end

          it 'adds all attributes successfully' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { project.reload.security_attribute_ids.count }.by(2)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_result['addedCount']).to eq(2)
            expect(mutation_result['removedCount']).to eq(0)
            expect(mutation_result['errors']).to be_empty

            expect(project.security_attribute_ids).to include(tag1_attr.id, tag2_attr.id)
          end
        end

        context 'when adding attributes from multiple categories' do
          let(:arguments) do
            mutation_args(add_attribute_ids: [critical_attr.to_global_id.to_s, other_attr.to_global_id.to_s])
          end

          it 'adds attributes from different categories successfully' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { project.reload.security_attribute_ids.count }.by(2)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_result['addedCount']).to eq(2)
            expect(mutation_result['removedCount']).to eq(0)
            expect(mutation_result['errors']).to be_empty

            expect(project.security_attribute_ids).to include(critical_attr.id, other_attr.id)
          end
        end

        context 'when attribute does not exist' do
          let(:arguments) do
            mutation_args(add_attribute_ids: ["gid://gitlab/Security::Attribute/#{non_existing_record_id}"])
          end

          it 'returns an error for missing attributes' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_result['errors']).to include('Invalid attributes')
            expect(mutation_result['project']).to be_nil
          end
        end

        context 'when removing attributes by id' do
          let!(:project_attribute1) do
            create(:project_to_security_attribute, project: project, security_attribute: critical_attr)
          end

          let!(:project_attribute2) do
            create(:project_to_security_attribute, project: project, security_attribute: other_attr)
          end

          let(:arguments) { mutation_args(remove_attribute_ids: [critical_attr.to_global_id.to_s]) }

          it 'removes attributes successfully' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { project.reload.security_attribute_ids.count }.by(-1)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_result).not_to be_nil
            expect(mutation_result['addedCount']).to eq(0)
            expect(mutation_result['removedCount']).to eq(1)
            expect(mutation_result['errors']).to be_empty

            expect(project.security_attribute_ids).not_to include(critical_attr.id)
            expect(project.security_attribute_ids).to include(other_attr.id)
          end

          context 'when attribute is not attached to project' do
            let(:arguments) { mutation_args(remove_attribute_ids: [medium_attr.to_global_id.to_s]) }

            it 'returns the correct response' do
              post_graphql_mutation(mutation, current_user: current_user)

              expect(response).to have_gitlab_http_status(:success)
              expect(mutation_result['removedCount']).to eq(0)
            end
          end
        end

        context 'when replacing attributes from same single-selection category' do
          let!(:project_attribute) do
            create(:project_to_security_attribute, project: project, security_attribute: critical_attr)
          end

          let(:arguments) do
            mutation_args(
              add_attribute_ids: [high_attr.to_global_id.to_s],
              remove_attribute_ids: [critical_attr.to_global_id.to_s]
            )
          end

          it 'successfully replaces attribute within same category' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.not_to change { project.reload.security_attribute_ids.count }

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_result).not_to be_nil
            expect(mutation_result['addedCount']).to eq(1)
            expect(mutation_result['removedCount']).to eq(1)
            expect(mutation_result['errors']).to be_empty

            expect(project.security_attribute_ids).not_to include(critical_attr.id)
            expect(project.security_attribute_ids).to include(high_attr.id)
          end
        end
      end

      describe 'adding attributes by template type' do
        let(:template_gid) { "gid://gitlab/Security::Attribute/business_critical" }

        context 'when using template-based Global IDs' do
          let(:arguments) { mutation_args(add_attribute_ids: [template_gid]) }

          it 'adds attributes by template type successfully' do
            expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
              .with(
                project: project,
                current_user: current_user,
                params: {
                  attributes: {
                    add_attribute_ids: [a_kind_of(Numeric)],
                    remove_attribute_ids: []
                  }
                }
              )
              .and_call_original

            post_graphql_mutation(mutation, current_user: current_user)
            expect(response).to have_gitlab_http_status(:success)
          end
        end

        context 'when fails to create predefined attributes' do
          let(:arguments) { mutation_args(add_attribute_ids: [template_gid]) }
          let(:error_message) { 'Failed to create predefined categories' }

          before do
            allow(Security::Categories::CreatePredefinedService).to receive(:new)
              .with(namespace: root_namespace, current_user: current_user)
              .and_return(instance_double(Security::Categories::CreatePredefinedService,
                execute: ServiceResponse.error(message: error_message)))
          end

          it 'returns predefined service error' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_result['errors']).to include(error_message)
            expect(mutation_result['project']).to be_nil
          end
        end
      end

      describe 'mixing persisted ids and template type ids' do
        let_it_be(:category) { create_category("mixed_test") }
        let_it_be(:existing_attr) { create_attribute(category, "ExistingAttr") }
        let_it_be(:critical_attr) do
          create(:security_attribute, security_category: category, name: 'Business Critical', namespace: root_namespace,
            template_type: :business_critical)
        end

        let(:template_gid) { "gid://gitlab/Security::Attribute/business_critical" }

        context 'when using both persisted id and template-based id' do
          let(:arguments) do
            mutation_args(add_attribute_ids: [existing_attr.to_global_id.to_s, template_gid])
          end

          it 'processes both persisted and template attributes' do
            expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
              .with(
                project: project,
                current_user: current_user,
                params: {
                  attributes: {
                    add_attribute_ids: an_array_matching([existing_attr.id, critical_attr.id]),
                    remove_attribute_ids: []
                  }
                }
              )
              .and_call_original

            post_graphql_mutation(mutation, current_user: current_user)
            expect(response).to have_gitlab_http_status(:success)
          end
        end

        context 'when same attribute comes from both persisted ID and template' do
          let(:arguments) do
            mutation_args(add_attribute_ids: [existing_attr.to_global_id.to_s, template_gid])
          end

          before do
            allow(Security::Attribute).to receive_message_chain(:by_namespace, :by_template_type, :pluck_id)
              .and_return([existing_attr.id])
          end

          it 'removes duplicates after processing templates' do
            expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
              .with(
                project: project,
                current_user: current_user,
                params: {
                  attributes: {
                    add_attribute_ids: [existing_attr.id],
                    remove_attribute_ids: []
                  }
                }
              )
              .and_call_original

            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
          end
        end
      end

      describe 'argument validation' do
        context 'when no attributes arguments are provided' do
          let(:arguments) { mutation_args }

          it 'returns validation error' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_result['addedCount']).to be_nil
            expect(mutation_result['removedCount']).to be_nil
            expect(mutation_result['errors']).to include("No attributes found for addition or removal")
          end
        end
      end

      describe 'service error handling' do
        let_it_be(:category) { create_category("TestCategory") }
        let_it_be(:test_attr) { create_attribute(category, "TestAttr") }

        let(:arguments) { mutation_args(add_attribute_ids: [test_attr.to_global_id.to_s]) }
        let(:error_message) { 'Service failed unexpectedly' }

        before do
          service_instance = instance_double(Security::Attributes::UpdateProjectAttributesService)
          allow(Security::Attributes::UpdateProjectAttributesService).to receive(:new).and_return(service_instance)
          allow(service_instance).to receive(:execute).and_return(ServiceResponse.error(message: error_message))
        end

        it 'returns service errors in response' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_result['errors']).to include(error_message)
          expect(mutation_result['project']).to be_nil
          expect(mutation_result['addedCount']).to be_nil
          expect(mutation_result['removedCount']).to be_nil
        end
      end

      describe 'attribute limits' do
        let(:limit) { 50 }
        let(:too_many_ids) { Array.new(limit + 1) { |i| "gid://gitlab/Security::Attribute/#{i + 1}" } }

        context 'when exceeding add limit' do
          let(:arguments) { mutation_args(add_attribute_ids: too_many_ids) }

          before do
            service_instance = instance_double(Security::Attributes::UpdateProjectAttributesService)
            allow(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
              .and_return(service_instance)
            allow(service_instance).to receive(:execute)
              .and_return(ServiceResponse.error(message: "Cannot process more than #{limit} attributes at once"))
          end

          it 'returns limit error' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_result['errors']).to include("Cannot process more than #{limit} attributes at once")
          end
        end

        context 'when exceeding combined add and remove limit' do
          let(:half_limit_ids) { Array.new(26) { |i| "gid://gitlab/Security::Attribute/#{i + 1}" } }

          let(:arguments) do
            mutation_args(
              add_attribute_ids: half_limit_ids,
              remove_attribute_ids: half_limit_ids
            )
          end

          before do
            service_instance = instance_double(Security::Attributes::UpdateProjectAttributesService)
            allow(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
              .and_return(service_instance)
            allow(service_instance).to receive(:execute)
              .and_return(ServiceResponse.error(message: "Cannot process more than #{limit} attributes at once"))
          end

          it 'returns limit error for combined operations' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_result['errors']).to include("Cannot process more than #{limit} attributes at once")
          end
        end
      end
    end
  end
end

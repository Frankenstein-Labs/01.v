# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'BulkUpdateSecurityAttributes', feature_category: :security_asset_inventories do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project1) { create(:project, namespace: namespace) }
  let_it_be(:project2) { create(:project, namespace: namespace) }
  let_it_be(:subgroup) { create(:group, parent: namespace) }
  let_it_be(:subproject) { create(:project, namespace: subgroup) }
  let_it_be(:root_namespace) { namespace.root_ancestor }

  let_it_be(:category) { create(:security_category, namespace: root_namespace, name: 'Test Category') }
  let_it_be(:attribute1) do
    create(:security_attribute, security_category: category, name: 'Critical', namespace: root_namespace)
  end

  let_it_be(:attribute2) do
    create(:security_attribute, security_category: category, name: 'High', namespace: root_namespace)
  end

  let(:items) { [project1.to_global_id.to_s, project2.to_global_id.to_s] }
  let(:attributes) { [attribute1.to_global_id.to_s, attribute2.to_global_id.to_s] }
  let(:mode) { 'ADD' }

  let(:mutation) do
    graphql_mutation(
      :bulk_update_security_attributes,
      {
        items: items,
        attributes: attributes,
        mode: mode
      }
    )
  end

  def mutation_result
    graphql_mutation_response(:bulk_update_security_attributes)
  end

  before do
    stub_licensed_features(security_attributes: true)
  end

  describe 'GraphQL mutation' do
    context 'when user does not have permission' do
      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'when user has permission' do
      before_all do
        namespace.add_maintainer(current_user)
      end

      context 'with valid arguments' do
        it 'schedules bulk update scheduler worker' do
          expect(Security::Attributes::BulkUpdateSchedulerWorker).to receive(:perform_async)
            .with([], [project1.id, project2.id], [attribute1.id, attribute2.id], 'ADD', current_user.id)

          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_result['errors']).to be_empty
        end

        it 'returns success response' do
          allow(Security::Attributes::BulkUpdateSchedulerWorker).to receive(:perform_async)

          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_result).not_to be_nil
          expect(mutation_result['errors']).to be_empty
        end
      end

      context 'with REMOVE mode' do
        let(:mode) { 'REMOVE' }

        it 'schedules scheduler worker with correct mode' do
          expect(Security::Attributes::BulkUpdateSchedulerWorker).to receive(:perform_async)
            .with([], [project1.id, project2.id], [attribute1.id, attribute2.id], 'REMOVE', current_user.id)

          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
        end
      end

      context 'with REPLACE mode' do
        let(:mode) { 'REPLACE' }

        it 'schedules scheduler worker with correct mode' do
          expect(Security::Attributes::BulkUpdateSchedulerWorker).to receive(:perform_async)
            .with([], [project1.id, project2.id], [attribute1.id, attribute2.id], 'REPLACE', current_user.id)

          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
        end
      end

      context 'with groups in items' do
        let(:items) { [namespace.to_global_id.to_s] }

        it 'schedules scheduler worker with group GIDs' do
          expect(Security::Attributes::BulkUpdateSchedulerWorker).to receive(:perform_async)
            .with([namespace.id], [], [attribute1.id, attribute2.id], 'ADD', current_user.id)

          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
        end
      end

      context 'with mixed groups and projects' do
        let(:items) { [namespace.to_global_id.to_s, project1.to_global_id.to_s] }

        it 'schedules scheduler worker with all GIDs' do
          expect(Security::Attributes::BulkUpdateSchedulerWorker).to receive(:perform_async)
            .with([namespace.id], [project1.id], [attribute1.id, attribute2.id], 'ADD', current_user.id)

          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
        end
      end

      context 'when service returns error' do
        before do
          allow_next_instance_of(Security::Attributes::BulkUpdateService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'Service failed'))
          end
        end

        it 'returns error in response' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_result['errors']).to include('Service failed')
        end
      end

      context 'when validating arguments' do
        context 'when items is empty' do
          let(:items) { [] }

          it 'returns validation error' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_present
            expect(graphql_errors.first['message']).to include('Items cannot be empty')
          end
        end

        context 'when attributes is empty' do
          let(:attributes) { [] }

          it 'returns validation error' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_present
            expect(graphql_errors.first['message']).to include('Attributes cannot be empty')
          end
        end

        context 'when mode is invalid' do
          let(:mode) { 'INVALID' }

          it 'returns GraphQL validation error' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_present
            expect(graphql_errors.first['message']).to include('INVALID')
          end
        end

        context 'when too many items provided' do
          let(:items) do
            Array.new(Mutations::Security::Attributes::BulkUpdate::MAX_ITEMS + 1) do
              project1.to_global_id.to_s
            end
          end

          it 'returns validation error from prepare step' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_present
            expect(graphql_errors.first['message']).to include('Too many items (maximum: 100)')
          end
        end

        context 'when too many attributes provided' do
          let(:attributes) do
            Array.new(Mutations::Security::Attributes::BulkUpdate::MAX_ATTRIBUTES + 1) do
              attribute1.to_global_id.to_s
            end
          end

          it 'returns validation error' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_present
            expect(graphql_errors.first['message']).to include('Too many attributes (maximum: 20)')
          end
        end
      end

      context 'with invalid Global IDs' do
        context 'when item ID is invalid' do
          let(:items) { ['invalid-gid'] }

          it 'returns GraphQL error' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_present
            expect(graphql_errors.first['message']).to include('invalid-gid')
          end
        end

        context 'when attribute ID is invalid' do
          let(:attributes) { ['invalid-gid'] }

          it 'returns GraphQL error' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_present
            expect(graphql_errors.first['message']).to include('invalid-gid')
          end
        end
      end

      context 'when attribute does not exist' do
        let(:attributes) { ["gid://gitlab/Security::Attribute/#{non_existing_record_id}"] }

        it 'returns GraphQL error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_present
          expect(graphql_errors.first['message']).to include('does not exist')
        end
      end

      context 'when attribute is soft deleted' do
        let(:deleted_attribute) do
          create(:security_attribute, security_category: category, name: 'Deleted',
            namespace: root_namespace, deleted_at: Time.current)
        end

        let(:attributes) { [deleted_attribute.to_global_id.to_s] }

        it 'returns a resource not available error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_present
          expect(graphql_errors.first['message']).to include("does not exist")
        end
      end

      context 'when some attributes are soft deleted' do
        let(:deleted_attribute) do
          create(:security_attribute, security_category: category, name: 'Deleted',
            namespace: root_namespace, deleted_at: Time.current)
        end

        let(:attributes) { [attribute1.to_global_id.to_s, deleted_attribute.to_global_id.to_s] }

        it 'returns a resource not available error for the first deleted attribute' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_present
          expect(graphql_errors.first['message']).to include("does not exist")
        end
      end

      context 'when user lacks permission for some items' do
        let_it_be(:other_namespace) { create(:group) }
        let_it_be(:other_project) { create(:project, namespace: other_namespace) }
        let(:items) { [project1.to_global_id.to_s, other_project.to_global_id.to_s] }

        it 'schedules scheduler worker with all provided GIDs' do
          expect(Security::Attributes::BulkUpdateSchedulerWorker).to receive(:perform_async)
            .with([], [project1.id, other_project.id], [attribute1.id, attribute2.id], 'ADD', current_user.id)

          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_result['errors']).to be_empty
        end
      end

      context 'when no accessible projects found' do
        let_it_be(:inaccessible_project) { create(:project) }
        let(:items) { [inaccessible_project.to_global_id.to_s] }

        it 'schedules scheduler worker and lets it handle the filtering' do
          expect(Security::Attributes::BulkUpdateSchedulerWorker).to receive(:perform_async)
            .with([], [inaccessible_project.id], [attribute1.id, attribute2.id], 'ADD', current_user.id)

          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_result['errors']).to be_empty
        end
      end

      context 'with large number of projects requiring batching' do
        let(:projects) { create_list(:project, 5, namespace: namespace) }
        let(:items) { projects.map { |p| p.to_global_id.to_s } }

        it 'schedules scheduler worker to handle batching' do
          expect(Security::Attributes::BulkUpdateSchedulerWorker).to receive(:perform_async)
            .with([], projects.map(&:id), [attribute1.id, attribute2.id], 'ADD', current_user.id)

          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_result['errors']).to be_empty
        end
      end
    end
  end
end

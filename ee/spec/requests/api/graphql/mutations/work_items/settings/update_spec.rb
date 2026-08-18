# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating work item settings', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:group_owner) { create(:user, maintainer_of: group, owner_of: group.organization) }

  let(:full_path) { group.full_path }
  let(:current_user) { group_owner }
  let(:customizable_type_visibility) { true }
  let(:params) do
    {
      full_path: full_path,
      customizable_type_visibility: customizable_type_visibility
    }
  end

  let(:mutation) { graphql_mutation(:work_item_settings_update, params) }
  let(:mutation_response) { graphql_mutation_response(:work_item_settings_update) }
  let(:unauthorized_error_message) do
    "The resource that you are attempting to access does not exist or you don't have permission to perform this action"
  end

  before do
    stub_licensed_features(configurable_work_item_types: true)
  end

  context 'when on SaaS' do
    before do
      stub_saas_features(namespace_scoped_work_item_types: true)
    end

    context 'when user is group maintainer' do
      it 'creates a settings record scoped to the root namespace' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { WorkItems::Settings.count }.by(1)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty
        expect(mutation_response['workItemSettings']).to include(
          'customizableTypeVisibility' => true
        )
        expect(mutation_response['errors']).to be_empty

        settings = WorkItems::Settings.last
        expect(settings.namespace_id).to eq(group.id)
        expect(settings.organization_id).to be_nil
      end

      context 'when disabling customizable type visibility' do
        let(:customizable_type_visibility) { false }

        it 'creates a settings record with customizable_type_visibility: false' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect_graphql_errors_to_be_empty
          expect(mutation_response['errors']).to be_empty

          settings = WorkItems::Settings.last
          expect(settings.customizable_type_visibility).to be false
        end
      end

      context 'when a settings record already exists' do
        let!(:existing_settings) do
          create(:work_item_settings, namespace: group, customizable_type_visibility: false)
        end

        it 'updates the existing record' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.not_to change { WorkItems::Settings.count }

          expect(response).to have_gitlab_http_status(:success)
          expect_graphql_errors_to_be_empty
          expect(mutation_response['errors']).to be_empty
          expect(existing_settings.reload.customizable_type_visibility).to be true
        end
      end

      context 'when full_path belongs to a project' do
        let(:full_path) { project.full_path }

        it 'returns authorization error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect_graphql_errors_to_include(unauthorized_error_message)
        end
      end

      context 'when customizable_type_visibility is not provided' do
        let(:params) { { full_path: full_path } }

        it 'creates a record with the database default value' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.to change { WorkItems::Settings.count }.by(1)

          expect(response).to have_gitlab_http_status(:success)
          expect_graphql_errors_to_be_empty
          expect(mutation_response['errors']).to be_empty

          settings = WorkItems::Settings.last
          expect(settings.customizable_type_visibility).to be false
        end

        context 'when a settings record already exists' do
          let!(:existing_settings) do
            create(:work_item_settings, namespace: group, customizable_type_visibility: true)
          end

          it 'does not change the existing value' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.not_to change { existing_settings.reload.customizable_type_visibility }

            expect(response).to have_gitlab_http_status(:success)
            expect_graphql_errors_to_be_empty
            expect(mutation_response['errors']).to be_empty
            expect(mutation_response['workItemSettings']).to include(
              'customizableTypeVisibility' => true
            )
          end
        end
      end

      context 'when the settings record fails to save' do
        before do
          allow_next_instance_of(WorkItems::Settings) do |settings|
            settings.errors.add(:base, 'something went wrong')
            allow(settings).to receive(:save).and_return(false)
          end
        end

        it 'returns errors' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect_graphql_errors_to_be_empty
          expect(mutation_response['workItemSettings']).to be_nil
          expect(mutation_response['errors']).to include('something went wrong')
        end
      end

      context 'when a concurrent request causes a unique constraint violation' do
        let(:customizable_type_visibility) { false }

        before do
          allow_next_instance_of(WorkItems::Settings) do |settings|
            allow(settings).to receive(:save).and_wrap_original do |_method|
              create(:work_item_settings, namespace: group, customizable_type_visibility: true)
              raise ActiveRecord::RecordNotUnique, 'duplicate key'
            end
          end
        end

        it 'retries and updates the existing record' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect_graphql_errors_to_be_empty
          expect(mutation_response['errors']).to be_empty
          expect(mutation_response['workItemSettings']).to include(
            'customizableTypeVisibility' => false
          )
        end

        context 'when the retry also fails validation' do
          before do
            allow_any_instance_of(WorkItems::Settings).to receive(:update).and_wrap_original do |method, *_args| # rubocop:disable RSpec/AnyInstanceOf -- need to stub the persisted instance found in retry
              method.receiver.errors.add(:base, 'validation failed on retry')
              false
            end
          end

          it 'returns errors from the retry' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect_graphql_errors_to_be_empty
            expect(mutation_response['workItemSettings']).to be_nil
            expect(mutation_response['errors']).to include('validation failed on retry')
          end
        end
      end
    end

    context 'when user is a developer' do
      let_it_be(:developer) { create(:user, developer_of: group) }
      let(:current_user) { developer }

      it 'returns authorization error' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_include(unauthorized_error_message)
      end
    end
  end

  context 'when on self-managed' do
    context 'when user is org owner' do
      it 'creates a settings record scoped to the organization' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { WorkItems::Settings.count }.by(1)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty
        expect(mutation_response['workItemSettings']).to include(
          'customizableTypeVisibility' => true
        )
        expect(mutation_response['errors']).to be_empty

        settings = WorkItems::Settings.last
        expect(settings.organization_id).to eq(group.organization_id)
        expect(settings.namespace_id).to be_nil
      end

      context 'when a settings record already exists' do
        let!(:existing_settings) do
          create(:work_item_settings,
            namespace: nil,
            organization: group.organization,
            customizable_type_visibility: false
          )
        end

        it 'updates the existing record' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.not_to change { WorkItems::Settings.count }

          expect(response).to have_gitlab_http_status(:success)
          expect_graphql_errors_to_be_empty
          expect(mutation_response['errors']).to be_empty
          expect(existing_settings.reload.customizable_type_visibility).to be true
        end
      end
    end

    context 'when user is group maintainer and org guest' do
      let_it_be(:group_maintainer) { create(:user, maintainer_of: group) }
      let(:current_user) { group_maintainer }

      it 'returns nil for work item settings' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty
        expect(mutation_response['workItemSettings']).to be_nil
      end
    end
  end

  context 'when full_path is omitted (organization-level)' do
    let(:params) { { customizable_type_visibility: true } }

    it 'creates a settings record scoped to the current organization' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { WorkItems::Settings.count }.by(1)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty
      expect(mutation_response['workItemSettings']).to include(
        'customizableTypeVisibility' => true
      )
      expect(mutation_response['errors']).to be_empty

      settings = WorkItems::Settings.last
      expect(settings.organization_id).to eq(current_organization.id)
      expect(settings.namespace_id).to be_nil
    end
  end

  context 'when namespace is a subgroup' do
    let(:full_path) { subgroup.full_path }

    it 'returns authorization error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end

  context 'when full_path is not valid' do
    let(:full_path) { 'invalid/path' }

    it 'returns authorization error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end

  context 'when licensed feature is not available' do
    before do
      stub_licensed_features(configurable_work_item_types: false)
    end

    it 'returns authorization error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Attaching a work item type to a custom lifecycle', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  let(:work_item_type) { build(:work_item_system_defined_type, :issue) }
  let(:requirement_work_item_type) { build(:work_item_system_defined_type, :requirement) }
  let(:target_lifecycle) { create(:work_item_custom_lifecycle, namespace: group) }
  let(:work_item_type_id) { work_item_type.to_gid }
  let(:lifecycle_id) { target_lifecycle.to_gid }
  let(:namespace_path) { group.full_path }

  let(:params) do
    {
      namespace_path: namespace_path,
      work_item_type_id: work_item_type_id,
      lifecycle_id: lifecycle_id
    }
  end

  let(:unauthorized_error_message) do
    "The resource that you are attempting to access does not exist or you don't have permission to perform this action"
  end

  let(:mutation) { graphql_mutation(:lifecycle_attach_work_item_type, params) }
  let(:mutation_response) { graphql_mutation_response(:lifecycle_attach_work_item_type) }

  before do
    stub_licensed_features(work_item_status: true)
  end

  context 'when custom lifecycle exists' do
    let!(:current_lifecycle) { create(:work_item_custom_lifecycle, :for_issues, namespace: group) }

    it 'attaches work item type to target lifecycle' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty

      expect(mutation_response['lifecycle']).to match(
        a_hash_including(
          'id' => target_lifecycle.to_gid.to_s,
          'name' => target_lifecycle.name
        )
      )

      expect(target_lifecycle.reload.work_item_types).to include(work_item_type)
    end

    context 'when status of current lifecycle is still in use' do
      let!(:work_item) { create(:work_item, namespace: group) }

      before do
        create(:work_item_current_status, namespace: group, custom_status: current_lifecycle.default_open_status)
      end

      it 'returns error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to include(
          "Cannot remove status '#{current_lifecycle.default_open_status.name}' from lifecycle " \
            "because it is in use and no mapping is provided"
        )
      end
    end

    context 'with status mappings' do
      let!(:current_status) { create(:work_item_custom_status, namespace: group) }
      let!(:target_status) { create(:work_item_custom_status, namespace: group) }

      let(:params) do
        super().merge(
          status_mappings: [
            {
              old_status_id: current_status.to_gid,
              new_status_id: target_status.to_gid
            }
          ]
        )
      end

      before do
        create(:work_item_custom_lifecycle_status,
          lifecycle: current_lifecycle, status: current_status, namespace: group)
        create(:work_item_custom_lifecycle_status,
          lifecycle: target_lifecycle, status: target_status, namespace: group)
      end

      it 'creates status mappings' do
        expect { post_graphql_mutation(mutation, current_user: user) }
          .to change { WorkItems::Statuses::Custom::Mapping.count }.by(1)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty

        mapping = WorkItems::Statuses::Custom::Mapping.last
        expect(mapping).to have_attributes(
          namespace_id: group.id,
          work_item_type_id: work_item_type.id,
          old_status_id: current_status.id,
          new_status_id: target_status.id
        )
      end

      context 'and status does not exist' do
        let(:old_status_id) { current_status.to_gid }
        let(:new_status_id) { target_status.to_gid }
        let(:params) do
          super().merge(
            status_mappings: [
              {
                old_status_id: old_status_id,
                new_status_id: new_status_id
              }
            ]
          )
        end

        context 'for old status' do
          let(:old_status_id) { 'gid://gitlab/WorkItems::Statuses::Custom::Status/999999' }

          it 'returns error' do
            post_graphql_mutation(mutation, current_user: user)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_response['errors']).to include(
              "Status #{old_status_id} is not part of the lifecycle or doesn't exist."
            )
          end
        end

        context 'for new status' do
          let(:new_status_id) { 'gid://gitlab/WorkItems::Statuses::Custom::Status/999999' }

          it 'returns error' do
            post_graphql_mutation(mutation, current_user: user)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_response['errors']).to include(
              "Couldn't find WorkItems::Statuses::Custom::Status with 'id'=999999"
            )
          end
        end
      end
    end

    context 'when target lifecycle is system-defined lifecycle' do
      let(:lifecycle_id) { build(:work_item_system_defined_lifecycle).to_gid }

      it 'returns error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to include(
          'Work item types can only be attached to custom lifecycles.'
        )
      end
    end

    context 'when target lifecycle belongs to different group' do
      let!(:other_group) { create(:group) }
      let!(:other_lifecycle) { create(:work_item_custom_lifecycle, namespace: other_group) }
      let(:lifecycle_id) { other_lifecycle.to_gid }

      it 'returns error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to include(
          "You don't have permission to attach work item types to this lifecycle."
        )
      end
    end

    context 'when target lifecycle is the same as current lifecycle' do
      let(:lifecycle_id) { current_lifecycle.to_gid }

      it 'returns error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to include(
          'Work item type is already attached to this lifecycle.'
        )
      end
    end

    context 'when work item type does not support the status feature' do
      let(:work_item_type_id) { requirement_work_item_type.to_gid }

      it 'returns error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to include(
          "Work item type doesn't support the status widget."
        )
      end
    end

    context 'when lifecycle does not exist' do
      let!(:current_lifecycle) { create(:work_item_custom_lifecycle, :for_issues, namespace: group) }

      let(:lifecycle_id) { 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/999999' }

      it 'returns error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to include(
          match(/Couldn't find WorkItems::Statuses::Custom::Lifecycle/)
        )
      end
    end
  end

  context 'when invalid input is provided' do
    context 'when required arguments are missing' do
      let(:params) { { namespace_path: namespace_path } }

      it 'returns validation error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_include(
          match(/was provided invalid value.*workItemTypeId.*Expected value to not be null/)
        )
        expect_graphql_errors_to_include(
          match(/was provided invalid value.*lifecycleId.*Expected value to not be null/)
        )
      end
    end

    context 'when namespace uses system-defined lifecycle' do
      it 'returns error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to include(
          'Work item types can only be attached to custom lifecycles.'
        )
      end
    end
  end

  context 'when user is unauthorized' do
    it 'returns error' do
      guest = create(:user, guest_of: group)

      post_graphql_mutation(mutation, current_user: guest)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end

  context 'when namespace is a subgroup' do
    let_it_be(:subgroup) { create(:group, :private, parent: group) }
    let_it_be(:subgroup_maintainer) { create(:user, maintainer_of: subgroup) }

    let(:namespace_path) { subgroup.full_path }

    it 'returns error' do
      post_graphql_mutation(mutation, current_user: subgroup_maintainer)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end
end

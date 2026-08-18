# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating a custom lifecycle', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  let_it_be(:system_defined_lifecycle) { WorkItems::Statuses::SystemDefined::Lifecycle.all.first }
  let_it_be(:system_defined_in_progress_status) { build(:work_item_system_defined_status, :in_progress) }
  let_it_be(:system_defined_wont_do_status) { build(:work_item_system_defined_status, :wont_do) }

  let(:namespace_path) { group.full_path }
  let(:params) do
    {
      namespace_path: namespace_path,
      id: system_defined_lifecycle.to_gid,
      statuses: [
        status_params_for(system_defined_lifecycle.default_open_status),
        status_params_for(system_defined_in_progress_status),
        status_params_for(system_defined_lifecycle.default_closed_status),
        status_params_for(system_defined_wont_do_status),
        status_params_for(system_defined_lifecycle.default_duplicate_status)
      ],
      default_open_status_index: 0,
      default_closed_status_index: 2,
      default_duplicate_status_index: 4
    }
  end

  let(:unauthorized_error_message) do
    "The resource that you are attempting to access does not exist or you don't have permission to perform this action"
  end

  let(:mutation) { graphql_mutation(:lifecycle_update, params) }
  let(:mutation_response) { graphql_mutation_response(:lifecycle_update) }

  before do
    stub_licensed_features(work_item_status: true)
  end

  context 'when custom lifecycle does not exist' do
    let(:lifecycle_name) { system_defined_lifecycle.name }

    shared_examples 'successful custom lifecycle creation' do
      it 'creates a custom lifecycle' do
        post_graphql_mutation(mutation, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty

        expect(mutation_response['lifecycle']).to match(
          a_hash_including(
            'name' => lifecycle_name,
            'statuses' => include(
              a_hash_including('name' => system_defined_lifecycle.default_open_status.name),
              a_hash_including('name' => system_defined_in_progress_status.name),
              a_hash_including('name' => system_defined_lifecycle.default_closed_status.name),
              a_hash_including('name' => system_defined_wont_do_status.name),
              a_hash_including('name' => system_defined_lifecycle.default_duplicate_status.name)
            )
          )
        )
      end

      it_behaves_like 'successful custom lifecycle creation'

      context 'when name param is provided' do
        let(:lifecycle_name) { 'Changed lifecycle name' }

        let(:params) do
          super().merge(name: lifecycle_name)
        end

        it_behaves_like 'successful custom lifecycle creation'
      end
    end
  end

  context 'when custom lifecycle exists' do
    let!(:custom_lifecycle) do
      create(:work_item_custom_lifecycle, name: system_defined_lifecycle.name, namespace: group)
    end

    context 'when system-defined lifecycle is provided' do
      it 'returns an error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to include(
          'Invalid lifecycle type. Custom lifecycle already exists.'
        )
      end
    end

    context 'when custom lifecycle is provided' do
      let!(:existing_in_progress_status) do
        create(:work_item_custom_status, name: 'In Progress', category: :in_progress, namespace: group)
      end

      let!(:lifecycle_status) do
        create(:work_item_custom_lifecycle_status,
          lifecycle: custom_lifecycle, status: existing_in_progress_status, namespace: group)
      end

      let(:lifecycle_name) { "Changed lifecycle name" }

      let(:params) do
        {
          namespace_path: group.full_path,
          id: custom_lifecycle.to_gid,
          name: lifecycle_name,
          statuses: [
            {
              name: 'Ready for development', # new default open status
              color: '#737278',
              description: nil,
              category: 'TO_DO'
            },
            status_params_for(custom_lifecycle.default_open_status),
            status_params_for(existing_in_progress_status),
            {
              name: 'Complete', # new default closed status
              color: '#108548',
              description: nil,
              category: 'DONE'
            },
            status_params_for(custom_lifecycle.default_closed_status),
            status_params_for(custom_lifecycle.default_duplicate_status)
          ],
          default_open_status_index: 0,
          default_closed_status_index: 3,
          default_duplicate_status_index: 5
        }
      end

      before do
        custom_lifecycle.default_open_status.name = "To do"
      end

      it 'updates the lifecycle' do
        post_graphql_mutation(mutation, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty

        expect(mutation_response['lifecycle']).to match(
          a_hash_including(
            'name' => lifecycle_name,
            'statuses' => include(
              a_hash_including('name' => 'Ready for development'),
              a_hash_including('name' => 'To do'),
              a_hash_including('name' => existing_in_progress_status.name),
              a_hash_including('name' => 'Complete'),
              a_hash_including('name' => custom_lifecycle.default_closed_status.name),
              a_hash_including('name' => custom_lifecycle.default_duplicate_status.name)
            )
          )
        )
      end

      context 'when only name is provided' do
        let(:params) do
          {
            namespace_path: group.full_path,
            id: custom_lifecycle.to_gid,
            name: lifecycle_name
          }
        end

        it 'updates the name of the lifecycle' do
          post_graphql_mutation(mutation, current_user: user)

          expect(response).to have_gitlab_http_status(:success)
          expect_graphql_errors_to_be_empty

          expect(mutation_response['lifecycle']['name']).to eq(lifecycle_name)
        end
      end

      context 'when mapping is provided although not needed' do
        let(:params) do
          super().merge({
            statuses: nil,
            status_mappings: [
              {
                old_status_id: existing_in_progress_status.to_gid,
                new_status_id: custom_lifecycle.default_open_status.to_gid
              }
            ]
          })
        end

        it 'accepts attribute and does nothing' do
          post_graphql_mutation(mutation, current_user: user)

          expect(response).to have_gitlab_http_status(:success)
          expect_graphql_errors_to_be_empty
        end
      end

      context 'when status should be removed from lifecycle' do
        let(:params) do
          {
            namespace_path: group.full_path,
            id: custom_lifecycle.to_gid,
            name: lifecycle_name,
            statuses: [
              status_params_for(custom_lifecycle.default_open_status),
              status_params_for(custom_lifecycle.default_closed_status),
              status_params_for(custom_lifecycle.default_duplicate_status)
            ],
            default_open_status_index: 0,
            default_closed_status_index: 1,
            default_duplicate_status_index: 2
          }
        end

        shared_examples 'updates the lifecycle' do
          it 'updates the lifecycle' do
            post_graphql_mutation(mutation, current_user: user)

            expect(response).to have_gitlab_http_status(:success)
            expect_graphql_errors_to_be_empty

            expect(mutation_response['lifecycle']).to match(
              a_hash_including(
                'name' => lifecycle_name,
                'statuses' => include(
                  a_hash_including('name' => custom_lifecycle.default_open_status.name),
                  a_hash_including('name' => custom_lifecycle.default_closed_status.name),
                  a_hash_including('name' => custom_lifecycle.default_duplicate_status.name)
                )
              )
            )
          end
        end

        it_behaves_like 'updates the lifecycle'

        context 'when status to remove is in use' do
          before do
            create(
              :work_item_type_custom_lifecycle,
              namespace: group,
              work_item_type: build(:work_item_system_defined_type, :issue),
              lifecycle: custom_lifecycle
            )

            create(:work_item, namespace: group, custom_status_id: existing_in_progress_status.id)
          end

          it 'returns an error' do
            post_graphql_mutation(mutation, current_user: user)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_response['errors']).to include(
              "Cannot remove status '#{existing_in_progress_status.name}' from lifecycle " \
                "because it is in use and no mapping is provided"
            )
          end

          context 'and mapping is provided' do
            let(:params) do
              super().merge(
                status_mappings: [
                  {
                    old_status_id: existing_in_progress_status.to_gid,
                    new_status_id: custom_lifecycle.default_open_status.to_gid
                  }
                ]
              )
            end

            it_behaves_like 'updates the lifecycle'
          end
        end
      end
    end
  end

  context 'when invalid input is provided' do
    it 'returns validation error for missing required argument' do
      invalid_params = params.except(:namespace_path)
      mutation = graphql_mutation(:lifecycle_update, invalid_params)

      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(
        "Variable $lifecycleUpdateInput of type LifecycleUpdateInput! was provided invalid value " \
          "for namespacePath (Expected value to not be null)"
      )
    end

    it 'returns validation error for invalid argument value' do
      invalid_params = params.merge(
        statuses: [
          status_params_for(system_defined_lifecycle.default_open_status),
          {
            name: 'Ready for development',
            color: '#737278',
            description: nil,
            category: 'INVALID_CATEGORY'
          },
          status_params_for(system_defined_lifecycle.default_closed_status),
          status_params_for(system_defined_lifecycle.default_duplicate_status)
        ]
      )

      mutation = graphql_mutation(:lifecycle_update, invalid_params)
      post_graphql_mutation(mutation, current_user: user)

      expect_graphql_errors_to_include(
        /Expected "INVALID_CATEGORY" to be one of: TRIAGE, TO_DO, IN_PROGRESS, DONE, CANCELED/
      )
    end
  end

  context 'when user is unauthorized' do
    it 'returns an error' do
      guest = create(:user, guest_of: group)

      post_graphql_mutation(mutation, current_user: guest)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end

  context 'when namespace is a subgroup' do
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:subgroup_maintainer) { create(:user, maintainer_of: subgroup) }

    let(:namespace_path) { subgroup.full_path }

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: subgroup_maintainer)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end

  def status_params_for(status)
    {
      id: status.to_global_id,
      name: status.name,
      color: status.color,
      description: status.description,
      category: status.category.upcase
    }
  end
end

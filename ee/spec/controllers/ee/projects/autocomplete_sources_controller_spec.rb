# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::AutocompleteSourcesController, feature_category: :text_editors do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:group2) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:epic) { create(:epic, group: group) }
  let_it_be(:epic2) { create(:epic, group: group2) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_read, project: project) }
  let_it_be(:issue) { create(:issue, project: project, title: 'Project Issue') }

  before do
    sign_in(user)
  end

  describe "issues" do
    context 'with standard functionality' do
      it 'returns the correct response', :aggregate_failures do
        get :issues, params: { namespace_id: project.namespace, project_id: project }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to be_an(Array)
        expect(json_response.first).to include(
          'iid' => issue.iid,
          'title' => issue.title,
          'icon_name' => issue.icon_name,
          'reference' => issue.to_reference
        )
      end
    end

    context 'with group-level issues' do
      let_it_be(:group_issue) { create(:work_item, :issue, namespace: group, title: 'Group Issue') }

      before_all do
        group.add_developer(user)
      end

      context 'when epics license is not available' do
        before do
          stub_licensed_features(epics: false)
        end

        it 'returns only project issues', :aggregate_failures do
          get :issues, params: { namespace_id: project.namespace, project_id: project }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an(Array)
          expect(json_response.pluck('title')).to include(issue.title)
          expect(json_response.pluck('title')).not_to include(group_issue.title)
        end
      end

      context 'when epics license is available' do
        before do
          stub_licensed_features(epics: true)
        end

        context 'when allow_group_items_in_project_autocompletion is disabled' do
          before do
            stub_feature_flags(allow_group_items_in_project_autocompletion: false)
          end

          it 'returns only project issues', :aggregate_failures do
            get :issues, params: { namespace_id: project.namespace, project_id: project }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to be_an(Array)
            expect(json_response.pluck('title')).to include(issue.title)
            expect(json_response.pluck('title')).not_to include(group_issue.title)
          end
        end

        context 'when allow_group_items_in_project_autocompletion is enabled' do
          before do
            stub_feature_flags(allow_group_items_in_project_autocompletion: true)
          end

          it 'returns both project and group issues', :aggregate_failures do
            get :issues, params: { namespace_id: project.namespace, project_id: project }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to be_an(Array)
            expect(json_response.pluck('title')).to include(issue.title)
            expect(json_response.pluck('title')).to include(group_issue.title)
          end

          it 'filters issues with search parameter', :aggregate_failures do
            searchable_issue = create(:issue, project: project, title: 'Searchable Issue')
            get :issues, params: {
              namespace_id: project.namespace,
              project_id: project,
              search: 'Searchable'
            }

            expect(json_response.pluck('title')).to include(searchable_issue.title)
            expect(json_response.pluck('title')).not_to include(issue.title)
          end
        end
      end
    end
  end

  describe '#epics', feature_category: :portfolio_management do
    context 'when epics feature is disabled' do
      it 'returns 404 status' do
        get :epics, params: { namespace_id: project.namespace, project_id: project }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when epics feature is enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      describe '#epics' do
        it 'returns the correct response', :aggregate_failures do
          epic_json_response = {
            'iid' => epic.iid,
            'title' => epic.title,
            'reference' => epic.to_reference,
            'icon_name' => 'work-item-epic'
          }

          get :epics, params: { namespace_id: project.namespace, project_id: project }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an(Array)
          expect(json_response.count).to eq(1)
          expect(json_response.first).to include(epic_json_response)
        end
      end
    end
  end

  describe '#iterations', :freeze_time do
    let_it_be(:cadence) { create(:iterations_cadence, group: group) }
    let_it_be(:open_iteration) { create(:iteration, iterations_cadence: cadence) }
    let_it_be(:closed_iteration) { create(:iteration, :closed, iterations_cadence: cadence) }
    let_it_be(:other_iteration) { create(:iteration, iterations_cadence: create(:iterations_cadence, group: group2)) }

    context 'when iterations feature is disabled' do
      before do
        stub_licensed_features(iterations: false)
      end

      it 'returns 404 status' do
        visit

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when iterations feature is enabled' do
      before do
        stub_licensed_features(iterations: true)
      end

      describe '#iterations' do
        it 'returns the correct response', :aggregate_failures do
          iteration_json_response = {
            'id' => open_iteration.id,
            'title' => open_iteration.display_text,
            'reference' => open_iteration.to_reference
          }

          visit

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an(Array)
          expect(json_response.count).to eq(1)
          expect(json_response.first).to include(iteration_json_response)
        end
      end

      it 'avoids N+1 queries', :use_sql_query_cache do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) { visit }

        create(:iteration, iterations_cadence: cadence)

        expect { visit }.not_to exceed_all_query_limit(control)
      end
    end

    def visit
      get :iterations, params: { namespace_id: project.namespace, project_id: project }
    end
  end

  describe '#vulnerabilities', feature_category: :vulnerability_management do
    context 'when vulnerabilities feature is disabled' do
      it 'returns 404 status' do
        get :vulnerabilities, params: { namespace_id: project.namespace, project_id: project }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when vulnerabilities feature is enabled' do
      before_all do
        project.add_developer(user)
      end

      before do
        stub_licensed_features(security_dashboard: true)
      end

      describe '#vulnerabilities' do
        it 'returns the correct response', :aggregate_failures do
          get :vulnerabilities, params: { namespace_id: project.namespace, project_id: project }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an(Array)
          expect(json_response.count).to eq(1)
          expect(json_response.first).to include(
            'id' => vulnerability.id, 'title' => vulnerability.title
          )
        end
      end
    end
  end

  describe '#commands', feature_category: :team_planning do
    context 'with custom work item types' do
      let_it_be(:custom_type) { create(:work_item_custom_type, :with_organization, organization: group.organization) }

      before_all do
        group.add_developer(user)
      end

      it 'returns commands for a work item with custom type' do
        get :commands, format: :json, params: {
          namespace_id: group.path,
          project_id: project.path,
          type: 'WorkItem',
          work_item_type_id: custom_type.id
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to be_an(Array)
        expect(json_response).to be_present
      end

      it 'includes assign command for custom types that support assignees' do
        get :commands, format: :json, params: {
          namespace_id: group.path,
          project_id: project.path,
          type: 'WorkItem',
          work_item_type_id: custom_type.id
        }

        command_names = json_response.pluck('name')
        expect(command_names).to include('assign')
      end

      it 'includes time tracking commands for custom types that support time tracking' do
        get :commands, format: :json, params: {
          namespace_id: group.path,
          project_id: project.path,
          type: 'WorkItem',
          work_item_type_id: custom_type.id
        }

        command_names = json_response.pluck('name')
        expect(command_names).to include('estimate')
        expect(command_names).to include('spend')
      end
    end
  end
end

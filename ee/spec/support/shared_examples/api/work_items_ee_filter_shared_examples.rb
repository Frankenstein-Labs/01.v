# frozen_string_literal: true

RSpec.shared_examples 'work item listing EE filters' do
  describe 'EE-specific filters' do
    describe 'custom_field filter' do
      let_it_be(:custom_field, freeze: false) { create(:custom_field, namespace: group) }
      let_it_be(:matching_option, freeze: false) { create(:custom_field_select_option, custom_field: custom_field) }
      let_it_be(:other_option, freeze: false) { create(:custom_field_select_option, custom_field: custom_field) }

      before do
        stub_licensed_features(epics: true, custom_fields: true)
        WorkItems::SelectFieldValue.update_work_item_field!(group_work_item, custom_field, [matching_option.id])
        WorkItems::SelectFieldValue.update_work_item_field!(group_work_item2, custom_field, [other_option.id])
      end

      it 'filters by custom_field_id and selected_option_ids' do
        get api(api_request_path, user), params: {
          custom_field: [{ custom_field_id: custom_field.id, selected_option_ids: matching_option.id.to_s }]
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to include(group_work_item.id)
        expect(json_response.pluck('id')).not_to include(group_work_item2.id)
      end

      it 'filters by custom_field_name and selected_option_values' do
        get api(api_request_path, user), params: {
          custom_field: [{
            custom_field_name: custom_field.name,
            selected_option_values: matching_option.value
          }]
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to include(group_work_item.id)
        expect(json_response.pluck('id')).not_to include(group_work_item2.id)
      end

      it 'rejects mutually exclusive custom_field_id and custom_field_name', :aggregate_failures do
        get api(api_request_path, user), params: {
          custom_field: [{
            custom_field_id: custom_field.id,
            custom_field_name: custom_field.name,
            selected_option_ids: matching_option.id.to_s
          }]
        }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include('mutually exclusive')
      end
    end

    describe 'status filter' do
      let_it_be(:to_do_status, freeze: false) { ::WorkItems::Statuses::SystemDefined::Status.find_by(id: 1) }
      let_it_be(:in_progress_status, freeze: false) { ::WorkItems::Statuses::SystemDefined::Status.find_by(id: 2) }

      before do
        stub_licensed_features(epics: true, work_item_status: true)
        create(:work_item_current_status, work_item: group_work_item, system_defined_status_id: to_do_status.id)

        # Give group_work_item2 an explicit status so it doesn't fall into the default "To do" bucket
        create(:work_item_current_status, work_item: group_work_item2, system_defined_status_id: in_progress_status.id)
      end

      it 'filters by id' do
        get api(api_request_path, user), params: { status: { id: to_do_status.id } }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to include(group_work_item.id)
        expect(json_response.pluck('id')).not_to include(group_work_item2.id)
      end

      it 'filters by status name' do
        get api(api_request_path, user), params: { status: { name: to_do_status.name } }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to include(group_work_item.id)
        expect(json_response.pluck('id')).not_to include(group_work_item2.id)
      end

      it 'rejects mutually exclusive id and name', :aggregate_failures do
        get api(api_request_path, user), params: {
          status: { id: to_do_status.id, name: to_do_status.name }
        }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include('mutually exclusive')
      end
    end

    describe 'health_status filter' do
      let_it_be(:at_risk_work_item, freeze: false) do
        create(:work_item, :group_level, namespace: group, health_status: :at_risk)
      end

      let_it_be(:on_track_work_item, freeze: false) do
        create(:work_item, :group_level, namespace: group, health_status: :on_track)
      end

      before do
        stub_licensed_features(epics: true, issuable_health_status: true)
      end

      it 'filters by health_status_filter', :aggregate_failures do
        get api(api_request_path, user), params: { health_status_filter: 'at_risk' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to include(at_risk_work_item.id)
        expect(json_response.pluck('id')).not_to include(on_track_work_item.id)
      end

      it 'excludes work items with the given health status via not', :aggregate_failures do
        get api(api_request_path, user), params: { not: { health_status_filter: 'at_risk' } }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).not_to include(at_risk_work_item.id)
        expect(json_response.pluck('id')).to include(on_track_work_item.id)
      end
    end

    describe 'verification_status_widget filter' do
      let_it_be(:requirement_work_item, freeze: false) { create(:requirement, project: project) }

      before do
        stub_licensed_features(epics: true, requirements: true)
        create(:test_report, requirement_issue: requirement_work_item, state: :passed, build: nil)
      end

      it 'filters by verification_status passed' do
        get api(api_request_path, user), params: {
          verification_status_widget: { verification_status: 'passed' },
          include_descendants: true
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to include(requirement_work_item.id)
        expect(json_response.pluck('id')).not_to include(group_work_item.id)
      end

      it 'filters by verification_status missing (no test reports)' do
        other_requirement = create(:requirement, project: project)

        get api(api_request_path, user), params: {
          verification_status_widget: { verification_status: 'missing' },
          include_descendants: true
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to include(other_requirement.id)
        expect(json_response.pluck('id')).not_to include(requirement_work_item.id)
      end
    end
  end
end

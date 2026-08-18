# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::WorkItems::Update, feature_category: :portfolio_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private, reporters: user) }
  let_it_be(:project) { create(:project, :private, group: group, reporters: user) }
  let_it_be(:work_item) { create(:work_item, :task, project: project) }

  before do
    stub_feature_flags(work_item_rest_api: true)
  end

  describe 'PATCH /projects/:id/-/work_items/:work_item_iid' do
    let(:api_request_path) { "/projects/#{project.id}/-/work_items/#{work_item.iid}" }

    context 'with health_status feature' do
      let_it_be(:issue_work_item) { create(:work_item, :issue, project: project) }
      let(:api_request_path) { "/projects/#{project.id}/-/work_items/#{issue_work_item.iid}" }

      before do
        stub_licensed_features(issuable_health_status: true)
      end

      it 'updates the health status' do
        patch api(api_request_path, user), params: {
          features: { health_status: { health_status: 'on_track' } }
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(issue_work_item.reload.health_status).to eq('on_track')
      end
    end

    context 'with iteration feature' do
      let_it_be(:iteration_cadence) { create(:iterations_cadence, group: group) }
      let_it_be(:iteration) { create(:iteration, iterations_cadence: iteration_cadence) }

      before do
        stub_licensed_features(iterations: true)
      end

      it 'sets the iteration on the work item' do
        patch api(api_request_path, user), params: {
          features: { iteration: { iteration_id: iteration.id } }
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(work_item.reload.iteration).to eq(iteration)
      end

      it 'unsets the iteration when iteration_id is null' do
        work_item.update!(iteration: iteration)

        patch api(api_request_path, user), params: {
          features: { iteration: { iteration_id: nil } }
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(work_item.reload.iteration).to be_nil
      end

      it 'returns not found for a non-existent iteration ID' do
        patch api(api_request_path, user), params: {
          features: { iteration: { iteration_id: non_existing_record_id } }
        }

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'returns not found for an iteration outside the work item group hierarchy' do
        other_group = create(:group, :private)
        other_cadence = create(:iterations_cadence, group: other_group)
        other_iteration = create(:iteration, iterations_cadence: other_cadence)

        patch api(api_request_path, user), params: {
          features: { iteration: { iteration_id: other_iteration.id } }
        }

        expect(response).to have_gitlab_http_status(:not_found)
      end

      context 'when the iterations license is disabled' do
        before do
          stub_licensed_features(iterations: false)
        end

        it 'silently ignores the iteration widget and succeeds' do
          patch api(api_request_path, user), params: {
            features: { iteration: { iteration_id: iteration.id } }
          }

          expect(response).to have_gitlab_http_status(:ok)
          expect(work_item.reload.iteration).to be_nil
        end
      end
    end

    context 'with weight feature' do
      before do
        stub_licensed_features(issue_weights: true)
      end

      it 'updates the weight' do
        patch api(api_request_path, user), params: {
          features: { weight: { weight: 8 } }
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(work_item.reload.weight).to eq(8)
      end

      it 'unsets the weight when weight is null' do
        work_item.update!(weight: 5)

        patch api(api_request_path, user), params: {
          features: { weight: { weight: nil } }
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(work_item.reload.weight).to be_nil
      end
    end

    context 'with progress feature' do
      let_it_be(:objective_work_item) { create(:work_item, :objective, project: project) }
      let(:api_request_path) { "/projects/#{project.id}/-/work_items/#{objective_work_item.iid}" }

      before do
        stub_licensed_features(okrs: true)
      end

      it 'updates the progress' do
        patch api(api_request_path, user), params: {
          features: { progress: { current_value: 50 } }
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(objective_work_item.reload.progress&.current_value).to eq(50)
      end

      it 'updates progress with start and end values' do
        patch api(api_request_path, user), params: {
          features: { progress: { current_value: 3, start_value: 0, end_value: 10 } }
        }

        expect(response).to have_gitlab_http_status(:ok)
        progress = objective_work_item.reload.progress
        expect(progress&.current_value).to eq(3)
        expect(progress&.start_value).to eq(0)
        expect(progress&.end_value).to eq(10)
      end
    end

    context 'with status feature' do
      before do
        stub_licensed_features(work_item_status: true)
      end

      it 'updates the work item with a system-defined status' do
        status = WorkItems::Statuses::SystemDefined::Status.all.first

        patch api(api_request_path, user), params: {
          features: { status: { status_id: status.id } }
        }

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'updates the work item with a custom status' do
        lifecycle = create(:work_item_custom_lifecycle, :for_tasks, namespace: group)
        custom_status = lifecycle.default_open_status

        patch api(api_request_path, user), params: {
          features: { status: { status_id: custom_status.id } }
        }

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'returns not found for a non-existent status ID' do
        patch api(api_request_path, user), params: {
          features: { status: { status_id: non_existing_record_id } }
        }

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'accepts null status_id' do
        patch api(api_request_path, user), params: {
          features: { status: { status_id: nil } }
        }

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'with custom_fields feature' do
      before do
        stub_licensed_features(custom_fields: true)
      end

      it 'updates a custom field value' do
        task_type = build(:work_item_system_defined_type, :task)
        custom_field = create(:custom_field, :number, namespace: group)
        create(:work_item_type_custom_field, custom_field: custom_field, work_item_type: task_type)

        patch api(api_request_path, user), params: {
          features: {
            custom_fields: [
              { custom_field_id: custom_field.id, number_value: 99 }
            ]
          }
        }

        expect(response).to have_gitlab_http_status(:ok)
        value = WorkItems::NumberFieldValue.for_field_and_work_item(custom_field.id, work_item.id).first
        expect(value&.value.to_i).to eq(99)
      end

      it 'rejects requests with more than the maximum number of custom_fields' do
        patch api(api_request_path, user), params: {
          features: {
            custom_fields: Array.new(31) { |i| { custom_field_id: i + 1, number_value: 1 } }
          }
        }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include('custom_fields')
      end

      it 'rejects requests with more than the maximum number of selected_option_ids' do
        patch api(api_request_path, user), params: {
          features: {
            custom_fields: [
              { custom_field_id: 1, selected_option_ids: (1..31).to_a }
            ]
          }
        }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include('selected_option_ids')
      end
    end
  end

  describe 'PATCH /groups/:id/-/work_items/:work_item_iid' do
    let_it_be(:group_work_item) { create(:work_item, :epic, namespace: group) }
    let(:api_request_path) { "/groups/#{group.id}/-/work_items/#{group_work_item.iid}" }

    before do
      stub_licensed_features(epics: true)
    end

    it 'updates the work item' do
      patch api(api_request_path, user), params: { title: 'Updated title' }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['title']).to eq('Updated title')
      expect(group_work_item.reload.title).to eq('Updated title')
    end

    it_behaves_like 'authorizing granular token permissions', :update_work_item do
      let(:boundary_object) { group }
      let(:request) do
        patch api(api_request_path, personal_access_token: pat), params: { title: 'Updated title' }
      end
    end
  end
end

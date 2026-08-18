# frozen_string_literal: true

RSpec.shared_examples 'work item listing EE iteration filters' do
  describe 'EE iteration filters' do
    let!(:iteration) { create(:iteration, group: group) }

    before do
      stub_licensed_features(epics: true, iterations: true)
      group_work_item.update!(iteration: iteration)
    end

    it 'filters by iteration_id' do
      get api(api_request_path, user), params: { iteration_id: iteration.id }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to include(group_work_item.id)
      expect(json_response.pluck('id')).not_to include(group_work_item2.id)
    end

    it 'filters by iteration_wildcard_id None' do
      get api(api_request_path, user), params: { iteration_wildcard_id: 'None' }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).not_to include(group_work_item.id)
    end

    it 'filters by iteration_wildcard_id Any' do
      get api(api_request_path, user), params: { iteration_wildcard_id: 'Any' }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to include(group_work_item.id)
      expect(json_response.pluck('id')).not_to include(group_work_item2.id)
    end

    it 'filters by negated iteration_id' do
      get api(api_request_path, user), params: { not: { iteration_id: iteration.id } }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).not_to include(group_work_item.id)
    end

    it 'filters by negated iteration_wildcard_id' do
      get api(api_request_path, user), params: { not: { iteration_wildcard_id: 'Any' } }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to include(group_work_item2.id)
      expect(json_response.pluck('id')).not_to include(group_work_item.id)
    end

    it 'rejects mutually exclusive top-level params', :aggregate_failures do
      get api(api_request_path, user), params: { iteration_id: 1, iteration_wildcard_id: 'None' }

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['error']).to include('mutually exclusive')
    end

    it 'rejects mutually exclusive negated params', :aggregate_failures do
      get api(api_request_path, user), params: { not: { iteration_id: 1, iteration_wildcard_id: 'None' } }

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['error']).to include('mutually exclusive')
    end

    it 'filters by iteration_wildcard_id Current' do
      iteration.update!(start_date: Date.current - 1.day, due_date: Date.current + 1.day)

      get api(api_request_path, user), params: { iteration_wildcard_id: 'Current' }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to include(group_work_item.id)
      expect(json_response.pluck('id')).not_to include(group_work_item2.id)
    end

    it 'filters by negated iteration_wildcard_id Current' do
      iteration.update!(start_date: Date.current - 1.day, due_date: Date.current + 1.day)

      get api(api_request_path, user), params: { not: { iteration_wildcard_id: 'Current' } }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to include(group_work_item2.id)
      expect(json_response.pluck('id')).not_to include(group_work_item.id)
    end

    it 'filters by iteration_cadence_id' do
      get api(api_request_path, user), params: { iteration_cadence_id: iteration.iterations_cadence_id }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to include(group_work_item.id)
      expect(json_response.pluck('id')).not_to include(group_work_item2.id)
    end

    it 'filters by iteration_wildcard_id and iteration_cadence_id combined' do
      iteration.update!(start_date: Date.current - 1.day, due_date: Date.current + 1.day)

      get api(api_request_path, user), params: {
        iteration_wildcard_id: 'Current',
        iteration_cadence_id: iteration.iterations_cadence_id
      }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to include(group_work_item.id)
      expect(json_response.pluck('id')).not_to include(group_work_item2.id)
    end
  end
end

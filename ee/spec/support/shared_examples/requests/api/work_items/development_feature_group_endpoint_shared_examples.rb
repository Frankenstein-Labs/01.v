# frozen_string_literal: true

# Shared behaviour for the group-scope (EE, epics-licensed) variant of a Work Item
# development-widget sub-endpoint. Group-level work items have no project-scoped
# development data, so the endpoint returns an empty collection but still enforces
# authorization and the epics license.
#
# The including context must define:
#   - `api_request_path`  the group-scoped endpoint path
#   - `group`             the group boundary object
#   - `user`              a user who can read the group work item
RSpec.shared_examples 'a group-level work item development feature endpoint returning empty' do
  it 'returns an empty array for the group-level work item', :aggregate_failures do
    get api(api_request_path, user)

    expect(response).to have_gitlab_http_status(:ok)
    expect(json_response).to eq([])
    # The empty collection is still paginated so clients always get the pagination headers.
    expect(response.headers['X-Total']).to eq('0')
  end

  it_behaves_like 'authorizing granular token permissions', :read_work_item do
    let(:boundary_object) { group }
    let(:request) do
      get api(api_request_path, personal_access_token: pat)
    end
  end

  context 'without the epics license' do
    before do
      stub_licensed_features(epics: false)
    end

    it 'returns 404 when the parent is not readable' do
      get api(api_request_path, user)

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end
end

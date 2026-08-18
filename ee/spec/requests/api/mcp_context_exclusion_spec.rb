# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'MCP API Context Exclusion', feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public, :repository, creator: user) }
  let_it_be(:mcp_token) { create(:oauth_access_token, user: user, scopes: [:mcp]) }
  let_it_be(:api_token) { create(:oauth_access_token, user: user, scopes: [:api]) }

  before_all do
    project.add_maintainer(user)
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/diffs' do
    let_it_be(:merge_request) do
      create(
        :merge_request,
        :simple,
        author: user,
        source_project: project,
        target_project: project
      )
    end

    let(:exclusion_rules) { ['*.md'] }

    before do
      project.create_project_setting unless project.project_setting
      project.project_setting.update!(duo_context_exclusion_settings: { exclusion_rules: exclusion_rules })
    end

    context 'when accessed with MCP token' do
      it 'filters out excluded files' do
        get api(
          "/projects/#{project.id}/merge_requests/#{merge_request.iid}/diffs",
          user,
          oauth_access_token: mcp_token
        )

        diffs = Gitlab::Json.parse(response.body)
        # Should not include files matching *.md pattern
        md_files = diffs.select { |d| d['new_path']&.end_with?('.md') || d['old_path']&.end_with?('.md') }

        expect(response).to have_gitlab_http_status(:ok)
        expect(md_files).to be_empty
      end

      context 'with no exclusion rules' do
        let(:exclusion_rules) { [] }

        it 'returns all diffs' do
          get api(
            "/projects/#{project.id}/merge_requests/#{merge_request.iid}/diffs",
            user,
            oauth_access_token: mcp_token
          )

          diffs = Gitlab::Json.parse(response.body)

          expect(response).to have_gitlab_http_status(:ok)
          expect(diffs.size).to eq(merge_request.diffs.size)
        end
      end
    end

    context 'when accessed with regular API token' do
      it 'does not filter excluded files' do
        get api(
          "/projects/#{project.id}/merge_requests/#{merge_request.iid}/diffs",
          user,
          oauth_access_token: api_token
        )

        diffs = Gitlab::Json.parse(response.body)

        expect(response).to have_gitlab_http_status(:ok)
        expect(diffs.size).to eq(merge_request.diffs.size)
      end
    end

    context 'when accessed without token (public project)' do
      it 'does not filter excluded files' do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/diffs")

        diffs = Gitlab::Json.parse(response.body)

        expect(response).to have_gitlab_http_status(:ok)
        expect(diffs.size).to eq(merge_request.diffs.size)
      end
    end
  end
end

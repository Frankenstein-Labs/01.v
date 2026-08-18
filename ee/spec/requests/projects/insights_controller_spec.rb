# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::InsightsController, feature_category: :value_stream_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, developer_of: group) }

  let(:query_params) do
    {
      type: 'bar',
      query: {
        data_source: 'issuables',
        params: {
          issuable_type: 'issue',
          collection_labels: ['bug']
        }
      }
    }
  end

  before do
    stub_licensed_features(insights: true, dora4_analytics: true)

    login_as(user)
  end

  describe 'GET #show' do
    it_behaves_like 'contribution analytics charts configuration' do
      let_it_be(:insights_entity) { project }

      def run_request
        get namespace_project_insights_path(
          namespace_id: group,
          project_id: project,
          format: :json
        )
      end
    end

    context 'when the project filters out charts via projects.only' do
      let_it_be(:filtered_project) do
        create(:project, :custom_repo, group: group, files: {
          ::Gitlab::Insights::CONFIG_FILE_PATH => <<~YAML
            issuesCreated:
              title: Issues
              charts:
                - title: Issues
                  type: bar
                  projects:
                    only:
                      - -1 # non-existent project ID ensures chart is filtered out
                  query:
                    data_source: issuables
                    params:
                      issuable_type: issue
          YAML
        })
      end

      it 'renders the filter-out notice' do
        get namespace_project_insights_path(namespace_id: group, project_id: filtered_project)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('Some items are not visible because the project was filtered out')
      end
    end

    context 'when the project has a structurally invalid insights.yml' do
      let_it_be(:bad_project) do
        create(:project, :custom_repo, group: group, files: {
          ::Gitlab::Insights::CONFIG_FILE_PATH => "Test_Insight:\n  - title: Testing yml\n    type: line\n"
        })
      end

      it 'renders the page with the invalid-config notice' do
        get namespace_project_insights_path(namespace_id: group, project_id: bad_project)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include(
          'The Insights configuration file (.gitlab/insights.yml) is not valid. ' \
            'Please correct it to load your insights.'
        )
      end

      it 'returns an empty config in the JSON endpoint' do
        get namespace_project_insights_path(namespace_id: group, project_id: bad_project, format: :json)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({})
      end
    end

    context 'when the project has a partially valid insights.yml' do
      let_it_be(:partial_project) do
        create(:project, :custom_repo, group: group, files: {
          ::Gitlab::Insights::CONFIG_FILE_PATH => <<~YAML
            good:
              title: Good
              charts:
                - title: Issues
                  type: bar
                  query:
                    data_source: issuables
                    params:
                      issuable_type: issue
            broken:
              - title: Bad entry
          YAML
        })
      end

      it 'renders the invalid-config notice and surfaces the valid entries in JSON' do
        get namespace_project_insights_path(namespace_id: group, project_id: partial_project)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include(
          'The Insights configuration file (.gitlab/insights.yml) is not valid.'
        )

        get namespace_project_insights_path(namespace_id: group, project_id: partial_project, format: :json)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.keys).to contain_exactly('good')
      end
    end
  end

  describe 'POST #query' do
    def run_request
      post query_namespace_project_insights_path(
        namespace_id: group,
        project_id: project,
        params: query_params,
        format: :json
      )
    end

    it 'succeeds' do
      run_request

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when statement timeout happens' do
      it 'returns error response' do
        expect_next_instance_of(IssuesFinder) do |instance|
          expect(instance).to receive(:execute).and_raise(ActiveRecord::QueryCanceled)
        end

        run_request

        expect(response).to have_gitlab_http_status(:unprocessable_entity)

        expect(json_response['message']).to include('Try lowering the period_limit setting')
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::InsightsController, feature_category: :value_stream_management do
  let_it_be(:group) { create(:group) }

  before do
    stub_licensed_features(insights: true, dora4_analytics: true)

    login_as(user)
  end

  describe 'GET #show' do
    it_behaves_like 'contribution analytics charts configuration' do
      let_it_be(:insights_entity) { group }

      def run_request
        get group_insights_path(
          group_id: group,
          format: :json
        )
      end
    end

    context 'when the group insights config project has a structurally invalid insights.yml' do
      let_it_be(:user) { create(:user, reporter_of: group) }
      let_it_be(:config_project) do
        create(:project, :custom_repo, group: group, files: {
          ::Gitlab::Insights::CONFIG_FILE_PATH => "Test_Insight:\n  - title: Testing yml\n    type: line\n"
        })
      end

      before_all do
        group.create_insight!(project: config_project)
      end

      it 'renders the page with the invalid-config notice' do
        get group_insights_path(group_id: group)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include(
          'The Insights configuration file (.gitlab/insights.yml) is not valid. ' \
            'Please correct it to load your insights.'
        )
      end

      it 'returns an empty config in the JSON endpoint' do
        get group_insights_path(group_id: group, format: :json)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({})
      end
    end

    context 'when the group insights config project has a partially valid insights.yml' do
      let_it_be(:user) { create(:user, reporter_of: group) }
      let_it_be(:config_project) do
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

      before_all do
        group.create_insight!(project: config_project)
      end

      it 'renders the invalid-config notice and surfaces the valid entries in JSON' do
        get group_insights_path(group_id: group)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include(
          'The Insights configuration file (.gitlab/insights.yml) is not valid.'
        )

        get group_insights_path(group_id: group, format: :json)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.keys).to contain_exactly('good')
      end
    end
  end
end

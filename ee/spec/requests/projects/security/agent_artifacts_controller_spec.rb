# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::AgentArtifactsController, feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  describe 'GET #download' do
    let_it_be(:workflow) { create(:duo_workflows_workflow, project: project) }
    let_it_be(:audit_event) do
      create(:audit_events_ai_audit_event, workflow_id: workflow.id, event_name: 'ai_agent_session_started')
    end

    subject(:request) { get download_project_security_agent_artifact_path(project, workflow.id) }

    context 'when user is not authorized' do
      before_all do
        project.add_maintainer(user)
      end

      before do
        sign_in(user)
        stub_licensed_features(project_level_compliance_dashboard: true)
      end

      it 'returns 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is authorized' do
      before_all do
        project.add_owner(user)
      end

      before do
        sign_in(user)
        stub_licensed_features(project_level_compliance_dashboard: true)
      end

      it 'returns the session artifact as a JSON attachment', :aggregate_failures do
        request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.media_type).to eq('application/json')
        expect(response.headers['Content-Disposition'])
          .to include('attachment', "session-artifact-#{workflow.id}.json")

        payload = Gitlab::Json.safe_parse(response.body)
        expect(payload['session']).to include(
          'id' => workflow.id,
          'workflow_definition' => workflow.workflow_definition
        )
        expect(payload['session']['project']).to include('full_path' => project.full_path)
        expect(payload['audit_events']).to contain_exactly(
          a_hash_including('event_name' => 'ai_agent_session_started')
        )
      end

      it 'returns 404 when the session artifact does not exist' do
        get download_project_security_agent_artifact_path(project, non_existing_record_id)

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'returns 404 for a session belonging to another project' do
        other_workflow = create(:duo_workflows_workflow)

        get download_project_security_agent_artifact_path(project, other_workflow.id)

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'serves the session when analytics are backed by ClickHouse and no Postgres artifact exists' do
        allow(::Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
        allow(::ClickHouse::Client).to receive(:select).and_return([])

        request

        expect(response).to have_gitlab_http_status(:ok)
        payload = Gitlab::Json.safe_parse(response.body)
        expect(payload['session']).to include('id' => workflow.id)
        expect(payload['audit_events']).to eq([])
      end

      context 'when agent_artifacts_page feature flag is disabled' do
        before do
          stub_feature_flags(agent_artifacts_page: false)
        end

        it 'returns 404' do
          request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when project_level_compliance_dashboard is not available' do
        before do
          stub_licensed_features(project_level_compliance_dashboard: false)
        end

        it 'returns 404' do
          request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end

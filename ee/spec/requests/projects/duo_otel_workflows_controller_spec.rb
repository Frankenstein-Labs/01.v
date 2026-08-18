# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::DuoOtelWorkflowsController, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user, freeze: false) { create(:user) }

  before_all do
    project.add_developer(user)
    project.project_setting.update!(duo_remote_flows_enabled: true)
  end

  before do
    sign_in(user)
    allow_next_found_instance_of(Project) do |p|
      allow(p).to receive_messages(
        empty_repo?: false,
        repository_languages: [instance_double(RepositoryLanguage)],
        duo_features_enabled: true,
        licensed_ai_features_available?: true,
        duo_foundational_flows_enabled: true
      )
    end
  end

  describe 'POST #create' do
    subject(:post_create) { post project_duo_otel_workflows_path(project) }

    context 'when user is not authorized' do
      context 'when user is not signed in' do
        before do
          sign_out(user)
        end

        it 'redirects to sign in' do
          post_create

          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context 'when feature flag duo_add_otel is disabled' do
        before do
          stub_feature_flags(duo_add_otel: false)
        end

        it 'returns 403' do
          post_create

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when user lacks create_duo_otel_workflow ability' do
        before do
          allow_next_found_instance_of(Project) do |p|
            allow(p).to receive(:duo_features_enabled).and_return(false)
          end
        end

        it 'returns 403' do
          post_create

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when rate limited' do
      before do
        allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_call_original
        allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?)
          .with(:create_duo_otel_workflow, scope: [user])
          .and_return(true)
      end

      it 'returns 429' do
        post_create

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end

    context 'when user is authorized' do
      let(:issue) { instance_double(Issue, iid: 42) }
      let(:workflow) { instance_double(Ai::DuoWorkflows::Workflow, id: 1) }
      let(:workload_id) { 'workload-abc-123' }
      let(:issue_web_url) { 'http://localhost/test/-/work_items/42' }

      context 'when service returns success' do
        before do
          allow_next_instance_of(Ai::DuoWorkflows::Otel::CreateWorkflowService) do |svc|
            allow(svc).to receive(:execute).and_return(
              ServiceResponse.success(
                payload: {
                  issue: issue,
                  workflow: workflow,
                  workload_id: workload_id
                }
              )
            )
          end

          allow(::Gitlab::UrlBuilder).to receive(:build).and_call_original
          allow(::Gitlab::UrlBuilder).to receive(:build).with(issue).and_return(issue_web_url)
        end

        it 'returns 201 with correct JSON' do
          post_create

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response).to include(
            'issue' => include('iid' => 42, 'web_url' => issue_web_url),
            'workflow' => include('id' => 1),
            'workload_id' => workload_id
          )
        end
      end

      context 'when service returns a forbidden error' do
        before do
          allow_next_instance_of(Ai::DuoWorkflows::Otel::CreateWorkflowService) do |svc|
            allow(svc).to receive(:execute).and_return(
              ServiceResponse.error(message: 'User cannot create issues', reason: :forbidden)
            )
          end
        end

        it 'returns 403 with error message' do
          post_create

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['error']).to eq('User cannot create issues')
        end
      end

      context 'when service returns a generic error' do
        before do
          allow_next_instance_of(Ai::DuoWorkflows::Otel::CreateWorkflowService) do |svc|
            allow(svc).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Something went wrong')
            )
          end
        end

        it 'returns 422 with error message' do
          post_create

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['error']).to eq('Something went wrong')
        end
      end
    end
  end
end

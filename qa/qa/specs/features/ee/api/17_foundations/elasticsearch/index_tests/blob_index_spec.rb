# frozen_string_literal: true

module QA
  RSpec.describe 'Foundations', feature_category: :global_search do
    describe(
      'When using elasticsearch API to search for a public blob',
      :orchestrated,
      :elasticsearch,
      :requires_admin,
      except: :production
    ) do
      include Support::API
      include_context 'advanced search active'

      let(:api_client) { Runtime::User::Store.user_api_client }
      let(:project) { create(:project, name: 'test-project-for-blob-index') }
      let(:project_file_content) { "File content for blob index test #{SecureRandom.hex(8)}" }

      before do
        create(:commit, project: project, actions: [
          { action: 'create', file_path: 'README.md', content: project_file_content }
        ])
      end

      it(
        'finds blob that matches file content',
        quarantine: {
          issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/928',
          type: :investigating,
          only: { pipeline: %w[staging-canary staging] }
        }
      ) do
        QA::Support::Retrier.retry_on_exception(
          max_attempts: Runtime::Search::RETRY_MAX_ITERATION,
          sleep_interval: Runtime::Search::RETRY_SLEEP_INTERVAL
        ) do
          response = Support::API.get(Runtime::Search.create_search_request(api_client, 'blobs',
            project_file_content).url)

          expect(response.code).to eq(QA::Support::API::HTTP_STATUS_OK)
          response_body = parse_body(response)

          expect(response_body).not_to be_empty, "Expected a blob to be returned from request to /search"
          expect(response_body[0][:data]).to match(project_file_content)
          expect(response_body[0][:project_id]).to equal(project.id)
        end
      end
    end
  end
end

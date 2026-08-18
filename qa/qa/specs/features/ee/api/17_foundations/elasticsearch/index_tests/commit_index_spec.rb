# frozen_string_literal: true

module QA
  RSpec.describe 'Foundations', feature_category: :global_search do
    describe(
      'When using Advanced Search API to search for a public commit',
      :orchestrated,
      :elasticsearch,
      :requires_admin,
      except: :production
    ) do
      include Support::API
      include_context 'advanced search active'

      let(:api_client) { Runtime::User::Store.user_api_client }
      let(:project) { create(:project, name: 'test-project-for-commit-index') }
      let(:content) { "Advanced search test commit #{SecureRandom.hex(8)}" }
      let(:commit) do
        create(:commit, project: project, commit_message: content, actions: [
          { action: 'create', file_path: 'test.txt', content: content }
        ])
      end

      it(
        'finds commit that matches commit message',
        quarantine: {
          issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/work_items/40387',
          type: :test_environment,
          only: { subdomain: :staging }
        }
      ) do
        QA::Support::Retrier.retry_on_exception(
          max_attempts: Runtime::Search::RETRY_MAX_ITERATION,
          sleep_interval: Runtime::Search::RETRY_SLEEP_INTERVAL) do
          response = Support::API.get(Runtime::Search.create_search_request(api_client, 'commits',
            commit.commit_message).url)

          expect(response.code).to eq(QA::Support::API::HTTP_STATUS_OK)
          response_body = parse_body(response)

          expect(response_body).not_to be_empty, "Expected a commit to be returned from request to /search"
          expect(response_body[0][:title]).to eq(commit.commit_message)
          expect(response_body[0][:short_id]).to eq(commit.short_id)
        end
      end
    end
  end
end

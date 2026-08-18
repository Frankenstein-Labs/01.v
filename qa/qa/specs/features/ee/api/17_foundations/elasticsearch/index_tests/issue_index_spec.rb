# frozen_string_literal: true

module QA
  RSpec.describe 'Foundations', feature_category: :global_search do
    describe(
      'When using elasticsearch API to search for a public issue',
      :orchestrated,
      :elasticsearch,
      :requires_admin,
      except: :production
    ) do
      include Support::API
      include_context 'advanced search active'

      let(:api_client) { Runtime::User::Store.user_api_client }

      let(:issue) do
        create(:issue,
          title: 'Issue for issue index test',
          description: "Some issue description #{SecureRandom.hex(8)}")
      end

      it(
        'finds issue that matches description',
        quarantine: {
          issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/929',
          type: :investigating,
          only: { pipeline: %w[staging-canary staging] }
        }
      ) do
        QA::Support::Retrier.retry_on_exception(
          max_attempts: Runtime::Search::RETRY_MAX_ITERATION,
          sleep_interval: Runtime::Search::RETRY_SLEEP_INTERVAL
        ) do
          response = Support::API.get(Runtime::Search.create_search_request(api_client, 'issues',
            issue.description).url)

          expect(response.code).to eq(QA::Support::API::HTTP_STATUS_OK)
          response_body = parse_body(response)

          expect(response_body).not_to be_empty, "Expected an issue to be returned from request to /search"
          expect(response_body[0][:description]).to eq(issue.description)
          expect(response_body[0][:project_id]).to equal(issue.project.id)
        end
      end
    end
  end
end

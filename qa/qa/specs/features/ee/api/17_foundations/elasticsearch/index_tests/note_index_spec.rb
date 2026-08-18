# frozen_string_literal: true

module QA
  RSpec.describe 'Foundations', feature_category: :global_search do
    describe(
      'When using elasticsearch API to search for a public note',
      :orchestrated,
      :elasticsearch,
      :requires_admin,
      except: :production
    ) do
      include Support::API
      include_context 'advanced search active'

      let(:api_client) { Runtime::User::Store.user_api_client }
      let(:issue) { create(:issue, title: 'Issue for note index test') }
      let(:note) do
        create(:issue_note,
          project: issue.project,
          issue: issue,
          body: "This is a comment with a unique number #{SecureRandom.hex(8)}")
      end

      it(
        'finds note that matches note body',
        quarantine: {
          issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/983',
          type: :investigating,
          only: { pipeline: %w[staging-canary staging] }
        }
      ) do
        QA::Support::Retrier.retry_on_exception(
          max_attempts: Runtime::Search::RETRY_MAX_ITERATION,
          sleep_interval: Runtime::Search::RETRY_SLEEP_INTERVAL
        ) do
          response = Support::API.get(Runtime::Search.create_search_request(api_client, 'notes', note.body).url)

          expect(response.code).to eq(QA::Support::API::HTTP_STATUS_OK)
          response_body = parse_body(response)

          expect(response_body).not_to be_empty, "Expected a note to be returned from request to /search"
          expect(response_body[0][:body]).to eq(note.body)
          expect(response_body[0][:noteable_id]).to eq(issue.id)
        end
      end
    end
  end
end

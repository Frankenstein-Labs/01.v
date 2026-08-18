# frozen_string_literal: true

module QA
  RSpec.describe 'Foundations', feature_category: :global_search do
    describe(
      'When using elasticsearch API to search for a public merge request',
      :orchestrated,
      :elasticsearch,
      :requires_admin,
      except: :production
    ) do
      include Support::API
      include_context 'advanced search active'

      let(:api_client) { Runtime::User::Store.user_api_client }

      let(:merge_request) do
        create(:merge_request,
          title: 'Merge request for merge request index test',
          description: "Some merge request description #{SecureRandom.hex(8)}")
      end

      it(
        'finds merge request that matches description',
        quarantine: {
          issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/21830',
          type: :investigating
        }
      ) do
        QA::Support::Retrier.retry_on_exception(
          max_attempts: Runtime::Search::RETRY_MAX_ITERATION,
          sleep_interval: Runtime::Search::RETRY_SLEEP_INTERVAL
        ) do
          response = Support::API.get(Runtime::Search.create_search_request(api_client, 'merge_requests',
            merge_request.description).url)

          expect(response.code).to eq(QA::Support::API::HTTP_STATUS_OK)
          response_body = parse_body(response)

          expect(response_body).not_to be_empty, "Expected a merge request to be returned from request to /search"
          expect(response_body[0][:description]).to eq(merge_request.description)
          expect(response_body[0][:project_id]).to eq(merge_request.project.id)
        end
      end
    end
  end
end

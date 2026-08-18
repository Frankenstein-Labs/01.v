# frozen_string_literal: true

module QA
  RSpec.describe 'Foundations', feature_category: :global_search do
    describe(
      'When using elasticsearch API to search for a known blob',
      :orchestrated,
      :elasticsearch,
      :requires_admin,
      except: :production
    ) do
      include Support::API
      include_context 'advanced search active'

      let(:project_file_content) { "elasticsearch: #{SecureRandom.hex(8)}" }
      let(:non_member_user) { create(:user, :with_personal_access_token) }
      let(:non_member_api_client) { non_member_user.api_client }
      let(:api_client) { Runtime::User::Store.user_api_client }

      let(:project) { create(:project, name: "api-es-#{SecureRandom.hex(8)}") }

      before do
        create(:commit, project: project, actions: [
          { action: 'create', file_path: 'README.md', content: project_file_content }
        ])
      end

      it(
        'searches public project and finds a blob as an non-member user',
        quarantine: {
          issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/937',
          type: :investigating
        }
      ) do
        response_body = perform_search_with_retry(non_member_api_client)

        expect(response_body).not_to be_empty, "Expected a blob to be returned from request to /search"
        expect(response_body[0][:data]).to match(project_file_content)
        expect(response_body[0][:project_id]).to equal(project.id)
      end

      describe 'When searching a private repository' do
        before do
          project.set_visibility(:private)
        end

        it(
          'finds a blob as an authorized user',
          quarantine: {
            issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24035',
            type: :flaky
          }) do
          response_body = perform_search_with_retry(api_client)

          expect(response_body).not_to be_empty, "Expected a blob to be returned from request to /search"
          expect(response_body[0][:data]).to match(project_file_content)
          expect(response_body[0][:project_id]).to equal(project.id)
        end

        it(
          'does not find a blob as an non-member user',
          quarantine: {
            issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/work_items/38269',
            type: :investigating
          }) do
          response_body = perform_search_with_retry(non_member_api_client)

          expect(response_body).to be_empty, "Expected no results from /search"
        end
      end

      private

      def perform_search_with_retry(api_client)
        QA::Support::Retrier.retry_on_exception(
          max_attempts: Runtime::Search::RETRY_MAX_ITERATION,
          sleep_interval: Runtime::Search::RETRY_SLEEP_INTERVAL
        ) do
          response = Support::API.get(Runtime::Search.create_search_request(api_client, 'blobs',
            project_file_content).url)
          expect(response.code).to eq(QA::Support::API::HTTP_STATUS_OK)

          parse_body(response)
        end
      end

      def parse_body(response)
        JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end

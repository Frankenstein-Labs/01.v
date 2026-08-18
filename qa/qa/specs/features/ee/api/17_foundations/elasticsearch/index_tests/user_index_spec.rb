# frozen_string_literal: true

module QA
  RSpec.describe 'Foundations', feature_category: :global_search do
    describe(
      'When using advanced search API to search for a user',
      :orchestrated,
      :elasticsearch,
      :requires_admin,
      :skip_live_env
    ) do
      include Support::API
      include_context 'advanced search active'

      let(:api_client) { Runtime::API::Client.as_admin }

      let(:user) do
        create(:user,
          api_client: api_client,
          name: 'JoeBloggs',
          username: "qa-user-name-#{SecureRandom.hex(8)}",
          first_name: 'Joe',
          last_name: 'Bloggs')
      end

      it 'finds the user that matches username' do
        QA::Support::Retrier.retry_on_exception(
          max_attempts: Runtime::Search::RETRY_MAX_ITERATION,
          sleep_interval: Runtime::Search::RETRY_SLEEP_INTERVAL
        ) do
          response = Support::API.get(Runtime::Search.create_search_request(api_client, 'users', user.username).url)

          expect(response.code).to eq(QA::Support::API::HTTP_STATUS_OK)
          response_body = parse_body(response)

          expect(response_body).not_to be_empty, "Expected a user to be returned from request to /search"
          expect(response_body[0][:name]).to eq(user.name)
          expect(response_body[0][:username]).to eq(user.username)
        end
      end
    end
  end
end

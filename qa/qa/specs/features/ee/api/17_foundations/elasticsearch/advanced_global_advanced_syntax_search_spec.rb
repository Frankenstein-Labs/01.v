# frozen_string_literal: true

module QA
  RSpec.describe 'Foundations', feature_category: :global_search do
    describe(
      'Elasticsearch advanced global search with advanced syntax',
      :orchestrated,
      :elasticsearch,
      :requires_admin,
      except: :production
    ) do
      include Support::API
      include_context 'advanced search active'

      let(:project_name_suffix) { SecureRandom.hex(8) }
      let(:api_client) { Runtime::User::Store.user_api_client }

      let(:project) do
        create(:project,
          name: "es-adv-global-search-#{project_name_suffix}",
          description: "This is a unique project description #{project_name_suffix}")
      end

      before do
        create(:commit, project: project, actions: [
          { action: 'create', file_path: 'elasticsearch.rb', content: "elasticsearch: #{SecureRandom.hex(8)}" }
        ])
      end

      context 'when searching for projects using advanced syntax' do
        it 'searches in the project name' do
          expect_search_to_find_project("es-adv-*#{project_name_suffix}")
        end

        it 'searches in the project description' do
          expect_search_to_find_project("unique +#{project_name_suffix}")
        end
      end

      private

      def expect_search_to_find_project(search_term)
        QA::Support::Retrier.retry_on_exception(
          max_attempts: Runtime::Search::RETRY_MAX_ITERATION,
          sleep_interval: Runtime::Search::RETRY_SLEEP_INTERVAL
        ) do
          response = Support::API.get(Runtime::Search.create_search_request(api_client, 'projects', search_term).url)

          expect(response.code).to eq(Support::API::HTTP_STATUS_OK)
          response_body = parse_body(response)

          expect(response_body).not_to be_empty, "Expected a project to be returned from request to /search"
          expect(response_body[0][:name]).to eq(project.name)
        end
      end
    end
  end
end

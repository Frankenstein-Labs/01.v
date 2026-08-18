# frozen_string_literal: true

module QA
  RSpec.describe 'Foundations', feature_category: :global_search do
    describe(
      'Search using Elasticsearch',
      :orchestrated,
      :elasticsearch,
      :requires_admin,
      :skip_live_env
    ) do
      include Runtime::Fixtures
      let(:admin_api_client) { Runtime::User::Store.admin_api_client }
      let(:project_file_name) { 'elasticsearch.rb' }
      let(:project_file_content) { "Some file content #{SecureRandom.hex(8)}" }
      let(:project) { create(:project, name: 'testing_elasticsearch_indexing') }
      let(:elasticsearch_original_state_on?) { Runtime::Search.elasticsearch_on?(admin_api_client) }

      before do
        QA::EE::Resource::Settings::Elasticsearch.fabricate_via_api! unless elasticsearch_original_state_on?

        Runtime::Search.assert_elasticsearch_responding

        Flow::Login.sign_in

        Resource::Repository::ProjectPush.fabricate! do |push|
          push.project = project
          push.file_name = project_file_name
          push.file_content = project_file_content
        end.project.visit!
      end

      it(
        'tests reindexing after push'
      ) do
        expect { Runtime::Search.find_code(project_file_name, project_file_content) }.not_to raise_error

        Page::Main::Menu.perform(&:go_to_groups)

        QA::Page::Main::Menu.perform do |menu|
          menu.search_for(project_file_content)
        end

        file_path = "#{project.group.sandbox.path} / #{project.group.path} / #{project.name}"

        Page::Search::Results.perform do |search|
          search.switch_to_code

          expect(search).to have_file_in_project_with_content(project_file_content, file_path)
        end
      end

      it(
        'tests reindexing after webIDE'
      ) do
        template = {
          file_name: 'LICENSE',
          name: 'ElasticsearchIndexingtest with IDE'
        }

        Page::Project::Show.perform(&:open_web_ide!)
        Page::Project::WebIDE::VSCode.perform do |ide|
          ide.wait_for_ide_to_load
          ide.create_new_file_from_template(template[:file_name], template[:name])
          ide.wait_for_ide_to_load
          ide.commit_toggle(template[:file_name])
          ide.push_to_existing_branch
          ide.wait_for_ide_to_load
          ide.switch_to_original_window
        end

        expect { Runtime::Search.find_code(template[:file_name], template[:name]) }.not_to raise_error

        Page::Main::Menu.perform(&:go_to_groups)

        QA::Support::Retrier.retry_on_exception(
          max_attempts: Runtime::Search::RETRY_MAX_ITERATION, sleep_interval: Runtime::Search::RETRY_SLEEP_INTERVAL
        ) do
          QA::Page::Main::Menu.perform do |menu|
            menu.search_for(template[:name])
          end
          Page::Search::Results.perform do |search|
            search.switch_to_code

            file_path = "#{project.group.sandbox.path} / #{project.group.path} / #{project.name}"

            aggregate_failures "testing expectations" do
              expect(search).to have_project_in_search_result(project.name)
              expect(search).to have_file_in_project(template[:file_name], project.name)
              expect(search).to have_file_in_project_with_content(template[:name], file_path)
            end
          end
        end
      end
    end
  end
end

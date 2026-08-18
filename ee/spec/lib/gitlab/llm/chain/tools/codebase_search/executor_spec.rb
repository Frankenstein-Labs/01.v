# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::CodebaseSearch::Executor, feature_category: :duo_chat do
  shared_examples 'tool returns an error' do
    it 'returns an error answer with the expected content' do
      answer = execute_tool
      expect(answer.status).to eq(:error)
      expect(answer.content).to include(answer_message)
    end
  end

  shared_examples 'codebase query is not executed' do
    it 'does not execute the codebase query' do
      expect(::Ai::ActiveContext::Queries::Code).not_to receive(:new)

      execute_tool
    end
  end

  let_it_be(:user) { create(:user) }

  it 'defines NAME' do
    expect(described_class::NAME).to eq('CodebaseSearch')
  end

  describe '#execute', :saas do
    subject(:execute_tool) { described_class.new(context: gitlab_context, options: tool_options).execute }

    let(:user_input) { "dummy user input" }
    let(:additional_context) { [] }

    let(:tool_options) { { input: user_input } }

    let(:gitlab_context) do
      Gitlab::Llm::Chain::GitlabContext.new(
        container: nil,
        resource: nil,
        current_user: user,
        ai_request: nil,
        additional_context: ::CodeSuggestions::Context.new(
          Array.wrap(additional_context)
        ).trimmed
      )
    end

    let(:logger) { instance_double(Gitlab::Llm::Logger, error: nil, info: nil) }

    before do
      allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
    end

    context 'when user does not have duo_chat access' do
      it_behaves_like 'codebase query is not executed'

      it_behaves_like 'tool returns an error' do
        let(:answer_message) { "you don't have access to them" }
      end
    end

    context 'when user has duo_chat access' do
      # group is needed for the 'with duo pro addon' included context
      let_it_be(:group) { create(:group, developers: [user]) }

      include_context 'with duo pro addon'

      context 'without repository additional_contexts' do
        it_behaves_like 'codebase query is not executed'

        it 'returns a not_executed answer with the expected content' do
          answer = execute_tool
          expect(answer.status).to eq(:not_executed)

          expected_content = "There are no repository additional contexts. Semantic search was not executed."
          expect(answer.content).to eq(expected_content)
        end
      end

      context 'when repository additional_contexts are given' do
        let_it_be(:project_1) { create(:project, description: 'This is Project 1', owners: [user]) }
        let_it_be(:project_2) { create(:project, description: nil, developers: [user]) }
        let(:projects_by_gid) do
          {
            "gid://gitlab/Project/#{project_1.id}" => project_1,
            "gid://gitlab/Project/#{project_2.id}" => project_2
          }
        end

        let(:additional_context) { repository_additional_contexts + directory_additional_contexts }

        let(:repository_additional_contexts) do
          projects = [project_1, project_2]
          projects.map do |p|
            {
              category: 'repository',
              id: "gid://gitlab/Project/#{p.id}",
              content: 'non-empty-content',
              metadata: {
                'name' => p.name,
                'pathWithNamespace' => p.full_path,
                'description' => p.description
              }
            }
          end
        end

        let(:directory_additional_contexts) do
          [
            {
              category: 'directory',
              id: "dir:///User/project/some/path",
              content: 'non-empty-content',
              metadata: {
                'relativePath' => 'some/path',
                'projectId' => "gid://gitlab/Project/#{project_1.id}",
                'projectPathWithNamespace' => project_1.full_path
              }
            }
          ]
        end

        let(:codebase_query) { ::Ai::ActiveContext::Queries::Code.new(search_term: user_input, user: user) }

        before do
          allow(::Ai::ActiveContext::Queries::Code).to receive(:new).and_return(codebase_query)
        end

        context 'when query on the Code collection is not available' do
          before do
            allow(codebase_query).to receive(:filter).and_raise(
              Ai::ActiveContext::Queries::Code::NotAvailable,
              raised_error_message
            )
          end

          let(:raised_error_message) { "Semantic search on Code collection is not available." }
          let(:expected_error_message) do
            "Error in semantic search: " \
              "#{Ai::ActiveContext::Queries::Code::NotAvailable} #{raised_error_message}"
          end

          it_behaves_like 'tool returns an error' do
            let(:answer_message) { expected_error_message }
          end

          it 'is logged as an error' do
            expect(logger).to receive(:error).with(
              message: expected_error_message,
              event_name: 'codebase_search_failed',
              unit_primitive: 'codebase_search',
              ai_component: 'duo_chat',
              klass: anything
            )

            execute_tool
          end
        end

        context 'when query on the Code collection is available' do
          before do
            # mock codebase query, with different results depending on filters
            allow(codebase_query).to receive(:filter).with(project_or_id: project_1.id, path: nil)
              .and_return(build_es_query_result(repository_es_docs[project_1.id]))
            allow(codebase_query).to receive(:filter).with(project_or_id: project_2.id, path: nil)
              .and_return(build_es_query_result(repository_es_docs[project_2.id]))
            allow(codebase_query).to receive(:filter).with(project_or_id: project_1.id, path: 'some/path')
              .and_return(build_es_query_result(directory_es_docs))
          end

          let(:repository_es_docs) do
            {
              project_1.id => [
                build_es_doc_source(project_1, "proj1/file1.txt", "test content 1-1"),
                build_es_doc_source(project_1, "proj1/file2.txt", "test content 1-1")
              ],
              project_2.id => [
                build_es_doc_source(project_2, "proj2/file1.txt", "test content 2-1")
              ]
            }
          end

          let(:directory_es_docs) do
            [
              build_es_doc_source(project_1, "proj1/file1.txt", "test content 1-1")
            ]
          end

          def expected_repository_search_results(project_id)
            es_docs = repository_es_docs[project_id] || []
            es_docs.pluck('_source')
          end

          def expected_directory_search_results
            directory_es_docs.pluck('_source')
          end

          def expected_repository_info(project)
            repo_infos = [
              "Name: #{project.name}",
              "Path: #{project.full_path}"
            ]
            repo_infos << "Description: #{project.description}" if project.description

            repo_infos.join("\n")
          end

          def expected_directory_info
            dir_infos = [
              "Path: some/path",
              "Repository ID: gid://gitlab/Project/#{project_1.id}"
            ]
            dir_infos << "Repository Path: #{project_1.full_path}"

            dir_infos.join("\n")
          end

          it 'returns a successful answer' do
            answer = execute_tool
            expect(answer.status).to eq(:ok)

            expected_message = "The repository additional contexts have been enhanced with semantic search results."
            expect(answer.content).to eq(expected_message)
          end

          it 'enhances the repository and directory additional contexts' do
            execute_tool

            gitlab_context.additional_context.each do |ac|
              ac_content = ac['content']

              expected_info = ""
              expected_search_results = []

              if ac['category'] == 'repository'
                context_project = projects_by_gid[ac['id']]
                expected_info = expected_repository_info(context_project)
                expected_search_results = expected_repository_search_results(context_project.id)
              elsif ac['category'] == 'directory'
                expected_info = expected_directory_info
                expected_search_results = expected_directory_search_results
              end

              expect(ac_content).to include(expected_info)

              expected_message = "A semantic search has been performed on the #{ac['category']}."
              expect(ac_content).to include(expected_message)

              expected_search_results.each do |esr_info|
                expected_search_result = "<search_result>\n" \
                  "<file_path>#{esr_info['path']}</file_path>\n" \
                  "<content>#{esr_info['content']}</content>\n" \
                  "</search_result>"
                expect(ac_content).to include(expected_search_result)
              end

              expect(ac_content).not_to include('non-empty-content')
            end
          end

          it 'logs the semantic search request events' do
            expect(logger).to receive(:info).with(
              message: a_string_matching(/Requesting semantic search/),
              event_name: 'codebase_search_requesting',
              unit_primitive: 'codebase_search',
              ai_component: 'duo_chat',
              klass: anything
            )
            expect(logger).to receive(:info).with(
              message: a_string_matching(/Semantic search requested/),
              event_name: 'codebase_search_requested',
              unit_primitive: 'codebase_search',
              ai_component: 'duo_chat',
              klass: anything
            )

            execute_tool
          end

          context 'when the search on a project has an accepted failure' do
            before do
              error_result = Ai::ActiveContext::Queries::Result.no_embeddings_error(
                error_detail: "initial indexing has been started"
              )
              allow(codebase_query).to receive(:filter).with(project_or_id: project_2.id, path: nil)
                .and_return(error_result)
            end

            it 'runs successfully but indicates the error' do
              answer = execute_tool
              expect(answer.status).to eq(:ok)

              project_2_ac = gitlab_context.additional_context.find do |ac|
                ac['category'] == 'repository' &&
                  ac['id'] == "gid://gitlab/Project/#{project_2.id}"
              end
              expect(project_2_ac['content']).to include(
                "A semantic search was attempted on the repository, but there was an error:\n" \
                  "Project '#{project_2.id}' has no embeddings - initial indexing has been started."
              )
            end
          end

          context 'when the directory additional context does not have the required metadata' do
            # only setup 1 repository additional context to make the test simpler
            let(:repository_additional_contexts) do
              [
                {
                  category: 'repository',
                  id: "gid://gitlab/Project/#{project_1.id}",
                  content: '',
                  metadata: {
                    'name' => project_1.name,
                    'pathWithNamespace' => project_1.full_path,
                    'description' => project_1.description
                  }
                }
              ]
            end

            let(:directory_additional_contexts) do
              [
                {
                  category: 'directory',
                  id: "dir:///User/project/some/path",
                  content: '',
                  metadata: {
                    'projectId' => "gid://gitlab/Project/#{project_2.id}"
                  }
                }
              ]
            end

            it 'runs successfully but does not perform a semantic search on the directory' do
              expect(codebase_query).not_to receive(:filter).with(project_or_id: project_2.id, path: anything)

              answer = execute_tool
              expect(answer.status).to eq(:ok)

              directory_ac = gitlab_context.additional_context.find { |ac| ac['category'] == 'directory' }
              semantic_search_message = 'A semantic search has been performed on the directory.'
              expect(directory_ac['content']).not_to include(semantic_search_message)
            end
          end

          context 'when there is an error in the semantic search' do
            before do
              allow(codebase_query).to receive(:filter).and_raise(
                StandardError, raised_error_message
              )
            end

            let(:raised_error_message) { "cannot search the vector store" }
            let(:expected_error_message) { "Error in semantic search: StandardError #{raised_error_message}" }

            it_behaves_like 'tool returns an error' do
              let(:answer_message) { expected_error_message }
            end

            it 'logs the correct events' do
              expect(logger).to receive(:info).with(
                message: a_string_matching(/Requesting semantic search/),
                event_name: 'codebase_search_requesting',
                unit_primitive: 'codebase_search',
                ai_component: 'duo_chat',
                klass: anything
              )
              expect(logger).to receive(:error).with(
                message: expected_error_message,
                event_name: 'codebase_search_failed',
                unit_primitive: 'codebase_search',
                ai_component: 'duo_chat',
                klass: anything
              )

              execute_tool
            end
          end
        end
      end
    end
  end

  def build_es_doc_source(project, file_path, content)
    {
      '_source' => {
        'project_id' => project.id,
        'path' => file_path,
        'content' => content
      }
    }
  end

  def build_es_query_result(es_docs)
    return unless es_docs

    hits = ActiveContext::Databases::Elasticsearch::QueryResult.new(
      result: { 'hits' => { 'total' => { 'value' => 1 }, 'hits' => es_docs } },
      collection: Ai::ActiveContext::Collections::Code,
      user: user
    )

    Ai::ActiveContext::Queries::Result.success(hits)
  end
end

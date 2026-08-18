# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::WorkItemReader::Executor, feature_category: :duo_chat do
  RSpec.shared_examples 'success response' do
    it 'returns success response' do
      ai_request = double
      allow(ai_request).to receive(:request).and_return(ai_response)
      allow(context).to receive(:ai_request).and_return(ai_request)
      resource_serialized = Ai::AiResource::WorkItem.new(context.current_user, resource)
        .serialize_for_ai(
          content_limit: ::Gitlab::Llm::Chain::Tools::WorkItemReader::Prompts::Anthropic::MAX_CHARACTERS
        ).to_xml(root: :root, skip_types: true, skip_instruct: true)

      response = "Please use this information about identified work item: #{resource_serialized}"

      expect(tool.execute.content).to eq(response)
    end
  end

  RSpec.shared_examples 'work item not found response' do
    let(:response) do
      "I'm sorry, I can't generate a response. You might want to try again. " \
        "You could also be getting this error because the items you're asking about " \
        "either don't exist, you don't have access to them, or your session has expired."
    end

    it 'returns success response' do
      allow(tool).to receive(:request).and_return(ai_response)

      expect(tool.execute.content).to eq(response)
    end
  end

  describe '#name' do
    it 'returns tool name' do
      expect(described_class::NAME).to eq('WorkItemReader')
    end

    it 'returns tool human name' do
      expect(described_class::HUMAN_NAME).to eq('Work Item Search')
    end
  end

  describe '#execute', :saas do
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be_with_reload(:project) { create(:project, group: group) }

    before_all do
      project.add_guest(user)
    end

    before do
      stub_const("::Gitlab::Llm::Chain::Tools::WorkItemReader::Prompts::Anthropic::MAX_CHARACTERS",
        999999)
      allow(tool).to receive(:provider_prompt_class)
                       .and_return(::Gitlab::Llm::Chain::Tools::WorkItemReader::Prompts::Anthropic)
    end

    context 'when work item is identified' do
      let_it_be(:work_item_1) { create(:work_item, project: project) }
      let_it_be(:work_item_2) { create(:work_item, project: project) }

      let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::AiGateway) }

      let(:context) do
        Gitlab::Llm::Chain::GitlabContext.new(
          container: project,
          resource: work_item_1,
          current_user: user,
          ai_request: ai_request_double
        )
      end

      let(:tool) { described_class.new(context: context, options: input_variables, stream_response_handler: nil) }
      let(:input_variables) do
        { input: "user input", suggestions: "Action: WorkItemReader\nActionInput: #{work_item_1.iid}" }
      end

      context 'when user has permission to read resource' do
        include_context 'with duo pro addon'

        before do
          stub_application_setting(check_namespace_plan: true)
          stub_licensed_features(ai_chat: true, epics: true)

          allow(project.root_ancestor.namespace_settings).to receive(:experiment_settings_allowed?).and_return(true)
          project.root_ancestor.update!(experiment_features_enabled: true)
        end

        context 'when ai response has invalid JSON' do
          it 'retries the ai call' do
            input_variables = { input: "user input", suggestions: "" }
            tool = described_class.new(context: context, options: input_variables)

            allow(tool).to receive(:request).and_return("random string")
            allow(Gitlab::Json).to receive(:parse).and_raise(JSON::ParserError)

            expect(tool).to receive(:request).exactly(3).times

            answer = tool.execute

            response = "I'm sorry, I can't generate a response. You might want to try again. " \
              "You could also be getting this error because the items you're asking about " \
              "either don't exist, you don't have access to them, or your session has expired."
            expect(answer.content).to eq(response)
            expect(answer.error_code).to eq("M3003")
          end
        end

        context 'when there is a StandardError' do
          it 'returns an error' do
            input_variables = { input: "user input", suggestions: "" }
            tool = described_class.new(context: context, options: input_variables)
            answer = tool.execute

            allow(tool).to receive(:request).and_raise(StandardError)

            expect(answer.content).to eq("I'm sorry, I can't generate a response. Please try again.")
            expect(answer.error_code).to eq("M4001")
          end
        end

        context 'when work item is the current work item in context' do
          let(:identifier) { 'current' }
          let(:ai_response) { "current\", \"ResourceIdentifier\": \"#{identifier}\"}" }
          let(:resource) { work_item_1 }

          it_behaves_like 'success response'
        end

        context 'when work item is identified by iid' do
          let(:identifier) { work_item_2.iid }
          let(:ai_response) { "iid\", \"ResourceIdentifier\": #{identifier}}" }
          let(:resource) { work_item_2 }

          it_behaves_like 'success response'
        end

        context 'when work item is identified by url' do
          let(:identifier) { Gitlab::UrlBuilder.build(work_item_2).gsub('issues', 'work_items') }
          let(:ai_response) { "url\", \"ResourceIdentifier\": \"#{identifier}\"\}" }
          let(:resource) { work_item_2 }

          it_behaves_like 'success response'
        end

        context 'when work item mistaken with an MR' do
          let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

          let(:ai_response) { "current\", \"ResourceIdentifier\": \"current\"}" }

          before do
            context.resource = merge_request
          end

          it_behaves_like 'work item not found response'
        end

        context 'when context container is a group' do
          before do
            context.container = group
          end

          let(:identifier) { work_item_2.iid }
          let(:ai_response) { "iid\", \"ResourceIdentifier\": #{identifier}}" }
          let(:resource) { work_item_2 }

          it_behaves_like 'success response'

          context 'when multiple work items are identified' do
            let_it_be(:project) { create(:project, group: group) }
            let_it_be(:work_item_3) { create(:work_item, iid: work_item_2.iid, project: project) }

            let(:identifier) { work_item_2.iid }
            let(:ai_response) { "iid\", \"ResourceIdentifier\": #{identifier}}" }

            it_behaves_like 'work item not found response'
          end
        end

        context 'when context container is a project namespace' do
          before do
            context.container = project.project_namespace
          end

          context 'when work item is the current work item in context' do
            let(:identifier) { work_item_2.iid }
            let(:ai_response) { "iid\", \"ResourceIdentifier\": #{identifier}}" }
            let(:resource) { work_item_2 }

            it_behaves_like 'success response'
          end
        end

        context 'when context container is nil' do
          before do
            context.container = nil
          end

          context 'when work item is identified by iid' do
            let(:identifier) { work_item_2.iid }
            let(:ai_response) { "iid\", \"ResourceIdentifier\": #{identifier}}" }

            it_behaves_like 'work item not found response'
          end

          context 'when work item is identified by url' do
            let(:identifier) { Gitlab::UrlBuilder.build(work_item_2).gsub('issues', 'work_items') }
            let(:ai_response) { "url\", \"ResourceIdentifier\": \"#{identifier}\"\}" }
            let(:resource) { work_item_2 }

            it_behaves_like 'success response'
          end

          context 'when work item is the current work item in context' do
            let(:identifier) { 'current' }
            let(:ai_response) { "current\", \"ResourceIdentifier\": \"#{identifier}\"}" }
            let(:resource) { work_item_1 }

            it_behaves_like 'success response'
          end

          context 'when work item belongs to other project' do
            let_it_be(:other_project) { create(:project, :public) }
            let_it_be(:other_work_item) { create(:work_item, project: other_project) }

            context 'when work item is identified by url' do
              let(:identifier) { Gitlab::UrlBuilder.build(other_work_item).gsub('issues', 'work_items') }
              let(:ai_response) { "url\", \"ResourceIdentifier\": \"#{identifier}\"\}" }
              let(:resource) { other_work_item }

              it_behaves_like 'success response'
            end
          end

          context 'when work item belongs to other group' do
            let_it_be(:epic) { create(:epic, group: group) }
            let_it_be(:other_work_item) { epic.work_item }

            before_all do
              group.add_developer(user)
            end

            context 'when work item is identified by url' do
              let(:identifier) { Gitlab::UrlBuilder.build(other_work_item).gsub('epics', 'work_items') }
              let(:ai_response) { "url\", \"ResourceIdentifier\": \"#{identifier}\"\}" }
              let(:resource) { other_work_item }

              it_behaves_like 'success response'
            end
          end

          context 'when identifier is not readable' do
            let_it_be(:other_project) { create(:project, :public) }
            let_it_be(:other_work_item) { create(:work_item, project: other_project) }

            context 'when work item is identified by url' do
              let(:identifier) { "http://url.does.not.make.sense" }
              let(:ai_response) { "url\", \"ResourceIdentifier\": \"#{identifier}\"\}" }
              let(:resource) { other_work_item }

              it_behaves_like 'work item not found response'
            end
          end

          context 'when group does not have ai enabled' do
            let(:identifier) { 'current' }
            let(:ai_response) { "current\", \"ResourceIdentifier\": \"#{identifier}\"}" }
            let(:resource) { work_item_1 }

            before do
              stub_licensed_features(ai_chat: false)
            end

            it_behaves_like 'success response'

            context 'when duo features are disabled for project' do
              let(:identifier) { 'current' }
              let(:ai_response) { "current\", \"ResourceIdentifier\": \"#{identifier}\"}" }
              let(:response) do
                "I am sorry, I cannot access the information you are asking about. " \
                  "A group or project owner has turned off Duo features in this group or project."
              end

              before do
                project.update!(duo_features_enabled: false)
              end

              it 'returns success response' do
                allow(tool).to receive(:request).and_return(ai_response)

                expect(tool.execute.content).to eq(response)
              end
            end
          end
        end

        context 'when work item was already identified' do
          let(:resource_iid) { work_item_1.iid }
          let(:ai_response) { "iid\", \"ResourceIdentifier\": #{work_item_1.iid}}" }

          before do
            context.tools_used << described_class
          end

          it 'returns already identified response' do
            ai_request = double
            allow(ai_request).to receive_message_chain(:complete, :dig, :to_s, :strip).and_return(ai_response)
            allow(context).to receive(:ai_request).and_return(ai_request)

            response = "You already have identified the work item #{context.resource.to_global_id}, read carefully."
            expect(tool.execute.content).to eq(response)
          end
        end
      end
    end
  end
end

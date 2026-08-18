# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::BuildReader::Executor, feature_category: :duo_chat do
  before do
    stub_application_setting(ci_job_live_trace_enabled: true)
  end

  RSpec.shared_examples 'success response' do
    it 'returns success response' do
      ai_request = double
      allow(ai_request).to receive(:request).and_return(ai_response)
      allow(context).to receive(:ai_request).and_return(ai_request)

      content = tool.execute.content

      expect(content).to include("Please use this information about identified ci build:")
      expect(content).to include("<job-log>BUILD TRACE</job-log>")
    end
  end

  RSpec.shared_examples 'build not found response' do
    it 'returns success response' do
      allow(tool).to receive(:request).and_return(ai_response)

      response = "I'm sorry, I can't generate a response. You might want to try again. " \
        "You could also be getting this error because the items you're asking about " \
        "either don't exist, you don't have access to them, or your session has expired."
      expect(tool.execute.content).to eq(response)
    end
  end

  describe '#name' do
    it 'returns tool name' do
      expect(described_class::NAME).to eq('BuildReader')
    end

    it 'returns tool human name' do
      expect(described_class::HUMAN_NAME).to eq('Build Search')
    end
  end

  describe '#unit_primitive' do
    let(:tool) { described_class.new(context: context, options: {}, stream_response_handler: nil) }
    let(:context) { instance_double(Gitlab::Llm::Chain::GitlabContext) }

    it 'returns tool unit_primitive' do
      expect(tool.unit_primitive).to eq('build_reader')
    end
  end

  describe '#execute', :saas do
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be_with_reload(:project) { create(:project, group: group) }
    let_it_be(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group)
    end

    let_it_be(:seat_assignment) do
      create(
        :gitlab_subscription_user_add_on_assignment,
        user: user,
        add_on_purchase: add_on_purchase
      )
    end

    before_all do
      project.add_developer(user)
    end

    before do
      stub_const("::Gitlab::Llm::Chain::Tools::BuildReader::Prompts::Anthropic::MAX_CHARACTERS",
        999999)
      allow(tool).to receive(:provider_prompt_class)
                       .and_return(::Gitlab::Llm::Chain::Tools::BuildReader::Prompts::Anthropic)
    end

    context 'when build is identified' do
      let(:build1) { create(:ci_build,  :trace_live, project: project) }
      let(:build2) { create(:ci_build,  :trace_live, project: project) }
      let(:context) do
        Gitlab::Llm::Chain::GitlabContext.new(
          container: project,
          resource: build1,
          current_user: user,
          ai_request: double
        )
      end

      let(:tool) { described_class.new(context: context, options: input_variables, stream_response_handler: nil) }
      let(:input_variables) do
        { input: "user input", suggestions: "Action: BuildReader\nActionInput: #{build1.id}" }
      end

      context 'when user has permission to read resource' do
        before do
          stub_application_setting(check_namespace_plan: true)
          stub_licensed_features(ai_chat: true)

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

            response = "I'm sorry, I can't generate a response. You might want to try again. " \
              "You could also be getting this error because the items you're asking about " \
              "either don't exist, you don't have access to them, or your session has expired."
            expect(tool.execute.content).to eq(response)
          end
        end

        context 'when there is a StandardError' do
          it 'returns an error' do
            input_variables = { input: "user input", suggestions: "" }
            tool = described_class.new(context: context, options: input_variables)

            allow(tool).to receive(:request).and_raise(StandardError)

            expect(tool.execute.content).to eq("I'm sorry, I can't generate a response. Please try again.")
          end
        end

        context 'when build is the current build in context' do
          let(:identifier) { 'current' }
          let(:ai_response) { "current\", \"ResourceIdentifier\": \"#{identifier}\"}" }
          let(:resource) { build1 }

          it_behaves_like 'success response'
        end

        context 'when build mistaken with an issue' do
          let_it_be(:issue) { create(:issue, project: project) }

          let(:ai_response) { "current\", \"ResourceIdentifier\": \"current\"}" }

          before do
            context.resource = issue
          end

          it_behaves_like 'build not found response'
        end

        context 'when context container is a group' do
          before do
            context.container = group
          end

          let(:identifier) { build2.id }
          let(:ai_response) { "current\", \"ResourceIdentifier\": #{identifier}}" }
          let(:resource) { build2 }

          it_behaves_like 'success response'
        end

        context 'when context container is a project namespace' do
          before do
            context.container = project.project_namespace
          end

          context 'when build is the current build in context' do
            let(:identifier) { build2.id }
            let(:ai_response) { "current\", \"ResourceIdentifier\": #{identifier}}" }
            let(:resource) { build2 }

            it_behaves_like 'success response'
          end
        end

        context 'when context container is nil' do
          before do
            context.container = nil
          end

          context 'when build is the current build in context' do
            let(:identifier) { 'current' }
            let(:ai_response) { "current\", \"ResourceIdentifier\": \"#{identifier}\"}" }
            let(:resource) { build1 }

            it_behaves_like 'success response'
          end

          context 'when group does not have ai enabled' do
            let(:identifier) { 'current' }
            let(:ai_response) { "current\", \"ResourceIdentifier\": \"#{identifier}\"}" }
            let(:resource) { build1 }

            before do
              stub_licensed_features(ai_chat: false)
            end

            it_behaves_like 'success response'
          end

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

        context 'when build was already identified' do
          let(:resource_id) { build1.id }
          let(:ai_response) { "current\", \"ResourceIdentifier\": #{build1.id}}" }

          before do
            context.tools_used << described_class
          end

          it 'returns already identified response' do
            ai_request = double
            allow(ai_request).to receive_message_chain(:complete, :dig, :to_s, :strip).and_return(ai_response)
            allow(context).to receive(:ai_request).and_return(ai_request)

            response = "You already have identified the ci build #{context.resource.to_global_id}, read carefully."
            expect(tool.execute.content).to eq(response)
          end
        end

        context 'with valid build url' do
          let(:resource_id) { build1.id }
          let(:ai_response) { "url\", \"ResourceIdentifier\": \"#{url}\"}" }
          let(:url) { "https://example.com/some/path/-/builds/#{build1.id}" }

          it_behaves_like 'success response'
        end

        context 'with invalid build url' do
          let(:ai_response) { "url\", \"ResourceIdentifier\": \"#{url}\"}" }
          let(:url) { "https://example.com/some/path/-/builds/999999999999dfd11" }

          it "returns success response with an explanatory message" do
            allow(tool).to receive(:request).and_return(ai_response)

            expect(tool.execute.content).to eq("I'm sorry, I can't generate a response. Please try again.")
          end
        end
      end
    end
  end
end

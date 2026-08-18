# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::MergeRequestReader::Executor, feature_category: :duo_chat do
  RSpec.shared_examples 'success response' do
    it 'returns success response' do
      ai_request = double
      expect(ai_request).to receive(:request).with(
        hash_including(options: hash_including(prompt_version: '^1.0.0')),
        unit_primitive: 'merge_request_reader'
      ).and_return(ai_response)

      allow(context).to receive(:ai_request).and_return(ai_request)
      resource_serialized = Ai::AiResource::MergeRequest.new(context.current_user, resource)
        .serialize_for_ai(
          content_limit: ::Gitlab::Llm::Chain::Tools::MergeRequestReader::Prompts::Anthropic::MAX_CHARACTERS
        ).to_xml(root: :root, skip_types: true, skip_instruct: true)

      response = "Please use this information about identified merge request: #{resource_serialized}"

      expect(tool.execute.content).to eq(response)
    end
  end

  RSpec.shared_examples 'merge request not found response' do
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
      expect(described_class::NAME).to eq('MergeRequestReader')
    end

    it 'returns tool human name' do
      expect(described_class::HUMAN_NAME).to eq('Merge Request Search')
    end
  end

  describe '#description' do
    it 'returns tool description' do
      expect(described_class::DESCRIPTION)
        .to include('Gets the content of the current merge request (also referenced as this or that, or MR)')
    end
  end

  describe '#execute', :saas do
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be_with_reload(:project) { create(:project, group: group) }

    include_context "with duo pro addon"

    before_all do
      project.add_developer(user)
    end

    before do
      stub_const("::Gitlab::Llm::Chain::Tools::MergeRequestReader::Prompts::Anthropic::MAX_CHARACTERS",
        999999)
      allow(tool).to receive(:provider_prompt_class)
                       .and_return(::Gitlab::Llm::Chain::Tools::MergeRequestReader::Prompts::Anthropic)
    end

    context 'when merge request is identified' do
      let_it_be(:merge_request1) { create(:merge_request, source_project: project, source_branch: 'branch-1') }
      let_it_be(:merge_request2) { create(:merge_request, source_project: project, source_branch: 'branch-2') }

      let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::AiGateway) }

      let(:context) do
        Gitlab::Llm::Chain::GitlabContext.new(
          container: project,
          resource: merge_request1,
          current_user: user,
          ai_request: ai_request_double
        )
      end

      let(:tool) { described_class.new(context: context, options: input_variables, stream_response_handler: nil) }
      let(:input_variables) do
        { input: "user input", suggestions: "Action: MergeRequestReader\nActionInput: #{merge_request1.iid}" }
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

        context 'when merge request is the current MR in context' do
          let(:identifier) { 'current' }
          let(:ai_response) { "current\", \"ResourceIdentifier\": \"#{identifier}\"}" }
          let(:resource) { merge_request1 }

          it_behaves_like 'success response'
        end

        context 'when merge request is identified by iid' do
          let(:identifier) { merge_request2.iid }
          let(:ai_response) { "iid\", \"ResourceIdentifier\": #{identifier}}" }
          let(:resource) { merge_request2 }

          it_behaves_like 'success response'
        end

        context 'when is merge request identified with reference' do
          let(:identifier) { merge_request2.to_reference(full: true) }
          let(:ai_response) do
            "reference\", \"ResourceIdentifier\": \"#{identifier}\"}"
          end

          let(:resource) { merge_request2 }

          it_behaves_like 'success response'
        end

        context 'when MR mistaken with an issue' do
          let_it_be(:issue) { create(:issue, project: project) }

          let(:ai_response) { "current\", \"ResourceIdentifier\": \"current\"}" }

          before do
            context.resource = issue
          end

          it_behaves_like 'merge request not found response'
        end

        context 'when context container is a group' do
          before do
            context.container = group
          end

          let(:identifier) { merge_request2.iid }
          let(:ai_response) { "iid\", \"ResourceIdentifier\": #{identifier}}" }
          let(:resource) { merge_request2 }

          it_behaves_like 'success response'

          context 'when multiple merge requests are identified' do
            let_it_be(:project) { create(:project, group: group) }
            let_it_be(:merge_request3) { create(:merge_request, iid: merge_request2.iid, source_project: project) }

            let(:identifier) { merge_request2.iid }
            let(:ai_response) { "iid\", \"ResourceIdentifier\": #{identifier}}" }

            it_behaves_like 'merge request not found response'
          end
        end

        context 'when context container is a project namespace' do
          before do
            context.container = project.project_namespace
          end

          context 'when merge request is the current merge_request in context' do
            let(:identifier) { merge_request2.iid }
            let(:ai_response) { "iid\", \"ResourceIdentifier\": #{identifier}}" }
            let(:resource) { merge_request2 }

            it_behaves_like 'success response'
          end
        end

        context 'when context container is nil' do
          before do
            context.container = nil
          end

          context 'when merge request is identified by iid' do
            let(:identifier) { merge_request2.iid }
            let(:ai_response) { "iid\", \"ResourceIdentifier\": #{identifier}}" }

            it_behaves_like 'merge request not found response'
          end

          context 'when merge request is the current MR in context' do
            let(:identifier) { 'current' }
            let(:ai_response) { "current\", \"ResourceIdentifier\": \"#{identifier}\"}" }
            let(:resource) { merge_request1 }

            it_behaves_like 'success response'
          end

          context 'when is merge request identified with reference' do
            let(:identifier) { merge_request2.to_reference(full: true) }
            let(:ai_response) do
              "reference\", \"ResourceIdentifier\": \"#{identifier}\"}"
            end

            let(:resource) { merge_request2 }

            it_behaves_like 'success response'
          end

          context 'when is merge request identified with not-full reference' do
            let(:identifier) { merge_request2.to_reference(full: false) }
            let(:ai_response) do
              "reference\", \"ResourceIdentifier\": \"#{identifier}\"}"
            end

            it_behaves_like 'merge request not found response'
          end

          context 'when group does not have ai enabled' do
            let(:identifier) { 'current' }
            let(:ai_response) { "current\", \"ResourceIdentifier\": \"#{identifier}\"}" }
            let(:resource) { merge_request1 }

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

        context 'when merge request was already identified' do
          let(:resource_iid) { merge_request1.iid }
          let(:ai_response) { "iid\", \"ResourceIdentifier\": #{merge_request1.iid}}" }

          before do
            context.tools_used << described_class
          end

          it 'returns already identified response' do
            ai_request = double
            allow(ai_request).to receive_message_chain(:complete, :dig, :to_s, :strip).and_return(ai_response)
            allow(context).to receive(:ai_request).and_return(ai_request)

            response = "You already have identified the merge request #{context.resource.to_global_id}, read carefully."
            expect(tool.execute.content).to eq(response)
          end
        end
      end
    end
  end
end

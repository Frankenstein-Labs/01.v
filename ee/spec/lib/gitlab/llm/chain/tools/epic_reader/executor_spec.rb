# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::EpicReader::Executor, feature_category: :duo_chat do
  RSpec.shared_examples 'success response' do
    it 'returns success response' do
      ai_request = double
      allow(ai_request).to receive(:request).and_return(ai_response)
      allow(context).to receive(:ai_request).and_return(ai_request)
      resource_serialized = Ai::AiResource::Epic.new(context.current_user, resource)
        .serialize_for_ai(
          content_limit: ::Gitlab::Llm::Chain::Tools::EpicReader::Prompts::Anthropic::MAX_CHARACTERS
        ).to_xml(root: :root, skip_types: true, skip_instruct: true)

      response = "Please use this information about identified epic: #{resource_serialized}"

      expect(tool.execute.content).to eq(response)
    end
  end

  RSpec.shared_examples 'epic not found response' do
    it 'returns response that epic was not found' do
      allow(tool).to receive(:request).and_return(ai_response)

      answer = tool.execute

      response = "I'm sorry, I can't generate a response. You might want to try again. " \
        "You could also be getting this error because the items you're asking about " \
        "either don't exist, you don't have access to them, or your session has expired."
      expect(answer.content).to eq(response)
      expect(answer.error_code).to eq("M3003")
    end
  end

  describe '#name' do
    it 'returns tool name' do
      expect(described_class::NAME).to eq('EpicReader')
    end

    it 'returns tool human name' do
      expect(described_class::HUMAN_NAME).to eq('Epic Search')
    end
  end

  describe '#description' do
    it 'returns tool description' do
      expect(described_class::DESCRIPTION)
        .to include('This tool retrieves the content of a specific epic')
    end
  end

  describe '#execute', :saas do
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
    # we need project for Gitlab::ReferenceExtractor
    let_it_be(:project) { create(:project, group: group) }

    include_context "with duo pro addon"

    before do
      stub_const("::Gitlab::Llm::Chain::Tools::IssueReader::Prompts::Anthropic::MAX_CHARACTERS",
        999999)
      allow(tool).to receive(:provider_prompt_class)
                     .and_return(::Gitlab::Llm::Chain::Tools::IssueReader::Prompts::Anthropic)
    end

    context 'when epic is identified' do
      let_it_be(:epic1, freeze: false) { create(:epic, group: group) }
      let_it_be(:epic2) { create(:epic, group: group) }

      let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::AiGateway) }

      let(:context) do
        Gitlab::Llm::Chain::GitlabContext.new(
          container: group,
          resource: epic1,
          current_user: user,
          ai_request: ai_request_double
        )
      end

      let(:tool) { described_class.new(context: context, options: input_variables) }
      let(:input_variables) do
        { input: "user input", suggestions: "Action: EpicReader\nActionInput: #{epic1.iid}" }
      end

      context 'when user does not have permission to read resource' do
        context 'when is epic identified with iid' do
          let(:ai_response) { "{\"ResourceIdentifierType\": \"iid\", \"ResourceIdentifier\": #{epic2.iid}}" }

          it_behaves_like 'epic not found response'
        end

        context 'when is epic identified with reference' do
          let(:ai_response) do
            "{\"ResourceIdentifierType\": \"url\", \"ResourceIdentifier\": #{epic1.to_reference(full: true)}}"
          end

          it_behaves_like 'epic not found response'
        end

        context 'when is epic identified with url' do
          let(:url) { Gitlab::Routing.url_helpers.group_epic_url(group, epic2) }
          let(:ai_response) { "{\"ResourceIdentifierType\": \"url\", \"ResourceIdentifier\": \"#{url}\"}" }

          it_behaves_like 'epic not found response'
        end
      end

      context 'when user has permission to read resource' do
        before_all do
          group.add_guest(user)
        end

        before do
          stub_application_setting(check_namespace_plan: true)
          stub_licensed_features(ai_chat: true, epics: true)
          group.update!(experiment_features_enabled: true)
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

            allow(tool).to receive(:request).and_raise(StandardError)

            expect(tool.execute.content).to eq("I'm sorry, I can't generate a response. Please try again.")
          end
        end

        context 'when epic is the current epic in context' do
          let(:identifier) { 'current' }
          let(:ai_response) { "current\", \"ResourceIdentifier\": \"#{identifier}\"}" }
          let(:resource) { epic1 }

          it_behaves_like 'success response'
        end

        context 'when epic is identified by iid' do
          let(:identifier) { epic2.iid }
          let(:ai_response) { "iid\", \"ResourceIdentifier\": #{identifier}}" }
          let(:resource) { epic2 }

          it_behaves_like 'success response'
        end

        context 'when is epic identified with reference' do
          let(:identifier) { epic2.to_reference(full: true) }
          let(:ai_response) do
            "reference\", \"ResourceIdentifier\": \"#{identifier}\"}"
          end

          let(:resource) { epic2 }

          it_behaves_like 'success response'
        end

        context 'when is epic identified with url' do
          let(:identifier) { Gitlab.com_url + Gitlab::Routing.url_helpers.group_epic_path(group, epic2) }
          let(:ai_response) { "url\", \"ResourceIdentifier\": \"#{identifier}\"}" }
          let(:resource) { epic2 }

          it_behaves_like 'success response'
        end

        context 'when context container is a group' do
          before do
            context.container = group
          end

          let(:identifier) { epic2.iid }
          let(:ai_response) { "iid\", \"ResourceIdentifier\": #{identifier}}" }
          let(:resource) { epic2 }

          it_behaves_like 'success response'
        end

        context 'when ai response is a fully formed json' do
          let(:identifier) { Gitlab.com_url + Gitlab::Routing.url_helpers.group_epic_path(group, epic2) }
          let(:resource) { epic2 }
          let(:ai_response) { "{\"ResourceIdentifierType\": \"url\", \"ResourceIdentifier\": \"#{identifier}\"}```" }

          it_behaves_like 'success response'
        end

        context 'when context container is nil' do
          before do
            context.container = nil
          end

          context 'when epic is identified by iid' do
            let(:identifier) { epic2.iid }
            let(:ai_response) { "iid\", \"ResourceIdentifier\": #{identifier}}" }
            let(:response) do
              "I'm sorry, I can't generate a response. You might want to try again. " \
                "You could also be getting this error because the items you're asking about " \
                "either don't exist, you don't have access to them, or your session has expired."
            end

            it 'returns response indicating the user does not have access' do
              allow(tool).to receive(:request).and_return(ai_response)

              expect(tool.execute.content).to eq(response)
            end
          end

          context 'when epic is the current epic in context' do
            let(:identifier) { 'current' }
            let(:ai_response) { "current\", \"ResourceIdentifier\": \"#{identifier}\"}" }
            let(:resource) { epic1 }

            it_behaves_like 'success response'
          end

          context 'when is epic identified with reference' do
            let(:identifier) { epic2.to_reference(full: true) }
            let(:ai_response) do
              "reference\", \"ResourceIdentifier\": \"#{identifier}\"}"
            end

            let(:resource) { epic2 }

            it_behaves_like 'success response'
          end

          context 'when is epic identified with not-full reference' do
            let(:identifier) { epic2.to_reference(full: false) }
            let(:ai_response) do
              "reference\", \"ResourceIdentifier\": \"#{identifier}\"}"
            end

            let(:resource) { epic2 }

            it_behaves_like 'success response'
          end

          context 'when is epic identified with url' do
            let(:identifier) { Gitlab.com_url + Gitlab::Routing.url_helpers.group_epic_path(group, epic2) }
            let(:ai_response) { "url\", \"ResourceIdentifier\": \"#{identifier}\"}" }
            let(:resource) { epic2 }

            it_behaves_like 'success response'
          end
        end

        context 'when epic was already identified' do
          let(:resource_iid) { epic1.iid }
          let(:ai_response) { "iid\", \"ResourceIdentifier\": #{epic1.iid}}" }

          before do
            context.tools_used << described_class
          end

          it 'returns already identified response' do
            ai_request = double
            allow(ai_request).to receive_message_chain(:complete, :dig, :to_s, :strip).and_return(ai_response)
            allow(context).to receive(:ai_request).and_return(ai_request)

            response = "You already have identified the epic #{context.resource.to_global_id}, read carefully."
            expect(tool.execute.content).to eq(response)
          end
        end

        context 'when group does not have ai enabled' do
          let(:identifier) { epic2.to_reference(full: true) }
          let(:ai_response) do
            "reference\", \"ResourceIdentifier\": \"#{identifier}\"}"
          end

          let(:resource) { epic2 }

          before do
            stub_licensed_features(epics: true, ai_chat: false)
          end

          it_behaves_like 'success response'

          context 'when duo features are disabled for group' do
            let(:identifier) { epic2.to_reference(full: true) }
            let(:ai_response) do
              "reference\", \"ResourceIdentifier\": \"#{identifier}\"}"
            end

            let(:response) do
              "I am sorry, I cannot access the information you are asking about. " \
                "A group or project owner has turned off Duo features in this group or project."
            end

            before do
              group.namespace_settings.reload.update!(duo_features_enabled: false)
              stub_licensed_features(epics: true, ai_chat: false)
            end

            it 'returns success response' do
              allow(tool).to receive(:request).and_return(ai_response)

              expect(tool.execute.content).to eq(response)
            end
          end
        end
      end

      describe '#get_resources' do
        let(:extractor) { double }

        context 'when work items are referenced' do
          let(:work_item) { create(:work_item, :epic, namespace: group, synced_epic: epic1) }

          before do
            allow(extractor).to receive(:has_work_item_references?).and_return(true)
            allow(extractor).to receive(:work_items).and_return([work_item])
          end

          it 'returns synced epics from work items' do
            expect(tool.send(:get_resources, extractor)).to eq([epic1])
          end
        end

        context 'when epics are referenced' do
          before do
            allow(extractor).to receive(:has_work_item_references?).and_return(false)
            allow(extractor).to receive(:epics).and_return([epic1])
          end

          it 'returns epics' do
            expect(tool.send(:get_resources, extractor)).to eq([epic1])
          end
        end
      end
    end
  end
end

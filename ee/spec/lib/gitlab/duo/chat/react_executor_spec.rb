# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Chat::ReactExecutor, feature_category: :duo_chat do
  include FakeBlobHelpers
  describe "#execute" do
    subject(:answer) { agent.execute }

    # rubocop:disable RSpec/MultipleMemoizedHelpers -- All the memoized vars are necessary
    let(:agent) do
      described_class.new(
        user_input: user_input,
        tools: tools,
        context: context,
        response_handler: response_service_double,
        stream_response_handler: stream_response_service_double
      )
    end

    let_it_be(:root_namespace) { create(:group) }
    let_it_be(:organization) { create(:common_organization) }
    let_it_be(:user) { create(:user, organization: organization) }
    let_it_be(:project) { create(:project, developers: [user]) }
    let_it_be(:issue) { create(:issue, project: project) }

    let(:resource) { issue }
    let(:user_input) { 'question?' }
    let(:tools) { [Gitlab::Llm::Chain::Tools::IssueReader] }
    let(:tool_double) { instance_double(Gitlab::Llm::Chain::Tools::IssueReader::Executor) }
    let(:response_service_double) { instance_double(::Gitlab::Llm::ResponseService) }
    let(:stream_response_service_double) { instance_double(::Gitlab::Llm::ResponseService) }
    let(:extra_resource) { {} }
    let(:started_at_timestamp) { 2.seconds.ago.to_i }
    let(:current_file) { nil }
    let(:model_metadata) do
      { feature_setting: "duo_chat", identifier: nil, provider: "gitlab" }
    end

    let(:additional_context) do
      [
        { category: 'snippet', id: 'hello world', content: 'puts "Hello, world"', metadata: {} }
      ]
    end

    let(:context) do
      Gitlab::Llm::Chain::GitlabContext.new(
        current_user: user,
        container: nil,
        resource: resource,
        ai_request: nil,
        extra_resource: extra_resource,
        started_at: started_at_timestamp,
        current_file: current_file,
        agent_version: nil,
        additional_context: additional_context
      )
    end

    let(:issue_resource) { Ai::AiResource::Issue.new(user, resource) }
    let(:issue_page_params) { { type: issue_resource.current_page_type, title: resource.title } }

    let(:answer_chunk) { create(:final_answer_chunk, chunk: "Ans") }

    let(:step_params) do
      {
        messages: [{
          role: "user",
          content: user_input,
          context: issue_page_params,
          current_file: nil,
          additional_context: context.additional_context
        }],
        model_metadata: model_metadata,
        unavailable_resources: %w[Pipelines Vulnerabilities]
      }
    end

    let(:action_event) do
      Gitlab::Duo::Chat::AgentEvents::Action.new(
        {
          "thought" => 'I think I need to use issue_reader',
          "tool" => 'issue_reader',
          "tool_input" => '#123'
        }
      )
    end

    before do
      allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive(:container).and_return(
        Gitlab::Llm::Utils::Authorizer::Response.new(allowed: true)
      )
      allow(Gitlab::AiGateway).to receive(:headers).and_return({})
      allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(root_namespace)
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    def expect_sli_error(failed)
      expect(Gitlab::Metrics::Sli::ErrorRate[:llm_chat_first_token]).to receive(:increment).with(
        labels: described_class::SLI_LABEL,
        error: failed
      )
    end

    context "when answer is final" do
      let(:another_chunk) { create(:final_answer_chunk, chunk: "wer") }
      let(:first_response_double) { double }
      let(:second_response_double) { double }
      let(:step_params) do
        {
          messages: [
            {
              role: "user",
              content: user_input,
              context: issue_page_params,
              current_file: nil,
              additional_context: context.additional_context
            },
            {
              agent_scratchpad: [{ observation: "observation" }],
              role: "assistant"
            }
          ],
          model_metadata: model_metadata,
          unavailable_resources: %w[Pipelines Vulnerabilities]
        }
      end

      let(:react_agent_double) { instance_double(Gitlab::Duo::Chat::StepExecutor) }

      before do
        event_1 = Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta.new({ "text" => "Ans" })
        event_2 = Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta.new({ "text" => "wer" })

        allow(Gitlab::Duo::Chat::StepExecutor).to receive(:new).and_return(react_agent_double)
        allow(react_agent_double).to receive(:agent_steps).and_return([{ observation: 'observation' }])
        allow(react_agent_double).to receive(:step).with(step_params)
          .and_yield(event_1).and_yield(event_2).and_return([event_1, event_2])

        allow(Gitlab::Llm::Chain::StreamedResponseModifier).to receive(:new).with(event_1.text, { chunk_id: 1 })
                                                                            .and_return(first_response_double)
        allow(Gitlab::Llm::Chain::StreamedResponseModifier).to receive(:new).with(event_2.text, { chunk_id: 2 })
                                                                            .and_return(second_response_double)
      end

      it "streams final answer" do
        expect(agent).to receive(:log_info).with(
          message: "ReAct turn", react_turn: 0, event_name: 'react_turn', ai_component: 'duo_chat')

        expect(react_agent_double).to receive(:step).with(step_params)

        expect(stream_response_service_double).to receive(:execute).with(
          response: first_response_double,
          options: { chunk_id: 1 }
        )
        expect(stream_response_service_double).to receive(:execute).with(
          response: second_response_double,
          options: { chunk_id: 2 }
        )
        expect_sli_error(false)

        expect(answer.is_final?).to be_truthy
        expect(answer.content).to include("Answer")
        expect(answer.extras).to include(agent_scratchpad: [{ observation: "observation" }])
      end

      context 'when started_at was too long ago' do
        let(:started_at_timestamp) { 10.seconds.ago.to_i }

        it "emits TTFT apdex" do
          expect(Gitlab::Metrics::Sli::Apdex[:llm_chat_first_token]).to receive(:increment).with(
            labels: { feature_category: :duo_chat, service_class: 'Gitlab::Llm::Completions::Chat' },
            success: false
          )

          expect(stream_response_service_double).to receive(:execute).with(
            response: first_response_double,
            options: { chunk_id: 1 }
          )
          expect(stream_response_service_double).to receive(:execute).with(
            response: second_response_double,
            options: { chunk_id: 2 }
          )

          expect(answer.content).to include("Answer")
        end
      end

      context 'when started_at was recent' do
        let(:started_at_timestamp) { 3.seconds.ago.to_i }

        it "emits TTFT apdex" do
          expect(Gitlab::Metrics::Sli::Apdex[:llm_chat_first_token]).to receive(:increment).with(
            labels: { feature_category: :duo_chat, service_class: 'Gitlab::Llm::Completions::Chat' },
            success: true
          )

          expect(stream_response_service_double).to receive(:execute).with(
            response: first_response_double,
            options: { chunk_id: 1 }
          )
          expect(stream_response_service_double).to receive(:execute).with(
            response: second_response_double,
            options: { chunk_id: 2 }
          )

          expect(answer.content).to include("Answer")
        end
      end

      context 'when started_at is absent' do
        let(:started_at_timestamp) { nil }

        it "does not emit TTFT apdex" do
          expect(Gitlab::Metrics::Sli::Apdex[:llm_chat_first_token]).not_to receive(:increment)

          expect(stream_response_service_double).to receive(:execute).with(
            response: first_response_double,
            options: { chunk_id: 1 }
          )
          expect(stream_response_service_double).to receive(:execute).with(
            response: second_response_double,
            options: { chunk_id: 2 }
          )

          expect(answer.content).to include("Answer")
        end
      end
    end

    context "when tool answer is final" do
      let(:tool_answer) { create(:answer, :final, content: 'tool answer') }

      before do
        event = Gitlab::Duo::Chat::AgentEvents::Action.new(
          {
            "thought" => 'I think I need to use issue_reader',
            "tool" => 'issue_reader',
            "tool_input" => '#123'
          }
        )

        allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          allow(react_agent).to receive(:step).with(step_params)
            .and_yield(event).and_return([event])
        end

        allow_next_instance_of(Gitlab::Llm::Chain::Tools::IssueReader::Executor) do |issue_tool|
          allow(issue_tool).to receive(:execute).and_return(tool_answer)
        end
      end

      it "returns tool answer" do
        expect(agent).to receive(:log_conditional_info).with(
          user,
          hash_including(
            message: "ReAct calling tool",
            ai_component: 'duo_chat'
          )
        )

        expect(agent).to receive(:log_info).with(
          message: "ReAct turn", react_turn: 0, event_name: 'react_turn', ai_component: 'duo_chat')

        expect(Gitlab::Llm::Chain::Tools::IssueReader::Executor).to receive(:new).with(
          hash_including(options: {
            input: '#123',
            suggestions: 'I think I need to use issue_reader'
          })
        )

        expect(answer.is_final?).to be_truthy
        expect(answer.content).to include("tool answer")
      end
    end

    context "when tool is not found" do
      before do
        event = Gitlab::Duo::Chat::AgentEvents::Action.new(
          {
            "thought" => 'I think I need to use undef_reader',
            "tool" => 'undef_reader',
            "tool_input" => '#123'
          }
        )

        allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          allow(react_agent).to receive(:step).with(step_params)
            .and_yield(event).and_return([event])
        end
      end

      it "returns an error answer" do
        expect_sli_error(true)
        expect(answer.is_final?).to be_truthy
        expect(answer.content).to eq("I'm sorry, I can't generate a response. Please try again.")
        expect(answer.error_code).to eq("A9999")
      end
    end

    context "when max iteration reached" do
      let(:llm_answer) { create(:answer, :tool, tool: Gitlab::Llm::Chain::Tools::IssueReader::Executor) }

      before do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)

        stub_const("#{described_class.name}::MAX_ITERATIONS", 2)

        event = Gitlab::Duo::Chat::AgentEvents::Action.new(
          {
            "thought" => 'I think I need to use issue_reader',
            "tool" => 'issue_reader',
            "tool_input" => '#123'
          }
        )

        allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          allow(react_agent).to receive(:step).with(step_params)
            .and_yield(event).and_return([event])
        end

        allow_next_instance_of(Gitlab::Llm::Chain::Tools::IssueReader::Executor) do |issue_tool|
          allow(issue_tool).to receive(:execute).and_return(llm_answer)
        end
      end

      it "returns an error" do
        expect_sli_error(true)
        expect(answer.is_final).to be(true)
        expect(answer.content).to include("I'm sorry, Duo Chat agent reached the limit before finding an " \
          "answer for your question. Please try a different prompt or clear your conversation history with /clear.")
        expect(answer.error_code).to include("A1006")
        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
          kind_of(described_class::ExhaustedLoopError)
        )
      end
    end

    context "when unknown event received" do
      before do
        event = Gitlab::Duo::Chat::AgentEvents::Unknown.new({ "text" => 'foo' })

        allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          allow(react_agent).to receive(:step).with(step_params)
                                              .and_yield(event).and_return([event])
        end
      end

      it "returns unknown answer as is" do
        expect(agent).to receive(:log_info).with(
          message: "ReAct turn", react_turn: 0, event_name: 'react_turn', ai_component: 'duo_chat')

        expect_sli_error(false)
        expect(answer.content).to include('foo')
      end
    end

    context "when retryable error event received" do
      before do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)

        event = Gitlab::Duo::Chat::AgentEvents::Error.new({ "message" => 'overload_error', 'retryable' => true })

        allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          allow(react_agent).to receive(:step).with(step_params)
                                              .and_yield(event).and_return([event])
        end
      end

      it "returns an error" do
        expect_sli_error(true)
        expect(answer.is_final).to be(true)
        expect(answer.content).to include("I'm sorry, I can't generate a response. Please try again.")
        expect(answer.error_code).to include("A1004")
        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
          kind_of(described_class::AgentEventError)
        )
      end

      context "when retry attempt is exceeded" do
        before do
          stub_const("#{described_class}::MAX_RETRY_STEP_FORWARD", 0)
        end

        it "returns an error" do
          expect_sli_error(true)
          expect(answer.is_final).to be(true)
          expect(answer.content).to include("I'm sorry, I can't generate a response. Please try again.")
          expect(answer.error_code).to include("A1004")
          expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
            kind_of(described_class::AgentEventError)
          )
        end
      end
    end

    context "when error event received and it's prompt length error" do
      let(:message) do
        <<~MESSAGE
          Error code: 400 - {'type': 'error', 'error': {'type': 'invalid_request_error', 'message': 'prompt is too long: 200082 tokens > 199999 maximum'}}
        MESSAGE
      end

      before do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)

        event = Gitlab::Duo::Chat::AgentEvents::Error.new({ "message" => message })

        allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          allow(react_agent).to receive(:step).with(step_params)
                                              .and_yield(event).and_return([event])
        end
      end

      it "returns an error" do
        expect(answer.is_final).to be(true)
        expect(answer.content).to include("I'm sorry, you've entered too many prompts. Please run " \
          "/clear or /reset before asking the next question.")
        expect(answer.error_code).to include("A1005")
        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
          kind_of(described_class::AgentEventError)
        )
      end
    end

    context "when agent error received" do
      before do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
        allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          allow(react_agent).to receive(:step).with(step_params)
            .and_yield(event).and_return([event])
        end
      end

      context "when license mismatch error received" do
        let(:event) do
          Gitlab::Duo::Chat::AgentEvents::Error.new({ "message" => 'tool not available', 'retryable' => false })
        end

        it "returns an error" do
          expect_sli_error(true)
          expect(answer.is_final).to be(true)
          expect(answer.content).to include("I'm sorry, but answering this question requires a different Duo")
          expect(answer.error_code).to include("G3001")
          expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
            kind_of(described_class::AgentEventError)
          )
        end
      end
    end

    context "when resource is not authorized" do
      let!(:user) { create(:user, organizations: [organization]) }

      it "sends request without context" do
        params = step_params
        params[:messages].first[:context] = nil

        expect_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          expect(react_agent).to receive(:step).with(hash_including(params))
            .and_yield(action_event).and_return([action_event])
        end

        agent.execute
      end
    end

    context "when there is no resource" do
      let(:context) do
        Gitlab::Llm::Chain::GitlabContext.new(
          current_user: user,
          container: nil,
          resource: nil,
          ai_request: nil
        )
      end

      it "sends request without context" do
        params = step_params
        params[:messages].first[:context] = nil

        expect_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          expect(react_agent).to receive(:step).with(hash_including(params))
            .and_yield(action_event).and_return([action_event])
        end

        agent.execute
      end
    end

    context "when code is selected" do
      let(:selected_text) { 'code selection' }
      let(:current_file) do
        {
          file_name: 'test.py',
          selected_text: selected_text,
          cotent_above_cursor: 'content_above_cursor',
          content_below_cursor: 'content_below_cursor'
        }
      end

      it "adds code file params to the question options" do
        params = step_params
        params[:messages].first[:current_file] = {
          file_path: 'test.py',
          data: 'code selection',
          selected_code: true
        }

        expect_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          expect(react_agent).to receive(:step).with(params)
            .and_yield(action_event).and_return([action_event])
        end

        agent.execute
      end
    end

    context "when code file is included in context" do
      let(:project) { build(:project) }
      let(:blob) { fake_blob(path: 'never.rb', data: 'puts "gonna give you up"') }
      let(:extra_resource) { { blob: blob } }

      it "adds code file params to the question options" do
        params = step_params
        params[:messages].first[:current_file] = {
          file_path: 'never.rb',
          data: 'puts "gonna give you up"',
          selected_code: false
        }

        expect_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          expect(react_agent).to receive(:step).with(params)
            .and_yield(action_event).and_return([action_event])
        end

        agent.execute
      end
    end

    context "when current page is included in context" do
      it "pass current page params" do
        params = step_params
        params[:messages].first[:context] = issue_page_params

        expect_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          expect(react_agent).to receive(:step).with(params)
            .and_yield(action_event).and_return([action_event])
        end

        agent.execute
      end
    end

    context 'when is_duo_code_review is true' do
      let(:context) do
        Gitlab::Llm::Chain::GitlabContext.new(
          current_user: user,
          container: nil,
          resource: resource,
          ai_request: nil,
          extra_resource: extra_resource,
          started_at: started_at_timestamp,
          current_file: current_file,
          agent_version: nil,
          additional_context: additional_context,
          is_duo_code_review: true
        )
      end

      it 'passes is_duo_code_review: true to StepExecutor from context' do
        expect_next_instance_of(
          Gitlab::Duo::Chat::StepExecutor,
          user,
          anything,
          is_duo_code_review: true,
          namespace_id: project.namespace_id,
          project_id: project.id
        ) do |react_agent|
          expect(react_agent).to receive(:step)
            .and_yield(action_event).and_return([action_event])
        end

        agent.execute
      end
    end

    context 'when Duo chat is self-hosted' do
      let_it_be(:self_hosted_model) { create(:ai_self_hosted_model, api_token: 'test_token') }
      let_it_be(:ai_feature) { create(:ai_feature_setting, self_hosted_model: self_hosted_model, feature: :duo_chat) }

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'sends the self-hosted model metadata' do
        params = step_params
        params[:model_metadata] = {
          api_key: "test_token",
          endpoint: "http://localhost:11434/v1",
          name: "mistral",
          provider: :openai,
          identifier: "provider/some-model"
        }

        expect_next_instance_of(
          Gitlab::Duo::Chat::StepExecutor,
          user,
          ai_feature,
          is_duo_code_review: false,
          namespace_id: project.namespace_id,
          project_id: project.id
        ) do |react_agent|
          expect(react_agent).to receive(:step).with(params)
            .and_yield(action_event).and_return([action_event])
        end

        agent.execute
      end
    end

    context 'when duo chat is vendored' do
      let_it_be(:ai_feature) { create(:ai_feature_setting, feature: :duo_chat, provider: :vendored) }
      let_it_be(:instance_feature) { create(:instance_model_selection_feature_setting, feature: :duo_chat) }

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'sends the vendored model metadata' do
        params = step_params
        params[:model_metadata] = {
          provider: 'gitlab',
          identifier: instance_feature.offered_model_ref,
          feature_setting: 'duo_chat'
        }

        expect_next_instance_of(
          Gitlab::Duo::Chat::StepExecutor,
          user,
          instance_feature,
          is_duo_code_review: false,
          namespace_id: project.namespace_id,
          project_id: project.id
        ) do |react_agent|
          expect(react_agent).to receive(:step).with(params)
            .and_yield(action_event).and_return([action_event])
        end

        agent.execute
      end
    end

    context 'for model selection at the namespace level', :saas do
      let(:ai_request) { instance_double(::Gitlab::Llm::Chain::Requests::AiGateway, root_namespace: root_namespace) }
      let(:context) do
        Gitlab::Llm::Chain::GitlabContext.new(
          current_user: user,
          container: nil,
          resource: resource,
          ai_request: ai_request,
          extra_resource: extra_resource,
          started_at: started_at_timestamp,
          current_file: current_file,
          agent_version: nil,
          additional_context: additional_context
        )
      end

      shared_examples_for 'sends a request with identifier and feature_setting' do
        specify do
          params = step_params
          params[:model_metadata] = {
            provider: 'gitlab',
            identifier: model_ref,
            feature_setting: 'duo_chat'
          }

          expect_next_instance_of(
            Gitlab::Duo::Chat::StepExecutor,
            user,
            ai_feature,
            is_duo_code_review: false,
            namespace_id: project.namespace_id,
            project_id: project.id
          ) do |react_agent|
            expect(react_agent).to receive(:step).with(params)
              .and_yield(action_event).and_return([action_event])
          end

          agent.execute
        end
      end

      context 'when a model is explicitly selected' do
        let_it_be(:model_ref) { 'claude-3-7-sonnet-20250219' }
        let_it_be(:ai_feature) do
          create(:ai_namespace_feature_setting,
            namespace: root_namespace,
            feature: :duo_chat,
            offered_model_ref: model_ref)
        end

        it_behaves_like 'sends a request with identifier and feature_setting'
      end

      context 'when the model is explicitly set to GitLab Default' do
        let_it_be(:model_ref) { nil }
        let_it_be(:ai_feature) do
          create(:ai_namespace_feature_setting,
            namespace: root_namespace,
            feature: :duo_chat,
            offered_model_ref: model_ref)
        end

        it_behaves_like 'sends a request with identifier and feature_setting'
      end

      context 'when there is no root_namespace given' do
        let(:ai_request) { nil }

        context 'with a self-hosted models present' do
          let(:model_metadata) { nil }

          before do
            self_hosted_model = create(:ai_self_hosted_model, api_token: 'test_token')
            create(:ai_feature_setting, self_hosted_model: self_hosted_model, feature: :duo_chat)
            stub_saas_features(gitlab_com_subscriptions: false)
          end

          it 'sends the self-hosted model metadata' do
            params = step_params
            params[:model_metadata] = {
              api_key: "test_token",
              endpoint: "http://localhost:11434/v1",
              name: "mistral",
              provider: :openai,
              identifier: "provider/some-model"
            }

            expect_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
              expect(react_agent).to receive(:step).with(params)
                                                   .and_yield(action_event).and_return([action_event])
            end

            agent.execute
          end
        end

        context 'when no duo namespace can be inferred' do
          let(:root_namespace) { nil }
          let(:duo_default_required) { false }

          before do
            expect_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
              allow(service).to receive(:default_duo_namespace_required?).and_return(duo_default_required)
            end
          end

          context 'when a duo default namespace is required' do
            let(:duo_default_required) { true }

            it "returns an error answer" do
              expect_sli_error(true)
              expect(answer.is_final?).to be_truthy
              expect(answer.content).to eq("I'm sorry, you have not selected a default GitLab Duo namespace. " \
                "Please go to GitLab and in user Preferences - Behavior, select a default namespace for GitLab Duo.")
              expect(answer.error_code).to eq("G3002")
            end
          end

          context 'when a duo default namespace is not required' do
            let(:duo_default_required) { false }

            it 'sends the self-hosted model metadata' do
              params = step_params
              params[:model_metadata] = nil

              expect_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
                expect(react_agent).to receive(:step).with(params)
                                                     .and_yield(action_event).and_return([action_event])
              end

              agent.execute
            end
          end
        end

        context 'when a duo namespace can be inferred' do
          let(:model_ref) { nil }
          let_it_be(:ai_feature) do
            create(:ai_namespace_feature_setting,
              namespace: root_namespace,
              feature: :duo_chat,
              offered_model_ref: nil,
              offered_model_name: nil,
              model_definitions: {}
            )
          end

          it_behaves_like 'sends a request with identifier and feature_setting'
        end
      end
    end

    context 'when amazon q is connected' do
      let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q) }

      before do
        stub_licensed_features(amazon_q: true)
        stub_current_organization(user.organization)
        Ai::Setting.for_organization(user.organization).update!(amazon_q_ready: true, amazon_q_role_arn: 'role-arn')
      end

      it 'sends the amazon q model metadata' do
        params = step_params
        params[:model_metadata] = {
          provider: :amazon_q,
          name: :amazon_q,
          role_arn: 'role-arn'
        }

        expect_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          expect(react_agent).to receive(:step).with(params)
            .and_yield(action_event).and_return([action_event])
        end

        agent.execute
      end
    end

    context "when times out error is raised" do
      let(:error) { Net::ReadTimeout.new }

      before do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      shared_examples "time out error" do
        it "returns an error" do
          expect_sli_error(true)
          expect(answer.is_final?).to be(true)
          expect(answer.content).to include("I'm sorry, I couldn't respond in time. Please try again.")
          expect(answer.error_code).to include("A1000")
          expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error)
        end
      end

      context "when streamed request times out" do
        before do
          allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
            allow(react_agent).to receive(:step).and_raise(error)
          end
        end

        it_behaves_like "time out error"
      end

      context "when tool times out out" do
        let(:llm_answer) { create(:answer, :tool, tool: Gitlab::Llm::Chain::Tools::IssueReader::Executor) }

        before do
          allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
            allow(react_agent).to receive(:step).with(step_params)
              .and_yield(action_event).and_return([action_event])
          end

          allow(::Gitlab::Llm::Chain::Answer).to receive(:from_response).and_return(llm_answer)
          allow_next_instance_of(Gitlab::Llm::Chain::Tools::IssueReader::Executor) do |issue_tool|
            allow(issue_tool).to receive(:execute).and_raise(error)
          end

          allow(stream_response_service_double).to receive(:execute)
        end

        it_behaves_like "time out error"
      end
    end

    context "when connection error is raised" do
      let(:error) { ::Gitlab::Llm::AiGateway::Client::ConnectionError.new }

      before do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)

        allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          allow(react_agent).to receive(:step).and_raise(error)
        end
      end

      it "returns an error" do
        expect(answer.is_final).to be(true)
        expect(answer.content).to include("I'm sorry, I can't generate a response. Please try again.")
        expect(answer.error_code).to include("A1001")
        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error)
      end
    end

    context "when forbidden error is raised" do
      let(:error) { ::Gitlab::AiGateway::ForbiddenError.new }

      before do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)

        allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          allow(react_agent).to receive(:step).and_raise(error)
        end
      end

      it "returns an error" do
        expect(answer.is_final).to be(true)
        expect(answer.content).to include("I'm sorry, you don't have the GitLab Duo subscription required " \
          "to use Duo Chat. Please contact your administrator.")
        expect(answer.error_code).to include("M3006")
        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error)
      end
    end

    context "when eof error is raised" do
      let(:error) { EOFError.new }

      before do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)

        allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          allow(react_agent).to receive(:step).and_raise(error)
        end
      end

      it "returns an error" do
        expect(answer.is_final).to be(true)
        expect(answer.content).to include("I'm sorry, I can't generate a response. Please try again.")
        expect(answer.error_code).to include("A1003")
        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error)
      end
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers
end

# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- there are lots of parameters at play
RSpec.describe Gitlab::Llm::Completions::Chat, feature_category: :duo_chat do
  include FakeBlobHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, organizations: [organization]) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:issue) { create(:issue, project: project) }
  let(:resource) { issue }
  let(:expected_container) { resource.try(:resource_parent) }
  let(:content) { 'Summarize issue' }
  let(:ai_request) { instance_double(Gitlab::Llm::Chain::Requests::AiGateway) }
  let(:blob) { fake_blob(path: 'file.md') }
  let(:extra_resource) { { blob: blob } }
  let(:started_at) { Gitlab::Utils::System.real_time }
  let(:current_file) do
    {
      file_name: 'test.py',
      selected_text: 'selected',
      content_above_cursor: 'content_above_cursor',
      content_below_cursor: 'content_below_cursor'
    }
  end

  let(:additional_context) do
    [
      { category: 'snippet', id: 'hello world', content: 'puts "Hello, world"', metadata: {} }
    ]
  end

  let(:options) do
    {
      content: content,
      extra_resource: extra_resource,
      current_file: current_file,
      started_at: started_at,
      additional_context: additional_context
    }
  end

  let(:container) { resource.try(:resource_parent) }
  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      container: container,
      current_user: user,
      resource: resource,
      request_id: 'uuid',
      ai_request: ai_request,
      current_file: current_file,
      additional_context: additional_context
    )
  end

  let(:categorize_service) { instance_double(::Llm::ExecuteMethodService) }
  let(:categorize_service_params) { { question: content, request_id: 'uuid', message_id: prompt_message.id } }

  let(:answer) do
    ::Gitlab::Llm::Chain::Answer.new(
      status: :ok, context: context, content: content, tool: nil, is_final: true
    )
  end

  let(:response_handler) { instance_double(Gitlab::Llm::ResponseService) }
  let(:stream_response_handler) { nil }

  let(:thread) { create(:ai_conversation_thread, user: user) }
  let(:prompt_message) do
    build(:ai_chat_message, user: user, resource: resource, request_id: 'uuid', content: content, thread: thread)
  end

  let(:tools) do
    [
      ::Gitlab::Llm::Chain::Tools::BuildReader,
      ::Gitlab::Llm::Chain::Tools::IssueReader,
      ::Gitlab::Llm::Chain::Tools::GitlabDocumentation,
      ::Gitlab::Llm::Chain::Tools::EpicReader,
      ::Gitlab::Llm::Chain::Tools::MergeRequestReader,
      ::Gitlab::Llm::Chain::Tools::CommitReader,
      ::Gitlab::Llm::Chain::Tools::WorkItemReader
    ]
  end

  subject(:execute) { described_class.new(prompt_message, nil, **options).execute }

  shared_examples 'success' do
    it 'calls the SingleAction Agent with the right parameters', :snowplow do
      expected_params = [
        user_input: content,
        thread: thread,
        tools: match_array(tools),
        context: context,
        response_handler: response_handler,
        stream_response_handler: stream_response_handler
      ]

      expect(Gitlab::Llm::Chain::Requests::AiGateway).to receive(:new).with(
        user,
        hash_including(
          unit_primitive_name: :duo_classic_chat,
          tracking_context: anything,
          root_namespace: expected_container&.root_ancestor
        )
      ).and_return(ai_request)

      expect_next_instance_of(::Gitlab::Duo::Chat::ReactExecutor, *expected_params) do |instance|
        expect(instance).to receive(:execute).and_return(answer)
      end

      expect(response_handler).to receive(:execute)
      expect(::Gitlab::Llm::ResponseService).to receive(:new)
        .with(context, { request_id: 'uuid', ai_action: :chat, thread: thread })
        .and_return(response_handler)
      expect(::Gitlab::Llm::Chain::GitlabContext).to receive(:new)
        .with(current_user: user, container: expected_container, resource: resource, ai_request: ai_request,
          extra_resource: extra_resource, request_id: 'uuid', current_file: current_file,
          started_at: started_at,
          additional_context: additional_context, is_duo_code_review: nil)
        .and_return(context)
      expect(categorize_service).to receive(:execute)
      expect(::Llm::ExecuteMethodService).to receive(:new)
        .with(user, user, :categorize_question, categorize_service_params)
        .and_return(categorize_service)

      subject

      expect_snowplow_event(
        category: described_class.to_s,
        label: "IssueReader",
        action: 'process_gitlab_duo_question',
        property: 'uuid',
        namespace: container&.namespace,
        project: container,
        user: user,
        value: 1
      )
    end

    context 'when client_subscription_id is set' do
      let(:prompt_message) do
        build(:ai_chat_message, user: user, resource: resource, thread: thread,
          request_id: 'uuid', client_subscription_id: 'someid', content: content)
      end

      let(:stream_response_handler) { instance_double(Gitlab::Llm::ResponseService) }

      it 'correctly initializes response handlers' do
        expected_params = [
          user_input: content,
          thread: thread,
          tools: an_instance_of(Array),
          context: an_instance_of(Gitlab::Llm::Chain::GitlabContext),
          response_handler: response_handler,
          stream_response_handler: stream_response_handler
        ]

        expect_next_instance_of(::Gitlab::Duo::Chat::ReactExecutor, *expected_params) do |instance|
          expect(instance).to receive(:execute).and_return(answer)
        end

        expect(response_handler).to receive(:execute)
        expect(::Gitlab::Llm::ResponseService).to receive(:new).with(
          an_instance_of(Gitlab::Llm::Chain::GitlabContext), { request_id: 'uuid', ai_action: :chat, thread: thread }
        ).and_return(response_handler)

        expect(::Gitlab::Llm::ResponseService).to receive(:new).with(
          an_instance_of(Gitlab::Llm::Chain::GitlabContext),
          { request_id: 'uuid', ai_action: :chat, client_subscription_id: 'someid', thread: thread }
        ).and_return(stream_response_handler).twice
        expect(stream_response_handler).to receive(:execute).with(response: anything, save_message: false)
        expect(categorize_service).to receive(:execute)
        expect(::Llm::ExecuteMethodService).to receive(:new)
          .with(user, user, :categorize_question, categorize_service_params)
          .and_return(categorize_service)

        subject
      end
    end

    context 'with unsuccessful response' do
      let(:answer) do
        ::Gitlab::Llm::Chain::Answer.new(
          status: :error, context: context, content: content, tool: nil, is_final: true
        )
      end

      it 'sends process_gitlab_duo_question snowplow event with value eql 0' do
        allow_next_instance_of(::Gitlab::Duo::Chat::ReactExecutor) do |instance|
          expect(instance).to receive(:execute).and_return(answer)
        end

        allow(::Gitlab::Llm::Chain::GitlabContext).to receive(:new).and_return(context)
        expect(categorize_service).to receive(:execute)
        expect(::Llm::ExecuteMethodService).to receive(:new)
         .with(user, user, :categorize_question, categorize_service_params)
         .and_return(categorize_service)

        subject

        expect_snowplow_event(
          category: described_class.to_s,
          label: "IssueReader",
          action: 'process_gitlab_duo_question',
          property: 'uuid',
          namespace: container&.namespace,
          project: container,
          user: user,
          value: 0
        )
      end
    end
  end

  describe '.initialize' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: root_group) }
    let_it_be(:project) { create(:project, namespace: subgroup) }
    let_it_be(:issue) { create(:issue, project: project) }
    let_it_be(:user) { create(:user) }

    let(:resource) { issue }
    let(:prompt_message) do
      build(:ai_chat_message, user: user, resource: resource, request_id: 'uuid', content: content, thread: thread)
    end

    let(:options) do
      {
        current_file: nil,
        additional_context: [],
        started_at: Time.current,

        extra_resource: {},
        tracking_context: {},
        resource: resource,
        user: user
      }
    end

    subject(:instance) do
      described_class.new(prompt_message, nil, **options)
    end

    it 'trims additional context' do
      expect(::CodeSuggestions::Context).to receive(:new).with([]).and_call_original
      instance
    end

    it 'sets root_namespace correctly on ai_request' do
      expect(instance.send(:context).ai_request.root_namespace).to eq(root_group)
    end

    context 'when resource has no resource_parent, fallback is used via root_namespace_global_id' do
      let_it_be(:fallback_namespace) { create(:group) }

      let(:prompt_message) do
        build(:ai_chat_message, user: user, resource: user, request_id: 'uuid', content: content, thread: thread)
      end

      let(:options) do
        {
          current_file: nil,
          additional_context: [],
          started_at: Time.current,

          extra_resource: {},
          tracking_context: {},
          resource: user,
          user: user,
          root_namespace_id: fallback_namespace.to_global_id.to_s
        }
      end

      subject(:instance) do
        described_class.new(prompt_message, nil, **options)
      end

      it 'uses root_namespace_global_id fallback when resource_parent is nil' do
        expect(instance.send(:context).ai_request.root_namespace).to eq(fallback_namespace)
      end
    end
  end

  describe '#execute' do
    before do
      allow(Gitlab::Llm::Chain::Requests::AiGateway).to receive(:new).and_return(ai_request)
      allow(context).to receive(:tools_used).and_return([Gitlab::Llm::Chain::Tools::IssueReader::Executor])
      stub_saas_features(duo_chat_categorize_question: true)
    end

    context 'when resource is an issue' do
      it_behaves_like 'success'
    end

    context 'when resource is a user' do
      let(:container) { nil }
      let(:expected_container) { nil }
      let_it_be(:resource) { user }

      it_behaves_like 'success'
    end

    context 'when resource is nil' do
      let(:resource) { nil }
      let(:expected_container) { nil }

      it_behaves_like 'success'
    end

    context 'when on self-managed cloud-connected instance' do
      before do
        allow(::CloudConnector).to receive(:self_managed_cloud_connected?).and_return(true)
      end

      it 'does not push expanded ai logging feature flag to AI Gateway' do
        allow_next_instance_of(::Gitlab::Duo::Chat::ReactExecutor) do |instance|
          allow(instance).to receive(:execute).and_return(answer)
        end

        expect(::Gitlab::AiGateway).not_to receive(:push_feature_flag).with(:expanded_ai_logging, user)
        expect(::Gitlab::AiGateway).not_to receive(:push_feature_flag).with(:ai_gateway_multi_default_models, user)

        subject
      end
    end

    context 'when message is a slash command' do
      shared_examples_for 'slash command execution' do
        let(:executor) { instance_double(Gitlab::Llm::Chain::Tools::ExplainCode::Executor) }

        before do
          allow(executor).to receive(:execute).and_return(answer)
        end

        it 'calls directly a tool' do
          expected_params = {
            context: an_instance_of(::Gitlab::Llm::Chain::GitlabContext),
            options: { input: content },
            stream_response_handler: nil,
            command: an_instance_of(::Gitlab::Llm::Chain::SlashCommand)
          }

          expect(::Gitlab::Duo::Chat::ReactExecutor).not_to receive(:new)
          expect(expected_tool)
            .to receive(:new).with(expected_params).and_return(executor)

          subject
        end

        it 'tracks slash command event', :snowplow do
          expect(expected_tool).to receive(:new).and_return(executor)

          subject

          expect_snowplow_event(
            category: described_class.to_s,
            action: 'process_gitlab_duo_slash_command',
            label: command,
            property: 'uuid',
            namespace: container&.namespace,
            project: container,
            user: user,
            value: 1
          )
        end
      end

      let(:content) { "#{command} something" }

      context 'when /explain is used' do
        let(:command) { '/explain' }

        it_behaves_like 'slash command execution' do
          let(:expected_tool) { ::Gitlab::Llm::Chain::Tools::ExplainCode::Executor }
        end
      end

      context 'when /troubleshoot is used' do
        let(:command) { '/troubleshoot' }

        it_behaves_like 'slash command execution' do
          let(:expected_tool) { ::Gitlab::Llm::Chain::Tools::TroubleshootJob::Executor }
        end
      end

      context 'when /tests is used' do
        let(:command) { '/tests' }

        it_behaves_like 'slash command execution' do
          let(:expected_tool) { ::Gitlab::Llm::Chain::Tools::WriteTests::Executor }
        end
      end

      context 'when /refactor is used' do
        let(:command) { '/refactor' }

        it_behaves_like 'slash command execution' do
          let(:expected_tool) { ::Gitlab::Llm::Chain::Tools::RefactorCode::Executor }
        end
      end

      context 'when /fix is used' do
        let(:command) { '/fix' }

        it_behaves_like 'slash command execution' do
          let(:expected_tool) { ::Gitlab::Llm::Chain::Tools::FixCode::Executor }
        end
      end

      context 'when slash command does not exist' do
        let(:command) { '/explain2' }

        it 'process the message with zero shot agent' do
          expect_next_instance_of(::Gitlab::Duo::Chat::ReactExecutor) do |instance|
            expect(instance).to receive(:execute).and_return(answer)
          end
          expect(::Gitlab::Llm::Chain::Tools::ExplainCode::Executor).not_to receive(:new)

          subject
        end
      end
    end

    context 'with on-premises GitLab instance' do
      before do
        stub_saas_features(duo_chat_categorize_question: false)
      end

      it 'does not execute question categorization' do
        expected_params = [
          user_input: content,
          thread: thread,
          tools: match_array(tools),
          context: context,
          response_handler: response_handler,
          stream_response_handler: stream_response_handler
        ]

        allow_next_instance_of(::Gitlab::Duo::Chat::ReactExecutor, *expected_params) do |instance|
          allow(instance).to receive(:execute).and_return(answer)
        end

        allow(response_handler).to receive(:execute)
        allow(::Gitlab::Llm::ResponseService).to receive(:new)
          .with(context, { request_id: 'uuid', ai_action: :chat, thread: thread })
          .and_return(response_handler)
        allow(::Gitlab::Llm::Chain::GitlabContext).to receive(:new)
          .with(current_user: user, container: expected_container, resource: resource, ai_request: ai_request,
            extra_resource: extra_resource, request_id: 'uuid', current_file: current_file,
            started_at: started_at,
            additional_context: additional_context, is_duo_code_review: nil)
          .and_return(context)

        expect(categorize_service).not_to receive(:execute)

        subject
      end
    end

    describe 'codebase search tool usage' do
      before do
        allow(context).to receive(:tools_used).and_call_original

        allow(::Gitlab::Duo::Chat::ReactExecutor).to receive(:new).and_return(react_executor)
        allow(codebase_search_tool_class).to receive(:new).and_return(codebase_search_tool)
      end

      let(:react_executor) { instance_double(::Gitlab::Duo::Chat::ReactExecutor, execute: answer) }

      let(:codebase_search_tool_class) { ::Gitlab::Llm::Chain::Tools::CodebaseSearch::Executor }
      let(:codebase_search_tool) { instance_double(codebase_search_tool_class, execute: cst_answer) }
      let(:cst_answer) do
        ::Gitlab::Llm::Chain::Answer.new(status: :ok, context: context, content: 'content', tool: nil)
      end

      context 'when there is no codebase-related additional context' do
        let(:additional_context) do
          [
            { category: 'file', id: 'file://somefile.text', content: 'file content', metadata: {} }
          ]
        end

        it 'does not call the codebase search tool' do
          expect(codebase_search_tool_class).not_to receive(:new)

          expect(react_executor).to receive(:execute)

          execute
        end
      end

      context 'when there is a repository additional context' do
        let(:additional_context) do
          [
            {
              category: 'repository',
              id: "gid://gitlab/Project/1",
              content: ''
            }
          ]
        end

        it 'executes the codebase search tool then the react executor' do
          expect(codebase_search_tool).to receive(:execute)

          expect(react_executor).to receive(:execute)

          execute
        end
      end

      context 'when there is a directory additional context' do
        let(:additional_context) do
          [
            {
              category: 'directory',
              id: "dir://User/project/some/path",
              content: '',
              metadata: {
                'projectId' => 'gid://gitlab/Project/1',
                'relativePath' => 'some/path'
              }
            }
          ]
        end

        it 'executes the codebase search tool then the react executor' do
          expect(codebase_search_tool).to receive(:execute)

          expect(react_executor).to receive(:execute)

          execute
        end
      end
    end

    context 'when is_duo_code_review is true' do
      let(:options) do
        {
          content: content,
          extra_resource: extra_resource,
          current_file: current_file,
          started_at: started_at,
          additional_context: additional_context,
          is_duo_code_review: true
        }
      end

      it 'passes is_duo_code_review to GitlabContext' do
        allow_next_instance_of(::Gitlab::Duo::Chat::ReactExecutor) do |instance|
          allow(instance).to receive(:execute).and_return(answer)
        end

        expect(::Gitlab::Llm::Chain::GitlabContext).to receive(:new)
                                                         .with(hash_including(is_duo_code_review: true))
                                                         .and_return(context)

        expect(categorize_service).to receive(:execute)
        expect(::Llm::ExecuteMethodService).to receive(:new).and_return(categorize_service)

        subject
      end

      it 'sets unit_primitive_name to duo_chat for AiGateway' do
        allow_next_instance_of(::Gitlab::Duo::Chat::ReactExecutor) do |instance|
          allow(instance).to receive(:execute).and_return(answer)
        end

        expect(Gitlab::Llm::Chain::Requests::AiGateway).to receive(:new).with(
          user,
          hash_including(unit_primitive_name: :duo_chat)
        ).and_return(ai_request)

        allow(::Gitlab::Llm::Chain::GitlabContext).to receive(:new).and_return(context)
        expect(categorize_service).to receive(:execute)
        expect(::Llm::ExecuteMethodService).to receive(:new).and_return(categorize_service)

        subject
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers

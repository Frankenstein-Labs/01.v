# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::Tool, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }

  let(:options) { {} }
  let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::Anthropic) }

  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user,
      container: nil,
      resource: nil,
      ai_request: ai_request_double
    )
  end

  subject { described_class.new(context: context, options: options) }

  describe '#execute' do
    it 'raises NotImplementedError' do
      expect { subject.execute }.to raise_error(NotImplementedError)
    end

    context 'when authorize returns true' do
      before do
        allow(subject).to receive(:authorize).and_return(true)
        allow(subject).to receive(:perform)
      end

      it 'calls perform' do
        expect(subject).to receive(:perform)
        subject.execute
      end

      it 'adds the tool to used tools' do
        expect { subject.execute }.to change { context.tools_used }.from([]).to([described_class])
      end
    end

    context 'when authorize returns false' do
      using RSpec::Parameterized::TableSyntax

      where(:flag_enabled, :unit_primitive, :expected_method) do
        false | 'troubleshoot_job' | :not_found
        false | 'explain_vulnerability' | :not_found
        false | 'other_tool'            | :not_found
        true  | 'other_tool'            | :not_found
        true  | 'troubleshoot_job'      | :not_in_current_plan
        true  | 'explain_vulnerability' | :not_in_current_plan
        true  | 'summarize_comments'    | :not_in_current_plan
      end

      with_them do
        let(:logger) { instance_double(Gitlab::Llm::Logger) }

        before do
          stub_feature_flags(dap_external_trigger_usage_billing: flag_enabled)
          allow(subject).to receive_messages(authorize: false, unit_primitive: unit_primitive)
          allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
          allow(logger).to receive(:error)
          allow(logger).to receive(:info)
        end

        it "calls #{params[:expected_method]}" do
          expect(subject).to receive(expected_method).and_call_original
          subject.execute
        end

        it 'logs the appropriate message' do
          if expected_method == :not_in_current_plan
            expect(logger).to receive(:info).with(hash_including(
              message: 'No access to external trigger',
              event_name: 'permission_denied',
              ai_component: 'abstraction_layer',
              ai_error_code: 'G3001'
            ))
          else
            expect(logger).to receive(:info).with(hash_including(
              message: 'No access to Duo Chat',
              event_name: 'permission_denied',
              ai_component: 'abstraction_layer',
              ai_error_code: 'M3004'
            ))
          end

          subject.execute
        end
      end
    end

    context 'when tool was already used' do
      before do
        context.tools_used << described_class
      end

      it 'returns already used answer' do
        content = "You already have the answer from #{described_class::NAME} tool, read carefully."
        answer = subject.execute

        expect(answer.content).to eq(content)
        expect(answer.status).to eq(:not_executed)
      end

      it 'logs the message' do
        logger = instance_double(Gitlab::Llm::Logger)
        allow(Gitlab::Llm::Logger).to receive(:build).at_least(:once).and_return(logger)

        expect(logger).to receive(:conditional_info).at_least(:once)
        expect(logger).to receive(:info).with(hash_including(message: "Tool cycling detected")).once

        subject.execute
      end
    end

    context 'when forbidden error is returned' do
      before do
        allow(subject).to receive(:authorize).and_return(true)
      end

      it 'returns forbidden answer' do
        allow(subject).to receive(:perform).and_raise(::Gitlab::AiGateway::ForbiddenError)
        answer = subject.execute

        expect(answer.content).to include('this question is not supported in your Duo Pro subscription')
      end
    end
  end

  describe '#perform' do
    it 'raises NotImplementedError' do
      expect { subject.perform }.to raise_error(NotImplementedError)
    end
  end

  describe '#group_from_context' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    it 'returns group if it is set as container' do
      context = Gitlab::Llm::Chain::GitlabContext.new(
        current_user: user,
        container: group,
        resource: nil,
        ai_request: ai_request_double
      )

      expect(described_class.new(context: context, options: options).group_from_context).to eq(group)
    end

    it 'returns parent group if project is set as container' do
      context = Gitlab::Llm::Chain::GitlabContext.new(
        current_user: user,
        container: project,
        resource: nil,
        ai_request: ai_request_double
      )

      expect(described_class.new(context: context, options: options).group_from_context).to eq(group)
    end

    it 'returns parent group if project is set as container' do
      context = Gitlab::Llm::Chain::GitlabContext.new(
        current_user: user,
        container: project.project_namespace,
        resource: nil,
        ai_request: ai_request_double
      )

      expect(described_class.new(context: context, options: options).group_from_context).to eq(group)
    end
  end

  describe '.full_definition' do
    let(:definition) do
      <<~XML.chomp
        <tool>
        <tool_name>TEST_TOOL</tool_name>
        <description>
        #{expected_description}
        </description>
        <example>
        EXAMPLE
        </example>
        </tool>
      XML
    end

    let(:expected_description) { 'TEST' }

    before do
      stub_const("#{described_class.name}::NAME", 'TEST_TOOL')
      stub_const("#{described_class.name}::DESCRIPTION", expected_description)
      stub_const("#{described_class.name}::EXAMPLE", 'EXAMPLE')
    end

    context 'when description is defined' do
      it 'returns detailed description of the tool' do
        expect(described_class.full_definition).to eq(definition)
      end
    end
  end
end

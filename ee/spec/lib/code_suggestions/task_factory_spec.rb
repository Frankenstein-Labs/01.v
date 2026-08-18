# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::TaskFactory, feature_category: :code_suggestions do
  using RSpec::Parameterized::TableSyntax

  describe '.task' do
    let_it_be(:current_user) { create(:user) }
    let(:client) { CodeSuggestions::Client.new({}) }
    let(:file_name) { 'python.py' }
    let(:content_above_cursor) { 'some content_above_cursor' }
    let(:content_below_cursor) { 'some content_below_cursor' }
    let(:user_instruction) { nil }
    let(:expected_project) { nil }
    let(:project_path) { nil }

    let(:instruction) do
      instance_double(CodeSuggestions::Instruction, instruction: 'instruction', trigger_type: 'comment')
    end

    let(:params) do
      {
        current_file: {
          file_name: file_name,
          content_above_cursor: content_above_cursor,
          content_below_cursor: content_below_cursor
        },
        generation_type: 'empty_function',
        user_instruction: user_instruction,
        context: [
          { type: 'file', name: 'main.go', content: 'package main' }
        ],
        instruction: instruction,
        content_above_cursor: content_above_cursor,
        project: expected_project,
        project_path: project_path,
        current_user: current_user
      }
    end

    subject(:get_task) { described_class.new(current_user, client: client, params: params).task }

    shared_examples 'correct task initializer' do
      it 'creates task with correct params' do
        expect(expected_class).to receive(:new).with(**expected_params)

        get_task
      end
    end

    it 'calls context trimmer' do
      ctx = instance_double(CodeSuggestions::Context, :trimmed)
      expect(CodeSuggestions::Context).to receive(:new).with(params[:context]).and_return(ctx)
      expect(ctx).to receive(:trimmed)

      get_task
    end

    it 'calls instructions extractor with expected params' do
      expect(CodeSuggestions::InstructionsExtractor)
        .to receive(:new)
        .with(an_instance_of(CodeSuggestions::FileContent), nil, 'empty_function', user_instruction)
        .and_call_original

      get_task
    end

    context 'when code completion' do
      let(:expected_class) { ::CodeSuggestions::Tasks::CodeCompletion }
      let(:expected_params) do
        {
          current_user: current_user,
          client: client,
          params: params,
          unsafe_passthrough_params: {}
        }
      end

      before do
        allow_next_instance_of(CodeSuggestions::InstructionsExtractor) do |instance|
          allow(instance).to receive(:extract).and_return(nil)
        end
      end

      it_behaves_like 'correct task initializer'

      context 'when on a self managed instance' do
        let(:expected_class) { ::CodeSuggestions::Tasks::CodeCompletion }
        let(:expected_params) do
          {
            current_user: current_user,
            client: client,
            params: params,
            unsafe_passthrough_params: {}
          }
        end

        let(:feature_setting) { create(:ai_feature_setting, feature: :code_completions) }

        context 'when code completion is self-hosted' do
          it_behaves_like 'correct task initializer'
        end
      end

      context 'with project' do
        let_it_be(:expected_project) { create(:project) }
        let(:project_path) { expected_project.full_path }

        before do
          allow_next_instance_of(::ProjectsFinder) do |instance|
            allow(instance).to receive(:execute).and_return([expected_project])
          end
        end

        it 'fetches project' do
          get_task

          expect(::ProjectsFinder).to have_received(:new)
            .with(
              current_user: current_user,
              params: { full_paths: [expected_project.full_path] }
            )
        end
      end
    end

    context 'when code generation' do
      let(:expected_class) { ::CodeSuggestions::Tasks::CodeGeneration }
      let(:expected_params) do
        {
          current_user: current_user,
          client: client,
          params: params,
          unsafe_passthrough_params: {}
        }
      end

      before do
        allow_next_instance_of(CodeSuggestions::InstructionsExtractor) do |instance|
          allow(instance).to receive(:extract).and_return(instruction)
        end
      end

      it_behaves_like 'correct task initializer'

      context 'with project' do
        let_it_be(:expected_project) { create(:project) }
        let(:project_path) { expected_project.full_path }

        let(:params) do
          {
            current_file: {
              file_name: file_name,
              content_above_cursor: content_above_cursor,
              content_below_cursor: content_below_cursor
            },
            project_path: project_path
          }
        end

        before do
          allow_next_instance_of(::ProjectsFinder) do |instance|
            allow(instance).to receive(:execute).and_return([expected_project])
          end
        end

        it 'fetches project' do
          get_task

          expect(::ProjectsFinder).to have_received(:new)
            .with(
              current_user: current_user,
              params: { full_paths: [expected_project.full_path] }
            )
        end
      end

      context 'with user_instruction param' do
        let(:user_instruction) { 'Some user instruction' }

        it_behaves_like 'correct task initializer'
      end

      context 'when on a self managed instance' do
        let(:expected_class) { ::CodeSuggestions::Tasks::CodeGeneration }
        let(:expected_params) do
          {
            current_user: current_user,
            client: client,
            params: params,
            unsafe_passthrough_params: {}
          }
        end

        let_it_be(:feature_setting) { create(:ai_feature_setting, feature: :code_generations) }

        context 'when code generations is self-hosted' do
          it_behaves_like 'correct task initializer'
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::TroubleshootJob::Executor, feature_category: :continuous_integration do
  let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::Anthropic) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let(:build) { create(:ci_build, :failed, :trace_live, project: project) }
  let(:stream_response_handler) { nil }
  let(:input) { 'user input' }
  let(:options) { { input: input } }
  let(:command) { nil }
  let(:prompt_class) { Gitlab::Llm::Chain::Tools::TroubleshootJob::Prompts::Anthropic }

  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user,
      container: nil,
      resource: build,
      ai_request: ai_request_double
    )
  end

  let(:expected_slash_commands) do
    {
      '/troubleshoot' => {
        description: 'Troubleshoot a job based on the logs.',
        selected_code_without_input_instruction: 'Troubleshoot the job log.',
        selected_code_with_input_instruction: "Troubleshoot the job log. Input: %<input>s."
      }
    }
  end

  subject(:tool) do
    described_class.new(
      context: context,
      options: options,
      stream_response_handler: stream_response_handler,
      command: command
    )
  end

  RSpec.shared_context 'with repo languages' do
    before do
      allow(project).to receive(:repository_languages).and_return(
        repository_languages.map do |lang|
          instance_double(RepositoryLanguage, name: lang)
        end
      )
    end
  end

  before do
    stub_application_setting(ci_job_live_trace_enabled: true)
    stub_feature_flags(dap_external_trigger_usage_billing: false)
    allow(user).to receive(:can?).and_call_original
    allow(user).to receive(:can?).with(:troubleshoot_job_with_ai, build).and_return(true)
  end

  describe '#name' do
    it 'returns the correct tool name' do
      expect(described_class::NAME).to eq('TroubleshootJob')
    end

    it 'returns the correct human-readable name' do
      expect(described_class::HUMAN_NAME).to eq('Troubleshoot Job')
    end
  end

  describe '#description' do
    it 'returns the correct description' do
      expect(described_class::DESCRIPTION).to include('Useful tool to troubleshoot job-related issues.')
    end
  end

  describe '#resource_name' do
    it 'returns the correct description' do
      expect(described_class::RESOURCE_NAME).to include('Ci::Build')
    end
  end

  describe '#execute' do
    context 'when the user is authorized' do
      include_context 'with stubbed LLM authorizer', allowed: true

      before do
        allow(tool).to receive(:provider_prompt_class).and_return(prompt_class)
        allow(user).to receive(:allowed_to_use?).with(:troubleshoot_job).and_return(true)
      end

      context 'when user input is blank' do
        before do
          allow(tool).to receive(:input_blank?).and_return(true)
        end

        it 'accepts blank input and performs the troubleshooting' do
          expect(tool).to receive(:request).and_return('Troubleshooting response')
          expect(tool.execute.content).to eq('Troubleshooting response')
        end
      end

      it 'performs the troubleshooting' do
        expect(tool).to receive(:request).and_return('Troubleshooting response')
        expect(tool.execute.content).to eq('Troubleshooting response')
      end

      context 'with repository languages' do
        include_context 'with repo languages'

        let(:repository_languages) { %w[C C++] }

        it 'calls prompt with correct params' do
          allow(tool).to receive(:provider_prompt_class).and_return(prompt_class)
          expect(prompt_class).to receive(:prompt).with(a_hash_including(
            input: input,
            language_info: "The repository code is written in C and C++.",
            selected_text: build.trace.raw # "BUILD TRACE"
          ))

          tool.execute
        end
      end

      context 'when log is truncated' do
        let(:log_size_allowed) { 3 }

        before do
          stub_const("#{described_class}::APPROX_MAX_INPUT_CHARS",
            described_class::PROMPT_TEMPLATE[1][1].size + log_size_allowed)
        end

        it 'calls prompt with correct params' do
          allow(tool).to receive(:provider_prompt_class).and_return(prompt_class)
          expect(prompt_class).to receive(:prompt).with(a_hash_including(
            input: input,
            language_info: '',
            selected_text: build.trace.raw.last(log_size_allowed) # ACE
          ))

          tool.execute
        end

        context 'when log does not exist' do
          before do
            build.trace.erase!
          end

          it 'returns an error message' do
            expect(tool.execute.content).to include(
              "There is no job log to troubleshoot"
            )
          end
        end

        context 'for internal events tracking' do
          before do
            allow(tool).to receive(:request).and_return('Troubleshooting response')
          end

          it 'tracks troubleshoot_job event when executed on a failed CI job' do
            expect(Gitlab::InternalEvents).to receive(:track_event).with(
              'troubleshoot_job',
              user: user,
              job: build,
              project: build.project
            ).and_call_original

            tool.execute
          end

          context 'when CI job is not failed but has a trace' do
            let(:build) { create(:ci_build, :running, :trace_live, project: project) }

            it 'tracks troubleshoot_job event' do
              expect(Gitlab::InternalEvents).to receive(:track_event).with(
                'troubleshoot_job',
                user: user,
                job: build,
                project: build.project
              ).and_call_original

              tool.execute
            end
          end
        end
      end

      context 'when the job is not failed' do
        let(:build) { create(:ci_build, :running, :trace_live, project: project) }

        it 'performs the troubleshooting', :aggregate_failures do
          expect(tool).to receive(:request).and_return('Troubleshooting response')
          expect(tool.execute.content).to eq('Troubleshooting response')
        end
      end

      context 'when the resource is not a Ci::Build' do
        let(:context) do
          Gitlab::Llm::Chain::GitlabContext.new(
            current_user: user,
            container: nil,
            resource: project,
            ai_request: nil
          )
        end

        before do
          allow(user).to receive(:can?).with(:read_build_trace, project).and_return(true)
        end

        it 'returns an error message' do
          expect(tool.execute.content).to include("I'm sorry, I can't generate a response.")
        end
      end
    end

    context 'when the user is not authorized' do
      include_context 'with stubbed LLM authorizer', allowed: false

      before do
        allow(tool).to receive(:provider_prompt_class).and_return(
          ::Gitlab::Llm::Chain::Tools::TroubleshootJob::Prompts::Anthropic
        )
        allow(user).to receive(:can?).with(:troubleshoot_job_with_ai, build).and_return(false)
      end

      context 'when dap_external_trigger_usage_billing flag is disabled' do
        before do
          stub_feature_flags(dap_external_trigger_usage_billing: false)
        end

        it 'returns not found error message' do
          expect(tool.execute.content).to include(
            "you don't have access to them, or your session has expired."
          )
        end
      end

      context 'when dap_external_trigger_usage_billing flag is enabled' do
        before do
          stub_feature_flags(dap_external_trigger_usage_billing: true)
          allow(user).to receive(:allowed_to_use?).with(:troubleshoot_job, root_namespace: build.project.root_ancestor)
            .and_return(false)
        end

        it 'returns not in current plan error message' do
          answer = tool.execute
          subscription_url = ::Gitlab::Routing.url_helpers.help_page_url('subscriptions/subscription-add-ons.md')
          agent_platform_url = ::Gitlab::Routing.url_helpers.help_page_url('user/duo_agent_platform/_index.md')

          response = "This feature is not available with your current configuration. You might need a different " \
            "[GitLab Duo add-on](#{subscription_url}), or access to the " \
            "[GitLab Duo Agent Platform](#{agent_platform_url}). " \
            "Alternatively, I can help with other questions."
          expect(answer.content).to eq(response)
        end
      end
    end

    describe '#job_log' do
      context 'when the job is present and failed' do
        it 'returns the job trace' do
          expect(tool.send(:job_log)).to eq(build.trace.raw)
        end
      end
    end

    describe '#language_info' do
      include_context 'with repo languages'

      context 'without languages' do
        let(:repository_languages) { [] }

        it 'returns an empty string' do
          expect(tool.send(:language_info)).to eq('')
        end
      end

      context 'when more than one language' do
        let(:repository_languages) { %w[Ruby JavaScript Go] }

        it 'returns the correct language information' do
          expect(tool.send(:language_info)).to eq('The repository code is written in Ruby, JavaScript and Go.')
        end
      end

      context 'with two languages' do
        let(:repository_languages) { %w[JavaScript Go] }

        it 'returns the correct language information' do
          expect(tool.send(:language_info)).to eq('The repository code is written in JavaScript and Go.')
        end
      end

      context 'when one language' do
        let(:repository_languages) { %w[Ruby] }

        it 'returns the correct language information' do
          expect(tool.send(:language_info)).to eq('The repository code is written in Ruby.')
        end
      end
    end

    context 'when selecting prompt version' do
      include_context 'with stubbed LLM authorizer', allowed: true

      before do
        allow(user).to receive(:allowed_to_use?).with(:troubleshoot_job).and_return(true)
        allow(tool).to receive(:provider_prompt_class).and_return(prompt_class)

        allow(Gitlab::Llm::Chain::Requests::AiGateway).to receive(:new).with(
          user,
          unit_primitive_name: :troubleshoot_job,
          tracking_context: { request_id: nil, action: 'troubleshoot_job' },
          root_namespace: project.root_ancestor
        ).and_return(ai_request_double)
      end

      it 'receives the default prompt version' do
        expect(ai_request_double).to receive(:request).with(
          hash_including(options: hash_including(prompt_version: described_class::DEFAULT_PROMPT_VERSION)),
          unit_primitive: 'troubleshoot_job'
        )

        tool.execute

        expect(Gitlab::Llm::Chain::Requests::AiGateway).to have_received(:new).with(
          user,
          unit_primitive_name: :troubleshoot_job,
          tracking_context: { request_id: nil, action: 'troubleshoot_job' },
          root_namespace: project.root_ancestor
        )
      end
    end
  end
end

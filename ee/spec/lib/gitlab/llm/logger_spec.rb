# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Logger, feature_category: :ai_abstraction_layer do
  describe "log_level" do
    subject(:log_level) { described_class.build.level }

    context 'when LLM_DEBUG is not set' do
      it { is_expected.to eq ::Logger::INFO }
    end

    context 'when LLM_DEBUG=true' do
      before do
        stub_env('LLM_DEBUG', true)
      end

      it { is_expected.to eq ::Logger::DEBUG }
    end

    context 'when LLM_DEBUG=false' do
      before do
        stub_env('LLM_DEBUG', false)
      end

      it { is_expected.to eq ::Logger::INFO }
    end
  end

  describe "#conditional_info" do
    let_it_be(:user) { create(:user) }
    let(:logger) { described_class.build }

    shared_examples_for 'logs on info level with limited params' do
      it 'logs on info level with limited params' do
        expect(logger).to receive(:info).with(message: 'test',
          klass: 'Gitlab::Llm',
          event_name: 'received_response',
          ai_component: 'ai_abstraction_layer',
          user_id: user.id)

        logger.conditional_info(user,
          message: 'test',
          klass: 'Gitlab::Llm',
          event_name: 'received_response',
          ai_component: 'ai_abstraction_layer',
          prompt: 'prompt')
      end
    end

    shared_examples_for 'logs on info level with all params' do
      it 'logs on info level with all params' do
        expect(logger).to receive(:info).with(message: 'test',
          klass: 'Gitlab::Llm',
          event_name: 'received_response',
          ai_component: 'ai_abstraction_layer',
          options: { prompt: 'prompt' },
          user_id: user.id)

        logger.conditional_info(user,
          message: 'test',
          klass: 'Gitlab::Llm',
          event_name: 'received_response',
          ai_component: 'ai_abstraction_layer',
          options: { prompt: 'prompt' })
      end
    end

    it_behaves_like 'logs on info level with all params'

    context 'with expanded_ai_logging switched off' do
      before do
        stub_feature_flags(expanded_ai_logging: false)
        stub_application_setting(enabled_instance_verbose_ai_logs: false)
      end

      it_behaves_like 'logs on info level with limited params'

      context 'with namespace setting' do
        let_it_be(:namespace) { create(:group) }

        before do
          stub_application_setting(enabled_instance_verbose_ai_logs: false)
        end

        context 'when namespace opt-in is enabled' do
          before do
            namespace.update!(ai_usage_data_collection_enabled: true)
          end

          it 'logs with all params when namespace is provided (namespace setting supersedes feature flag)' do
            stub_feature_flags(expanded_ai_logging: false)

            expect(logger).to receive(:info).with(message: 'test',
              klass: 'Gitlab::Llm',
              event_name: 'received_response',
              ai_component: 'ai_abstraction_layer',
              prompt: 'prompt',
              user_id: user.id)

            logger.conditional_info(user,
              message: 'test',
              klass: 'Gitlab::Llm',
              event_name: 'received_response',
              ai_component: 'ai_abstraction_layer',
              namespace: namespace,
              prompt: 'prompt')
          end
        end

        context 'when namespace opt-in is disabled' do
          before do
            namespace.update!(ai_usage_data_collection_enabled: false)
          end

          it 'logs with all params when feature flag is enabled (supersedes namespace setting)' do
            stub_feature_flags(expanded_ai_logging: true)

            expect(logger).to receive(:info).with(message: 'test',
              klass: 'Gitlab::Llm',
              event_name: 'received_response',
              ai_component: 'ai_abstraction_layer',
              prompt: 'prompt',
              user_id: user.id)

            logger.conditional_info(user,
              message: 'test',
              klass: 'Gitlab::Llm',
              event_name: 'received_response',
              ai_component: 'ai_abstraction_layer',
              namespace: namespace,
              prompt: 'prompt')
          end
        end

        context 'when both instance setting and namespace setting are enabled' do
          before do
            stub_application_setting(enabled_instance_verbose_ai_logs: true)
            namespace.update!(ai_usage_data_collection_enabled: true)
          end

          it 'logs with all params (instance setting takes precedence)' do
            stub_feature_flags(expanded_ai_logging: false)

            expect(logger).to receive(:info).with(message: 'test',
              klass: 'Gitlab::Llm',
              event_name: 'received_response',
              ai_component: 'ai_abstraction_layer',
              prompt: 'prompt',
              user_id: user.id)

            logger.conditional_info(user,
              message: 'test',
              klass: 'Gitlab::Llm',
              event_name: 'received_response',
              ai_component: 'ai_abstraction_layer',
              namespace: namespace,
              prompt: 'prompt')
          end
        end

        context 'when instance setting is enabled but namespace setting is disabled' do
          before do
            stub_application_setting(enabled_instance_verbose_ai_logs: true)
            namespace.update!(ai_usage_data_collection_enabled: false)
          end

          it 'logs with all params (instance setting takes precedence over namespace)' do
            stub_feature_flags(expanded_ai_logging: false)

            expect(logger).to receive(:info).with(message: 'test',
              klass: 'Gitlab::Llm',
              event_name: 'received_response',
              ai_component: 'ai_abstraction_layer',
              prompt: 'prompt',
              user_id: user.id)

            logger.conditional_info(user,
              message: 'test',
              klass: 'Gitlab::Llm',
              event_name: 'received_response',
              ai_component: 'ai_abstraction_layer',
              namespace: namespace,
              prompt: 'prompt')
          end
        end
      end

      context 'with AI logs instance setting' do
        context 'when enabled' do
          before do
            stub_application_setting(enabled_instance_verbose_ai_logs: true)
          end

          it_behaves_like 'logs on info level with all params'
        end

        context 'when disabled' do
          before do
            stub_application_setting(enabled_instance_verbose_ai_logs: false)
          end

          it_behaves_like 'logs on info level with limited params'
        end
      end
    end
  end
end

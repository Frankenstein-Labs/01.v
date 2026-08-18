# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::Internal::CompletionService, :saas, feature_category: :ai_abstraction_layer do
  include FakeBlobHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:resource) { create(:merge_request, source_project: project, target_project: project, author: user) }
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

  let(:options) { { 'key' => 'value' } }
  let(:ai_action_name) { :summarize_review }
  let(:referer_url) { nil }
  let(:extra_resource) { {} }
  let(:completion) { instance_double(::Gitlab::Llm::AiGateway::Completions::SummarizeReview) }
  let(:logger) { instance_double(Gitlab::Llm::Logger) }

  let(:prompt_message) do
    build(:ai_message, user: user, resource: resource, ai_action: ai_action_name, request_id: 'uuid')
  end

  let(:params) do
    options.merge(referer_url: referer_url)
  end

  subject(:service) { described_class.new(prompt_message, params) }

  include_context 'with ai features enabled for group'

  describe '#execute' do
    before do
      allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
      allow(logger).to receive(:conditional_info)
      allow(logger).to receive(:debug)
      stub_licensed_features(summarize_review: true)
    end

    subject(:execute) { service.execute }

    shared_examples 'performs successfully' do
      it 'calls Gitlab::Llm::CompletionsFactory', :aggregate_failures do
        completion = instance_double(::Gitlab::Llm::AiGateway::Completions::SummarizeReview)
        extra_resource_finder = instance_double(::Llm::ExtraResourceFinder)

        expect(::Llm::ExtraResourceFinder).to receive(:new).with(user, referer_url).and_return(extra_resource_finder)
        expect(extra_resource_finder).to receive(:execute).and_return(extra_resource)

        expect(Gitlab::Llm::CompletionsFactory)
          .to receive(:completion!)
          .with(an_object_having_attributes(
            user: user,
            resource: resource,
            request_id: 'uuid',
            ai_action: ai_action_name
          ),
            options.symbolize_keys.merge(extra_resource: extra_resource))
          .and_return(completion)

        expect(logger).to receive(:debug).with(a_hash_including(
          message: "Performing CompletionService",
          event_name: 'completion_service_performed',
          ai_component: 'abstraction_layer',
          user_id: user.to_gid,
          completion_service_name: completion.class.name,
          request_id: 'uuid',
          resource_id: resource&.to_gid,
          action_name: ai_action_name,
          client_subscription_id: nil
        ))

        expect(completion).to receive(:execute)

        execute
      end
    end

    context 'with valid parameters' do
      before_all do
        group.add_reporter(user)
      end

      it 'updates duration metric' do
        allow(Gitlab::Llm::CompletionsFactory)
          .to receive(:completion!)
          .and_return(completion)
        allow(completion).to receive(:execute)

        expect(Gitlab::Metrics::Sli::Apdex[:llm_completion])
          .to receive(:increment)
          .with(labels: { feature_category: anything, service_class: an_instance_of(String) }, success: true)

        execute
      end

      context 'when the completion succeeds' do
        let(:ai_message) { instance_double(Gitlab::Llm::AiMessage, errors: []) }

        before do
          allow(Gitlab::Llm::CompletionsFactory).to receive(:completion!).and_return(completion)
          allow(completion).to receive(:execute).and_return({ ai_message: ai_message, status: :success })
        end

        it 'records the completion as a success in the error rate SLI' do
          expect(Gitlab::Metrics::Sli::ErrorRate[:llm_completion])
            .to receive(:increment)
            .with(labels: {
              feature_category: :duo_code_review,
              service_class: 'Gitlab::Llm::AiGateway::Completions::SummarizeReview'
            }, error: false)

          execute
        end
      end

      context 'when the completion returns errors' do
        let(:ai_message) { instance_double(Gitlab::Llm::AiMessage, errors: ['boom']) }

        before do
          allow(Gitlab::Llm::CompletionsFactory).to receive(:completion!).and_return(completion)
          allow(completion).to receive(:execute).and_return({ ai_message: ai_message, status: :error })
        end

        it 'records the completion as an error in the error rate SLI' do
          expect(Gitlab::Metrics::Sli::ErrorRate[:llm_completion])
            .to receive(:increment)
            .with(labels: {
              feature_category: :duo_code_review,
              service_class: 'Gitlab::Llm::AiGateway::Completions::SummarizeReview'
            }, error: true)

          execute
        end
      end

      context 'when a start_time option is provided', :request_store do
        let(:options) do
          {
            'x_gitlab_client_type' => 'ide',
            'x_gitlab_client_version' => '1.0',
            'x_gitlab_client_name' => 'gitlab-extension',
            'x_gitlab_interface' => 'vscode',
            'x_gitlab_tracking_context' => '{"distribution":"npm","execution_environment":"CI"}'
          }
        end

        it 'sets the value to AI Gateway context' do
          expect(Gitlab::Llm::CompletionsFactory)
            .to receive(:completion!)
            .with(an_object_having_attributes(
              user: user,
              resource: resource,
              request_id: 'uuid',
              ai_action: ai_action_name
            ),
              options.symbolize_keys.merge(extra_resource: extra_resource))
            .and_return(completion)

          expect(completion).to receive(:execute)

          execute

          expect(::Gitlab::AiGateway.current_context[:x_gitlab_client_type]).to eq('ide')
          expect(::Gitlab::AiGateway.current_context[:x_gitlab_client_version]).to eq('1.0')
          expect(::Gitlab::AiGateway.current_context[:x_gitlab_client_name]).to eq('gitlab-extension')
          expect(::Gitlab::AiGateway.current_context[:x_gitlab_interface]).to eq('vscode')
          expect(::Gitlab::AiGateway.current_context[:x_gitlab_tracking_context])
            .to eq('{"distribution":"npm","execution_environment":"CI"}')
        end
      end

      context 'when a start_time option is provided', :freeze_time do
        let(:start_time) { ::Gitlab::Metrics::System.monotonic_time - 20 }
        let(:options) { { start_time: start_time } }

        it 'calculates the duration based off of start_time' do
          expect(Gitlab::Llm::CompletionsFactory)
            .to receive(:completion!)
            .with(an_object_having_attributes(
              user: user,
              resource: resource,
              request_id: 'uuid',
              ai_action: ai_action_name
            ),
              options.symbolize_keys.merge(extra_resource: extra_resource))
            .and_return(completion)

          expect(completion).to receive(:execute)
          expect(Gitlab::Metrics::Sli::Apdex[:llm_completion])
            .to receive(:increment)
            .with(labels: { feature_category: anything, service_class: an_instance_of(String) }, success: true)

          execute
        end

        context 'when the duration is more than the MAX_RUN_TIME' do
          let(:start_time) { ::Gitlab::Metrics::System.monotonic_time - 60 }
          let(:options) { { start_time: start_time } }

          it 'sets the Apdex success as false',
            quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/5541' do
            expect(Gitlab::Metrics::Sli::Apdex[:llm_completion])
              .to receive(:increment)
              .with(labels: { feature_category: anything, service_class: an_instance_of(String) }, success: false)

            execute
          end
        end
      end

      context 'when extra resource is found' do
        let(:referer_url) { "foobar" }
        let(:extra_resource) { { blob: fake_blob(path: 'file.md') } }

        it_behaves_like 'performs successfully'
      end

      context 'for an issue' do
        let_it_be(:resource) { create(:issue, project: project) }

        it_behaves_like 'performs successfully'
      end

      context 'for a work item' do
        let_it_be(:resource) { create(:work_item, :task, project: project) }

        it_behaves_like 'performs successfully'
      end

      context 'for a merge request' do
        it_behaves_like 'performs successfully'
      end

      context 'for an epic' do
        before do
          stub_licensed_features(epics: true)
        end

        let_it_be(:resource) { create(:epic, group: group) }

        it_behaves_like 'performs successfully'
      end

      context 'when resource is nil' do
        let_it_be(:resource) { nil }

        it_behaves_like 'performs successfully'
      end

      context 'when it is chat request' do
        let_it_be(:resource) { nil }
        let(:ai_action_name) { :chat }
        let(:prompt_message) do
          build(:ai_chat_message, user: user, resource: resource, ai_action: ai_action_name, request_id: 'uuid')
        end

        before do
          stub_feature_flags(ai_global_switch: false)
        end

        it_behaves_like 'performs successfully'
      end

      context 'when it is self-managed feature request' do
        before do
          stub_feature_flags(ai_global_switch: false)
          stub_const(
            "::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST",
            summarize_review: {
              self_managed: true,
              service_class: ::Gitlab::Llm::AiGateway::Completions::SummarizeReview,
              prompt_class: nil
            }
          )
        end

        it_behaves_like 'performs successfully'
      end
    end

    context 'with service failure' do
      before_all do
        group.add_reporter(user)
      end

      before do
        allow(Gitlab::Llm::CompletionsFactory).to receive(:completion!).and_return(completion)
        allow(completion).to receive(:execute).and_raise(StandardError, 'service failure')
      end

      it 'updates error rate' do
        expect(Gitlab::Metrics::Sli::ErrorRate[:llm_completion])
          .to receive(:increment)
          .with(labels: {
            feature_category: :duo_code_review,
            service_class: 'Gitlab::Llm::AiGateway::Completions::SummarizeReview'
          }, error: true)

        expect do
          execute
        end.to raise_error(StandardError, 'service failure')
      end

      context 'when resource is nil' do
        let_it_be(:resource) { nil }

        it 'updates error rate' do
          expect(Gitlab::Metrics::Sli::ErrorRate[:llm_completion])
            .to receive(:increment)
              .with(labels: {
                feature_category: :duo_code_review,
                service_class: 'Gitlab::Llm::AiGateway::Completions::SummarizeReview'
              }, error: true)

          expect do
            execute
          end.to raise_error(StandardError, 'service failure')
        end
      end
    end

    context 'when user can not read the resource' do
      it 'calls Gitlab::Llm::CompletionsFactory.completion! without resource' do
        allow(completion).to receive(:execute)

        expect(logger).to receive(:info).with(
          a_hash_including(
            message: "Nullifying resource to prevent unauthorized access",
            event_name: 'permission_denied',
            ai_component: 'abstraction_layer',
            user_id: user.to_gid,
            resource_id: resource&.to_gid,
            request_id: 'uuid',
            action_name: ai_action_name,
            client_subscription_id: nil
          )
        )

        expect(Gitlab::Llm::CompletionsFactory).to receive(:completion!) do |prompt_message, _options|
          expect(prompt_message.resource).to be_nil
          completion
        end

        expect(execute).to eq(nil)
      end
    end
  end
end

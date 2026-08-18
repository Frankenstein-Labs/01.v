# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::BaseService, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }

  let(:action_name) { :test }
  let(:options) { { ai_action: action_name } }

  subject { described_class.new(user, resource, options) }

  shared_examples 'returns an error' do
    it 'returns an error' do
      result = subject.execute

      expect(result).to be_error
      expect(result.message).to eq(described_class::INVALID_MESSAGE)
    end
  end

  shared_examples 'raises a NotImplementedError' do
    it 'raises a NotImplementedError' do
      expect { subject.execute }.to raise_error(NotImplementedError)
    end
  end

  shared_examples 'success when implemented' do
    subject do
      Class.new(described_class) do
        def perform
          schedule_completion_worker
        end

        def ai_action
          :test
        end
      end.new(user, resource, options)
    end

    it_behaves_like 'schedules completion worker' do
      let(:action_name) { :test }
      let(:options) { { start_time: ::Gitlab::Metrics::System.monotonic_time } }

      before do
        allow(subject).to receive(:start_time) { options[:start_time] }
      end
    end

    it 'logs with namespace parameter' do
      logger = instance_double(Gitlab::Llm::Logger)
      allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
      allow(logger).to receive(:conditional_info)
      allow(::Llm::CompletionWorker).to receive(:perform_for)

      subject.execute

      expect(logger).to have_received(:conditional_info).with(
        user,
        hash_including(
          message: "Enqueuing CompletionWorker",
          event_name: 'worker_enqueued',
          ai_component: 'abstraction_layer',
          namespace: anything
        )
      )
    end
  end

  shared_examples 'authorizing a resource' do
    let(:authorizer_response) { instance_double(Gitlab::Llm::Utils::Authorizer::Response, allowed?: allowed) }

    before do
      allow(Gitlab::Llm::Utils::Authorizer).to receive(:resource).with(resource: resource, user: user)
        .and_return(authorizer_response)
    end

    context 'when the resource is authorized' do
      let(:allowed) { true }

      it_behaves_like 'success when implemented'
    end

    context 'when the resource is not authorized' do
      let(:allowed) { false }

      it_behaves_like 'returns an error'
    end
  end

  context 'for SaaS instance', :saas do
    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan, developers: user) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:resource) { create(:issue, project: project) }

    before do
      stub_const('::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST',
        { action_name => { self_managed: false } })
    end

    context 'when user does not have access to AI features' do
      it_behaves_like 'returns an error'
    end

    context 'when user has access to AI features as a non-member' do
      before do
        allow(user).to receive(:allowed_to_use?).and_return(true)
      end

      it_behaves_like 'authorizing a resource'
    end

    context 'when user has access as a member' do
      before do
        allow(user).to receive(:allowed_to_use?).and_return(true)
      end

      context 'when ai_global_switch feature flag is not enabled' do
        before do
          stub_feature_flags(ai_global_switch: false)
        end

        it_behaves_like 'returns an error'
      end

      context 'when experimental features are disabled for the group' do
        before do
          allow(user).to receive(:allowed_to_use?).and_return(false)
        end

        include_context 'with experiment features disabled for group'

        it_behaves_like 'returns an error'

        context 'when feature is in ga' do
          before do
            allow(user).to receive(:allowed_to_use?).and_return(true)

            stub_const('::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST',
              { action_name => { self_managed: false, maturity: :ga } })
          end

          it_behaves_like 'authorizing a resource'
        end
      end

      context 'when ai features are enabled' do
        include_context 'with ai features enabled for group'

        it_behaves_like 'raises a NotImplementedError'

        context 'when resource is an issue' do
          let_it_be(:resource) { create(:issue, project: project) }

          it_behaves_like 'authorizing a resource'
        end

        context 'when resource is a user' do
          let_it_be(:resource) { user }

          it_behaves_like 'authorizing a resource'
        end

        context 'when resource is nil' do
          let_it_be(:resource) { nil }

          it_behaves_like 'success when implemented'
        end
      end
    end
  end

  context 'for self-managed instance' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:resource) { create(:issue, project: project) }

    before do
      stub_const(
        '::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST',
        { action_name => { self_managed: true } }
      )
    end

    context 'when user has no access' do
      it_behaves_like 'returns an error'
    end

    context 'when user has access' do
      before do
        allow(user).to receive(:allowed_to_use?).and_return(true)
      end

      it_behaves_like 'authorizing a resource'
    end
  end
end

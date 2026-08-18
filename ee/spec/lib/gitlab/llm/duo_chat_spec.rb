# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::DuoChat, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }

  describe '#enabled_for_container?', :use_clean_rails_redis_caching do
    let_it_be_with_reload(:group) { create(:group) }
    let(:authorizer_response) { instance_double(Gitlab::Llm::Utils::Authorizer::Response, allowed?: allowed) }
    let(:checked_user) { user }
    let(:container) { nil }

    subject(:enabled_for_container) do
      described_class.new(user: checked_user, container: container).enabled_for_container?
    end

    context 'when user present and container is not present' do
      where(:allowed, :result) do
        [
          [true, true],
          [false, false]
        ]
      end

      with_them do
        before do
          allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive(:user).with(user: user)
                                                                            .and_return(authorizer_response)
        end

        it { is_expected.to be(result) }
      end
    end

    context 'when user and container are both present' do
      let(:container) { group }

      where(:allowed, :result) do
        [
          [true, true],
          [false, false]
        ]
      end

      with_them do
        before do
          allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive(:container).with(user: user, container: group)
                                                                                 .and_return(authorizer_response)
        end

        it { is_expected.to be(result) }
      end
    end

    context 'when user is not present' do
      let(:checked_user) { nil }

      it { is_expected.to be(false) }
    end
  end

  describe '#classic_chat_available?' do
    let(:checked_user) { nil }
    let(:container) { nil }

    subject(:chat_available) { described_class.new(user: checked_user, container: container).classic_chat_available? }

    context 'when user is nil' do
      it { is_expected.to be false }
    end

    context 'when user is present' do
      let(:checked_user) { user }
      let(:can_access_classic_chat) { false }

      before do
        allow(checked_user).to receive(:can?).with(:access_duo_classic_chat,
          container).and_return(can_access_classic_chat)
      end

      context 'when user can access duo classic chat' do
        let(:can_access_classic_chat) { true }

        it { is_expected.to be true }
      end

      context 'when user cannot access duo classic chat' do
        let(:can_access_classic_chat) { false }

        it { is_expected.to be false }
      end

      context 'with container (project)' do
        let(:container) { create(:project) }

        before do
          allow(checked_user).to receive(:can?).with(:access_duo_classic_chat,
            container).and_return(can_access_classic_chat)
        end

        context 'when user can access duo classic chat for project' do
          let(:can_access_classic_chat) { true }

          it { is_expected.to be true }
        end

        context 'when user cannot access duo classic chat for project' do
          let(:can_access_classic_chat) { false }

          it { is_expected.to be false }
        end
      end

      context 'with container (group)' do
        let(:container) { create(:group) }

        before do
          allow(checked_user).to receive(:can?).with(:access_duo_classic_chat,
            container).and_return(can_access_classic_chat)
        end

        context 'when user can access duo classic chat for group' do
          let(:can_access_classic_chat) { true }

          it { is_expected.to be true }
        end

        context 'when user cannot access duo classic chat for group' do
          let(:can_access_classic_chat) { false }

          it { is_expected.to be false }
        end
      end
    end
  end

  describe '#agentic_mode_available?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:group) { create(:group) }
    let(:container) { nil }

    subject(:agentic_mode_available) { described_class.new(user: user, container: container).agentic_mode_available? }

    context 'when container is a project' do
      let(:container) { project }

      context 'when user can access duo agentic chat for project' do
        before do
          allow(user).to receive(:can?).with(:access_duo_agentic_chat, project).and_return(true)
        end

        it { is_expected.to be(true) }
      end

      context 'when user cannot access duo agentic chat for project' do
        before do
          allow(user).to receive(:can?).with(:access_duo_agentic_chat, project).and_return(false)
        end

        it { is_expected.to be(false) }
      end
    end

    context 'when container is a group' do
      let(:container) { group }

      context 'when user can access duo agentic chat for group' do
        before do
          allow(user).to receive(:can?).with(:access_duo_agentic_chat, group).and_return(true)
        end

        it { is_expected.to be(true) }
      end

      context 'when user cannot access duo agentic chat for group' do
        before do
          allow(user).to receive(:can?).with(:access_duo_agentic_chat, group).and_return(false)
        end

        it { is_expected.to be(false) }
      end
    end

    context 'when container is nil' do
      before do
        allow(user).to receive(:can?).with(:access_duo_agentic_chat, nil).and_return(false)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#show_duo_entry_point?' do
    let(:authorizer_response) { instance_double(Gitlab::Llm::Utils::Authorizer::Response, allowed?: allowed) }

    subject(:show_duo_entry_point) { described_class.new(user: user).show_duo_entry_point? }

    where(:allowed, :duo_chat_access) do
      [
        [true, true],
        [false, false]
      ]
    end

    with_them do
      before do
        allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer)
          .to receive(:user).with(user: user).and_return(authorizer_response)
      end

      it { is_expected.to be(duo_chat_access) }
    end
  end

  describe '#credits_available?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:group) { create(:group) }

    context 'when user is nil' do
      it 'returns false' do
        expect(described_class.new(user: nil, project: project, group: group).credits_available?).to be false
      end
    end

    context 'when required params are present' do
      before do
        allow_next_instance_of(::Ai::UsageQuotaService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success)
        end
      end

      it 'calls service with project' do
        expect(described_class.new(user: user, project: project).credits_available?).to be true
      end

      it 'calls service with group' do
        expect(described_class.new(user: user, group: group).credits_available?).to be true
      end
    end

    context 'when service returns an error' do
      context 'when no default namespace exists' do
        before do
          allow_next_instance_of(::Ai::UsageQuotaService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(reason: :namespace_missing,
              message: "No namespace"))
          end
        end

        it 'returns false' do
          expect(described_class.new(user: user, project: project).credits_available?).to be false
        end

        it 'returns false with group' do
          expect(described_class.new(user: user, group: group).credits_available?).to be false
        end

        it 'returns false with neither project nor group' do
          expect(described_class.new(user: user).credits_available?).to be false
        end
      end

      context 'when billing error returned' do
        before do
          allow_next_instance_of(::Ai::UsageQuotaService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(reason: :usage_quota_exceeded,
              message: "Billing error"))
          end
        end

        it 'returns false' do
          expect(described_class.new(user: user, project: project).credits_available?).to be false
        end
      end
    end
  end

  describe '#usage_billing_forbidden?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:group) { create(:group) }

    context 'when user is nil' do
      it 'returns false' do
        expect(described_class.new(user: nil, project: project).usage_billing_forbidden?).to be false
      end
    end

    context 'when service returns usage_billing_forbidden' do
      before do
        allow_next_instance_of(::Ai::UsageQuotaService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.error(reason: :usage_billing_forbidden, message: "Billing not available")
          )
        end
      end

      it 'returns true' do
        expect(described_class.new(user: user, project: project).usage_billing_forbidden?).to be true
      end
    end

    context 'when service succeeds' do
      before do
        allow_next_instance_of(::Ai::UsageQuotaService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success)
        end
      end

      it 'returns false' do
        expect(described_class.new(user: user, project: project).usage_billing_forbidden?).to be false
      end
    end

    context 'when service returns a different error reason' do
      before do
        allow_next_instance_of(::Ai::UsageQuotaService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.error(reason: :usage_quota_exceeded, message: "Quota exceeded")
          )
        end
      end

      it 'returns false' do
        expect(described_class.new(user: user, project: project).usage_billing_forbidden?).to be false
      end
    end

    it 'calls the usage quota service only once when both credits_available? and usage_billing_forbidden? are called' do
      allow_next_instance_of(::Ai::UsageQuotaService) do |service|
        expect(service).to receive(:execute).once.and_return(ServiceResponse.success)
      end

      bot = described_class.new(user: user, project: project)
      bot.credits_available?
      bot.usage_billing_forbidden?
    end
  end

  describe '#chat_disabled_reason' do
    let(:authorizer_response) { instance_double(Gitlab::Llm::Utils::Authorizer::Response, allowed?: allowed) }
    let(:container) { build_stubbed(:group) }

    subject(:chat_disabled_reason) { described_class.new(user: user, container: container).chat_disabled_reason }

    before do
      allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer)
        .to receive(:container).with(container: container, user: user)
                               .and_return(authorizer_response)
    end

    context 'when chat is allowed' do
      let(:allowed) { true }

      it { is_expected.to be_nil }
    end

    context 'when chat is not allowed' do
      let(:allowed) { false }

      context 'with a group' do
        it { is_expected.to be(:group) }
      end

      context 'with a project' do
        let(:container) { build_stubbed(:project) }

        it { is_expected.to be(:project) }
      end

      context 'without a container' do
        let(:container) { nil }

        it { is_expected.to be_nil }
      end
    end
  end

  describe '#default_duo_namespace_check_passes?' do
    let(:container) { nil }

    subject(:namespace_check) do
      described_class.new(user: user, container: container).default_duo_namespace_check_passes?
    end

    context 'for SaaS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when a governing namespace exists' do
        let(:default_namespace) { create(:group) }

        before do
          allow(user).to receive(:governing_namespace).with(container).and_return(default_namespace)
        end

        it 'passes the check' do
          is_expected.to be_truthy
        end
      end

      context 'when a governing namespace does not exist' do
        before do
          allow(user).to receive(:governing_namespace).with(container).and_return(nil)
        end

        it 'fails the check' do
          is_expected.to be_falsey
        end
      end

      context 'with a project container' do
        let_it_be(:project) { create(:project) }
        let(:container) { project }
        let(:root_namespace) { build_stubbed(:group) }

        before do
          allow(user).to receive(:governing_namespace).with(container).and_return(root_namespace)
        end

        it 'passes the check with project container' do
          is_expected.to be_truthy
        end
      end

      context 'with a group container' do
        let_it_be(:group) { create(:group) }
        let(:container) { group }
        let(:root_namespace) { build_stubbed(:group) }

        before do
          allow(user).to receive(:governing_namespace).with(container).and_return(root_namespace)
        end

        it 'passes the check with group container' do
          is_expected.to be_truthy
        end
      end
    end

    context 'for self-managed' do
      it 'passes the check' do
        is_expected.to be_truthy
      end
    end
  end

  describe '#user_model_selection_enabled?' do
    let_it_be(:group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group) }

    context 'when container is present' do
      subject(:result) { described_class.new(user: user, container: subgroup).user_model_selection_enabled? }

      context 'when root namespace is present' do
        before do
          allow(user).to receive(:governing_namespace).with(subgroup.root_ancestor).and_return(group)
          allow_next_instance_of(Ai::FeatureSettingSelectionService) do |service|
            allow(service).to receive(:execute).and_return(service_response)
          end
        end

        context 'when the feature setting returns ai_feature_setting payload' do
          let(:payload) { build(:ai_feature_setting, feature: :duo_agent_platform) }
          let(:service_response) { ServiceResponse.success(payload: payload) }

          it { is_expected.to be_falsey }
        end

        context 'when the feature setting returns instance_model_selection_feature_setting payload' do
          let(:payload) { build(:instance_model_selection_feature_setting, feature: :duo_agent_platform) }
          let(:service_response) { ServiceResponse.success(payload: payload) }

          it { is_expected.to be_truthy }
        end

        context 'when the feature setting returns ai_namespace_feature_setting payload' do
          let(:payload) { build(:ai_namespace_feature_setting, namespace: group, feature: :duo_agent_platform) }
          let(:service_response) { ServiceResponse.success(payload: payload) }

          it { is_expected.to be_truthy }
        end

        context 'when the feature setting service returns an error' do
          let(:service_response) { ServiceResponse.error(message: "error!") }

          it { is_expected.to be_falsey }
        end
      end

      context 'when governing namespace returns nil' do
        before do
          allow(user).to receive(:governing_namespace).with(subgroup.root_ancestor).and_return(nil)
        end

        it { is_expected.to be_falsey }
      end
    end

    context 'when container is nil' do
      subject(:result) { described_class.new(user: user, container: nil).user_model_selection_enabled? }

      before do
        allow(user).to receive(:governing_namespace).with(nil).and_return(nil)
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '.duo_scope_hash' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:project) { create(:project) }
    let_it_be(:group) { create(:group) }
    let_it_be(:default_namespace) { create(:group) }
    let(:non_persisted_project) { build(:project) }
    let(:non_persisted_group) { build(:group) }

    before do
      allow(user).to receive(:default_duo_namespace).and_return(default_namespace)
    end

    where(:controller_name, :project_param, :group_param, :expected_result) do
      'search' | ref(:project)                | ref(:group)                | { namespace: ref(:default_namespace),
default_namespace_applied: true }
      'search' | nil                          | ref(:group)                | { namespace: ref(:default_namespace),
default_namespace_applied: true }
      'note'   | ref(:project)                | ref(:group)                | { project: ref(:project),
default_namespace_applied: false }
      'note'   | ref(:non_persisted_project)  | ref(:group)                | { namespace: ref(:group),
default_namespace_applied: false }
      'note'   | nil                          | ref(:group)                | { namespace: ref(:group),
default_namespace_applied: false }
      'note'   | ref(:non_persisted_project)  | ref(:non_persisted_group)  | { namespace: ref(:default_namespace),
default_namespace_applied: true }
      'note'   | nil                          | nil                        | { namespace: ref(:default_namespace),
default_namespace_applied: true }
    end

    with_them do
      it 'returns the expected scope hash' do
        expect(described_class.duo_scope_hash(user, project_param, group_param, controller_name))
          .to eq(expected_result)
      end
    end
  end
end

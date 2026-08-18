# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DuoChatPanel::Component, :aggregate_failures, feature_category: :duo_chat do
  let(:user) { build_stubbed(:user) }
  let(:project) { nil }
  let(:group) { nil }
  let(:controller_name) { nil }

  let(:duo_chat_instance) { instance_double(::Gitlab::Llm::DuoChat, show_duo_entry_point?: false) }
  let(:instance) do
    described_class.new(user: user, project: project, group: group, controller_name: controller_name)
  end

  before do
    allow(::Gitlab::Llm::DuoChat).to receive(:new).with(user: user).and_return(duo_chat_instance)
    allow(::Gitlab::CurrentSettings).to receive(:duo_never_on?).and_return(false)
  end

  subject(:component_instance) { instance.send(:component_instance) }

  context 'when show_chat? is true' do
    before do
      allow(duo_chat_instance).to receive(:show_duo_entry_point?).and_return(true)
    end

    it 'returns a ChatComponent instance' do
      is_expected.to be_a(DuoChatPanel::ChatComponent)
    end
  end

  context 'when both show_chat? and access_denied? are true' do
    before do
      allow(duo_chat_instance).to receive(:show_duo_entry_point?).and_return(true)
    end

    it 'returns a ChatComponent, not an AccessDeniedComponent' do
      is_expected.to be_a(DuoChatPanel::ChatComponent)
    end
  end

  context 'when show_trial_expired? is true', :saas_gitlab_com_subscriptions do
    let(:group) { build_stubbed(:group) }

    before do
      allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
        .with(user, nil, group, nil)
        .and_return({ namespace: nil, default_namespace_applied: true })
      allow(group).to receive(:root_ancestor).and_return(group)
      allow(GitlabSubscriptions::Trials).to receive(:free_plan_expired?).with(group).and_return(true)
    end

    it 'returns a TrialExpiredComponent instance' do
      is_expected.to be_a(DuoChatPanel::TrialExpiredComponent)
    end
  end

  context 'when both show_chat? and show_trial_expired? are true', :saas_gitlab_com_subscriptions do
    let(:group) { build_stubbed(:group) }

    before do
      allow(duo_chat_instance).to receive(:show_duo_entry_point?).and_return(true)
      allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
        .with(user, nil, group, nil)
        .and_return({ namespace: group, default_namespace_applied: false })
      allow(group).to receive_messages(duo_features_enabled: true, root_ancestor: group)
      allow(GitlabSubscriptions::Trials).to receive(:free_plan_expired?).with(group).and_return(true)
    end

    it 'returns a ChatComponent, not a TrialExpiredComponent' do
      is_expected.to be_a(DuoChatPanel::ChatComponent)
    end
  end

  context 'when access_denied? is true' do
    it 'returns an AccessDeniedComponent instance' do
      is_expected.to be_a(DuoChatPanel::AccessDeniedComponent)
    end
  end

  context 'when identity verification is required' do
    let(:project) { build_stubbed(:project) }

    before do
      allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
        .with(user, project, nil, nil)
        .and_return({ project: project, default_namespace_applied: false })
      allow(project).to receive(:duo_features_enabled).and_return(true)
      allow(user).to receive(:dap_identity_verification_required?)
        .with(project).and_return(true)
    end

    it 'returns an IdentityVerificationComponent instance' do
      is_expected.to be_a(DuoChatPanel::IdentityVerificationComponent)
    end

    context 'when show_chat? is also true' do
      before do
        allow(duo_chat_instance).to receive(:show_duo_entry_point?).and_return(true)
      end

      it 'returns an IdentityVerificationComponent, not a ChatComponent' do
        is_expected.to be_a(DuoChatPanel::IdentityVerificationComponent)
      end
    end

    context 'when the container is not persisted (e.g. the new project form)' do
      let(:project) { build(:project) }

      it 'does not evaluate identity verification and does not raise' do
        expect(user).not_to receive(:dap_identity_verification_required?)
        is_expected.not_to be_a(DuoChatPanel::IdentityVerificationComponent)
      end
    end
  end

  describe '#show_identity_verification?' do
    subject(:show_identity_verification) { instance.send(:show_identity_verification?) }

    let(:project) { build_stubbed(:project) }

    before do
      allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
        .with(user, project, nil, nil)
        .and_return({ project: project, default_namespace_applied: false })
    end

    context 'when Duo features are disabled on the container' do
      before do
        allow(project).to receive(:duo_features_enabled).and_return(false)
      end

      it 'returns false without evaluating the identity verification abilities' do
        expect(user).not_to receive(:dap_identity_verification_required?)

        expect(show_identity_verification).to be(false)
      end
    end
  end

  context 'when can_start_trial? is true' do
    before do
      allow(instance).to receive(:can_start_trial?).and_return(true)
    end

    it 'returns a StartTrialComponent instance' do
      is_expected.to be_a(DuoChatPanel::StartTrialComponent)
    end

    context 'with a project' do
      let(:project) { build_stubbed(:project) }

      it 'passes a container wrapping the project' do
        expect(DuoChatPanel::StartTrialComponent).to receive(:new)
          .with(container: have_attributes(record: project), user: user).and_call_original

        component_instance
      end
    end

    context 'with a group' do
      let(:group) { build_stubbed(:group) }

      before do
        allow(group).to receive(:duo_features_enabled).and_return(true)
      end

      it 'passes a container wrapping the group' do
        expect(DuoChatPanel::StartTrialComponent).to receive(:new)
          .with(container: have_attributes(record: group), user: user).and_call_original

        component_instance
      end
    end

    context 'when both project and group are present' do
      let(:project) { build_stubbed(:project) }
      let(:group) { build_stubbed(:group) }

      it 'passes a container (project takes priority via duo_scope_hash)' do
        expect(DuoChatPanel::StartTrialComponent).to receive(:new)
          .with(container: have_attributes(record: project), user: user).and_call_original

        component_instance
      end
    end

    context 'when show_chat? is also true' do
      before do
        allow(duo_chat_instance).to receive(:show_duo_entry_point?).and_return(true)
      end

      it 'returns a ChatComponent, not a StartTrialComponent' do
        is_expected.to be_a(DuoChatPanel::ChatComponent)
      end
    end

    context 'when show_trial_expired? is also true', :saas_gitlab_com_subscriptions do
      let(:group) { build_stubbed(:group) }

      before do
        allow(group).to receive_messages(duo_features_enabled: true, root_ancestor: group)
        allow(GitlabSubscriptions::Trials).to receive(:free_plan_expired?).with(group).and_return(true)
      end

      it 'returns a TrialExpiredComponent, not a StartTrialComponent' do
        is_expected.to be_a(DuoChatPanel::TrialExpiredComponent)
      end
    end

    context 'when show_duo_disabled_non_admin? is also true' do
      let(:project) { build_stubbed(:project) }

      before do
        allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
          .with(user, project, nil, nil)
          .and_return({ project: project, default_namespace_applied: false })
        allow(project).to receive(:duo_features_enabled).and_return(false)
        allow(user).to receive(:can?).with(:admin_project, project).and_return(false)
      end

      it 'returns a DuoDisabledNonAdminComponent, not a StartTrialComponent' do
        is_expected.to be_a(DuoChatPanel::DuoDisabledNonAdminComponent)
      end
    end
  end

  context 'when can_start_trial? is false' do
    before do
      allow(instance).to receive(:can_start_trial?).and_return(false)
    end

    it 'falls through to AccessDeniedComponent' do
      is_expected.to be_a(DuoChatPanel::AccessDeniedComponent)
    end

    it 'does not return a StartTrialComponent' do
      is_expected.not_to be_a(DuoChatPanel::StartTrialComponent)
    end
  end

  context 'when user is nil' do
    let(:user) { nil }

    it 'does not render' do
      expect(instance.render?).to be false
    end
  end

  describe 'show_trial_expired? on .com', :saas_gitlab_com_subscriptions do
    context 'when source is nil' do
      it 'does not return a TrialExpiredComponent' do
        is_expected.not_to be_a(DuoChatPanel::TrialExpiredComponent)
      end
    end

    context 'when source is a group' do
      let(:group) { build_stubbed(:group) }

      before do
        allow(group).to receive(:root_ancestor).and_return(group)
      end

      context 'when namespace has free plan and trial is expired' do
        before do
          allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
            .with(user, nil, group, nil)
            .and_return({ namespace: nil, default_namespace_applied: true })
          allow(GitlabSubscriptions::Trials).to receive(:free_plan_expired?).with(group).and_return(true)
        end

        it 'returns a TrialExpiredComponent instance' do
          is_expected.to be_a(DuoChatPanel::TrialExpiredComponent)
        end
      end

      context 'when namespace does not have free plan with expired trial' do
        before do
          allow(GitlabSubscriptions::Trials).to receive(:free_plan_expired?).with(group).and_return(false)
        end

        it 'does not return a TrialExpiredComponent' do
          is_expected.not_to be_a(DuoChatPanel::TrialExpiredComponent)
        end
      end
    end

    context 'when source is a project' do
      let(:project) { build_stubbed(:project) }
      let(:root_group) { build_stubbed(:group) }

      before do
        allow(project).to receive(:root_ancestor).and_return(root_group)
      end

      context 'when namespace has free plan and trial is expired' do
        before do
          allow(GitlabSubscriptions::Trials).to receive(:free_plan_expired?).with(root_group).and_return(true)
        end

        it 'returns a TrialExpiredComponent instance' do
          is_expected.to be_a(DuoChatPanel::TrialExpiredComponent)
        end
      end

      context 'when namespace does not have free plan with expired trial' do
        before do
          allow(GitlabSubscriptions::Trials).to receive(:free_plan_expired?).with(root_group).and_return(false)
        end

        it 'does not return a TrialExpiredComponent' do
          is_expected.not_to be_a(DuoChatPanel::TrialExpiredComponent)
        end
      end
    end
  end

  describe 'show_trial_expired? on self-managed' do
    context 'when license is an expired ultimate trial' do
      before do
        expired_trial_license = build(:license, :ultimate_trial, expired: true)
        allow(License).to receive(:current).and_return(expired_trial_license)
      end

      it 'returns a TrialExpiredComponent instance' do
        is_expected.to be_a(DuoChatPanel::TrialExpiredComponent)
      end

      context 'when project and group are nil' do
        let(:project) { nil }
        let(:group) { nil }

        it 'still returns a TrialExpiredComponent instance' do
          is_expected.to be_a(DuoChatPanel::TrialExpiredComponent)
        end
      end
    end

    context 'when license is an active ultimate trial' do
      before do
        active_license = build(:license, :ultimate_trial)
        allow(License).to receive(:current).and_return(active_license)
      end

      it 'does not return a TrialExpiredComponent' do
        is_expected.not_to be_a(DuoChatPanel::TrialExpiredComponent)
      end
    end

    context 'when both show_chat? and self_managed_trial_expired? are true' do
      before do
        allow(duo_chat_instance).to receive(:show_duo_entry_point?).and_return(true)
        expired_trial_license = build(:license, :ultimate_trial, expired: true)
        allow(License).to receive(:current).and_return(expired_trial_license)
      end

      it 'returns a ChatComponent, not a TrialExpiredComponent' do
        is_expected.to be_a(DuoChatPanel::ChatComponent)
      end
    end
  end

  describe 'show_duo_disabled_non_admin?' do
    context 'when container is nil' do
      it 'does not render DuoDisabledNonAdminComponent even if duo features are disabled' do
        is_expected.not_to be_a(DuoChatPanel::DuoDisabledNonAdminComponent)
      end
    end

    context 'when duo is disabled and user cannot enable it' do
      let(:user) { build_stubbed(:user) }
      let(:project) { build_stubbed(:project) }

      before do
        allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
          .with(user, project, nil, nil)
          .and_return({ project: project, default_namespace_applied: false })
        allow(project).to receive(:duo_features_enabled).and_return(false)
        allow(user).to receive(:can?).with(:admin_project, project).and_return(false)
        allow(duo_chat_instance).to receive(:show_duo_entry_point?).and_return(true)
      end

      it 'renders DuoDisabledNonAdminComponent instead of ChatComponent' do
        is_expected.to be_a(DuoChatPanel::DuoDisabledNonAdminComponent)
      end
    end
  end

  describe 'show_subscription_expired? on .com', :saas_gitlab_com_subscriptions do
    let(:group) { build_stubbed(:group) }

    before do
      allow(group).to receive_messages(duo_features_enabled: true, root_ancestor: group)
      allow(GitlabSubscriptions::Trials).to receive(:free_plan_expired?).with(group).and_return(false)
      allow(instance).to receive(:can_start_trial?).and_return(false)
    end

    context 'when namespace has no gitlab_subscription' do
      before do
        allow(group).to receive(:gitlab_subscription).and_return(nil)
      end

      it 'does not route to ChatComponent via subscription_expired' do
        is_expected.to be_a(DuoChatPanel::AccessDeniedComponent)
      end
    end

    context 'when gitlab_subscription is paid and expired' do
      let(:gitlab_subscription) { instance_double(GitlabSubscription, paid_and_expired?: true) }

      before do
        allow(group).to receive(:gitlab_subscription).and_return(gitlab_subscription)
      end

      it 'returns a ChatComponent instance (blocked state handled in Vue)' do
        is_expected.to be_a(DuoChatPanel::ChatComponent)
      end
    end

    context 'when gitlab_subscription is not paid-and-expired' do
      let(:gitlab_subscription) { instance_double(GitlabSubscription, paid_and_expired?: false) }

      before do
        allow(group).to receive(:gitlab_subscription).and_return(gitlab_subscription)
      end

      it 'falls through to AccessDeniedComponent' do
        is_expected.to be_a(DuoChatPanel::AccessDeniedComponent)
      end
    end
  end

  describe 'show_subscription_expired? on self-managed' do
    context 'when license is expired and non-trial' do
      let(:license) { build(:license, :expired_paid) }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns a ChatComponent instance (blocked state handled in Vue)' do
        is_expected.to be_a(DuoChatPanel::ChatComponent)
      end
    end

    context 'when license is nil' do
      before do
        allow(License).to receive(:current).and_return(nil)
      end

      it 'falls through to AccessDeniedComponent' do
        is_expected.to be_a(DuoChatPanel::AccessDeniedComponent)
      end
    end

    context 'when license is a trial license' do
      let(:license) { build(:license, :ultimate_trial, expired: true) }

      it 'does not route to ChatComponent via subscription_expired (trial-expired branch wins)' do
        allow(License).to receive(:current).and_return(license)
        is_expected.to be_a(DuoChatPanel::TrialExpiredComponent)
      end
    end

    context 'when license is not expired' do
      let(:license) { build(:license, :active_paid) }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'falls through to AccessDeniedComponent' do
        is_expected.to be_a(DuoChatPanel::AccessDeniedComponent)
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::CombinedBypassChecker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :stubbed_repository) }
  let_it_be(:branch_name) { 'main' }
  let_it_be(:user) { create(:user, :project_bot) }
  let_it_be(:user_access) { Gitlab::UserAccess.new(user, container: project) }
  let(:push_options) { Gitlab::PushOptions.new([]) }

  let(:checker) do
    described_class.new(
      project: project,
      user_access: user_access,
      branch_name: branch_name,
      push_options: push_options
    )
  end

  describe '#protected_branch_bypass_granted?' do
    subject { checker.protected_branch_bypass_granted? }

    context 'when the feature is not available' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it { is_expected.to be false }
    end

    context 'when the feature is available' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when protected branch bypass is granted' do
        let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }

        before do
          create(:security_policy, :approval_policy, linked_projects: [project],
            bypass_access_token_ids: [personal_access_token.id])
          allow(::Gitlab::Audit::Auditor).to receive(:audit)
        end

        it { is_expected.to be true }
      end
    end
  end

  describe '#policy_bypass_granted?' do
    subject { checker.policy_bypass_granted? }

    context 'when the feature is not available' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it { is_expected.to be false }
    end

    context 'when the feature is available' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when protected branch bypass is granted' do
        let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }

        before do
          create(:security_policy, :approval_policy, linked_projects: [project],
            bypass_access_token_ids: [personal_access_token.id])
          allow(::Gitlab::Audit::Auditor).to receive(:audit)
        end

        it { is_expected.to be true }

        it 'does not run the push policy bypass check' do
          expect(Security::ScanResultPolicies::PushBypassChecker).to receive(:new)
            .with(hash_including(
              bypass_context: instance_of(Security::ScanResultPolicies::BypassContexts::ProtectedBranchContext)
            )).and_call_original

          expect(Security::ScanResultPolicies::PushBypassChecker).not_to receive(:new)
            .with(hash_including(
              bypass_context: instance_of(Security::ScanResultPolicies::BypassContexts::PushPolicyContext)
            ))

          checker.policy_bypass_granted?
        end
      end

      context 'when no bypass is granted' do
        before do
          create(:security_policy, :approval_policy, linked_projects: [project])
        end

        it { is_expected.to be false }
      end
    end
  end

  describe '#bypass_reason_required?' do
    subject { checker.bypass_reason_required? }

    context 'when the feature is not available' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it { is_expected.to be false }
    end

    context 'when the feature is available' do
      let_it_be(:regular_user) { create(:user) }
      let_it_be(:regular_user_access) { Gitlab::UserAccess.new(regular_user, container: project) }

      let(:checker) do
        described_class.new(
          project: project,
          user_access: regular_user_access,
          branch_name: branch_name,
          push_options: push_options
        )
      end

      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when user bypass is allowed but no reason is provided' do
        before do
          create(:security_policy, linked_projects: [project], content: {
            bypass_settings: {
              users: [{ id: regular_user.id }]
            }
          })
        end

        it { is_expected.to be true }
      end

      context 'when no bypass is allowed' do
        before do
          create(:security_policy, :approval_policy, linked_projects: [project])
        end

        it { is_expected.to be false }
      end
    end
  end
end

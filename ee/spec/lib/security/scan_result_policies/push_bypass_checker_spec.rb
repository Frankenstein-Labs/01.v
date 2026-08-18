# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::PushBypassChecker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :stubbed_repository) }

  let_it_be(:branch_name) { 'main' }
  let_it_be(:user) { create(:user, :project_bot) }
  let_it_be(:user_access) { Gitlab::UserAccess.new(user, container: project) }
  let(:push_options) { Gitlab::PushOptions.new([]) }
  let(:bypass_context) do
    Security::ScanResultPolicies::BypassContexts::PushPolicyContext.new(push_options: push_options)
  end

  let(:checker) do
    described_class.new(
      project: project,
      user_access: user_access,
      branch_name: branch_name,
      bypass_context: bypass_context
    )
  end

  describe '#check_bypass!' do
    context 'when the feature is not available' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it 'returns false' do
        expect(checker.check_bypass!).to be false
      end
    end

    context 'when the feature is available' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when there are no policies with bypass settings' do
        it 'returns false' do
          expect(checker.check_bypass!).to be false
        end
      end

      context 'when there is a policy with bypass settings for access token' do
        let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
        let_it_be_with_reload(:security_policy) do
          create(:security_policy, :approval_policy, linked_projects: [project],
            bypass_access_token_ids: [personal_access_token.id])
        end

        it 'returns true' do
          expect(checker.check_bypass!).to be true
        end

        context 'when the access token is not allowed to bypass' do
          before do
            another_access_token = create(:personal_access_token)
            security_policy.update!(content: { bypass_settings: { access_tokens: [{ id: another_access_token.id }] } })
          end

          it 'returns false' do
            expect(checker.check_bypass!).to be false
          end
        end

        context 'when BypassReasonRequiredError is raised and suppressed' do
          before do
            allow_next_instance_of(Security::ScanResultPolicies::PolicyBypassChecker) do |instance|
              allow(instance).to receive(:bypass_allowed?).and_raise(
                Security::ScanResultPolicies::PolicyBypassChecker::BypassReasonRequiredError
              )
            end

            allow(bypass_context).to receive(:suppress_reason_required_error?).and_return(true)
          end

          it 'returns false' do
            expect(checker.check_bypass!).to be false
          end
        end

        context 'when BypassReasonRequiredError is raised and not suppressed' do
          before do
            allow_next_instance_of(Security::ScanResultPolicies::PolicyBypassChecker) do |instance|
              allow(instance).to receive(:bypass_allowed?).and_raise(
                Security::ScanResultPolicies::PolicyBypassChecker::BypassReasonRequiredError
              )
            end

            allow(bypass_context).to receive(:suppress_reason_required_error?).and_return(false)
          end

          it 'raises the error' do
            expect { checker.check_bypass! }.to raise_error(
              Security::ScanResultPolicies::PolicyBypassChecker::BypassReasonRequiredError
            )
          end
        end
      end

      context 'with multiple security policies' do
        let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }

        context 'when multiple policies have bypass_settings' do
          let_it_be_with_reload(:security_policy) do
            create(:security_policy, :approval_policy, linked_projects: [project],
              bypass_access_token_ids: [personal_access_token.id])
          end

          let_it_be_with_reload(:non_matching_security_policy) do
            create(:security_policy, :approval_policy, linked_projects: [project],
              bypass_access_token_ids: [999_999])
          end

          it 'returns true if any policy allows bypass' do
            expect(checker.check_bypass!).to be true
          end
        end

        context 'when only one policy has bypass_settings' do
          let_it_be_with_reload(:security_policy) do
            create(:security_policy, :approval_policy, linked_projects: [project],
              bypass_access_token_ids: [personal_access_token.id])
          end

          let_it_be_with_reload(:non_matching_security_policy) do
            create(:security_policy, :approval_policy, linked_projects: [project], content: {})
          end

          it 'returns true if the policy with bypass_settings allows bypass' do
            expect(checker.check_bypass!).to be true
          end
        end

        context 'when multiple policies have no bypass_settings' do
          let_it_be_with_reload(:security_policy1) do
            create(:security_policy, :approval_policy, linked_projects: [project], content: {})
          end

          let_it_be_with_reload(:security_policy2) do
            create(:security_policy, :approval_policy, linked_projects: [project], content: {})
          end

          it 'returns false' do
            expect(checker.check_bypass!).to be false
          end
        end
      end

      context 'with protected branch bypass context' do
        let(:bypass_context) { Security::ScanResultPolicies::BypassContexts::ProtectedBranchContext.new }
        let(:checker) do
          described_class.new(
            project: project,
            user_access: user_access,
            branch_name: branch_name,
            bypass_context: bypass_context
          )
        end

        let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }

        context 'when there is a policy with bypass settings' do
          let_it_be_with_reload(:security_policy) do
            create(:security_policy, :approval_policy, linked_projects: [project],
              bypass_access_token_ids: [personal_access_token.id])
          end

          before do
            allow(::Gitlab::Audit::Auditor).to receive(:audit)
          end

          it 'returns true' do
            expect(checker.check_bypass!).to be true
          end
        end
      end
    end
  end
end

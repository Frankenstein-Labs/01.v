# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::BranchCheck, feature_category: :source_code_management do
  let_it_be_with_reload(:project) { create(:project, :stubbed_repository, skip_disk_validation: true) }
  let_it_be(:user) { create(:user) }
  let(:user_access) { Gitlab::UserAccess.new(user, container: project) }
  let(:oldrev) { 'a' * 40 }
  let(:newrev) { '1' * 40 }
  let(:ref) { 'refs/heads/main' }
  let(:changes) { { oldrev: oldrev, newrev: newrev, ref: ref } }
  let(:protocol) { 'ssh' }
  let(:timeout) { Gitlab::GitAccess::INTERNAL_TIMEOUT }
  let(:logger) { Gitlab::Checks::TimedLogger.new(timeout: timeout) }
  let(:gitaly_context) { nil }
  let(:push_options) { Gitlab::PushOptions.new([]) }
  let(:change_access) do
    Gitlab::Checks::SingleChangeAccess.new(
      changes,
      project: project,
      user_access: user_access,
      protocol: protocol,
      logger: logger,
      push_options: push_options,
      gitaly_context: gitaly_context
    )
  end

  before_all do
    project.add_developer(user)
  end

  describe '#validate!' do
    subject(:validate!) { branch_check.validate! }

    let(:branch_check) { described_class.new(change_access) }

    before do
      allow(project).to receive(:branch_protection_settings).and_return(nil)
      allow(Gitlab::Checks::ForcePush).to receive(:force_push?).and_return(false)
    end

    context 'with protected branch' do
      let!(:protected_branch) { create(:protected_branch, project: project, name: 'main') }

      shared_examples_for 'does not allow the action' do
        it 'does not allow the action' do
          expect { validate! }.to raise_error(Gitlab::GitAccess::ForbiddenError)
        end
      end

      context 'when the security policy feature is available' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
          allow(::Gitlab::Audit::Auditor).to receive(:audit)
        end

        context 'when security policy allows protected branch bypass' do
          let_it_be(:personal_access_token) { create(:personal_access_token, user: create(:user, :project_bot)) }

          before do
            create(:security_policy, :approval_policy, linked_projects: [project],
              bypass_access_token_ids: [personal_access_token.id])

            allow(user_access).to receive(:user).and_return(personal_access_token.user)
          end

          it 'allows the push' do
            expect { validate! }.not_to raise_error
          end

          context 'when force pushing' do
            before do
              allow(Gitlab::Checks::ForcePush).to receive(:force_push?).and_return(true)
            end

            it 'allows force push to protected branch' do
              expect { validate! }.not_to raise_error
            end
          end

          context 'when creating a branch' do
            let(:oldrev) { '0' * 40 }

            it_behaves_like 'does not allow the action'
          end

          context 'when deleting a branch' do
            let(:newrev) { '0' * 40 }

            it_behaves_like 'does not allow the action'
          end
        end

        context 'when security policy does not allow protected branch bypass' do
          before do
            create(:security_policy, :approval_policy, linked_projects: [project])
          end

          it_behaves_like 'does not allow the action'
        end
      end

      context 'when security policy feature is not available' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it_behaves_like 'does not allow the action'
      end
    end
  end
end

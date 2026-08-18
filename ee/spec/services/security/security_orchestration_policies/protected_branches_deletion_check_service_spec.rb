# frozen_string_literal: true

require "spec_helper"

RSpec.describe Security::SecurityOrchestrationPolicies::ProtectedBranchesDeletionCheckService, "#execute", feature_category: :security_policy_management do
  let_it_be_with_reload(:project) { create(:project, :small_repo) }
  let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }
  let_it_be_with_reload(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: protected_branch.project)
  end

  let_it_be(:current_user) { nil }

  subject(:result) do
    described_class.new(project: project, current_user: current_user).execute([protected_branch])
  end

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  before_all do
    project.repository.add_branch(project.creator, protected_branch.name, "HEAD")
  end

  context "without blocking scan result policy" do
    it "excludes the protected branch" do
      expect(result).to exclude(protected_branch)
    end
  end

  context "with blocking scan result policy" do
    include_context 'with persisted approval policies'

    include_context 'with approval policy blocking protected branches' do
      let(:branch_name) { protected_branch.name }

      context 'when policy is applicable based on the policy scope configuration' do
        it "includes the protected branch" do
          expect(result).to include(protected_branch)
        end

        context 'when protected branch is not backed by git ref' do
          before do
            project.repository.delete_branch(branch_name)
          end

          after do
            project.repository.add_branch(project.creator, branch_name, "HEAD")
          end

          it "includes the protected branch" do
            expect(result).to include(protected_branch)
          end
        end
      end

      context 'when policy is not linked to project and policy scope excludes project' do
        before do
          project.security_policies.first.unlink_project!(project)
        end

        it "excludes the protected branch" do
          expect(result).to exclude(protected_branch)
        end
      end
    end

    context 'when policy branch specification has wildcard' do
      let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project, name: "rc-1") }

      include_context 'with approval policy blocking protected branches' do
        let(:branch_name) { "rc-*" }

        it "includes the protected branch" do
          expect(result).to include(protected_branch)
        end
      end
    end

    context "with mismatching branch specification" do
      include_context 'with approval policy blocking protected branches' do
        let(:branch_name) { protected_branch.name }
        let(:approval_policy) do
          build(:approval_policy, branches: [branch_name.reverse],
            approval_settings: { block_branch_modification: true })
        end

        it "excludes the protected branch" do
          expect(result).to exclude(protected_branch)
        end
      end
    end

    context 'with ignore_warn_mode' do
      include_context 'with approval policy blocking protected branches' do
        let(:branch_name) { protected_branch.name }
        let(:approval_policy) do
          build(:approval_policy, branches: [branch_name],
            approval_settings: { block_branch_modification: true },
            enforcement_type: Security::Policy::ENFORCEMENT_TYPE_WARN)
        end

        context 'when ignore_warn_mode is false' do
          let(:result) do
            described_class.new(project: project, current_user: current_user,
              ignore_warn_mode: false).execute([protected_branch])
          end

          it_behaves_like 'when policy is applicable based on the policy scope configuration' do
            it "excludes the protected branch (warn mode policy is filtered)" do
              expect(result).to exclude(protected_branch)
            end
          end
        end

        context 'when ignore_warn_mode is true' do
          let(:result) do
            described_class.new(project: project, current_user: current_user,
              ignore_warn_mode: true).execute([protected_branch])
          end

          it_behaves_like 'when policy is applicable based on the policy scope configuration' do
            it "includes the protected branch (warn mode policy is not filtered)" do
              expect(result).to include(protected_branch)
            end
          end
        end
      end
    end

    context 'with service account bypass' do
      let_it_be(:service_account) { create(:user, :service_account) }
      let_it_be(:current_user) { service_account }

      include_context 'with approval policy' do
        let(:branch_name) { protected_branch.name }
        let(:approval_policy) do
          build(:approval_policy,
            branches: [branch_name],
            approval_settings: { block_branch_modification: true },
            bypass_settings: { service_accounts: [{ id: service_account.id }] })
        end
      end

      it "excludes the protected branch when service account is in bypass_settings" do
        expect(result).to exclude(protected_branch)
      end

      context 'when service account is not in bypass_settings' do
        let_it_be(:other_service_account) { create(:user, :service_account) }

        include_context 'with approval policy' do
          let(:branch_name) { protected_branch.name }
          let(:approval_policy) do
            build(:approval_policy,
              branches: [branch_name],
              approval_settings: { block_branch_modification: true },
              bypass_settings: { service_accounts: [{ id: other_service_account.id }] })
          end
        end

        it "includes the protected branch" do
          expect(result).to include(protected_branch)
        end
      end

      context 'when current_user is nil' do
        let_it_be(:current_user) { nil }

        include_context 'with approval policy' do
          let(:branch_name) { protected_branch.name }
          let(:approval_policy) do
            build(:approval_policy,
              branches: [branch_name],
              approval_settings: { block_branch_modification: true },
              bypass_settings: { service_accounts: [{ id: service_account.id }] })
          end
        end

        it "includes the protected branch" do
          expect(result).to include(protected_branch)
        end
      end
    end

    context 'with access token bypass' do
      let_it_be(:project_bot) { create(:user, :project_bot) }
      let_it_be_with_reload(:personal_access_token) { create(:personal_access_token, user: project_bot) }
      let_it_be(:current_user) { project_bot }

      include_context 'with approval policy' do
        let(:branch_name) { protected_branch.name }
        let(:approval_policy) do
          build(:approval_policy,
            branches: [branch_name],
            approval_settings: { block_branch_modification: true },
            bypass_settings: { access_tokens: [{ id: personal_access_token.id }] })
        end
      end

      it "excludes the protected branch when access token is in bypass_settings" do
        expect(result).to exclude(protected_branch)
      end

      context 'when access token is revoked' do
        before do
          personal_access_token.revoke!
        end

        it "includes the protected branch" do
          expect(result).to include(protected_branch)
        end
      end

      context 'when access token is not in bypass_settings' do
        let_it_be(:other_token) { create(:personal_access_token) }

        include_context 'with approval policy' do
          let(:branch_name) { protected_branch.name }
          let(:approval_policy) do
            build(:approval_policy,
              branches: [branch_name],
              approval_settings: { block_branch_modification: true },
              bypass_settings: { access_tokens: [{ id: other_token.id }] })
          end
        end

        it "includes the protected branch" do
          expect(result).to include(protected_branch)
        end
      end
    end

    context 'when approval_settings does not block branch modification' do
      include_context 'with persisted approval policies'

      include_context 'with approval policy' do
        let(:branch_name) { protected_branch.name }
        let(:approval_policy) do
          build(:approval_policy, branches: [branch_name],
            approval_settings: { block_branch_modification: false })
        end
      end

      it "excludes the protected branch" do
        expect(result).to exclude(protected_branch)
      end
    end

    context 'when approval_settings has no block_branch_modification key' do
      include_context 'with persisted approval policies'

      include_context 'with approval policy' do
        let(:branch_name) { protected_branch.name }
        let(:approval_policy) do
          build(:approval_policy, branches: [branch_name],
            approval_settings: {})
        end
      end

      it "excludes the protected branch" do
        expect(result).to exclude(protected_branch)
      end
    end
  end

  describe 'log_bypass_audit' do
    let(:test_class) do
      Class.new do
        include Security::SecurityOrchestrationPolicies::Concerns::ProtectedBranchesDeletionCheck

        attr_reader :current_user, :container

        def initialize(current_user)
          @current_user = current_user
          @container = nil
        end
      end
    end

    let_it_be(:service_account) { create(:user, :service_account) }

    let(:policy_record) do
      create(:security_policy, :approval_policy, security_orchestration_policy_configuration: policy_configuration)
    end

    context 'when container is nil' do
      let(:service_without_container) { test_class.new(service_account) }
      let(:bypass_checker) do
        Security::ScanResultPolicies::BotBypassChecker.new(
          bypass_settings: Security::ScanResultPolicies::BypassSettings.new(
            { service_accounts: [{ id: service_account.id }] }
          ),
          user: service_account
        )
      end

      it 'returns early without creating an auditor' do
        expect(Security::ScanResultPolicies::BranchDeletionBypassAuditor).not_to receive(:new)

        service_without_container.send(:log_bypass_audit, policy_record, bypass_checker)
      end
    end

    context 'when bypass has neither service_account_id nor access_token_ids' do
      let(:test_class_with_container) do
        test_project = project
        Class.new do
          include Security::SecurityOrchestrationPolicies::Concerns::ProtectedBranchesDeletionCheck

          attr_reader :current_user

          define_method(:container) { test_project }

          def initialize(current_user)
            @current_user = current_user
          end
        end
      end

      let(:service_with_container) { test_class_with_container.new(service_account) }
      let(:bypass_checker) do
        Security::ScanResultPolicies::BotBypassChecker.new(
          bypass_settings: Security::ScanResultPolicies::BypassSettings.new({}),
          user: service_account
        )
      end

      it 'does not log any bypass event' do
        auditor = Security::ScanResultPolicies::BranchDeletionBypassAuditor.new(
          security_policy: policy_record, container: project, user: service_account
        )
        allow(Security::ScanResultPolicies::BranchDeletionBypassAuditor).to receive(:new).and_return(auditor)

        expect(auditor).not_to receive(:log_service_account_bypass)
        expect(auditor).not_to receive(:log_access_token_bypass)

        service_with_container.send(:log_bypass_audit, policy_record, bypass_checker)
      end
    end

    context 'with service account bypass' do
      let_it_be(:bypass_service_account) { create(:user, :service_account) }
      let(:result) do
        described_class.new(project: project, current_user: bypass_service_account).execute([protected_branch])
      end

      include_context 'with persisted approval policies'

      include_context 'with approval policy' do
        let(:branch_name) { protected_branch.name }
        let(:approval_policy) do
          build(:approval_policy,
            branches: [branch_name],
            approval_settings: { block_branch_modification: true },
            bypass_settings: { service_accounts: [{ id: bypass_service_account.id }] })
        end
      end

      it 'logs service account bypass and does not log access token bypass' do
        expect_next_instance_of(Security::ScanResultPolicies::BranchDeletionBypassAuditor) do |auditor|
          expect(auditor).to receive(:log_service_account_bypass).with(bypass_service_account.id)
          expect(auditor).not_to receive(:log_access_token_bypass)
        end

        expect(result).to exclude(protected_branch)
      end
    end
  end

  describe 'approval_settings_block_modification?' do
    let(:service) { described_class.new(project: project, current_user: current_user) }

    context 'when policy type is not approval_policy' do
      let(:policy_record) do
        create(:security_policy, :scan_execution_policy,
          security_orchestration_policy_configuration: policy_configuration)
      end

      it 'returns false when approval_policy is nil' do
        expect(service.send(:approval_settings_block_modification?, policy_record)).to be(false)
      end
    end

    context 'when policy content has no approval_settings key' do
      let(:policy_record) do
        create(:security_policy, :approval_policy,
          security_orchestration_policy_configuration: policy_configuration,
          content: {})
      end

      it 'returns false when block_branch_modification is nil' do
        expect(service.send(:approval_settings_block_modification?, policy_record)).to be(false)
      end
    end

    context 'when block_branch_modification is true' do
      let(:policy_record) do
        create(:security_policy, :approval_policy,
          security_orchestration_policy_configuration: policy_configuration,
          content: { approval_settings: { block_branch_modification: true } })
      end

      it 'returns true' do
        expect(service.send(:approval_settings_block_modification?, policy_record)).to be(true)
      end
    end
  end
end

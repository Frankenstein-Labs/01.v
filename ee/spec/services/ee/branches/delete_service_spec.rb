# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Branches::DeleteService, feature_category: :source_code_management do
  describe '#execute' do
    subject(:execute_service) { described_class.new(project, user).execute(protected_branch_name) }

    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:project) { create(:project, :small_repo, developers: user) }

    let!(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let!(:protected_branch) { create(:protected_branch, name: protected_branch_name, project: project) }
    let(:protected_branch_name) { 'protected_branch' }

    before do
      project.repository.create_branch(protected_branch_name, project.default_branch_or_main)
    end

    shared_examples 'a deleted branch' do
      it 'removes the branch' do
        expect(branch_exists?(protected_branch_name)).to be true

        result = execute_service

        expect(result.status).to eq :success
        expect(branch_exists?(protected_branch_name)).to be false
      end
    end

    it_behaves_like 'a deleted branch'

    context 'with approval policy blocking protected branches' do
      include_context 'with approval policy blocking protected branches'
      include_context 'with persisted approval policies'

      let(:branch_name) { protected_branch_name }

      it 'does not allow delete', :aggregate_failures do
        result = execute_service

        expect(result.status).to eq :error
        expect(result.message).to eq 'Deleting protected branches is blocked by security policies'
        expect(result.reason).to eq :forbidden
      end

      context 'when the security_orchestration_policies feature is not available' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it_behaves_like 'a deleted branch'
      end

      context 'when branch is not included in security policy' do
        include_context 'with approval policy blocking protected branches' do
          let(:branch_name) { 'some other branch' }
        end

        it_behaves_like 'a deleted branch'
      end

      context 'with branch exceptions' do
        include_context 'with approval policy blocking protected branches' do
          let(:rules) do
            [
              {
                type: 'scan_finding',
                branch_type: 'protected',
                branch_exceptions: [branch_name],
                scanners: %w[container_scanning],
                vulnerabilities_allowed: 0,
                severity_levels: %w[critical],
                vulnerability_states: %w[detected],
                vulnerability_attributes: {}
              }
            ]
          end

          let(:approval_policy) do
            build(:approval_policy, rules: rules, approval_settings: { block_branch_modification: true })
          end
        end

        it_behaves_like 'a deleted branch'
      end

      context 'with service account bypass' do
        let_it_be(:service_account) { create(:user, :service_account, developer_of: project) }

        subject(:execute_service) { described_class.new(project, service_account).execute(protected_branch_name) }

        include_context 'with approval policy' do
          let(:approval_policy) do
            build(:approval_policy,
              branches: [branch_name],
              approval_settings: { block_branch_modification: true },
              bypass_settings: { service_accounts: [{ id: service_account.id }] })
          end
        end

        it_behaves_like 'a deleted branch'

        context 'when service account is not in bypass_settings' do
          let(:other_service_account) { create(:user, :service_account) }

          include_context 'with approval policy' do
            let(:approval_policy) do
              build(:approval_policy,
                branches: [branch_name],
                approval_settings: { block_branch_modification: true },
                bypass_settings: { service_accounts: [{ id: other_service_account.id }] })
            end
          end

          it 'does not allow delete', :aggregate_failures do
            result = execute_service

            expect(result.status).to eq :error
            expect(result.message).to eq 'Deleting protected branches is blocked by security policies'
            expect(result.reason).to eq :forbidden
          end
        end
      end

      context 'with access token bypass' do
        let_it_be(:project_bot) { create(:user, :project_bot, developer_of: project) }
        let_it_be_with_reload(:personal_access_token) { create(:personal_access_token, user: project_bot) }

        subject(:execute_service) { described_class.new(project, project_bot).execute(protected_branch_name) }

        include_context 'with approval policy' do
          let(:approval_policy) do
            build(:approval_policy,
              branches: [branch_name],
              approval_settings: { block_branch_modification: true },
              bypass_settings: { access_tokens: [{ id: personal_access_token.id }] })
          end
        end

        it_behaves_like 'a deleted branch'

        context 'when access token is revoked' do
          before do
            personal_access_token.revoke!
          end

          it 'does not allow delete', :aggregate_failures do
            result = execute_service

            expect(result.status).to eq :error
            expect(result.message).to eq 'Deleting protected branches is blocked by security policies'
            expect(result.reason).to eq :forbidden
          end
        end
      end
    end

    context 'when there is a push rule matching the branch name' do
      before_all do
        create(:push_rule, branch_name_regex: '^(w*)$')
      end

      let(:protected_branch_name) { 'add-pdf-file' }

      it_behaves_like 'a deleted branch'
    end

    def branch_exists?(branch_name)
      project.repository.ref_exists?("refs/heads/#{branch_name}")
    end
  end
end

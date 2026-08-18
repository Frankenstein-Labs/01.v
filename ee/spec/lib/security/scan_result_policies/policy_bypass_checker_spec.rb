# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::PolicyBypassChecker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:branch_name) { 'main' }
  let_it_be(:user) { create(:user, :project_bot) }
  let_it_be(:service_account) { create(:service_account) }
  let_it_be(:normal_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:custom_role) { create(:member_role, namespace: project.namespace) }

  let(:bypass_settings) { {} }
  let(:security_policy) do
    create(:security_policy, linked_projects: [project], content: { bypass_settings: bypass_settings })
  end

  let_it_be(:service_account_access) { Gitlab::UserAccess.new(service_account, container: project) }
  let_it_be(:user_access) { Gitlab::UserAccess.new(user, container: project) }
  let_it_be(:normal_user_access) { Gitlab::UserAccess.new(normal_user, container: project) }

  describe '#bypass_allowed?' do
    subject(:bypass_allowed?) do
      described_class.new(
        security_policy: security_policy,
        project: project,
        user_access: user_access,
        branch_name: branch_name,
        bypass_context: Security::ScanResultPolicies::BypassContexts::PushPolicyContext.new(
          push_options: push_options
        )
      ).bypass_allowed?
    end

    let(:push_options) { Gitlab::PushOptions.new([]) }

    before do
      allow(Gitlab::Audit::Auditor).to receive(:audit).and_call_original
    end

    shared_examples 'bypass is not allowed and audit log is not created' do
      it 'returns false and does not create an audit log' do
        result = bypass_allowed?

        expect(result).to be false
        expect(Gitlab::Audit::Auditor).not_to have_received(:audit).with(hash_including(message: a_string_including(
          "Branch push restriction on '#{branch_name}' for project '#{project.full_path}' has been bypassed by"
        )))
      end
    end

    context 'when bypass_settings is blank' do
      before do
        security_policy.update!(content: { actions: [] })
      end

      it_behaves_like 'bypass is not allowed and audit log is not created'
    end

    context 'when bypass_settings has access_tokens' do
      let_it_be_with_reload(:personal_access_token) { create(:personal_access_token, user: user) }

      before do
        security_policy.update!(content: { bypass_settings: { access_tokens: [{ id: personal_access_token.id }] } })
      end

      context 'when the access token is inactive' do
        before do
          personal_access_token.update!(expires_at: 1.day.ago)
        end

        it_behaves_like 'bypass is not allowed and audit log is not created'
      end

      context 'when the access token is active' do
        before do
          personal_access_token.update!(expires_at: nil)
        end

        it 'returns true and creates an audit log' do
          result = bypass_allowed?

          expect(result).to be true
          expect(Gitlab::Audit::Auditor).to have_received(:audit).with(hash_including(
            name: 'security_policy_access_token_push_bypass',
            author: user,
            scope: security_policy.security_policy_management_project,
            target: security_policy,
            message:
              "Branch push restriction on '#{branch_name}' for project '#{project.full_path}' " \
              "has been bypassed by access_token with ID: [#{personal_access_token.id}]",
            additional_details: hash_including(
              bypass_type: :access_token,
              access_token_ids: [personal_access_token.id],
              security_policy_name: security_policy.name,
              security_policy_id: security_policy.id,
              branch_name: branch_name
            )
          ))
        end
      end

      context 'when the access token is not allowed to bypass' do
        before do
          another_access_token = create(:personal_access_token)
          security_policy.update!(content: { bypass_settings: { access_tokens: [{ id: another_access_token.id }] } })
        end

        it_behaves_like 'bypass is not allowed and audit log is not created'
      end

      context 'when user_access is not a project bot' do
        let_it_be(:user_access) do
          normal_user = create(:user)
          Gitlab::UserAccess.new(normal_user, container: project)
        end

        it_behaves_like 'bypass is not allowed and audit log is not created'
      end
    end

    context 'when bot_checker allows bypass but has no service_account_id or access_token_ids' do
      let(:bot_checker) do
        instance_double(
          Security::ScanResultPolicies::BotBypassChecker,
          bypass_allowed?: true,
          service_account_id: nil,
          access_token_ids: nil
        )
      end

      before do
        allow(Security::ScanResultPolicies::BotBypassChecker).to receive(:new).and_return(bot_checker)
      end

      it 'returns true without creating a bypass audit log' do
        result = bypass_allowed?

        expect(result).to be true
        expect(Gitlab::Audit::Auditor).not_to have_received(:audit).with(
          hash_including(message: a_string_including("has been bypassed by"))
        )
      end
    end

    context 'when bypass_settings has service_accounts' do
      before do
        security_policy.update!(content: { bypass_settings: { service_accounts: [{ id: service_account.id }] } })
      end

      context 'when user_access is the allowed service account' do
        let_it_be(:user_access) { service_account_access }

        it 'returns true and creates an audit log' do
          result = bypass_allowed?

          expect(result).to be true
          expect(Gitlab::Audit::Auditor).to have_received(:audit).with(hash_including(
            name: 'security_policy_service_account_push_bypass',
            author: service_account,
            scope: security_policy.security_policy_management_project,
            target: security_policy,
            message:
              "Branch push restriction on '#{branch_name}' for project '#{project.full_path}' " \
              "has been bypassed by service_account with ID: #{service_account.id}",
            additional_details: hash_including(
              bypass_type: :service_account,
              service_account_id: service_account.id,
              security_policy_name: security_policy.name,
              security_policy_id: security_policy.id,
              branch_name: branch_name
            )
          ))
        end
      end

      context 'when user_access is a different service account' do
        let_it_be(:user_access) do
          other_service_account = create(:service_account)
          Gitlab::UserAccess.new(other_service_account, container: project)
        end

        it_behaves_like 'bypass is not allowed and audit log is not created'
      end

      context 'when user_access is not a service account' do
        let_it_be(:user_access) { Gitlab::UserAccess.new(user, container: project) }

        it_behaves_like 'bypass is not allowed and audit log is not created'
      end
    end

    context 'when bypass_settings has users' do
      let_it_be(:user_access) { normal_user_access }

      before do
        security_policy.update!(content: { bypass_settings: { users: [{ id: normal_user.id }] } })
      end

      context 'when user is a project bot' do
        let_it_be(:user_access) { Gitlab::UserAccess.new(user, container: project) }

        it_behaves_like 'bypass is not allowed and audit log is not created'
      end

      context 'when user is a service account' do
        let_it_be(:user_access) { service_account_access }

        it_behaves_like 'bypass is not allowed and audit log is not created'
      end

      context 'when user is not in the allowed users list' do
        before do
          security_policy.update!(content: { bypass_settings: { users: [{ id: create(:user).id }] } })
        end

        it_behaves_like 'bypass is not allowed and audit log is not created'
      end

      context 'when user is in the allowed users list but no bypass reason provided' do
        it 'raises BypassReasonRequiredError' do
          expect { bypass_allowed? }.to raise_error(
            Security::ScanResultPolicies::PolicyBypassChecker::BypassReasonRequiredError,
            'Bypass reason is required for user bypass'
          )
        end
      end

      context 'when user is in the allowed users list and bypass reason is provided' do
        let(:push_options) { Gitlab::PushOptions.new(['security_policy.bypass_reason=Emergency fix']) }

        it 'returns true and creates an audit log' do
          result = bypass_allowed?

          expect(result).to be true
          expect(Gitlab::Audit::Auditor).to have_received(:audit).with(hash_including(
            name: 'security_policy_user_push_bypass',
            author: normal_user,
            scope: security_policy.security_policy_management_project,
            target: security_policy,
            message:
              "Branch push restriction on '#{branch_name}' for project '#{project.full_path}' " \
              "has been bypassed by user with ID: #{normal_user.id} with reason: Emergency fix",
            additional_details: hash_including(
              bypass_type: :user,
              user_id: normal_user.id,
              reason: 'Emergency fix',
              security_policy_name: security_policy.name,
              security_policy_id: security_policy.id,
              branch_name: branch_name
            )
          ))
        end
      end
    end

    context 'when bypass_settings has groups' do
      let_it_be(:user_access) { normal_user_access }

      before do
        group.add_member(normal_user, Gitlab::Access::DEVELOPER)
        security_policy.update!(content: { bypass_settings: { groups: [{ id: group.id }] } })
      end

      context 'when user is not a member of the allowed group' do
        before do
          group.members.find_by(user: normal_user).destroy!
        end

        it_behaves_like 'bypass is not allowed and audit log is not created'
      end

      context 'when user is a member of the allowed group but no bypass reason provided' do
        it 'raises BypassReasonRequiredError' do
          expect { bypass_allowed? }.to raise_error(
            Security::ScanResultPolicies::PolicyBypassChecker::BypassReasonRequiredError,
            'Bypass reason is required for user bypass'
          )
        end
      end

      context 'when user is a member of the allowed group and bypass reason is provided' do
        let(:push_options) { Gitlab::PushOptions.new(['security_policy.bypass_reason=Critical security update']) }

        it 'returns true and creates an audit log' do
          result = bypass_allowed?

          expect(result).to be true
          expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
            hash_including(
              name: 'security_policy_user_push_bypass',
              author: normal_user,
              additional_details: hash_including(
                bypass_type: :group,
                group_ids: [group.id],
                user_id: normal_user.id,
                reason: 'Critical security update',
                event_name: 'security_policy_user_push_bypass'
              )
            )
          ).at_least(:once)
        end
      end
    end

    context 'when bypass_settings has both default roles and custom roles' do
      let_it_be(:user_access) { normal_user_access }

      before do
        project.add_member(normal_user, Gitlab::Access::MAINTAINER)
        member = project.members.find_by(user: normal_user)
        member.update!(member_role: custom_role)
        security_policy.update!(content: {
          bypass_settings: {
            default_roles: ['MAINTAINER'],
            custom_roles: [{ id: custom_role.id }]
          }
        })
      end

      context 'when bypass reason is provided' do
        let(:push_options) { Gitlab::PushOptions.new(['security_policy.bypass_reason=Multiple role bypass']) }

        it 'returns true and creates an audit log' do
          result = bypass_allowed?

          expect(result).to be true
          expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
            hash_including(
              name: 'security_policy_user_push_bypass',
              author: normal_user,
              additional_details: hash_including(
                bypass_type: :role,
                default_roles: [],
                custom_role_ids: [custom_role.id],
                reason: 'Multiple role bypass',
                event_name: 'security_policy_user_push_bypass'
              )
            )
          ).at_least(:once)
        end
      end
    end

    context 'when audit is disabled' do
      subject(:bypass_allowed?) do
        described_class.new(
          security_policy: security_policy,
          project: project,
          user_access: user_access,
          branch_name: branch_name,
          bypass_context: Security::ScanResultPolicies::BypassContexts::PushPolicyContext.new(
            push_options: push_options
          ),
          audit: false
        ).bypass_allowed?
      end

      shared_examples 'grants the bypass without auditing' do
        it 'returns true and does not create an audit log', :aggregate_failures do
          expect(bypass_allowed?).to be true
          expect(Gitlab::Audit::Auditor).not_to have_received(:audit).with(
            hash_including(message: a_string_including('has been bypassed by'))
          )
        end
      end

      context 'with an automated actor (access token) bypass' do
        let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
        let(:bypass_settings) { { access_tokens: [{ id: personal_access_token.id }] } }

        it_behaves_like 'grants the bypass without auditing'
      end

      context 'with a user bypass' do
        let_it_be(:user_access) { normal_user_access }
        let(:push_options) { Gitlab::PushOptions.new(['security_policy.bypass_reason=Emergency fix']) }
        let(:bypass_settings) { { users: [{ id: normal_user.id }] } }

        it_behaves_like 'grants the bypass without auditing'
      end
    end

    context 'when bypass reason contains HTML' do
      let_it_be(:user_access) { normal_user_access }
      let(:push_options) do
        Gitlab::PushOptions.new(['security_policy.bypass_reason=<script>alert("xss")</script>Emergency fix'])
      end

      before do
        security_policy.update!(content: { bypass_settings: { users: [{ id: normal_user.id }] } })
      end

      it 'sanitizes the bypass reason' do
        result = bypass_allowed?

        expect(result).to be true
        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(hash_including(
          additional_details: hash_including(
            reason: 'Emergency fix'
          )
        )).at_least(:once)
      end
    end
  end
end

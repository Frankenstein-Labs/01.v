# frozen_string_literal: true

require "spec_helper"

RSpec.describe Security::SecurityOrchestrationPolicies::GroupProtectedBranchesDeletionCheckService, "#execute", feature_category: :security_policy_management do
  include RepoHelpers
  using RSpec::Parameterized::TableSyntax

  include_context 'with approval policy' do
    let(:approval_policy) { policy }
    let(:approval_policies) { policies }
    let(:policy_configuration) { policy_config }
  end

  include_context 'with persisted approval policies'

  let(:service) { described_class.new(group: group, params: params) }
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:policy_config, freeze: false) do
    create(
      :security_orchestration_policy_configuration,
      :namespace,
      namespace: group)
  end

  let(:params) { {} }

  let(:block_branch_modification) { nil }
  let(:block_group_branch_modification) { nil }
  let(:approval_settings) do
    { block_branch_modification: block_branch_modification,
      block_group_branch_modification: block_group_branch_modification }.compact
  end

  let(:policies) { [policy] }
  let(:policy) do
    build(:approval_policy, approval_settings: approval_settings, enforcement_type: enforcement_type)
  end

  let(:enforcement_type) { Security::Policy::DEFAULT_ENFORCEMENT_TYPE }

  before do
    allow(group).to receive(:all_security_orchestration_policy_configurations).and_return([policy_config])
  end

  subject(:execute) { service.execute }

  where(:block_branch_modification, :block_group_branch_modification, :expectation) do
    true | nil   | true
    true | true  | true
    true | false | false
    nil  | nil   | false
    nil  | true  | true
    nil  | false | false

    true | { enabled: true }  | true
    true | { enabled: false } | false
    nil  | { enabled: true }  | true
    nil  | { enabled: false } | false

    true  | { enabled: true, exceptions: [{ id: lazy { group.id } }] }  | false
    true  | { enabled: false, exceptions: [{ id: lazy { group.id } }] } | false
    false | { enabled: true, exceptions: [{ id: lazy { group.id } }] }  | false
    false | { enabled: false, exceptions: [{ id: lazy { group.id } }] } | false

    true  | { enabled: true, exceptions: [{ id: lazy { non_existing_record_id } }] }  | true
    true  | { enabled: false, exceptions: [{ id: lazy { non_existing_record_id } }] } | false
    false | { enabled: true, exceptions: [{ id: lazy { non_existing_record_id } }] }  | true
    false | { enabled: false, exceptions: [{ id: lazy { non_existing_record_id } }] } | false
  end

  with_them do
    it { is_expected.to be(expectation) }
  end

  context 'without approval_settings' do
    let(:approval_settings) { {} }

    it { is_expected.to be(false) }
  end

  context 'when policy has no approval_policy' do
    let(:approval_settings) { { block_group_branch_modification: true } }

    before do
      allow_next_found_instance_of(Security::Policy) do |policy_record|
        allow(policy_record).to receive(:approval_policy).and_return(nil)
      end
    end

    it { is_expected.to be(false) }
  end

  context 'with conflicting settings' do
    let(:policies) do
      [
        build(:approval_policy, approval_settings: { block_group_branch_modification: true }),
        build(:approval_policy, approval_settings: { block_group_branch_modification: false })
      ]
    end

    it { is_expected.to be(true) }
  end

  context 'with warn mode policy' do
    let(:block_branch_modification) { true }
    let(:block_group_branch_modification) { true }
    let(:enforcement_type) { Security::Policy::ENFORCEMENT_TYPE_WARN }

    let(:policy) do
      build(:approval_policy,
        approval_settings: approval_settings,
        enforcement_type: Security::Policy::ENFORCEMENT_TYPE_WARN)
    end

    context 'with default-enforced policies only' do
      let(:params) { {} }

      it { is_expected.to be(false) }
    end

    context 'with warn mode policies only' do
      let(:params) { { policy_enforcement_type: ::Security::Policy::ENFORCEMENT_TYPE_WARN } }

      it { is_expected.to be(true) }

      context 'when ignore_warn_mode is true' do
        let(:service) { described_class.new(group: group, params: params, ignore_warn_mode: true) }

        it { is_expected.to be(false) }
      end
    end
  end

  context 'when collecting blocking policies' do
    let(:params) { { collect_blocking_policies: true } }

    let(:blocking_policy_1) { build(:approval_policy, approval_settings: { block_group_branch_modification: true }) }
    let(:non_blocking_policy) { build(:approval_policy, approval_settings: { block_group_branch_modification: false }) }
    let(:blocking_policy_2) { build(:approval_policy, approval_settings: { block_branch_modification: true }) }

    let(:policies) do
      [
        blocking_policy_1,
        non_blocking_policy,
        blocking_policy_2
      ]
    end

    it 'returns true and collects blocking policies', :aggregate_failures do
      expect(execute).to be(true)
      expect(service.blocking_policies).to contain_exactly(
        have_attributes(policy_configuration_id: policy_config.id,
          security_policy_name: blocking_policy_1[:name]),
        have_attributes(policy_configuration_id: policy_config.id,
          security_policy_name: blocking_policy_2[:name])
      )
    end

    context 'when no policies are blocking' do
      let(:policies) { [non_blocking_policy] }

      it 'returns false and collects no blocking policies' do
        expect(execute).to be(false)
        expect(service.blocking_policies).to be_empty
      end
    end

    context 'with warn mode policies' do
      let(:warn_mode_blocking_policy) do
        build(:approval_policy,
          approval_settings: { block_group_branch_modification: true },
          enforcement_type: Security::Policy::ENFORCEMENT_TYPE_WARN)
      end

      let(:default_blocking_policy) { blocking_policy_1 }

      let(:policies) { [warn_mode_blocking_policy, default_blocking_policy] }

      context 'when filtering for default-enforced policies (default behavior)' do
        let(:params) { { collect_blocking_policies: true } }

        it 'collects blocking default-enforced policy' do
          expect(execute).to be(true)
          expect(service.blocking_policies).to contain_exactly(
            have_attributes(policy_configuration_id: policy_config.id,
              security_policy_name: default_blocking_policy[:name]))
        end
      end

      context 'when filtering for warn mode policies' do
        let(:params) do
          { collect_blocking_policies: true, policy_enforcement_type: ::Security::Policy::ENFORCEMENT_TYPE_WARN }
        end

        it 'collects blocking warn mode policies' do
          expect(execute).to be(true)
          expect(service.blocking_policies).to contain_exactly(
            have_attributes(policy_configuration_id: policy_config.id,
              security_policy_name: warn_mode_blocking_policy[:name]))
        end
      end
    end
  end

  context 'with service account bypass' do
    let_it_be(:service_account, freeze: false) { create(:user, :service_account) }

    let(:service) { described_class.new(group: group, current_user: service_account, params: params) }
    let(:block_branch_modification) { true }
    let(:block_group_branch_modification) { nil }
    let(:policy) do
      build(:approval_policy,
        approval_settings: approval_settings,
        bypass_settings: { service_accounts: [{ id: service_account.id }] })
    end

    it { is_expected.to be(false) }

    context 'when service account is not in bypass_settings' do
      let_it_be(:other_service_account, freeze: false) { create(:user, :service_account) }

      let(:policy) do
        build(:approval_policy,
          approval_settings: approval_settings,
          bypass_settings: { service_accounts: [{ id: other_service_account.id }] })
      end

      it { is_expected.to be(true) }
    end

    context 'when current_user is nil' do
      let(:service) { described_class.new(group: group, current_user: nil, params: params) }

      it { is_expected.to be(true) }
    end
  end

  context 'with access token bypass' do
    let_it_be(:project_bot, freeze: false) { create(:user, :project_bot) }
    let_it_be(:personal_access_token, freeze: false) { create(:personal_access_token, user: project_bot) }

    let(:service) { described_class.new(group: group, current_user: project_bot, params: params) }
    let(:block_branch_modification) { true }
    let(:block_group_branch_modification) { nil }
    let(:policy) do
      build(:approval_policy,
        approval_settings: approval_settings,
        bypass_settings: { access_tokens: [{ id: personal_access_token.id }] })
    end

    it { is_expected.to be(false) }

    context 'when access token is revoked' do
      before do
        personal_access_token.revoke!
      end

      it { is_expected.to be(true) }
    end

    context 'when access token is not in bypass_settings' do
      let_it_be(:other_token, freeze: false) { create(:personal_access_token) }

      let(:policy) do
        build(:approval_policy,
          approval_settings: approval_settings,
          bypass_settings: { access_tokens: [{ id: other_token.id }] })
      end

      it { is_expected.to be(true) }
    end
  end
end

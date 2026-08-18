# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::PushSettingsOverrides, '#all', feature_category: :security_policy_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:security_configuration) { create(:security_orchestration_policy_configuration) }

  let(:warn_mode_policies) { [] }
  let(:enforced_policies) { [] }
  let(:protected_branches) { [protected_branch_main, protected_branch_release] }

  let(:protected_branch_main) { build_stubbed(:protected_branch, project: project, name: 'main') }
  let(:protected_branch_release) { build_stubbed(:protected_branch, project: project, name: 'release/*') }

  subject(:overrides) do
    described_class
      .new(
        project: project,
        warn_mode_policies: warn_mode_policies
      )
      .all
      .map do |override|
        {
          attribute: override.attribute,
          policy: override.security_policy,
          branches: override.protected_branches.to_a
        }
      end
  end

  before do
    allow(project).to receive(:protected_branches).and_return(protected_branches)
    allow(protected_branch_main).to receive_messages(modification_blocked_by_policy?: true, allow_force_push: false)
    allow(protected_branch_release).to receive_messages(modification_blocked_by_policy?: true, allow_force_push: false)

    allow(ProtectedBranch).to receive(:matching) do |name, _|
      case name
      when 'main'        then [protected_branch_main]
      when 'release/*'   then [protected_branch_release]
      else []
      end
    end
  end

  def stub_policy_branches(mapping)
    allow_next_instance_of(Security::SecurityOrchestrationPolicies::PolicyBranchesService) do |svc|
      mapping.each do |policy, branches|
        approval_rules = policy.approval_policy_rules.pluck(:content).map(&:deep_symbolize_keys)

        allow(svc).to receive(:scan_result_branches).with(approval_rules).and_return(branches)
      end
    end
  end

  context 'without policies' do
    it { is_expected.to be_empty }
  end

  context 'with restrictive protected branch settings' do
    let(:policy_a) { security_policy(1, approval_settings: { block_branch_modification: true }) }
    let(:policy_b) { security_policy(2, approval_settings: { prevent_pushing_and_force_pushing: true }) }

    let(:warn_mode_policies) { [policy_a, policy_b] }

    before do
      stub_policy_branches(
        policy_a => ['main'],
        policy_b => ['release/*', 'release/v1']
      )
    end

    it { is_expected.to be_empty }
  end

  context 'with permissive protected branch settings' do
    let(:policy_a) { security_policy(1, branches: 'main', approval_settings: { block_branch_modification: true }) }
    let(:policy_b) do
      security_policy(2, branches: 'release/*', approval_settings: { prevent_pushing_and_force_pushing: true })
    end

    let(:warn_mode_policies) { [policy_a, policy_b] }

    before do
      allow(protected_branch_main).to receive(:modification_blocked_by_policy?).and_return(false)
      allow(protected_branch_release).to receive(:allow_force_push?).and_return(true)

      stub_policy_branches(
        policy_a => ['main'],
        policy_b => ['release/v1', 'release/*']
      )
    end

    it 'returns overrides' do
      expect(overrides).to match_array([
        { attribute: :block_branch_modification, policy: policy_a, branches: [protected_branch_main] },
        { attribute: :prevent_pushing_and_force_pushing, policy: policy_b, branches: [protected_branch_release] }
      ])
    end
  end

  context 'with overlapped restrictive policies' do
    let(:policy_a) { security_policy(1, approval_settings: { block_branch_modification: true }) }
    let(:policy_b) { security_policy(2, approval_settings: { block_branch_modification: true }) }

    let(:warn_mode_policies) { [policy_a, policy_b] }

    before do
      allow(protected_branch_main).to receive(:modification_blocked_by_policy?).and_return(false)

      stub_policy_branches(
        policy_a => ['main'],
        policy_b => ['main']
      )
    end

    it 'returns overrides for each policy separately' do
      expect(overrides).to match_array([
        { attribute: :block_branch_modification, policy: policy_a, branches: [protected_branch_main] },
        { attribute: :block_branch_modification, policy: policy_b, branches: [protected_branch_main] }
      ])
    end
  end

  context 'with mixed settings' do
    let(:policy_a) { security_policy(1, branches: 'main', approval_settings: { block_branch_modification: true }) }
    let(:policy_b) do
      security_policy(2, branches: 'release/*', approval_settings: { prevent_pushing_and_force_pushing: true })
    end

    let(:policy_c) do
      security_policy(3, branches: ['main', 'release/*'], approval_settings: {
        block_branch_modification: true,
        prevent_pushing_and_force_pushing: true
      })
    end

    let(:policy_d) do
      security_policy(4, branches: 'release/*', approval_settings: { block_branch_modification: true })
    end

    let(:warn_mode_policies) { [policy_a, policy_b, policy_c, policy_d] }

    before do
      allow(protected_branch_main).to receive_messages(modification_blocked_by_policy?: false, allow_force_push?: false)
      allow(protected_branch_release).to receive_messages(modification_blocked_by_policy?: true,
        allow_force_push?: true)

      stub_policy_branches(
        policy_a => ['main'],
        policy_b => ['release/*'],
        policy_c => ['main', 'release/v1', 'release/*'],
        policy_d => ['release/v1', 'release/*']
      )
    end

    it 'returns all overrides' do
      expect(overrides).to match_array([
        { attribute: :block_branch_modification, policy: policy_a, branches: [protected_branch_main] },
        { attribute: :prevent_pushing_and_force_pushing, policy: policy_b, branches: [protected_branch_release] },
        { attribute: :block_branch_modification, policy: policy_c, branches: [protected_branch_main] },
        { attribute: :prevent_pushing_and_force_pushing, policy: policy_c, branches: [protected_branch_release] }
      ])
    end
  end

  context 'with enforced policies' do
    let(:warn_policy)     { security_policy(1, approval_settings: { block_branch_modification: true }) }
    let(:enforced_policy) { security_policy(2, approval_settings: { block_branch_modification: true }, traits: []) }

    let(:warn_mode_policies) { [warn_policy] }
    let(:enforced_policies)  { [enforced_policy] }

    before do
      allow(protected_branch_main).to receive(:modification_blocked_by_policy?).and_return(false)

      stub_policy_branches(
        warn_policy => ['main']
      )
    end

    it 'returns override only for warn policy' do
      expect(overrides).to match_array([
        { attribute: :block_branch_modification, policy: warn_policy, branches: [protected_branch_main] }
      ])
    end
  end

  private

  def security_policy(policy_index, approval_settings:, branches: ['main'], traits: [:enforcement_type_warn])
    create(:security_policy, *traits,
      security_orchestration_policy_configuration: security_configuration,
      policy_index: policy_index,
      content: { approval_settings: approval_settings }).tap do |policy|
        build(:approval_policy_rule, :scan_finding, security_policy: policy).then do |rule|
          rule.content[:branches] = Array(branches)
          rule.save!
        end
      end
  end
end

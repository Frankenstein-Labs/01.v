# frozen_string_literal: true

require "spec_helper"

RSpec.describe Security::SecurityOrchestrationPolicies::ProtectedBranchesPushService, feature_category: :security_policy_management do
  let_it_be_with_refind(:project) { create(:project, :small_repo) }
  let_it_be(:policy_project) { create(:project, :small_repo) }
  let_it_be(:protected_branch) { create(:protected_branch, project: project) }
  let_it_be(:branch_name) { protected_branch.name }
  let_it_be_with_refind(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: protected_branch.project,
      security_policy_management_project: policy_project)
  end

  subject(:result) { described_class.new(project: project).execute }

  before_all do
    project.repository.add_branch(project.creator, protected_branch.name, "HEAD")
  end

  context 'without blocking scan result policy' do
    it { is_expected.to be_empty }
  end

  context 'with blocking scan result policy' do
    include_context 'with approval security policy preventing force pushing'

    it 'includes the protected branch' do
      expect(result).to include(branch_name)
    end

    context 'with deleted approval_policy_rule' do
      let!(:deleted_rule) do
        create(:approval_policy_rule,
          security_policy: approval_policy_preventing_force_pushing,
          rule_index: -1,
          content: {
            type: 'scan_finding',
            branches: [branch_name],
            scanners: %w[sast],
            vulnerabilities_allowed: 0,
            severity_levels: %w[high],
            vulnerability_states: %w[detected]
          })
      end

      it 'excludes deleted rules from the result' do
        expect(result).to include(branch_name)
      end

      it 'does not cause N+1 queries when multiple policies exist' do
        control = ActiveRecord::QueryRecorder.new { described_class.new(project: project).execute }

        second_policy = create(:security_policy, :prevent_pushing_and_force_pushing,
          security_orchestration_policy_configuration: policy_configuration,
          policy_index: 2)
        create(:approval_policy_rule,
          security_policy: second_policy,
          content: {
            type: 'scan_finding',
            branches: [branch_name],
            scanners: %w[container_scanning],
            vulnerabilities_allowed: 0,
            severity_levels: %w[critical],
            vulnerability_states: %w[detected]
          })
        create(:security_policy_project_link, project: project, security_policy: second_policy)

        expect { described_class.new(project: project).execute }.not_to exceed_query_limit(control)
      end
    end

    context 'with branch is not protected' do
      before do
        approval_policy_rule_preventing_force_pushing.update!(
          content: approval_policy_rule_preventing_force_pushing.content.merge('branches' => [branch_name.reverse])
        )
      end

      it { is_expected.to be_empty }
    end

    context 'when policy is not preventing force pushing' do
      before do
        approval_policy_preventing_force_pushing.update!(
          content: { 'approval_settings' => { 'prevent_pushing_and_force_pushing' => false } }
        )
      end

      it { is_expected.to be_empty }
    end

    context 'with warn mode' do
      before do
        approval_policy_preventing_force_pushing.update!(
          content: approval_policy_preventing_force_pushing.content.merge(
            'enforcement_type' => Security::Policy::ENFORCEMENT_TYPE_WARN
          )
        )
      end

      it { is_expected.to be_empty }
    end

    context 'with ignore_warn_mode' do
      let_it_be(:warn_mode_policy) do
        create(:security_policy, :prevent_pushing_and_force_pushing,
          security_orchestration_policy_configuration: policy_configuration,
          policy_index: 1,
          content: {
            'approval_settings' => { 'prevent_pushing_and_force_pushing' => true },
            'enforcement_type' => Security::Policy::ENFORCEMENT_TYPE_WARN
          })
      end

      let_it_be(:warn_mode_policy_rule) do
        create(:approval_policy_rule,
          security_policy: warn_mode_policy,
          content: {
            'type' => 'scan_finding',
            'branches' => [branch_name],
            'scanners' => %w[container_scanning],
            'vulnerabilities_allowed' => 0,
            'severity_levels' => %w[critical],
            'vulnerability_states' => %w[detected]
          })
      end

      before do
        create(:security_policy_project_link, project: project, security_policy: warn_mode_policy)

        approval_policy_preventing_force_pushing.destroy!
      end

      context 'when ignore_warn_mode is false' do
        subject(:result) { described_class.new(project: project, ignore_warn_mode: false).execute }

        it 'excludes the protected branch (warn mode policy is filtered)' do
          expect(result).not_to include(branch_name)
        end
      end

      context 'when ignore_warn_mode is true' do
        subject(:result) { described_class.new(project: project, ignore_warn_mode: true).execute }

        it 'includes the protected branch (warn mode policy is not filtered)' do
          expect(result).to include(branch_name)
        end
      end
    end
  end
end

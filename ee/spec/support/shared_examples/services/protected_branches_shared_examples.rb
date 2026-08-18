# frozen_string_literal: true

RSpec.shared_context 'with approval policy' do
  include RepoHelpers

  let(:policy_path) { Security::OrchestrationPolicyConfiguration::POLICY_PATH }
  let_it_be(:policy_project, freeze: false) { create(:project, :repository) }
  let(:default_branch) { policy_project.default_branch }

  let(:policy_yaml) do
    build(:orchestration_policy_yaml, scan_execution_policy: [], approval_policy: approval_policies)
  end

  let(:approval_policies) { [approval_policy] }

  before do
    policy_configuration.update_attribute(:security_policy_management_project, policy_project)

    if policy_project.repository.blob_at(default_branch, policy_path)
      policy_project.repository.delete_file(
        policy_project.creator, policy_path, message: 'delete policy', branch_name: default_branch
      )
    end

    create_file_in_repo(policy_project, default_branch, default_branch, policy_path, policy_yaml)

    stub_licensed_features(security_orchestration_policies: true)
  end
end

RSpec.shared_context 'with persisted approval policies' do
  before do
    next unless respond_to?(:approval_policies)
    next if policy_configuration.security_policies.type_approval_policy.count >= approval_policies.size

    linked_projects = policy_configuration.project ? [policy_configuration.project] : []

    approval_policies.each_with_index do |policy_hash, index|
      content = policy_hash.slice(:actions, :approval_settings, :bypass_settings, :enforcement_type,
        :fallback_behavior, :policy_tuning)
        .reject { |_, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }

      rules_data = policy_hash.fetch(:rules, []).map do |rule|
        { type: rule.fetch(:type, 'scan_finding').to_sym, content: rule }
      end

      create(:security_policy, :approval_policy,
        security_orchestration_policy_configuration: policy_configuration,
        name: policy_hash[:name],
        policy_index: index,
        content: content,
        approval_policy_rules_data: rules_data,
        linked_projects: linked_projects)
    end
  end
end

RSpec.shared_context 'with approval policy blocking protected branches' do
  include_context 'with approval policy' do
    let(:approval_policy) do
      build(:approval_policy, branches: [branch_name], approval_settings: { block_branch_modification: true })
    end
  end
end

RSpec.shared_context 'with approval policy blocking group-level protected branches' do
  include_context 'with approval policy' do
    let(:approval_policy) do
      build(:approval_policy, branches: [branch_name], approval_settings: { block_group_branch_modification: true })
    end
  end
end

RSpec.shared_context 'with approval policy preventing force pushing' do
  include_context 'with approval policy' do
    let(:prevent_pushing_and_force_pushing) { true }

    let(:approval_policy) do
      build(:approval_policy, branches: [branch_name],
        approval_settings: { prevent_pushing_and_force_pushing: prevent_pushing_and_force_pushing })
    end

    let(:policy_yaml) do
      build(:orchestration_policy_yaml, approval_policy: [approval_policy])
    end
  end

  after do
    policy_project.repository.delete_file(
      policy_project.creator,
      policy_path,
      message: 'Automatically deleted policy',
      branch_name: default_branch
    )
  end
end

RSpec.shared_context 'with approval security policy preventing force pushing' do
  let(:approval_policy_preventing_force_pushing_policy_index) { 0 }

  let!(:approval_policy_preventing_force_pushing) do
    create(:security_policy, :prevent_pushing_and_force_pushing,
      security_orchestration_policy_configuration: policy_configuration,
      policy_index: approval_policy_preventing_force_pushing_policy_index)
  end

  let!(:approval_policy_rule_preventing_force_pushing) do
    create(:approval_policy_rule,
      security_policy: approval_policy_preventing_force_pushing,
      content: {
        type: 'scan_finding',
        branches: [branch_name],
        scanners: %w[container_scanning],
        vulnerabilities_allowed: 0,
        severity_levels: %w[critical],
        vulnerability_states: %w[detected]
      })
  end

  before do
    if protected_branch.project_level?
      create(:security_policy_project_link, project: protected_branch.project,
        security_policy: approval_policy_preventing_force_pushing)
    end

    stub_licensed_features(security_orchestration_policies: true)
  end
end

RSpec.shared_context 'with approval security policy blocking protected branches' do
  let(:approval_policy_blocking_protected_branches_policy_index) { 0 }

  let!(:approval_policy_blocking_protected_branches) do
    create(:security_policy, :block_branch_modification,
      security_orchestration_policy_configuration: policy_configuration,
      policy_index: approval_policy_blocking_protected_branches_policy_index)
  end

  let!(:approval_policy_rule_blocking_protected_branches) do
    create(:approval_policy_rule,
      security_policy: approval_policy_blocking_protected_branches,
      content: {
        type: 'scan_finding',
        branches: [branch_name],
        scanners: %w[container_scanning],
        vulnerabilities_allowed: 0,
        severity_levels: %w[critical],
        vulnerability_states: %w[detected]
      })
  end

  before do
    if protected_branch.project_level?
      create(:security_policy_project_link, project: protected_branch.project,
        security_policy: approval_policy_blocking_protected_branches)
    end

    stub_licensed_features(security_orchestration_policies: true)
  end
end

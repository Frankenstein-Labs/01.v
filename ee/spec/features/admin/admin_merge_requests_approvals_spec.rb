# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin interacts with merge requests approvals settings', :js, feature_category: :source_code_management do
  include StubENV
  include Features::SecurityPolicyHelpers

  include_context 'with default organization security policy configuration'

  let_it_be(:user) { create(:admin) }
  let_it_be(:project) { create(:project, :repository, creator: user) }

  before do
    sign_in(user)
    enable_admin_mode!(user)

    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    allow(License).to receive(:feature_available?).and_return(true)

    visit(admin_push_rule_path)
  end

  it 'updates instance-level merge request approval settings and enforces project-level ones' do
    within_testid('merge-request-approval-settings') do
      check 'Prevent approval by merge request creator'
      check 'Prevent approvals by users who add commits'
      check 'Prevent editing approval rules in projects and merge requests'
      click_button('Save changes')
    end

    visit(admin_push_rule_path)

    expect(find_field('Prevent approval by merge request creator')).to be_checked
    expect(find_field('Prevent approvals by users who add commits')).to be_checked
    expect(find_field('Prevent editing approval rules in projects and merge requests')).to be_checked

    visit project_settings_merge_requests_path(project)

    within_testid('merge-request-approval-settings') do
      expect(find_field('Prevent approval by merge request creator', disabled: true)).to be_checked
      expect(find_field('Prevent approvals by users who add commits', disabled: true)).to be_checked
      expect(find_field('Prevent editing approval rules in merge requests', disabled: true)).to be_checked
    end
  end

  context 'when project has security policies', :sidekiq_inline, :use_clean_rails_memory_store_caching do
    let_it_be(:policy_management_project) { create(:project, :repository, namespace: project.namespace) }
    let_it_be(:policy_name) { 'Deny MIT licenses' }
    let_it_be(:approver) { create(:user) }
    let_it_be(:approver_roles) { ['maintainer'] }
    let_it_be(:license_states) { %w[newly_detected] }
    let_it_be(:policy_branch_names) { %w[master] }

    let(:policy_hash) do
      build(:approval_policy, name: policy_name,
        actions: [{ type: 'require_approval', approvals_required: 1, role_approvers: approver_roles }],
        rules: [{
          type: 'license_finding',
          branches: policy_branch_names,
          match_on_inclusion_license: true,
          license_types: ['MIT License'],
          license_states: license_states
        }])
    end

    let(:policy_yaml) do
      build(:orchestration_policy_yaml, scan_execution_policy: [], approval_policy: [policy_hash])
    end

    before_all do
      project.add_developer(user)
      project.add_maintainer(approver)
      policy_management_project.add_developer(user)
    end

    before do
      create_policy_setup
    end

    it 'shows the security approvals' do
      visit project_settings_merge_requests_path(project)
      expect(find_by_testid('security-policies-approvals')).to have_content(policy_name)
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::AllBranchesRule, feature_category: :source_code_management do
  let_it_be(:created_at) { Time.current.change(usec: 0) }
  let_it_be(:updated_at) { Time.current.change(usec: 0) }
  let_it_be_with_reload(:project) { create(:project, :small_repo) }

  let_it_be(:approval_rule) do
    create(:approval_project_rule, project: project, created_at: created_at + 1.day, updated_at: updated_at - 1.day)
  end

  let_it_be(:status_check) do
    create(:external_status_check, project: project, created_at: created_at, updated_at: updated_at)
  end

  subject(:all_branches_rule) { described_class.new(project) }

  describe '#created_at' do
    it 'returns timestamp when the first status check or approval rule was created' do
      expect(all_branches_rule.created_at).to eq(created_at)
    end
  end

  describe '#updated_at' do
    it 'returns timestamp when the most recent status check or approval rule was updated' do
      expect(all_branches_rule.updated_at).to eq(updated_at)
    end
  end

  describe '#approval_project_rules' do
    let_it_be(:protected_branch, freeze: false) do
      rule = create(:approval_project_rule, project: project)
      create(:protected_branch, project: project, approval_project_rules: [rule])
    end

    it 'returns only rules that do not belong to a protected branch' do
      expect(all_branches_rule.approval_project_rules).to eq([approval_rule])
    end
  end

  describe '#external_status_checks' do
    let_it_be(:protected_branch, freeze: false) do
      check = create(:external_status_check, project: project)
      create(:protected_branch, project: project, external_status_checks: [check])
    end

    it 'returns only rules that do not belong to a protected branch' do
      expect(all_branches_rule.external_status_checks).to eq([status_check])
    end
  end

  describe '#merge_request_approval_settings' do
    it 'returns a merge request approval setting' do
      setting = all_branches_rule.merge_request_approval_settings
      expect(setting).to be_instance_of(Projects::AllBranchesRules::MergeRequestApprovalSetting)
      expect(setting.project).to eq(project)
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(branch_rules_merge_request_approval_settings: false)
      end

      it 'returns nil' do
        expect(all_branches_rule.merge_request_approval_settings).to be_nil
      end
    end
  end
end

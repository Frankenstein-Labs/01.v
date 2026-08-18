# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ApprovalRulesProject, type: :model, feature_category: :code_review_workflow do
  describe 'associations' do
    it { is_expected.to belong_to(:approval_rule) }
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    context 'when adding the same project to an approval rule' do
      let_it_be(:project) { create(:project) }
      let(:approval_rule) { create(:merge_requests_approval_rule, project_id: project.id) }

      before do
        create(:merge_requests_approval_rules_project, approval_rule: approval_rule, project: project)
      end

      it 'is not valid' do
        duplicate_approval_rules_project = build(:merge_requests_approval_rules_project, approval_rule: approval_rule,
          project_id: project.id)
        expect(duplicate_approval_rules_project).not_to be_valid
        expect(duplicate_approval_rules_project.errors[:project_id]).to include('has already been taken')
      end
    end
  end
end

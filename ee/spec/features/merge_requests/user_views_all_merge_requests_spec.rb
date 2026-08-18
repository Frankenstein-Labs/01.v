# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User views all merge requests', :js, feature_category: :code_review_workflow do
  let!(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let(:project) { create(:project, :public, approvals_before_merge: 1) }
  let(:user) { create(:user) }
  let(:another_user) { create(:user) }

  before do
    project.add_developer(user)
  end

  describe 'more approvals are required' do
    let!(:approval_rule) { create(:approval_merge_request_rule, merge_request: merge_request, users: [user, another_user], approvals_required: 2, name: "test rule") }

    it 'shows generic approvals tooltip' do
      visit(project_merge_requests_path(project, state: :all))
      expect(page.all('[data-testid="mr-approvals"]').any? { |item| item["aria-label"] == "Required approvals (0 of 2 given)" }).to be true
    end

    it 'shows custom tooltip after a different user has approved' do
      merge_request.approvals.create!(user: another_user)
      visit(project_merge_requests_path(project, state: :all))
      expect(page.all('[data-testid="mr-approvals"]').any? { |item| item["aria-label"] == "Required approvals (1 of 2 given)" }).to be true
    end

    it 'shows custom tooltip after self has approved' do
      merge_request.approvals.create!(user: user)
      sign_in(user)
      visit(project_merge_requests_path(project, state: :all))
      expect(page.all('[data-testid="mr-approvals"]').any? { |item| item["aria-label"] == "Required approvals (1 of 2 given, you've approved)" }).to be true
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Merge request > User edits MR with approval rules', :js, feature_category: :code_review_workflow do
  let_it_be_with_reload(:project) { create(:project, :public, :repository) }
  let_it_be(:merge_request) { create(:merge_request, :merged, source_project: project) }
  let(:approval_rules_selector) { '[data-testid="mr-approval-rules"]' }

  before do
    project.update!(disable_overriding_approvers_per_merge_request: false)
    stub_licensed_features(multiple_approval_rules: true)

    sign_in(project.owner)
    visit(edit_project_merge_request_path(project, merge_request))

    wait_for_requests
  end

  it "does not allow user to edit rules" do
    click_button 'Approval rules'

    page.within(find_by_testid('mr-approval-rules')) do
      expect(page).to have_selector('input[disabled]')
      expect(page).not_to have_button('Add approval rule')
    end
  end

  it 'passes axe automated accessibility testing', :js do
    click_button 'Approval rules'

    wait_for_requests

    expect(page).to be_axe_clean.within(approval_rules_selector).skipping :'heading-order'
  end
end

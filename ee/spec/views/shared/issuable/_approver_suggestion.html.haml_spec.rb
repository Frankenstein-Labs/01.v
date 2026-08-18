# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/issuable/_approver_suggestion.html.haml' do
  let_it_be(:merge_request) { create(:merge_request) }
  let_it_be(:user) { merge_request.author }
  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:presenter, freeze: false) { merge_request.present(current_user: user) }

  let(:approvals_available) { true }

  before do
    allow(view).to receive(:can?).with(user, :update_approvers, merge_request).and_return(true)
    allow(view).to receive(:current_user).and_return(user)
    allow(presenter).to receive(:approval_feature_available?).and_return(approvals_available)

    assign(:target_project, merge_request.target_project)
  end

  def do_render
    render 'shared/issuable/approver_suggestion', issuable: merge_request, presenter: presenter
  end

  context 'when the approval feature is enabled' do
    let(:approvals_available) { true }

    before do
      assign(:mr_presenter, presenter)

      # used inside the projects/merge_requests/_code_owner_approval_rules partial
      assign(:project, merge_request.target_project)
    end

    it 'renders the MR approvals promo' do
      do_render

      expect(rendered).to have_css('#js-mr-approvals-input')
      expect(view).to render_template('projects/merge_requests/_code_owner_approval_rules')
    end
  end

  context 'when the approval feature is not enabled' do
    let(:approvals_available) { false }

    before do
      stub_saas_features(gitlab_com_subscriptions: gitlab_com_subscriptions_enabled)
    end

    context 'when the gitlab_com_subscriptions saas feature is not available' do
      let(:gitlab_com_subscriptions_enabled) { false }

      it 'renders nothing' do
        do_render

        expect(rendered).to be_blank
      end
    end
  end
end

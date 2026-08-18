# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Issue actions', :js, :saas, feature_category: :team_planning do
  let(:group) { create(:group_with_plan, plan: :premium_plan) }
  let(:project) { create(:project, group: group) }
  let(:issue) { create(:issue, project: project) }
  let(:user) { create(:user) }

  include_context 'with duo features enabled and agentic chat available for group on SaaS'

  before do
    stub_licensed_features(epics: true, agentic_chat: true, summarize_comments: true)
    sign_in(user)
  end

  describe 'promote issue to epic action' do
    context 'when user is unauthorized' do
      before do
        group.add_guest(user)
        visit project_work_item_path(project, issue)
      end

      it 'does not show "Promote to epic" item in issue actions dropdown' do
        click_button 'More actions', match: :first

        expect(page).not_to have_button 'Change type'
      end
    end

    context 'when user is authorized' do
      before do
        group.add_owner(user)

        add_on_purchase = create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group)
        create(:gitlab_subscription_user_add_on_assignment, user: user, add_on_purchase: add_on_purchase)

        # TODO: restore threshold after epic-work item sync
        # issue: https://gitlab.com/gitlab-org/gitlab/-/issues/438295
        allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(125)
      end

      it_behaves_like 'user can use summarize button in issue' do
        subject { project_work_item_path(project, issue) }
      end

      it 'clicking "Promote to epic" creates and redirects user to epic' do
        visit project_work_item_path(project, issue)

        click_button 'More actions', match: :first
        click_button 'Change type'
        select 'Epic (Promote to group)', from: 'Type'
        click_button 'Change type'

        expect(page).to have_current_path(group_work_item_path(group, 1))
      end
    end
  end
end

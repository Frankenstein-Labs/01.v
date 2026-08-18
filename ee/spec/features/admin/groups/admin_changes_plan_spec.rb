# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Changes GL.com plan for group', :js, :saas, feature_category: :plan_provisioning do
  include WaitForRequests

  let!(:premium_plan) { create(:premium_plan) }
  let(:admin) { create(:admin) }

  before do
    allow(Gitlab::CurrentSettings).to receive(:should_check_namespace_plan?).and_return(true)

    sign_in(admin)
    enable_admin_mode!(admin)
  end

  describe 'for group namespace' do
    let(:group) { create(:group) }

    before do
      visit admin_group_path(group)
      click_link 'Edit'
    end

    it 'changes the plan', quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/17069' do
      find('#group_gitlab_subscription_attributes_hosted_plan_id').find(:xpath, 'option[2]').select_option

      click_button('Save changes')

      expect(page).to have_content('Plan: Premium')
    end
  end

  describe 'for user namespace' do
    let(:user) { create(:user) }

    before do
      visit admin_user_path(user)
      click_link 'Edit'
    end

    it 'changes the plan' do
      find('#user_namespace_attributes_gitlab_subscription_attributes_hosted_plan_id').find(:xpath, 'option[2]').select_option

      click_button('Save changes')

      expect(page).to have_content('Plan: Premium')
    end
  end
end

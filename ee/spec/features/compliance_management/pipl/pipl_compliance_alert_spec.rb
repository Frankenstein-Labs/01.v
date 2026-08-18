# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'user is pipl compliant alert', :saas, :js, feature_category: :compliance_management do
  include SubscriptionPortalHelpers

  let_it_be(:pipl_user) { create(:pipl_user, initial_email_sent_at: 20.days.ago) }
  let_it_be(:user) { pipl_user.user }
  let_it_be(:project) { create(:project) }

  before_all do
    project.add_maintainer(user)
  end

  before do
    stub_ee_application_setting(enforce_pipl_compliance: true)
    allow(ComplianceManagement::Pipl).to receive(:user_subject_to_pipl?).and_return(true)
  end

  shared_examples 'a hidden alert' do
    it 'does not appear on the project page' do
      visit project_path(project)

      expect_alert_to_be_hidden
    end
  end

  context 'when the user is not authenticated' do
    it_behaves_like 'a hidden alert'
  end

  context 'when the user is not eligible for the alert' do
    before do
      stub_ee_application_setting(enforce_pipl_compliance: true)
      allow(ComplianceManagement::Pipl).to receive(:user_subject_to_pipl?).and_return(false)
    end

    it_behaves_like 'a hidden alert'
  end

  context 'when enforce_pipl_compliance setting is disabled' do
    before do
      stub_ee_application_setting(enforce_pipl_compliance: false)
    end

    it_behaves_like 'a hidden alert'
  end

  context 'when the user is eligible for the alert' do
    before do
      sign_in(user)
    end

    it 'shows the dismissible alert on the project page' do
      visit project_path(project)

      expect(page).to have_content("located in Mainland China, Macao, and Hong Kong")
      expect(page)
        .to have_content(
          "You have 40 days to complete the transition"
        )

      find_by_testid('pipl-compliance-alert-dismiss').click

      expect_alert_to_be_hidden

      # reload the page to ensure it stays dismissed
      visit project_path(project)

      expect_alert_to_be_hidden
    end
  end

  def expect_alert_to_be_hidden
    expect(page).not_to have_content("located in Mainland China, Macao, and Hong Kong")
  end
end

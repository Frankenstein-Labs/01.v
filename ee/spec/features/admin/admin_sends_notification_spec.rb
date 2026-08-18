# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Admin sends notification", :js, :sidekiq_might_not_need_inline, feature_category: :notifications do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:user2) { create(:user) }

  let(:notification_text) { 'Your project has been moved.' }

  before do
    group.add_developer(user)
    group.add_developer(user2)

    sign_in(admin)
    enable_admin_mode!(admin)

    visit(admin_email_path)

    ActionMailer::Base.deliveries.clear
  end

  it "sends notification" do
    perform_enqueued_jobs do
      fill_in(:subject, with: "My Subject")
      fill_in(:body, with: notification_text)

      click_button(_('Select group or project'))

      within_testid('base-dropdown-menu') do
        expect(page).to have_content(_('All groups and projects'))
        expect(page).to have_content(group.name)
        expect(page).to have_content(project.name)

        page.find('li[role="option"]', text: group.name).click
      end

      click_button("Send message")

      expect(page).to have_content('Email sent')
    end

    emails = ActionMailer::Base.deliveries
    emails_to = emails.flat_map(&:to)
    user_emails = group.group_members.non_invite.preload_users.map { |member| member.user.email }

    expect(emails_to).to match_array(user_emails)
    expect(emails.last.text_part.body.decoded).to include(notification_text)
  end
end

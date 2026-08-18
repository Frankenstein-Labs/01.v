# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Admin unsubscribes from notification", feature_category: :user_profile do
  let_it_be(:user) { create(:user) }
  let_it_be(:urlsafe_email) { Base64.urlsafe_encode64(user.email) }

  let(:notification_text) { 'You have been unsubscribed from receiving GitLab administrator notifications.' }

  before do
    sign_in(user)

    visit(unsubscribe_path(urlsafe_email))
  end

  it "unsubscribes from notifications" do
    perform_enqueued_jobs do
      click_button("Unsubscribe")

      expect(page).to have_current_path(root_path, ignore_query: true)
    end

    last_email = ActionMailer::Base.deliveries.last
    expect(last_email.text_part.body.decoded).to include(notification_text)
  end
end

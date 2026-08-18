# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial Sign In', :with_trial_types, feature_category: :subscription_management do
  let(:user) { create(:user) }

  describe 'on GitLab.com', :saas do
    it 'logs the user in', :js do
      url_params = { glm_source: 'any-source', glm_content: 'any-content' }
      visit(new_trial_registration_path(url_params))

      click_on 'Sign in'

      within_testid('sign-in-form') do
        fill_in 'user_login', with: user.email
        fill_in 'user_password', with: user.password

        click_button 'Sign in'
      end

      expect(page).to have_current_path(new_trial_path(url_params))
    end
  end

  describe 'not on GitLab.com' do
    it 'returns 404' do
      visit(new_trial_registration_path)

      expect(status_code).to eq(404)
    end
  end
end

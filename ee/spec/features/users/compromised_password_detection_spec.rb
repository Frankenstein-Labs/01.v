# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Compromised Password Detection', :js, feature_category: :system_access do
  let(:current_password) { User.random_password }
  let(:new_password) { User.random_password }
  let(:user) { create(:user, :with_namespace, password: current_password) }

  before do
    stub_saas_features(notify_compromised_passwords: true)
  end

  shared_examples 'shows compromised password alert' do
    it 'shows compromised password alert until password is changed' do
      gitlab_sign_in(user)

      expect(page).to have_content('Security Alert: Change your GitLab password')
      expect(page).to have_content(
        'Your GitLab.com account password may be compromised due to a data breach on another service or platform. ' \
          'Please change your password immediately.')
      expect(page).to have_link('Change GitLab Password')

      click_link('Change GitLab Password')

      expect(page).to have_current_path edit_user_settings_password_path

      page.within '.update-password' do
        fill_in 'user_password', with: current_password
        fill_in 'New password', with: new_password
        fill_in 'Password confirmation', with: new_password
        click_button 'Save password'
      end

      visit dashboard_projects_path

      expect(page).not_to have_content('Security Alert: Change your GitLab password')
      expect(page).not_to have_content('Your GitLab.com account password may be compromised')
      expect(page).not_to have_button(_('Change GitLab Password'))
    end
  end

  shared_examples 'does not show compromised password alert' do
    it 'does not show compromised password alert' do
      gitlab_sign_in(user)

      expect(page).not_to have_content('Security Alert: Change Your GitLab Password')
      expect(page).not_to have_content('Your GitLab.com account password may be compromised')
      expect(page).not_to have_link(_('Change GitLab Password'))
    end
  end

  context 'when user signs in without detected compromised password' do
    it_behaves_like 'does not show compromised password alert'

    context 'when user has CompromisedPasswordDetection' do
      before do
        create(:compromised_password_detection, user: user, resolved_at: resolved_at)
      end

      context 'when CompromisedPasswordDetection is unresolved' do
        let(:resolved_at) { nil }

        it_behaves_like 'shows compromised password alert'
      end

      context 'when CompromisedPasswordDetection is resolved' do
        let(:resolved_at) { 1.month.ago }

        it_behaves_like 'does not show compromised password alert'
      end
    end
  end

  context 'when user signs in with detected compromised password' do
    before do
      allow(Gitlab::Auth::CloudflareExposedCredentialChecker)
        .to receive(:new)
        .and_return(
          instance_double(
            Gitlab::Auth::CloudflareExposedCredentialChecker,
            result: :exact_password,
            exact_password?: true
          )
        )
    end

    it_behaves_like 'shows compromised password alert'
  end
end

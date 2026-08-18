# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Profile > Account', feature_category: :user_profile do
  let(:user) { create(:user, :with_namespace) }

  before do
    sign_in(user)
  end

  describe 'Delete account' do
    context "on GitLab.com when the user's password is automatically set" do
      before do
        allow(::Gitlab).to receive(:com?).and_return(true)
        user.update!(password_automatically_set: true)
        visit profile_account_path
      end

      it 'shows that the identity cannot be verified' do
        expect(page).to have_content 'GitLab is unable to verify your identity automatically.'
      end

      it 'does not display a delete button' do
        expect(page).not_to have_button 'Delete account'
      end
    end
  end
end

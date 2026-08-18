# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'user_settings/profiles/show', feature_category: :user_profile do
  let_it_be(:user_status) { build_stubbed(:user_status, clear_status_at: 8.hours.from_now) }
  let_it_be(:user) { user_status.user }
  let(:can_update_private_profile) { true }

  before do
    assign(:user, user)
    allow(controller).to receive(:current_user).and_return(user)
    allow(view).to receive(:experiment_enabled?)
    stub_feature_flags(edit_user_profile_vue: false)
    allow(view).to receive(:can?).with(user, :make_profile_private, user).and_return(can_update_private_profile)
  end

  context 'when the profile page is opened' do
    describe 'private profile', feature_category: :user_management do
      context 'when current_user.can?(:update_private_profile) is true' do
        it 'renders CE partial' do
          render

          expect(rendered).to render_template('user_settings/profiles/_private_profile')
          expect(rendered).to have_link 'What information is hidden?',
            href: help_page_path('user/profile/_index.md', anchor: 'make-your-user-profile-page-private')
          expect(rendered).not_to have_selector('.js-vue-popover')
          expect(rendered).not_to have_selector("input[type=checkbox][id='user_private_profile'][disabled]")
        end
      end

      context 'when current_user.can?(:update_private_profile) is false' do
        let(:can_update_private_profile) { false }

        it 'renders with disabled checkbox' do
          render

          expect(rendered).to render_template('user_settings/profiles/_private_profile')
          expect(rendered).not_to have_link 'What information is hidden?',
            href: help_page_path('user/profile/_index.md', anchor: 'make-your-user-profile-page-private')
          expect(rendered).to have_selector('.js-vue-popover')
          expect(rendered).to have_selector("input[type=checkbox][id='user_private_profile'][disabled]")
        end
      end
    end
  end
end

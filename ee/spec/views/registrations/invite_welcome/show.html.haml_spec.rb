# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'registrations/invite_welcome/show', feature_category: :onboarding do
  before do
    allow(view).to receive(:current_user).and_return(build_stubbed(:user))

    render
  end

  subject { rendered }

  context 'with basic form items' do
    it 'has correct form action' do
      is_expected.to have_css('form[action="/users/sign_up/welcome"]')
    end

    it { is_expected.to have_tracking(action: 'render', label: 'invite_registration') }

    it 'shows the text for the submit button' do
      is_expected.to have_button(_('Get started!'))
    end

    it 'renders a select and text field for additional information' do
      is_expected.to have_selector('select[name="user[onboarding_status_registration_objective]"]')
      is_expected.to have_selector('.js-jobs-to-be-done-other-group.hidden')
      is_expected.to have_selector('input[name="jobs_to_be_done_other"]')
    end

    it 'renders role dropdown with translated options' do
      expect(rendered).to have_selector('select[name="user[onboarding_status_role]"]')
      expect(rendered).to have_selector('option', text: 'Software Developer')
      expect(rendered).to have_selector('option', text: 'Development Team Lead')
      expect(rendered).to have_selector('option', text: 'Other')
    end
  end
end

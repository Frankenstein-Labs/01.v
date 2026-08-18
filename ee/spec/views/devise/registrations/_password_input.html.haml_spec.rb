# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'devise/registrations/_password_input', feature_category: :system_access do
  let(:minimum_password_length) { 8 }
  let(:password_length_hint) { "Minimum length is #{minimum_password_length} characters." }

  before do
    allow(view).to receive_messages(
      form: instance_double(Gitlab::FormBuilders::GitlabUiFormBuilder, label: '_label_'),
      form_resource_name: 'new_user',
      preregistration_tracking_label: ''
    )

    stub_licensed_features(password_complexity: false)
    assign(:minimum_password_length, minimum_password_length)
  end

  it 'renders the password length hint' do
    render

    expect(rendered).to have_content(password_length_hint)
  end

  describe 'when displaying password requirements' do
    before do
      stub_licensed_features(password_complexity: true)
    end

    it 'does not render the password length hint' do
      render

      expect(rendered).not_to have_content(password_length_hint)
    end

    it 'marks the password field as required' do
      render

      expect(rendered).to have_css('[data-testid="new-user-password-field"][data-required="true"]')
    end
  end
end

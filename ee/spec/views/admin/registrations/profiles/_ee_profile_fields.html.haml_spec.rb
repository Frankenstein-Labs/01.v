# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/registrations/profiles/_ee_profile_fields', feature_category: :onboarding do
  let_it_be(:user) { build_stubbed(:user) }
  let(:udf) do
    Gitlab::FormBuilders::GitlabUiFormBuilder.new(
      'user[user_detail_attributes]', user.user_detail, view, {}
    )
  end

  before do
    render partial: 'admin/registrations/profiles/ee_profile_fields', locals: { udf: udf }
  end

  it 'renders the country select with World helper countries' do
    expect(rendered).to have_css('select[data-testid="country"]')
    expect(rendered).to have_css('option', text: 'United States of America')
    expect(rendered).not_to have_css('option', text: 'Cuba')
  end

  it 'renders the country select as required' do
    expect(rendered).to have_css('select[data-testid="country"][required]')
  end

  it 'renders the opt-in checkbox with legal-approved label' do
    expect(rendered).to have_css(
      'label',
      text: 'I agree that GitLab can contact me by email about its product, services, or events.'
    )
  end

  it 'renders the opt-in checkbox unchecked when no value is set' do
    expect(rendered).to have_unchecked_field(
      'I agree that GitLab can contact me by email about its product, services, or events.'
    )
  end

  it 'tracks the uncheck event on the email opt-in checkbox' do
    expect(rendered).to trigger_internal_events('uncheck_email_optin_setup_profile').on_click
  end
end

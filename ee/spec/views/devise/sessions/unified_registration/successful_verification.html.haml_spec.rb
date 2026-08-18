# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'devise/sessions/unified_registration/successful_verification.html.haml',
  feature_category: :onboarding do
  let(:redirect_url) { '/some/path' }

  before do
    assign(:redirect_url, redirect_url)
  end

  it 'renders a meta refresh tag with the redirect url' do
    render

    expect(view.content_for(:meta_tags))
      .to have_css("meta[http-equiv='refresh'][content='3; url=#{redirect_url}']", visible: :hidden)
  end

  it 'renders the illustration' do
    render

    expect(rendered).to have_css("img[data-src*='secure-sm']")
  end

  it 'renders the verification successful heading' do
    render

    expect(rendered).to have_css('h1', text: 'Verification successful')
  end

  it 'renders the redirect copy with a link to the redirect url' do
    render

    expect(rendered).to have_content("You'll be redirected in just a moment.")
    expect(rendered).to have_link('', href: redirect_url)
  end

  it 'does not override the marketing-panel image and heading (uses default)' do
    render

    expect(view.content_for(:registration_marketing_panel_image)).to be_blank
    expect(view.content_for(:registration_marketing_panel_heading)).to be_blank
  end

  it 'forwards the :data local to the root container' do
    render locals: { data: { track_action: 'render', track_label: 'some_label' } }

    expect(rendered).to have_css(
      "[data-testid='successful-verification-root'][data-track-action='render'][data-track-label='some_label']"
    )
  end

  it 'defaults to no tracking attributes when :data local is not provided' do
    render

    expect(rendered).to have_css("[data-testid='successful-verification-root']")
    expect(rendered).not_to have_css('[data-track-action]')
  end
end

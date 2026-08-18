# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'registrations/customers_portal_redirect/show', feature_category: :onboarding do
  let(:customers_portal_url) { 'https://customers.example.com/some/path' }

  before do
    assign(:customers_portal_url, customers_portal_url)
  end

  it 'suppresses the bare-logo navbar' do
    render

    expect(view.content_for(:hide_empty_navbar)).to be_truthy
  end

  it 'renders the in-page header with the GitLab logo and Customers Portal label' do
    render

    expect(rendered).to have_css('header svg')
    expect(rendered).to have_css('[data-testid="customers-portal-label"]', text: 'Customers Portal')
  end

  it 'renders the heading and body copy' do
    render

    expect(rendered).to have_css('[data-testid="complete-purchase-heading"]', text: 'Complete your purchase')
    expect(rendered).to have_content(
      "You'll use your GitLab.com account to access Customers Portal"
    )
  end

  it 'renders the continue button linking to the Customers Portal URL' do
    render

    expect(rendered).to have_link('Continue to Customers Portal', href: customers_portal_url)
  end
end

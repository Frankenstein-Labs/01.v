# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/gitlab_credits_dashboard/index.html.haml', feature_category: :consumables_cost_management do
  before do
    render
  end

  it 'renders the dashboard root element with CTA paths' do
    expect(rendered).to have_selector(
      "#js-instance-usage-billing-dashboard" \
        "[data-upgrade-button-path='#{promo_pricing_url(query: { deployment: 'self-managed-deployment' })}']" \
        "[data-purchase-credits-path='#{subscription_portal_self_managed_purchase_credits_url}']"
    )
  end
end

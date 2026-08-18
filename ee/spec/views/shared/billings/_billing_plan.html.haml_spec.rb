# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/billings/_billing_plan.html.haml', :saas do
  include SubscriptionPortalHelpers

  let(:plan) { Hashie::Mash.new(billing_plans_data.find { |plan_data| plan_data[:code] == 'free' }) }
  let(:namespace) { build(:namespace) }

  before do
    allow(view).to receive(:is_current)
    allow(view).to receive_messages(plan: plan, namespace: namespace)
  end

  shared_examples 'contains the default page features' do
    it 'contains the feature link' do
      comparison_url = ::Gitlab::Routing.url_helpers.promo_pricing_url(path: '/gitlab-com/feature-comparison')

      expect(rendered).to have_link "See all #{plan.name} features", href: comparison_url
    end

    it 'contains tracking' do
      expect(rendered).to have_tracking(action: 'click_link', label: 'plan_features', property: plan.code)
    end
  end

  context 'when read_only is false' do
    before do
      allow(view).to receive(:read_only).and_return(false)

      render
    end

    it_behaves_like 'contains the default page features'

    it 'contains the footer' do
      expect(rendered).to have_css('.card-footer')
    end
  end

  context 'when read_only is true' do
    before do
      allow(view).to receive(:read_only).and_return(true)

      render
    end

    it_behaves_like 'contains the default page features'
    it 'does not contain the footer' do
      expect(rendered).not_to have_css('.card-footer')
    end
  end
end

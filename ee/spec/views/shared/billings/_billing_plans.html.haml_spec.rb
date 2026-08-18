# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/billings/_billing_plans.html.haml', feature_category: :subscription_management do
  let(:namespace) { build(:namespace) }
  let(:subscription) { instance_double(GitlabSubscription, has_a_paid_hosted_plan?: true) }

  before do
    allow(view).to receive(:show_plans?).and_return(true)
    allow(view).to receive(:billing_available_plans).and_return({})
    allow(view).to receive(:plans_data)
    allow(view).to receive(:namespace).and_return(namespace)
    allow(view).to receive(:current_plan)
    allow(namespace).to receive(:gitlab_subscription).and_return(subscription)
  end

  it 'tracks the paid render event on the downgrade-link section' do
    render

    expect(rendered).to have_tracking(action: 'render', label: 'paid')
  end

  context 'when the namespace has no paid hosted plan' do
    let(:subscription) { instance_double(GitlabSubscription, has_a_paid_hosted_plan?: false) }

    it 'does not emit the paid render tracking event' do
      render

      expect(rendered).not_to have_tracking(action: 'render', label: 'paid')
    end
  end
end

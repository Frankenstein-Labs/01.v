# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/billings/_billing_plan_actions.html.haml' do
  include SubscriptionPortalHelpers

  let(:plan) { Hashie::Mash.new(billing_plans_data.find { |plan_data| plan_data[:code] == 'free' }) }

  before do
    allow(view).to receive(:show_contact_sales_button?).and_return(true)
    allow(view).to receive(:plan).and_return(plan)
    allow(view).to receive(:purchase_link).and_return(plan.purchase_link)
    allow(view).to receive(:show_upgrade_button)
    allow(view).to receive(:namespace)
    allow(view).to receive(:read_only)
  end

  it 'contains the hand raise lead selector' do
    render

    expect(rendered).to have_selector('.js-hand-raise-lead-trigger')
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/billings/_top_level_billing_plan_header.html.haml', feature_category: :subscription_management do
  it 'offers to learn more about plans' do
    render 'groups/billings/top_level_billing_plan_header',
      namespace: build(:group),
      current_plan: build(:plan)

    expect(rendered).to have_content('Learn more about each plan by visiting our')
  end
end

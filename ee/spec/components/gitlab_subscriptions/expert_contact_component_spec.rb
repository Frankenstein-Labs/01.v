# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::ExpertContactComponent, feature_category: :acquisition do
  before do
    render_inline(described_class.new)
  end

  it 'renders the heading text' do
    expect(page).to have_content("Have a question? We're here to help.")
  end

  it 'has correct hand raise lead tracking data' do
    trigger = page.find('.js-hand-raise-lead-trigger')

    expect(trigger['data-glm-content']).to eq('billing-group')

    cta_tracking = ::Gitlab::Json.safe_parse(trigger['data-cta-tracking'])
    expect(cta_tracking['action']).to eq('click_button')
  end
end

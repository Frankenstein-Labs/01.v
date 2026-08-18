# frozen_string_literal: true

require "spec_helper"

RSpec.describe GitlabSubscriptions::TrialAdvantageComponent, :aggregate_failures, feature_category: :subscription_management do
  let(:advantage) { '_some_advantage_' }

  subject(:component) { described_class.new(advantage) }

  it 'renders the component' do
    render_inline(component)

    expect(page).to have_selector("[data-testid='check-circle-icon']")
    expect(page).to have_content(advantage)
  end
end

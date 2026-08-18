# frozen_string_literal: true

require "spec_helper"

RSpec.describe GitlabSubscriptions::TrialAdvantagesComponent, :aggregate_failures, feature_category: :subscription_management do
  let(:advantage) { '_some_advantage_' }
  let(:another_advantage) { '_another_advantage_' }
  let(:advantages) { [advantage, another_advantage] }
  let(:header) { '_header_' }
  let(:footer) { '_footer_' }

  subject(:component) do
    described_class.new.with_header_content(header).with_footer_content(footer).tap do |c|
      c.with_advantages(advantages)
    end
  end

  it 'renders the component' do
    render_inline(component)

    expect(page).to have_content(header)
    expect(page).to have_content(advantage)
    expect(page).to have_content(another_advantage)
    expect(page).to have_content(footer)
  end
end

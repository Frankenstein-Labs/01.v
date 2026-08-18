# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DependencyFirewall::BetaCreditsAlertComponent, feature_category: :dependency_firewall do
  before do
    render_inline(described_class.new)
  end

  it 'renders the beta credits alert' do
    expect(page).to have_testid('ga-billing-alert')
  end

  it 'links to the GitLab credits documentation' do
    expect(page).to have_link('GitLab Credits', href: %r{subscriptions/gitlab_credits})
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Duo::CodeReviewEnabledByDefaultAlertComponent, feature_category: :duo_code_review do
  let(:current_user) { build_stubbed(:user) }
  let(:group) { build_stubbed(:group) }

  let(:namespace_settings) { instance_double(NamespaceSetting, enable_duo_code_review_by_default_enabled?: true) }

  subject(:component) do
    render_inline(described_class.new(current_user: current_user, group: group))
  end

  before do
    stub_default_url_options(host: 'test.host')
    allow(group).to receive(:namespace_settings).and_return(namespace_settings)
    allow(current_user).to receive(:can?).with(:admin_group, group).and_return(true)
  end

  it 'renders the alert with correct content', :aggregate_failures do
    expect(component).to have_content('Automated code review is enabled')
    expect(component).to have_content(
      'Code Review flow automatically reviews your merge requests to help you ship better code, faster.'
    )
    expect(component).to have_link(
      'Learn more',
      href: ::Gitlab::Routing.url_helpers.help_page_url(
        'user/duo_agent_platform/flows/foundational_flows/code_review/_index.md',
        anchor: 'automatic-reviews'
      )
    )
    expect(component).to have_link(
      'Update group settings',
      href: edit_group_path(group, anchor: 'js-merge-requests-settings')
    )
  end

  it 'renders the dismissible callout for the group' do
    expect(component).to have_dismissible_callout(
      feature_id: 'duo_code_review_enabled_by_default',
      group: group
    )
  end

  context 'when user is absent' do
    let(:current_user) { nil }

    it 'does not render the alert' do
      is_expected.not_to have_content('Automated code review is enabled')
    end
  end

  context 'when user cannot admin the group' do
    before do
      allow(current_user).to receive(:can?).with(:admin_group, group).and_return(false)
    end

    it 'does not render the alert' do
      is_expected.not_to have_content('Automated code review is enabled')
    end
  end

  context 'when Duo Code Review by default is not enabled for the group' do
    before do
      allow(namespace_settings).to receive(:enable_duo_code_review_by_default_enabled?).and_return(false)
    end

    it 'does not render the alert' do
      is_expected.not_to have_content('Automated code review is enabled')
    end
  end

  context 'when namespace_settings is nil' do
    before do
      allow(group).to receive(:namespace_settings).and_return(nil)
    end

    it 'does not render the alert' do
      is_expected.not_to have_content('Automated code review is enabled')
    end
  end
end

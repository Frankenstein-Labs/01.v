# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/duo_agents_platform/show', feature_category: :duo_agent_platform do
  let_it_be(:group) { build_stubbed(:group) }

  before do
    assign(:group, group)
    allow(view).to receive_messages(duo_agents_group_data: {}, duo_agents_platform_identity_verification_data: {})
  end

  context 'when identity verification is required' do
    before do
      allow(view).to receive(:dap_identity_verification_required?).with(group).and_return(true)
    end

    it 'renders the identity verification alert instead of the page' do
      render

      expect(rendered).to have_css('.js-duo-agents-platform-verification-alert')
      expect(rendered).not_to have_css('#js-duo-agents-platform-page')
    end

    it 'passes the identity verification data to the alert' do
      expect(view).to receive(:duo_agents_platform_identity_verification_data).with(group)
      render
    end
  end

  context 'when identity verification is not required' do
    before do
      allow(view).to receive(:dap_identity_verification_required?).with(group).and_return(false)
    end

    it 'renders the agents platform page container' do
      render

      expect(rendered).to have_css('#js-duo-agents-platform-page')
      expect(rendered).not_to have_css('.js-duo-agents-platform-verification-alert')
    end

    it 'passes the group data to the page container' do
      expect(view).to receive(:duo_agents_group_data).with(group)
      render
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SeatAlert::Admin::OverageComponent, :aggregate_failures, feature_category: :seat_cost_management do
  let(:license) { build_stubbed(:license) }
  let(:restricted_access_enabled) { false }
  let(:component_instance) { described_class.new }

  subject(:component) { render_inline(component_instance) }

  before do
    allow(License).to receive(:current).and_return(license)
    allow(license).to receive_messages(
      active_user_count_threshold_reached?: true,
      restricted_user_count: 100
    )
    allow(Gitlab::CurrentSettings).to receive(:seat_control_block_overages?).and_return(restricted_access_enabled)
    allow(component_instance).to receive_messages(render?: true, remaining_user_count: -5, total_user_count: 100)
  end

  it 'renders the overage title' do
    expect(component).to have_content('Your instance has exceeded its seat limit')
  end

  it 'renders warning variant alert' do
    expect(component).to have_css('.gl-alert-warning')
  end

  it 'renders purchase more seats button' do
    expect(component).to have_link('Purchase more seats')
  end

  context 'when restricted access is enabled' do
    let(:restricted_access_enabled) { true }

    it 'renders the overage count' do
      expect(component).to have_content('5 over limit')
    end

    it 'renders text about restricted access blocking new users' do
      expect(component).to have_content('Restricted access is blocking new users')
    end

    it 'renders turn off restricted access button' do
      expect(component).to have_link('Turn off restricted access')
    end
  end

  context 'when restricted access is disabled' do
    let(:restricted_access_enabled) { false }

    it 'renders the overage count' do
      expect(component).to have_content('5 over limit')
    end

    it 'renders text suggesting to turn on restricted access' do
      expect(component).to have_content('turn on restricted access to prevent further overages')
    end

    it 'presents the actions as alternative suggestions' do
      expect(component).to have_content('more seats or turn on restricted access')
    end

    it 'renders turn on restricted access button' do
      expect(component).to have_link('Turn on restricted access')
    end
  end

  context 'with a single seat license' do
    before do
      allow(component_instance).to receive_messages(remaining_user_count: -1, total_user_count: 1)
    end

    context 'when restricted access is enabled' do
      let(:restricted_access_enabled) { true }

      it 'renders singular form for total seats' do
        expect(component).to have_content(/2 of 1 seat\b/)
      end
    end

    context 'when restricted access is disabled' do
      let(:restricted_access_enabled) { false }

      it 'renders singular form for total seats' do
        expect(component).to have_content(/2 of 1 seat\b/)
      end
    end
  end
end

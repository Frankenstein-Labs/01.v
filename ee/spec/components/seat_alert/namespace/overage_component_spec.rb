# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SeatAlert::Namespace::OverageComponent, :aggregate_failures, :saas, feature_category: :seat_cost_management do
  let(:group) do
    build_stubbed(:group, namespace_settings: build_stubbed(:namespace_settings, seat_control: seat_control))
  end

  let(:user) { build(:user) }
  let(:seat_control) { :off }
  let(:remaining_seat_count) { -5 }
  let(:total_seat_count) { 100 }

  subject(:component) do
    render_inline(
      described_class.new(
        root_namespace: group,
        current_user: user,
        remaining_seat_count: remaining_seat_count,
        total_seat_count: total_seat_count
      )
    )
  end

  it_behaves_like 'seat alert namespace component'

  it 'renders the overage title' do
    expect(component).to have_content('Your namespace has exceeded its seat limit')
  end

  it 'renders warning variant alert' do
    expect(component).to have_css('.gl-alert-warning')
  end

  it 'renders the correct alert class for dismissal' do
    expect(component).to have_css('.js-overage-seat-count-threshold')
  end

  it 'renders the correct alert testid' do
    expect(component).to have_css("[data-testid='overage-seat-count-threshold-alert']")
  end

  it 'renders the dismiss button with correct testid' do
    expect(component).to have_css("[data-testid='overage-seat-count-threshold-alert-dismiss']")
  end

  it 'renders the correct feature ID for tracking dismissals' do
    expect(component).to have_css("[data-feature-id='overage_seat_count_threshold']")
  end

  context 'when restricted access is enabled' do
    let(:seat_control) { :block_overages }

    it 'renders the used seats and total seats' do
      expect(component).to have_content('105 of 100 seats')
    end

    it 'renders the overage count' do
      expect(component).to have_content('5 over limit')
    end

    it 'renders text about restricted access blocking new users' do
      expect(component).to have_content('Restricted access is blocking new users')
    end
  end

  context 'when restricted access is disabled' do
    let(:seat_control) { :off }

    it 'renders the used seats and total seats' do
      expect(component).to have_content('105 of 100 seats')
    end

    it 'renders the overage count' do
      expect(component).to have_content('5 over limit')
    end

    it 'renders text suggesting to turn on restricted access' do
      expect(component).to have_content('turn on restricted access to prevent further overages')
    end

    it 'presents the actions as alternative suggestions' do
      expect(component).to have_content('more seats or turn on restricted access')
    end
  end
end

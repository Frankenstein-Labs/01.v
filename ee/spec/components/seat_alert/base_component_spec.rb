# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SeatAlert::BaseComponent, feature_category: :seat_cost_management do
  let(:admin) { build_stubbed(:admin) }
  let(:license) { build_stubbed(:license) }
  let(:admin_component) { SeatAlert::AdminComponent.new(current_user: admin, admin_section: true) }

  subject(:component) { render_inline(admin_component) }

  before do
    allow(admin).to receive(:can_admin_all_resources?).and_return(true)
    allow(License).to receive(:current).and_return(license)
    allow(license).to receive_messages(
      active_user_count_threshold_reached?: true,
      restricted_user_count: 100
    )
    allow(admin_component).to receive_messages(remaining_user_count: remaining, total_user_count: 100)
  end

  describe 'seat state rendering' do
    context 'when remaining_user_count > 0' do
      let(:remaining) { 5 }

      before do
        allow_next_instance_of(SeatAlert::Admin::ThresholdComponent) do |instance|
          allow(instance).to receive_messages(render?: true, remaining_user_count: remaining, total_user_count: 100)
        end
      end

      it 'renders the threshold component' do
        expect(component).to have_content('Your instance is approaching its seat limit')
      end
    end

    context 'when remaining_user_count == 0' do
      let(:remaining) { 0 }

      before do
        allow_next_instance_of(SeatAlert::Admin::ReachedComponent) do |instance|
          allow(instance).to receive_messages(render?: true, remaining_user_count: remaining, total_user_count: 100)
        end
      end

      it 'renders the reached component' do
        expect(component).to have_content('Your instance has reached its seat limit')
      end
    end

    context 'when remaining_user_count < 0' do
      let(:remaining) { -3 }

      before do
        allow_next_instance_of(SeatAlert::Admin::OverageComponent) do |instance|
          allow(instance).to receive_messages(render?: true, remaining_user_count: remaining, total_user_count: 100)
        end
      end

      it 'renders the overage component' do
        expect(component).to have_content('Your instance has exceeded its seat limit')
      end
    end
  end
end

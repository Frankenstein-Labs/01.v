# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SeatAlert::AdminComponent, :aggregate_failures, feature_category: :seat_cost_management do
  let(:admin) { build_stubbed(:admin) }
  let(:user) { build_stubbed(:user) }
  let(:license) { build_stubbed(:license) }
  let(:current_user) { admin }
  let(:admin_section) { true }
  let(:component_instance) { described_class.new(current_user: current_user, admin_section: admin_section) }

  subject(:component) { render_inline(component_instance) }

  before do
    allow(admin).to receive(:can_admin_all_resources?).and_return(true)
    allow(License).to receive(:current).and_return(license)
    allow(license).to receive(:active_user_count_threshold_reached?).and_return(true)
    allow(component_instance).to receive_messages(remaining_user_count: 5, total_user_count: 100)
  end

  describe '#render?' do
    context 'when all conditions are met' do
      before do
        allow_next_instance_of(SeatAlert::Admin::ThresholdComponent) do |instance|
          allow(instance).to receive_messages(render?: true, remaining_user_count: 5, total_user_count: 100)
        end
      end

      it 'renders the component' do
        expect(component).to have_content('Your instance is approaching its seat limit')
      end
    end

    context 'when on GitLab.com' do
      before do
        allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(true)
      end

      it 'does not render the component' do
        expect(component.text).to be_empty
      end
    end

    context 'when not in admin section' do
      let(:admin_section) { false }

      it 'does not render the component' do
        expect(component.text).to be_empty
      end
    end

    context 'when user cannot admin all resources' do
      let(:current_user) { user }

      it 'does not render the component' do
        expect(component.text).to be_empty
      end
    end

    context 'when license is nil' do
      before do
        allow(License).to receive(:current).and_return(nil)
      end

      it 'does not render the component' do
        expect(component.text).to be_empty
      end
    end

    context 'when threshold is not reached' do
      before do
        allow(license).to receive(:active_user_count_threshold_reached?).and_return(false)
      end

      it 'does not render the component' do
        expect(component.text).to be_empty
      end
    end

    context 'when user has dismissed the callout' do
      before do
        allow(admin).to receive(:dismissed_callout?).and_return(true)
      end

      it 'does not render the component' do
        expect(component.text).to be_empty
      end
    end

    context 'when the subscription is small (2 seats or fewer)' do
      where(:total_seats) { [1, 2] }

      with_them do
        before do
          allow(component_instance).to receive(:total_user_count).and_return(total_seats)
        end

        it 'does not render the component' do
          expect(component.text).to be_empty
        end
      end
    end

    context 'when the subscription has 3 seats' do
      before do
        allow(component_instance).to receive_messages(remaining_user_count: 1, total_user_count: 3)
        allow_next_instance_of(SeatAlert::Admin::ThresholdComponent) do |instance|
          allow(instance).to receive_messages(render?: true, remaining_user_count: 1, total_user_count: 3)
        end
      end

      it 'still renders the component' do
        expect(component).to have_content('Your instance is approaching its seat limit')
      end
    end

    context 'when the subscription has an unlimited seat count' do
      before do
        allow(component_instance).to receive(:total_user_count).and_return(nil)
        allow_next_instance_of(SeatAlert::Admin::ThresholdComponent) do |instance|
          allow(instance).to receive_messages(render?: true, remaining_user_count: 5, total_user_count: 100)
        end
      end

      it 'renders the component' do
        expect(component).to have_content('Your instance is approaching its seat limit')
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SeatAlert::NamespaceComponent, :aggregate_failures, :saas, feature_category: :seat_cost_management do
  let(:namespace_settings) { build_stubbed(:namespace_settings, seat_control: :off) }
  let(:group) { build_stubbed(:group, namespace_settings: namespace_settings) }
  let(:user) { build_stubbed(:user) }
  let(:billable_members_count) { 9 }

  let(:subscription) do
    build_stubbed(:gitlab_subscription, :ultimate,
      namespace: group,
      seats: 10
    )
  end

  let(:context) { group }
  let(:current_user) { user }
  let(:component_instance) { described_class.new(context: context, current_user: current_user) }

  subject(:component) { render_inline(component_instance) }

  before do
    allow(group).to receive_messages(
      gitlab_subscription: subscription,
      billable_members_count_with_reactive_cache: billable_members_count
    )
  end

  describe '#render?' do
    context 'when all conditions are met for threshold state' do
      before do
        stub_member_access_level(group, owner: user)
      end

      it 'renders the component' do
        expect(component).to have_content('Your namespace is approaching its seat limit')
      end
    end

    context 'when not on GitLab.com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'does not render the component' do
        expect(component.text).to be_empty
      end
    end

    context 'when user cannot read subscription usage' do
      before do
        stub_member_access_level(group, developer: user)
      end

      it 'does not render the component' do
        expect(component.text).to be_empty
      end
    end

    context 'when subscription is not present' do
      before do
        stub_member_access_level(group, owner: user)
      end

      let(:subscription) { nil }

      it 'does not render the component' do
        expect(component.text).to be_empty
      end
    end

    context 'when subscription is expired' do
      before do
        stub_member_access_level(group, owner: user)
      end

      let(:subscription) { build_stubbed(:gitlab_subscription, :ultimate, :expired, namespace: group, seats: 10) }

      it 'does not render the component' do
        expect(component.text).to be_empty
      end
    end

    context 'when subscription is not a paid plan' do
      before do
        stub_member_access_level(group, owner: user)
      end

      let(:subscription) { build_stubbed(:gitlab_subscription, :free, namespace: group, seats: 10) }

      it 'does not render the component' do
        expect(component.text).to be_empty
      end
    end

    context 'when billable_members_count is nil' do
      before do
        stub_member_access_level(group, owner: user)
      end

      let(:billable_members_count) { nil }

      it 'does not render the component' do
        expect(component.text).to be_empty
      end
    end

    context 'when seat count threshold is not reached' do
      before do
        stub_member_access_level(group, owner: user)
      end

      let(:billable_members_count) { 5 }

      it 'does not render the component' do
        expect(component.text).to be_empty
      end
    end

    context 'when all conditions are met for reached state' do
      before do
        stub_member_access_level(group, owner: user)
      end

      let(:billable_members_count) { 10 }

      it 'renders the reached component' do
        expect(component).to have_content('Your namespace has reached its seat limit')
      end
    end

    context 'when namespace is in overage' do
      before do
        stub_member_access_level(group, owner: user)
      end

      let(:billable_members_count) { 12 }

      it 'renders the overage component' do
        expect(component).to have_content('Your namespace has exceeded its seat limit')
      end
    end

    context 'when the subscription is small (2 seats or fewer)' do
      before do
        stub_member_access_level(group, owner: user)
      end

      where(:seats, :billable_members_count) do
        [
          [1, 1],
          [2, 2]
        ]
      end

      with_them do
        let(:subscription) { build_stubbed(:gitlab_subscription, :ultimate, namespace: group, seats: seats) }

        it 'does not render the component' do
          expect(component.text).to be_empty
        end
      end

      context 'when the subscription has 3 seats' do
        let(:billable_members_count) { 3 }
        let(:subscription) { build_stubbed(:gitlab_subscription, :ultimate, namespace: group, seats: 3) }

        it 'still renders the component' do
          expect(component).to have_content('Your namespace has reached its seat limit')
        end
      end
    end

    context 'when user has dismissed the callout' do
      where(:billable_members_count, :feature_name) do
        [
          [9,  Users::GroupCalloutsHelper::APPROACHING_SEAT_COUNT_THRESHOLD],
          [10, Users::GroupCalloutsHelper::REACHED_SEAT_COUNT_THRESHOLD],
          [12, Users::GroupCalloutsHelper::OVERAGE_SEAT_COUNT_THRESHOLD]
        ]
      end

      with_them do
        before do
          stub_member_access_level(group, owner: user)
          allow(user).to receive(:dismissed_callout_for_group?).with(
            feature_name: feature_name,
            group: group
          ).and_return(true)
        end

        it 'does not render the component' do
          expect(component.text).to be_empty
        end
      end
    end

    shared_examples 'respects callout dismissal' do
      before do
        stub_member_access_level(group, owner: user)
      end

      it 'does not render the component for the user who dismissed' do
        allow(user).to receive(:dismissed_callout_for_group?).with(
          feature_name: feature_name,
          group: group
        ).and_return(true)

        expect(component.text).to be_empty
      end

      it 'renders the component for a user who has not dismissed' do
        allow(user).to receive(:dismissed_callout_for_group?).with(
          feature_name: feature_name,
          group: group
        ).and_return(false)

        expect(component).to have_content(title)
      end
    end

    context 'when user has dismissed the threshold callout' do
      let(:feature_name) { Users::GroupCalloutsHelper::APPROACHING_SEAT_COUNT_THRESHOLD }
      let(:title) { 'Your namespace is approaching its seat limit' }

      it_behaves_like 'respects callout dismissal'
    end

    context 'when user has dismissed the reached callout' do
      let(:feature_name) { Users::GroupCalloutsHelper::REACHED_SEAT_COUNT_THRESHOLD }
      let(:title) { 'Your namespace has reached its seat limit' }
      let(:billable_members_count) { 10 }

      it_behaves_like 'respects callout dismissal'
    end
  end
end

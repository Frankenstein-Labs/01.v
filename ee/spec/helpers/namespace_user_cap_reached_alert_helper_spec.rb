# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NamespaceUserCapReachedAlertHelper, feature_category: :seat_cost_management do
  describe '#display_namespace_user_cap_reached_alert?', :freeze_time do
    subject(:display_alert?) { helper.display_namespace_user_cap_reached_alert?(group) }

    context 'with a non persisted namespace' do
      let(:group) { build_stubbed(:group) }

      it { is_expected.to be(false) }
    end

    context 'with a persisted namespace' do
      let_it_be(:group) do
        build_stubbed(:group, :public,
          namespace_settings: build_stubbed(:namespace_settings, seat_control: :user_cap, new_user_signups_cap: 1))
      end

      let_it_be(:subgroup) { build_stubbed(:group, parent: group) }
      let_it_be(:owner) { build_stubbed(:user) }
      let_it_be(:developer) { build_stubbed(:user) }

      before do
        allow(helper).to receive(:can?).with(owner, :admin_namespace, group).and_return(true)
        allow(helper).to receive(:can?).with(developer, :admin_namespace, group).and_return(false)
        allow(group).to receive(:user_cap_available?).and_return(true)
        set_cap_reached(true)
        set_dismissed(false)
      end

      it 'returns true when the user cap is reached for a user who can admin the namespace' do
        sign_in(owner)

        expect(display_alert?).to be true
      end

      it 'returns false if the user cap has not been reached for a user who can admin the namespace' do
        set_cap_reached(false)

        sign_in(owner)

        expect(display_alert?).to be false
      end

      it 'returns false when the user cap is reached for a user who cannot admin the namespace' do
        sign_in(developer)

        expect(display_alert?).to be false
      end

      it 'returns false when the user cap feature is unavailable' do
        allow(group).to receive(:user_cap_available?).and_return(false)

        sign_in(owner)

        expect(display_alert?).to be false
      end

      it 'returns false if the alert has been dismissed' do
        set_dismissed(true)

        sign_in(owner)

        expect(display_alert?).to be false
      end

      it 'returns false if on the pending members page' do
        allow(helper).to receive(:current_page?).with(pending_members_group_usage_quotas_path(group)).and_return(true)
        sign_in(owner)

        expect(display_alert?).to be false
      end

      def sign_in(user)
        allow(helper).to receive(:current_user).and_return(user)
      end

      def set_cap_reached(user_cap_reached)
        allow(group).to receive(:user_cap_reached?).with(use_cache: true).and_return(user_cap_reached)
      end

      def set_dismissed(dismissed)
        allow(helper).to receive(:user_dismissed_for_group).with(
          "namespace_user_cap_reached_alert",
          group,
          30.days.ago
        ).and_return(dismissed)
      end
    end
  end

  describe '#namespace_user_cap_reached_alert_callout_data' do
    subject(:callout_data) { helper.namespace_user_cap_reached_alert_callout_data(group) }

    let(:group) { build_stubbed(:group) }

    it 'returns the group callout data' do
      expect(callout_data).to eq({
        feature_id: 'namespace_user_cap_reached_alert',
        dismiss_endpoint: group_callouts_path,
        group_id: group.id
      })
    end
  end
end

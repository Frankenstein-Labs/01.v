# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::BlockSeatOverages::MinimalAccessProvisioningAlertComponent,
  :saas, :clean_gitlab_redis_shared_state, :freeze_time, feature_category: :seat_cost_management do
  include GitlabSubscriptions::MemberManagement::SeatAwareProvisioning

  let_it_be(:owner) { build_stubbed(:user) }
  let_it_be(:group) { build_stubbed(:group) }

  let(:component) { described_class.new(current_user: owner, root_namespace: group) }

  subject { render_inline(component) && page }

  def populate_today_with(*user_ids)
    Gitlab::Redis::SharedState.with do |redis|
      redis.sadd(format_users_cache_key(group.id, Date.current.iso8601), user_ids.map(&:to_s))
    end
  end

  def record_dismissal_for(user)
    GitlabSubscriptions::MemberManagement::SeatAwareProvisioning
      .record_group_count_at_dismissal(group, user)
  end

  before do
    allow(group).to receive(:block_seat_overages?).and_return(true)
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(owner, :edit_billing, group).and_return(true)
  end

  describe 'rendering' do
    before do
      populate_today_with(1, 2, 3)
    end

    it 'has correct data attributes' do
      is_expected.to have_css(
        '#js-minimal-access-provisioning-alert' \
          '[data-affected-users-count]' \
          '[data-purchase-seats-link]' \
          '[data-learn-more-link]' \
          '[data-restricted-access-link]' \
          '[data-dismiss-path]'
      )
    end

    it 'passes the affected users count' do
      is_expected.to have_css("[data-affected-users-count='3']")
    end
  end

  describe '#render?' do
    shared_examples 'does not render the alert' do
      it { is_expected.not_to have_css('#js-minimal-access-provisioning-alert') }
    end

    context 'when on self-managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        populate_today_with(1, 2, 3)
      end

      it_behaves_like 'does not render the alert'
    end

    context 'when bso_minimal_access_fallback feature flag is disabled' do
      before do
        stub_feature_flags(bso_minimal_access_fallback: false)
        populate_today_with(1, 2, 3)
      end

      it_behaves_like 'does not render the alert'
    end

    context 'when current_user is nil' do
      let(:component) { described_class.new(current_user: nil, root_namespace: group) }

      it_behaves_like 'does not render the alert'
    end

    context 'when current_user is not a group owner' do
      let_it_be(:user) { build_stubbed(:user) }

      let(:component) { described_class.new(current_user: user, root_namespace: group) }

      before do
        populate_today_with(1, 2, 3)
      end

      it_behaves_like 'does not render the alert'
    end

    context 'when block seat overages is not enabled for the group' do
      before do
        allow(group).to receive(:block_seat_overages?).and_return(false)
        populate_today_with(1, 2, 3)
      end

      it_behaves_like 'does not render the alert'
    end

    context 'when there are no affected users' do
      it_behaves_like 'does not render the alert'
    end

    context 'with affected users' do
      before do
        populate_today_with(1, 2, 3)
      end

      it { is_expected.to have_css('#js-minimal-access-provisioning-alert') }

      context 'when the affected user count exceeds the count since the last banner dismissal' do
        before do
          record_dismissal_for(owner)
          populate_today_with(4, 5)
        end

        it { is_expected.to have_css('#js-minimal-access-provisioning-alert') }
      end

      context 'when the affected user count does not exceed the count since the last banner dismissal' do
        before do
          record_dismissal_for(owner)
        end

        it_behaves_like 'does not render the alert'
      end
    end
  end
end

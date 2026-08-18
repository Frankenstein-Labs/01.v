# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::ApplyPendingMemberApprovalsWorker, feature_category: :seat_cost_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:member_user) { create(:user) }
  let(:user_id) { member_user.id }
  let(:modified_by_admin_event) do
    ::Members::MembershipModifiedByAdminEvent.new(
      data: { member_user_id: user_id }
    )
  end

  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

  let!(:member_approval) do
    create(:gitlab_subscription_member_management_member_approval, user: member_user, member_namespace: group,
      member: nil, old_access_level: nil)
  end

  before do
    stub_application_setting(enable_member_promotion_management: true)
    allow(License).to receive(:current).and_return(license)
  end

  it_behaves_like 'subscribes to event' do
    let(:event) { modified_by_admin_event }
  end

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  describe '#handle_event' do
    shared_examples 'does not perform any action' do
      it do
        expect(::GitlabSubscriptions::MemberManagement::ProcessUserBillablePromotionService).not_to receive(:new)

        consume_event(subscriber: described_class, event: modified_by_admin_event)
      end
    end

    context 'when member_user exists and has pending approvals' do
      it 'applies pending promotion' do
        expect do
          consume_event(subscriber: described_class, event: modified_by_admin_event)
        end.to change { member_approval.reload.status }
      end
    end

    context 'when member_user does not exist' do
      let(:user_id) { non_existing_record_id }

      it_behaves_like 'does not perform any action'
    end

    context 'when member_user has no pending approvals' do
      let!(:member_approval) { nil }

      it_behaves_like 'does not perform any action'
    end

    context 'when setting is disabled' do
      before do
        stub_application_setting(enable_member_promotion_management: false)
      end

      it_behaves_like 'does not perform any action'
    end

    context 'when license is not Ultimate' do
      let(:license) { create(:license, plan: License::STARTER_PLAN) }

      it_behaves_like 'does not perform any action'
    end
  end
end

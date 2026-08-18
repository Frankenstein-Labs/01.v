# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::PromotionManagementUtils, feature_category: :seat_cost_management do
  include described_class

  let(:current_user) { create(:user) }
  let(:plan_type) { License::ULTIMATE_PLAN }
  let(:license) { create(:license, plan: plan_type) }
  let(:setting_enabled) { true }

  before do
    allow(License).to receive(:current).and_return(license)
    stub_application_setting(enable_member_promotion_management: setting_enabled)
  end

  describe '#member_promotion_management_enabled?' do
    context 'when self-managed' do
      context 'when setting is disabled' do
        let(:setting_enabled) { false }

        it 'returns false' do
          expect(member_promotion_management_enabled?).to be false
        end
      end

      context 'when feature and setting is enabled' do
        context 'when guests are excluded' do
          it 'returns true' do
            expect(member_promotion_management_enabled?).to be true
          end
        end

        context 'when guests are not excluded' do
          let(:plan_type) { License::STARTER_PLAN }

          it 'returns false' do
            expect(member_promotion_management_enabled?).to be false
          end
        end
      end
    end

    context 'when on saas', :saas do
      it 'returns false' do
        expect(member_promotion_management_enabled?).to be false
      end
    end
  end

  describe '#member_promotion_management_feature_available?' do
    context 'when self-managed' do
      it 'returns true' do
        expect(member_promotion_management_feature_available?).to be true
      end

      context 'when guests are not excluded' do
        let(:plan_type) { License::STARTER_PLAN }

        it 'returns false' do
          expect(member_promotion_management_feature_available?).to be false
        end
      end
    end

    context 'when on saas', :saas do
      it 'returns false' do
        expect(member_promotion_management_feature_available?).to be false
      end
    end
  end

  describe '#promotion_management_required_for_role?', :aggregate_failures do
    let_it_be(:access_level) { ::Gitlab::Access::DEVELOPER }
    let(:billable_role_change_value) { true }

    before do
      allow(self).to receive(:sm_billable_role_change?).and_return(billable_role_change_value)
    end

    subject(:promotion_check) { promotion_management_required_for_role?(new_access_level: access_level) }

    context 'when member_promotion_management_enabled? returns true' do
      context 'when role change is billable' do
        it { is_expected.to be true }
      end

      context 'when role change is not billable' do
        let(:billable_role_change_value) { false }

        it { is_expected.to be false }
      end
    end

    context 'when member_promotion_management_enabled? returns false' do
      before do
        allow(self).to receive(:member_promotion_management_enabled?).and_return(false)
      end

      it { is_expected.to be false }
    end
  end

  describe '#trigger_event_to_promote_pending_members!' do
    let(:user) { create(:user) }
    let(:member) { create(:group_member, :developer, user: user) }
    let!(:member_approval) do
      create(:gitlab_subscription_member_management_member_approval, :to_maintainer, user: user)
    end

    subject(:trigger_event) { trigger_event_to_promote_pending_members!(member) }

    shared_examples 'does not publish any event' do
      it 'does not publish any event' do
        expect(::Gitlab::EventStore).not_to receive(:publish)

        trigger_event
      end
    end

    context 'when member promotion management is disabled' do
      let(:setting_enabled) { false }

      it_behaves_like 'does not publish any event'
    end

    context 'when member is not eligible for admin event' do
      before do
        allow(self).to receive(:member_eligible_for_admin_event?).with(member).and_return(false)
      end

      it_behaves_like 'does not publish any event'
    end

    context 'when there are no pending member approvals' do
      before do
        pending_approvals = instance_double(ActiveRecord::Relation, exists?: false)
        allow(::GitlabSubscriptions::MemberManagement::MemberApproval).to receive(:pending_member_approvals_for_user)
                                            .with(member.user_id)
                                            .and_return(pending_approvals)
      end

      it_behaves_like 'does not publish any event'
    end

    context 'when all conditions are met' do
      it 'publishes a MembershipModifiedByAdminEvent' do
        expect(::Gitlab::EventStore).to receive(:publish).with(
          an_instance_of(::Members::MembershipModifiedByAdminEvent)
        )

        trigger_event
      end

      it 'includes the correct member user ID in the event data' do
        expect(::Members::MembershipModifiedByAdminEvent).to receive(:new)
                                                             .with(data: { member_user_id: member.user_id })
                                                             .and_call_original

        trigger_event
      end
    end
  end
end

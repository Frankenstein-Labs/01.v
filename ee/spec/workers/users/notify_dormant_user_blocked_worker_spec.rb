# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::NotifyDormantUserBlockedWorker, feature_category: :seat_cost_management do
  describe '#perform' do
    let_it_be(:user) { create(:user, :blocked_pending_approval) }

    subject(:perform) { described_class.new.perform(user.id) }

    context 'when the user does not exist' do
      it 'does not enqueue any mailer jobs' do
        expect { described_class.new.perform(non_existing_record_id) }
          .not_to have_enqueued_mail(Notify, :dormant_user_blocked_on_reactivation)
      end
    end

    context 'when the user is not blocked pending approval' do
      let_it_be(:active_user) { create(:user) }

      subject(:perform) { described_class.new.perform(active_user.id) }

      it 'does not enqueue the mailer' do
        expect { perform }.not_to have_enqueued_mail(Notify, :dormant_user_blocked_on_reactivation)
      end
    end

    context 'on Self-Managed' do
      let_it_be(:admin) { create(:admin) }
      let_it_be(:second_admin) { create(:admin) }

      it 'enqueues a mailer for each active admin' do
        expect { perform }
          .to have_enqueued_mail(Notify, :dormant_user_blocked_on_reactivation).with(admin.id, user.id)
          .and have_enqueued_mail(Notify, :dormant_user_blocked_on_reactivation).with(second_admin.id, user.id)
      end
    end

    context 'on GitLab.com', :saas do
      let_it_be(:enterprise_group) { create(:group) }
      let_it_be(:owner) { create(:user) }
      let_it_be(:second_owner) { create(:user) }
      let_it_be(:enterprise_user) do
        create(:enterprise_user, :blocked_pending_approval, enterprise_group: enterprise_group)
      end

      before_all do
        enterprise_group.add_owner(owner)
        enterprise_group.add_owner(second_owner)
      end

      subject(:perform) { described_class.new.perform(enterprise_user.id) }

      it 'enqueues a mailer for each enterprise group owner' do
        expect { perform }
          .to have_enqueued_mail(Notify, :dormant_user_blocked_on_reactivation)
          .with(owner.id, enterprise_user.id, enterprise_group.id)
          .and have_enqueued_mail(Notify, :dormant_user_blocked_on_reactivation)
          .with(second_owner.id, enterprise_user.id, enterprise_group.id)
      end

      context 'when the user has no enterprise group' do
        let_it_be(:non_enterprise_user) { create(:user, :blocked_pending_approval) }

        subject(:perform) { described_class.new.perform(non_enterprise_user.id) }

        it 'does not enqueue any mailer jobs' do
          expect { perform }.not_to have_enqueued_mail(Notify, :dormant_user_blocked_on_reactivation)
        end
      end

      context 'when the enterprise group no longer exists' do
        before do
          Group.where(id: enterprise_group.id).delete_all
        end

        it 'does not enqueue any mailer jobs' do
          expect { perform }.not_to have_enqueued_mail(Notify, :dormant_user_blocked_on_reactivation)
        end
      end
    end
  end
end

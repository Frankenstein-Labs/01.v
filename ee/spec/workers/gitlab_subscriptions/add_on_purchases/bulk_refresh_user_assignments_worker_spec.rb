# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::BulkRefreshUserAssignmentsWorker, :saas, feature_category: :seat_cost_management do
  describe '#perform_work' do
    subject(:perform_work) { described_class.new.perform_work }

    let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
    let_it_be(:add_on_purchase_fresh) do
      create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 1.hour.ago)
    end

    before_all do
      add_on_purchase_fresh.assigned_users.create!(user: create(:user))
    end

    shared_examples 'returns early' do
      it 'does not remove assigned users' do
        expect(Gitlab::AppLogger).not_to receive(:info)

        expect do
          perform_work
        end.not_to change { GitlabSubscriptions::UserAddOnAssignment.count }
      end
    end

    context 'when there are stale add_on_purchases' do
      let_it_be(:add_on_purchase_stale) do
        create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 1.day.ago)
      end

      let_it_be(:user) { create(:user) }

      before_all do
        add_on_purchase_stale.assigned_users.create!(user: user)
      end

      describe 'idempotence' do
        include_examples 'an idempotent worker' do
          it 'refreshes assigned_users for stale add_on_purchases' do
            expect do
              perform_work
            end.to change { GitlabSubscriptions::UserAddOnAssignment.count }.by(-1)
              .and change { add_on_purchase_stale.reload.last_assigned_users_refreshed_at }

            expect(add_on_purchase_fresh.assigned_users.count).to eq(1)
          end

          context 'when there is a seat overage' do
            let_it_be(:user_1) { create(:user) }
            let_it_be(:user_2) { create(:user) }
            let_it_be(:user_3) { create(:user) }

            before_all do
              GitlabSubscriptions::UserAddOnAssignment.delete_all

              # user_3 is not added as a group member; thus is ineligible
              add_on_purchase_stale.namespace.add_developer(user_1)
              add_on_purchase_stale.namespace.add_developer(user_2)

              # user_2 is assigned last; thus will be prioritzed for overage cleanup
              add_on_purchase_stale.assigned_users.create!(user: user_3)
              add_on_purchase_stale.assigned_users.create!(user: user_1)
              add_on_purchase_stale.assigned_users.create!(user: user_2)
            end

            it 'reconciles any seat overage' do
              expect do
                perform_work
              end.to change { add_on_purchase_stale.reload.assigned_users.count }.by(-2)
                .and change { add_on_purchase_stale.reload.last_assigned_users_refreshed_at }

              expect(add_on_purchase_stale.assigned_users.map(&:user)).to eq([user_1])
            end
          end
        end
      end

      it 'logs info when assignments are refreshed' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          message: 'Ineligible UserAddOnAssignments destroyed',
          user_ids: [user.id],
          add_on: add_on.name,
          add_on_purchase: add_on_purchase_stale.id,
          namespace: add_on_purchase_stale.namespace.path
        ).ordered

        expect(Gitlab::AppLogger).to receive(:info).with(
          message: 'AddOnPurchase user assignments refreshed via scheduled CronJob',
          deleted_assignments_count: 1,
          add_on: add_on_purchase_stale.add_on.name,
          namespace: add_on_purchase_stale.namespace.path
        ).ordered

        perform_work
      end

      context 'with exclusive lease' do
        include ExclusiveLeaseHelpers

        let(:lock_key) { add_on_purchase_stale.lock_key_for_refreshing_user_assignments }
        let(:timeout) { described_class::LEASE_TTL }

        context 'when exclusive lease has not been taken' do
          it 'obtains a new exclusive lease' do
            expect_to_obtain_exclusive_lease(lock_key, timeout: timeout)

            perform_work
          end
        end

        context 'when exclusive lease has already been taken' do
          before do
            stub_exclusive_lease_taken(lock_key, timeout: timeout)
          end

          it 'raises an error' do
            expect { perform_work }
              .to raise_error(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
          end
        end
      end
    end

    context 'when there are no stale add_on_purchase to refresh' do
      it_behaves_like 'returns early'
    end
  end

  describe '#max_running_jobs' do
    it 'returns constant value' do
      expect(subject.max_running_jobs).to eq(described_class::MAX_RUNNING_JOBS)
    end
  end

  describe '#remaining_work_count' do
    before_all do
      add_on = create(:gitlab_subscription_add_on)
      3.times do
        create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 1.day.ago)
      end
    end

    context 'when there is remaining work' do
      before do
        stub_const("#{described_class}::MAX_RUNNING_JOBS", 1)
      end

      it 'returns correct amount' do
        expect(subject.remaining_work_count).to eq(2)
      end
    end

    context 'when there is no remaining work' do
      before do
        GitlabSubscriptions::AddOnPurchase.update_all(last_assigned_users_refreshed_at: Time.current)
      end

      it 'returns zero' do
        expect(subject.remaining_work_count).to eq(0)
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker, feature_category: :seat_cost_management do
  describe '#perform' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
    let_it_be(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, namespace: namespace, quantity: 2, add_on: add_on)
    end

    let_it_be(:other_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, add_on: add_on) }

    let(:root_namespace_id) { namespace.id }

    let_it_be(:user_1) { create(:user) }
    let_it_be(:user_2) { create(:user) }

    before_all do
      add_on_purchase.assigned_users.create!(user: user_1)
      add_on_purchase.assigned_users.create!(user: user_2)

      other_add_on_purchase.assigned_users.create!(user: create(:user))
    end

    shared_examples 'does not remove seat assignment' do
      specify do
        expect do
          subject.perform(root_namespace_id)
        end.not_to change { GitlabSubscriptions::UserAddOnAssignment.count }
      end
    end

    shared_examples 'updates last_assigned_users_refreshed_at attribute' do
      specify do
        freeze_time do
          expect do
            subject.perform(root_namespace_id)
          end.to change { add_on_purchase.reload.last_assigned_users_refreshed_at }.from(nil).to(Time.current)
        end
      end
    end

    context 'when root namespace does not have related purchase' do
      let(:root_namespace_id) { create(:group).id }

      it_behaves_like 'does not remove seat assignment'
    end

    describe 'idempotence' do
      include_examples 'an idempotent worker' do
        let(:job_args) { [root_namespace_id] }

        it 'removes the all ineligible user assignments' do
          expect do
            subject
          end.to change { GitlabSubscriptions::UserAddOnAssignment.where(add_on_purchase: add_on_purchase).count }
            .by(-2)

          # other not related user assignments remain intact
          expect(other_add_on_purchase.assigned_users.count).to eq(1)
        end

        context 'when some user is still eligible for assignment' do
          before_all do
            namespace.add_guest(user_1)
          end

          it 'removes only the ineligible user assignment' do
            expect do
              subject
            end.to change { GitlabSubscriptions::UserAddOnAssignment.count }.by(-1)

            expect(add_on_purchase.assigned_users.by_user(user_1).count).to eq(1)
          end
        end

        context 'when there is a seat overage' do
          let_it_be(:user_3) { create(:user) }

          before_all do
            GitlabSubscriptions::UserAddOnAssignment.delete_all

            # user_2 is not added as a group member; thus is inelligble
            add_on_purchase.reload.namespace.add_guest(user_1)
            add_on_purchase.namespace.add_developer(user_3)

            # user_3 is assigned last; thus will be prioritzed for overage cleanup
            add_on_purchase.assigned_users.create!(user: user_1)
            add_on_purchase.assigned_users.create!(user: user_2)
            add_on_purchase.assigned_users.create!(user: user_3)

            # decrease the quantity to create overage
            add_on_purchase.update!(quantity: 1)
          end

          it 'removes ineligible users and reconciles any seat overage' do
            expect do
              subject
            end.to change { GitlabSubscriptions::UserAddOnAssignment.count }.by(-2)

            expect(add_on_purchase.assigned_users.map(&:user)).to eq([user_1])
          end
        end
      end
    end

    it_behaves_like 'updates last_assigned_users_refreshed_at attribute'

    it 'logs an info about assignments refreshed' do
      expect(Gitlab::AppLogger).to receive(:info).with(
        message: 'Ineligible UserAddOnAssignments destroyed',
        user_ids: [user_1.id, user_2.id],
        add_on: add_on_purchase.add_on.name,
        add_on_purchase: add_on_purchase.id,
        namespace: namespace.path
      ).ordered

      expect(Gitlab::AppLogger).to receive(:info).with(
        message: 'AddOnPurchase user assignments refreshed in bulk',
        deleted_assignments_count: 2,
        add_on: add_on_purchase.add_on.name,
        add_on_purchase_id: add_on_purchase.id,
        namespace_id: namespace.id
      ).ordered

      subject.perform(root_namespace_id)
    end

    context 'when root_namespace_id is nil' do
      let(:root_namespace_id) { nil }

      context 'when there is no associated add_on_purchase' do
        it_behaves_like 'does not remove seat assignment'
      end

      shared_examples 'refreshes user seat assignments' do
        before do
          add_on_purchase.assigned_users.create!(user: user_1)
          add_on_purchase.assigned_users.create!(user: user_2)
        end

        it 'refreshes users seat assignments' do
          expect do
            subject.perform(root_namespace_id)
          end.to change { add_on_purchase.reload.assigned_users.count }.from(2).to(1)

          expect(add_on_purchase.assigned_users.map(&:user)).to eq([user_1])
        end

        it_behaves_like 'updates last_assigned_users_refreshed_at attribute'
      end

      context 'with Duo Pro add-on purchase' do
        let(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: add_on, quantity: 1)
        end

        it_behaves_like 'refreshes user seat assignments'
      end

      context "with Duo Enterprise add-on purchase" do
        let(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_enterprise, quantity: 1)
        end

        it_behaves_like 'refreshes user seat assignments'
      end
    end

    context 'when no assignments were deleted' do
      before_all do
        namespace.add_guest(user_1)
        namespace.add_guest(user_2)
      end

      it_behaves_like 'updates last_assigned_users_refreshed_at attribute'

      it 'does not log any info about assignments refreshed' do
        expect(Gitlab::AppLogger).not_to receive(:info)

        subject.perform(root_namespace_id)
      end
    end

    context 'with exclusive lease' do
      include ExclusiveLeaseHelpers

      let(:lock_key) { add_on_purchase.lock_key_for_refreshing_user_assignments }
      let(:timeout) { described_class::LEASE_TTL }

      context 'when exclusive lease has not been taken' do
        it 'obtains a new exclusive lease' do
          expect_to_obtain_exclusive_lease(lock_key, timeout: timeout)

          subject.perform(root_namespace_id)
        end
      end

      context 'when exclusive lease has already been taken' do
        before do
          stub_exclusive_lease_taken(lock_key, timeout: timeout)
        end

        it 'raises an error' do
          expect { subject.perform(root_namespace_id) }
            .to raise_error(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
        end
      end
    end
  end
end

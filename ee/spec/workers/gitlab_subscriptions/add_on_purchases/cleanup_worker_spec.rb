# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::CleanupWorker, feature_category: :subscription_management do
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

  it { is_expected.to include_module(CronjobQueue) }
  it { expect(described_class.get_feature_category).to eq(:subscription_management) }

  describe '#perform' do
    let_it_be(:add_on_name) { 'code_suggestions' }
    let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
    let_it_be(:non_seat_assignable_add_on) { create(:gitlab_subscription_add_on, :duo_core) }
    let_it_be(:expires_on) { 1.day.from_now }
    let_it_be(:namespace_path) { 'Socotra' }

    let(:namespace) { create(:group, path: namespace_path) }
    let!(:add_on_purchase) do
      create(
        :gitlab_subscription_add_on_purchase,
        add_on: add_on,
        expires_on: expires_on.to_date,
        namespace: namespace
      )
    end

    let(:non_seat_assignable_add_on_purchase) do
      create(
        :gitlab_subscription_add_on_purchase,
        add_on: non_seat_assignable_add_on,
        expires_on: expires_on.to_date,
        namespace: namespace
      )
    end

    let(:no_assigned_user_add_on_purchase) do
      create(
        :gitlab_subscription_add_on_purchase,
        add_on: add_on,
        expires_on: expires_on.to_date,
        namespace: namespace
      )
    end

    it_behaves_like 'an idempotent worker' do
      subject(:worker) { described_class.new }

      it 'does nothing' do
        expect { worker.perform }.to not_change { add_on_purchase.reload }
      end

      context 'with expired add_on_purchase' do
        let(:expires_on) { (GitlabSubscriptions::AddOnPurchase::CLEANUP_DELAY_PERIOD + 1.day).ago }

        it 'does nothing' do
          expect { worker.perform }.to not_change { add_on_purchase.reload }
        end

        it 'does not log a deletion message' do
          expect(Gitlab::AppLogger).not_to receive(:info)

          worker.perform
        end

        context 'with assigned_users' do
          let_it_be(:user_1) { create(:user) }
          let_it_be(:user_2) { create(:user) }
          let_it_be(:message_deletion) { 'CleanupWorker destroyed UserAddOnAssignments' }
          let_it_be(:message_summary) { 'CleanupWorker UserAddOnAssignments deletion summary' }

          let!(:user_add_on_assignment_1) do
            create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user_1)
          end

          let!(:user_add_on_assignment_2) do
            create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user_2)
          end

          it 'destroys add-on purchase assigned users' do
            worker.perform

            add_on_purchase.reload
            expect(add_on_purchase.assigned_users).to be_empty
          end

          it 'logs the deletion and the summary' do
            expect(Gitlab::AppLogger).to receive(:info).with(
              add_on: add_on_name,
              add_on_purchase: add_on_purchase.id,
              message: message_deletion,
              namespace: namespace_path,
              user_ids: [user_1.id, user_2.id]
            ).ordered

            expect(Gitlab::AppLogger).to receive(:info).with(
              add_on: add_on_name,
              add_on_purchase: add_on_purchase.id,
              message: message_summary,
              namespace: namespace_path,
              user_add_on_assignments_count: 2
            ).ordered

            worker.perform
          end

          context 'with multiple batches' do
            before do
              stub_const('GitlabSubscriptions::AddOnPurchases::CleanupWorker::BATCH_SIZE', 1)
            end

            it 'logs for every batch a deletion log' do
              expect(Gitlab::AppLogger).to receive(:info).with(
                add_on: add_on_name,
                add_on_purchase: add_on_purchase.id,
                message: message_deletion,
                namespace: namespace_path,
                user_ids: [user_1.id]
              ).ordered

              expect(Gitlab::AppLogger).to receive(:info).with(
                add_on: add_on_name,
                add_on_purchase: add_on_purchase.id,
                message: message_deletion,
                namespace: namespace_path,
                user_ids: [user_2.id]
              ).ordered

              expect(Gitlab::AppLogger).to receive(:info).with(
                add_on: add_on_name,
                add_on_purchase: add_on_purchase.id,
                message: message_summary,
                namespace: namespace_path,
                user_add_on_assignments_count: 2
              ).ordered

              worker.perform
            end
          end

          context 'without namespace' do
            let(:namespace) { nil }

            it 'logs the deletion with blank namespace' do
              expect(Gitlab::AppLogger).to receive(:info).with(
                add_on: add_on_name,
                add_on_purchase: add_on_purchase.id,
                message: message_deletion,
                namespace: nil,
                user_ids: [user_1.id, user_2.id]
              ).ordered

              expect(Gitlab::AppLogger).to receive(:info).with(
                add_on: add_on_name,
                add_on_purchase: add_on_purchase.id,
                message: message_summary,
                namespace: nil,
                user_add_on_assignments_count: 2
              ).ordered

              worker.perform
            end
          end
        end

        context 'without any assigned users' do
          let(:add_on_purchase) { no_assigned_user_add_on_purchase }

          it 'does nothing' do
            expect { worker.perform }.to not_change { add_on_purchase.reload }
          end

          it 'does not log a deletion message' do
            expect(Gitlab::AppLogger).not_to receive(:info)
            worker.perform
          end
        end

        context 'with non seat assignable add_ons' do
          let(:add_on_purchase) { non_seat_assignable_add_on_purchase }

          it 'does not process add-on purchase' do
            expect(Gitlab::AppLogger).not_to receive(:info)
            worker.perform
          end
        end
      end
    end
  end
end

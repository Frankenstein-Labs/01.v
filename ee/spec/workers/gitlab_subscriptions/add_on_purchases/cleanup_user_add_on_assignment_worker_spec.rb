# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::CleanupUserAddOnAssignmentWorker, feature_category: :seat_cost_management do
  describe '#perform' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:remove_user) { create(:user) }

    let_it_be(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: namespace)
    end

    let(:root_namespace_id) { namespace.id }
    let(:user_id) { remove_user.id }

    before_all do
      add_on_purchase.assigned_users.create!(user: remove_user)
    end

    shared_examples 'returns early' do
      it 'does not remove seat assignment' do
        expect(Gitlab::AppLogger).not_to receive(:info)
        expect do
          expect(subject.perform(root_namespace_id, user_id)).to be_nil
        end.not_to change { GitlabSubscriptions::UserAddOnAssignment.count }
      end
    end

    context 'when root_namespace_id does not exist' do
      let(:root_namespace_id) { nil }

      it_behaves_like 'returns early'
    end

    context 'when user_id does not exist' do
      let(:user_id) { nil }

      it_behaves_like 'returns early'
    end

    context 'when no add on purchases exist' do
      before do
        add_on_purchase.destroy!
      end

      it_behaves_like 'returns early'
    end

    context 'when there is no exising assigned seat for user' do
      before do
        add_on_purchase.assigned_users.by_user(remove_user).delete_all
      end

      it_behaves_like 'returns early'
    end

    describe 'idempotence' do
      include_examples 'an idempotent worker' do
        let(:job_args) { [root_namespace_id, user_id] }

        it 'removes the user addon assignment' do
          expect do
            subject
          end.to change { GitlabSubscriptions::UserAddOnAssignment.where(user_id: user_id).count }.by(-1)
        end

        describe 'when add-on is Duo Enterprise' do
          let_it_be(:add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace)
          end

          before do
            add_on_purchase.assigned_users.create!(user: remove_user)
          end

          it 'removes the user addon assignment' do
            expect do
              subject
            end.to change { GitlabSubscriptions::UserAddOnAssignment.where(user_id: user_id).count }.by(-1)
          end
        end

        it 'expires the cache key for the user', :use_clean_rails_redis_caching do
          cache_key = User.duo_pro_cache_key_formatted(user_id)
          Rails.cache.write(cache_key, true, expires_in: 1.hour)

          expect { subject }.to change { Rails.cache.read(cache_key) }.from(true).to(nil)
        end

        context 'when the user is still eligible for seat usage' do
          before_all do
            namespace.add_guest(remove_user)
          end

          it 'does not removes the user addon assignment' do
            expect do
              subject
            end.not_to change { GitlabSubscriptions::UserAddOnAssignment.count }
          end
        end
      end
    end

    it 'logs an info about user assignment destroyed' do
      expect(Gitlab::AppLogger).to receive(:info).with(
        message: 'CleanupUserAddOnAssignmentWorker destroyed UserAddOnAssignment',
        user: remove_user.username.to_s,
        user_id: remove_user.id,
        add_on: add_on_purchase.add_on.name,
        add_on_purchase: add_on_purchase.id,
        namespace: namespace.path
      )

      subject.perform(root_namespace_id, user_id)
    end
  end
end

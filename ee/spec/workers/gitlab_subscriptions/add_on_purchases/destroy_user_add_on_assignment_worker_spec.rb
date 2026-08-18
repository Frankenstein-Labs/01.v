# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::DestroyUserAddOnAssignmentWorker,
  feature_category: :subscription_management do
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

  describe '#perform' do
    let_it_be(:user) { create(:user) }
    let_it_be(:other_user) { create(:user) }
    let_it_be(:expires_on) { 1.day.from_now }

    subject(:perform) { described_class.new.perform(user.id, namespace&.id) }

    shared_examples 'destroy Duo add-on assignment' do
      let_it_be(:add_on_purchase) do
        create(
          :gitlab_subscription_add_on_purchase,
          :duo_pro,
          expires_on: expires_on.to_date,
          namespace: namespace
        )
      end

      before do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user)
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: other_user)
      end

      it 'is successful' do
        expect(perform).to be_success
      end

      it_behaves_like 'an idempotent worker' do
        let_it_be(:job_args) { [user.id, namespace&.id] }

        it 'destroys one seat' do
          expect { perform_idempotent_work }.to change { add_on_purchase.assigned_users.count }.from(2).to(1)
        end
      end

      context 'when user is nil' do
        it 'does not error' do
          expect(described_class.new.perform(nil, namespace&.id)).to be_nil
        end
      end
    end

    context 'for SaaS', :saas do
      let_it_be(:namespace) { create(:group) }

      it_behaves_like 'destroy Duo add-on assignment'
    end

    context 'for self-managed' do
      let_it_be(:namespace) { nil }

      it_behaves_like 'destroy Duo add-on assignment'
    end
  end
end

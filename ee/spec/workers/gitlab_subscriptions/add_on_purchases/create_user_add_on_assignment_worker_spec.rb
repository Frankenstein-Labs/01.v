# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::CreateUserAddOnAssignmentWorker, feature_category: :subscription_management do
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

  describe '#perform' do
    let_it_be(:user) { create(:user) }
    let_it_be(:expires_on) { 1.day.from_now }

    subject(:perform) { described_class.new.perform(user.id, namespace&.id) }

    shared_examples 'Duo add-on assignment' do
      let_it_be_with_reload(:add_on_purchase) do
        create(
          :gitlab_subscription_add_on_purchase,
          :duo_pro,
          expires_on: expires_on.to_date,
          namespace: namespace
        )
      end

      it 'does not error' do
        expect { perform }.not_to raise_error
      end

      it 'is successful' do
        expect(perform).to be_success
      end

      it_behaves_like 'an idempotent worker' do
        let_it_be(:job_args) { [user.id, namespace&.id] }

        it 'only assigns one seat' do
          expect { perform_idempotent_work }.to change { add_on_purchase.assigned_users.count }.by(1)
        end
      end

      context 'with expired add_on_purchase' do
        it 'does not assign a seat' do
          add_on_purchase.update!(expires_on: (GitlabSubscriptions::AddOnPurchase::CLEANUP_DELAY_PERIOD + 1.day).ago)

          expect { perform }.to not_change { add_on_purchase.assigned_users.count }
        end
      end

      context 'when user is nil' do
        it 'does not error' do
          expect(described_class.new.perform(nil, namespace&.id)).to be_nil
        end
      end
    end

    context 'for SaaS' do
      let_it_be(:namespace) { create(:group, developers: user) }

      before do
        stub_saas_features(gitlab_duo_saas_only: true)
      end

      it_behaves_like 'Duo add-on assignment'
    end

    context 'for self-managed' do
      let_it_be(:namespace) { nil }

      it_behaves_like 'Duo add-on assignment'
    end
  end
end

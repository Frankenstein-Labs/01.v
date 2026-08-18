# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::GitlabCom::UpdateService, feature_category: :plan_provisioning do
  describe '#execute' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
    let_it_be(:add_on_purchase) do
      create(
        :gitlab_subscription_add_on_purchase,
        namespace: namespace,
        add_on: add_on
      )
    end

    let_it_be(:params) do
      {
        quantity: 1,
        started_on: Date.current.to_s,
        expires_on: 1.year.from_now.to_date.to_s,
        purchase_xid: 'A-S00000001',
        trial: true
      }
    end

    subject(:execute_service) { described_class.new(namespace, add_on, params).execute }

    it 'does not enqueue RefreshUserAssignmentsWorker' do
      expect(GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker).not_to receive(:perform_async)

      execute_service
    end
  end
end

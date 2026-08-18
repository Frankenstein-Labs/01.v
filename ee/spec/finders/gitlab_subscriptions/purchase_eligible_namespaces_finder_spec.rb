# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::PurchaseEligibleNamespacesFinder, feature_category: :subscription_management do
  describe '#execute' do
    let_it_be(:user) { create(:user) }

    # candidate eligible namespaces
    let_it_be(:owned_group_1) { create(:group, owners: user) }
    let_it_be(:owned_group_2) { create(:group, owners: user) }

    before_all do
      # create some ineligible namespace types
      create(:group, developers: user)
      create(:group, parent: owned_group_1, owners: user)
      create(:project, owners: user)
    end

    context 'when no user is supplied' do
      it 'returns an empty collection' do
        results = described_class.new(user: nil, plan_id: 'test').execute

        expect(results).to be_empty
      end
    end

    context 'when the supplied user has no namespaces' do
      it 'returns an empty collection' do
        results = described_class.new(user: build(:user)).execute

        expect(results).to be_empty
      end
    end

    context 'when check_subscription_status is false' do
      it 'returns all candidate namespaces without filtering by subscription status' do
        results = described_class.new(user: user, check_subscription_status: false).execute

        expect(results).to match_array [owned_group_1, owned_group_2]
      end

      it 'does not call the subscription portal client' do
        expect(Gitlab::SubscriptionPortal::Client).not_to receive(:filter_purchase_eligible_namespaces)

        described_class.new(user: user, check_subscription_status: false).execute
      end

      context 'when namespace_id is also provided' do
        it 'returns only the specified namespace' do
          results = described_class.new(
            user: user,
            check_subscription_status: false,
            namespace_id: owned_group_1.id
          ).execute

          expect(results).to match_array [owned_group_1]
        end
      end
    end

    context 'when the http request fails' do
      before do
        allow(Gitlab::SubscriptionPortal::Client)
          .to receive(:filter_purchase_eligible_namespaces)
          .and_return(success: false, data: { errors: 'error' })
      end

      it 'returns an empty collection' do
        results = described_class.new(user: user, plan_id: 'test').execute

        expect(results).to be_empty
      end
    end

    context 'when all candidate namespaces are eligible' do
      before do
        stub_subscription_portal_request(
          sent_namespaces: [owned_group_1, owned_group_2],
          received_namespaces: [owned_group_1, owned_group_2],
          plan_id: 'test'
        )
      end

      it 'returns all the candidate namespaces' do
        results = described_class.new(user: user, plan_id: 'test').execute

        expect(results).to match_array [owned_group_1, owned_group_2]
      end
    end

    context 'when the user has only ineligible namespaces' do
      before do
        stub_subscription_portal_request(
          sent_namespaces: [owned_group_1, owned_group_2],
          received_namespaces: [],
          plan_id: 'test'
        )
      end

      it 'returns an empty collection' do
        results = described_class.new(user: user, plan_id: 'test').execute

        expect(results).to be_empty
      end
    end

    context 'when the user has an ineligible namespace' do
      before do
        stub_subscription_portal_request(
          sent_namespaces: [owned_group_1, owned_group_2],
          received_namespaces: [owned_group_1],
          plan_id: 'test'
        )
      end

      it 'is filtered from the results', :aggregate_failures do
        results = described_class.new(user: user, plan_id: 'test').execute

        expect(results).to match_array [owned_group_1]
      end
    end

    context 'when the plan_id is not supplied' do
      before do
        stub_subscription_portal_request(
          sent_namespaces: [owned_group_1, owned_group_2],
          received_namespaces: [owned_group_1],
          any_self_service_plan: true
        )
      end

      it 'filters the results by eligibility for any self service plan' do
        results = described_class.new(user: user).execute

        expect(results).to match_array [owned_group_1]
      end
    end

    context 'when supplied an eligible namespace_id' do
      before do
        stub_subscription_portal_request(
          sent_namespaces: [owned_group_2],
          received_namespaces: [owned_group_2],
          any_self_service_plan: true
        )
      end

      it 'returns only that namespace in the results' do
        results = described_class.new(user: user, namespace_id: owned_group_2.id).execute

        expect(results).to match_array [owned_group_2]
      end
    end

    context 'when supplied an ineligible namespace_id' do
      before do
        stub_subscription_portal_request(
          sent_namespaces: [owned_group_2],
          received_namespaces: [],
          any_self_service_plan: true
        )
      end

      it 'returns an empty collection' do
        results = described_class.new(user: user, namespace_id: owned_group_2.id).execute

        expect(results).to be_empty
      end
    end

    context 'when the user does not own the supplied namespace ID' do
      it 'returns an empty collection' do
        results = described_class.new(user: build(:user), namespace_id: owned_group_2.id).execute

        expect(results).to be_empty
      end
    end

    def stub_subscription_portal_request(sent_namespaces:, received_namespaces:, **args)
      allow(Gitlab::SubscriptionPortal::Client)
        .to receive(:filter_purchase_eligible_namespaces)
        .with(a_collection_containing_exactly(*sent_namespaces), **args)
        .and_return(success: true, data: received_namespaces.map { |namespace| { 'id' => namespace.id } })
    end
  end
end

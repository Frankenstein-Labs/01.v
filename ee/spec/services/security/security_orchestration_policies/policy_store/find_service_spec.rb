# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PolicyStore::FindService, :policy_store,
  feature_category: :security_policy_management do
  include_context 'with policy store service authorization'

  let(:policy) do
    create_policy(
      organization_id: organization.id,
      name: 'Test policy',
      trigger_type: 'deployment_requested'
    )
  end

  subject(:service) do
    described_class.new(organization: organization, current_user: current_user, policy_id: policy.id)
  end

  include_context 'with the policy store experiment active'

  describe '#execute' do
    it 'returns the policy as a store value object', :aggregate_failures do
      result = service.execute

      expect(result).to be_success
      expect(result.payload[:policy]).to be_a(Gitlab::PolicyStore::Policy)
      expect(result.payload[:policy].id).to eq(policy.id)
    end

    context 'when the policy does not exist' do
      subject(:service) do
        described_class.new(organization: organization, current_user: current_user, policy_id: non_existing_record_id)
      end

      it 'returns a not found error', :aggregate_failures do
        result = service.execute

        expect(result).to be_error
        expect(result.reason).to eq(:not_found)
        expect(result.message).to eq('Policy was not found')
      end
    end

    context 'when the policy belongs to another organization' do
      let(:policy) do
        create_policy(
          organization_id: create(:organization).id,
          name: 'Other organization policy',
          trigger_type: 'deployment_requested'
        )
      end

      it 'returns the same not found error as a missing policy', :aggregate_failures do
        result = service.execute

        expect(result).to be_error
        expect(result.reason).to eq(:not_found)
        expect(result.message).to eq('Policy was not found')
      end
    end

    it_behaves_like 'a service that requires policy authorization', :read_govern_policy
    it_behaves_like 'a service gated by the policy store experiment', :find
  end
end

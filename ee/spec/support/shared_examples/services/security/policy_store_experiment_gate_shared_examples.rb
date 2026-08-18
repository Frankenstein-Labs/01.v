# frozen_string_literal: true

# `store_method` is the facade method the service would reach for, asserted to
# stay untouched while the experiment is off.
RSpec.shared_examples 'a service gated by the policy store experiment' do |store_method|
  shared_examples 'an inactive experiment' do
    it 'returns an error without using the store', :aggregate_failures do
      expect(Gitlab::PolicyStore).not_to receive(store_method)

      result = service.execute

      expect(result).to be_error
      expect(result.reason).to eq(:experiment_not_active)
      expect(result.message).to eq('Policy Store experiment is not active for this organization')
    end
  end

  context 'when the feature flag is disabled' do
    before do
      stub_feature_flags(security_policies_v2: false)
    end

    it_behaves_like 'an inactive experiment'
  end

  context 'when the license is not available' do
    before do
      stub_licensed_features(security_orchestration_policies: false)
    end

    it_behaves_like 'an inactive experiment'
  end

  context 'when the experiment is disabled for the instance' do
    before do
      stub_application_setting(policy_store_experiment_enabled: false)
    end

    it_behaves_like 'an inactive experiment'
  end
end

# Expects the including context to define `service` and the actors from the
# 'with policy store service authorization' shared context. Takes the ability
# the service must check, so a service wired to the wrong ability fails here
# even though all govern_policy abilities share one grant rule.
RSpec.shared_examples 'a service that requires policy authorization' do |ability|
  it "checks the #{ability} ability against the organization" do
    expect(Ability).to receive(:allowed?).with(current_user, ability, organization).and_call_original

    service.execute
  end

  shared_examples 'a forbidden request' do
    it 'returns a forbidden error', :aggregate_failures do
      result = service.execute

      expect(result).to be_error
      expect(result.reason).to eq(:forbidden)
    end
  end

  context 'when the user is not an owner of the organization' do
    let(:current_user) { non_owner }

    it_behaves_like 'a forbidden request'
  end

  context 'when the user owns a different organization' do
    let(:current_user) { foreign_org_owner }

    it_behaves_like 'a forbidden request'
  end

  context 'when there is no current user' do
    let(:current_user) { nil }

    it_behaves_like 'a forbidden request'
  end
end

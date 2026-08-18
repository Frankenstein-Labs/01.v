# frozen_string_literal: true

RSpec.shared_context 'when no policy is applicable due to the policy scope' do
  before do
    allow_next_instance_of(Security::SecurityOrchestrationPolicies::PolicyScopeChecker) do |scope_checker|
      allow(scope_checker).to receive(:policy_applicable?).and_return(false)
    end
  end
end

RSpec.shared_context 'when policy is applicable based on the policy scope configuration' do
  before do
    allow_next_instance_of(Security::SecurityOrchestrationPolicies::PolicyScopeChecker) do |scope_checker|
      allow(scope_checker).to receive(:policy_applicable?).and_return(true)
    end
  end
end

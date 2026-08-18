# frozen_string_literal: true

RSpec.shared_context 'with default organization security policy configuration' do
  include Security::PolicyCspHelpers

  let_it_be(:organization, freeze: false) { create(:organization) }
  let_it_be(:policy_configuration, freeze: false) do
    create(:security_orchestration_policy_configuration, :namespace)
  end

  before do
    allow(::Organizations::Organization).to receive(:default_organization).and_return(organization)

    stub_csp_group(policy_configuration.namespace)
  end
end

# frozen_string_literal: true

RSpec.shared_context 'with csp group configuration' do
  include Security::PolicyCspHelpers

  let_it_be_with_refind(:csp_group) { create(:group) }
  let_it_be(:csp_policy_project, freeze: false) { create(:project, group: csp_group) }
  let_it_be(:csp_security_orchestration_policy_configuration, freeze: false) do
    create(:security_orchestration_policy_configuration, :namespace, namespace: csp_group,
      security_policy_management_project: csp_policy_project)
  end

  before do
    stub_csp_group(csp_group)
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "User creates scan execution policy", :js, feature_category: :security_policy_management do
  include ListboxHelpers

  let_it_be(:owner) { create(:user, :with_namespace) }
  let_it_be(:group) { create(:group, owners: owner) }
  let_it_be(:project) { create(:project, :repository, namespace: owner.namespace) }
  let_it_be(:path_to_policy_editor) { new_group_security_policy_path(group) }
  let_it_be(:policy_management_project) { create(:project, :repository, owners: owner) }
  let_it_be(:policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      :namespace,
      security_policy_management_project: policy_management_project,
      namespace: group
    )
  end

  before do
    sign_in(owner)
  end

  it_behaves_like 'creating scan execution policy with valid properties'

  context 'when the user is a security_manager' do
    let_it_be(:security_manager_user) { create(:user, :with_namespace) }

    before do
      group.add_security_manager(security_manager_user)
      policy_management_project.add_security_manager(security_manager_user)
      sign_in(security_manager_user)
    end

    it_behaves_like 'creating scan execution policy with valid properties'
  end

  context 'with quarantine', quarantine: {
    issue: [
      'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/6887',
      'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/6886',
      'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/6885'
    ]
  } do
    it_behaves_like 'creating scan execution policy with invalid properties'
  end
end

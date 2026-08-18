# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "User creates scan execution policy", :js, feature_category: :security_policy_management do
  let_it_be(:owner) { create(:user, :with_namespace) }
  let_it_be(:project) { create(:project, :repository, namespace: owner.namespace) }
  let_it_be(:path_to_policy_editor) { new_project_security_policy_path(project) }
  let_it_be(:policy_management_project) { create(:project, :repository, namespace: owner.namespace) }
  let_it_be(:policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      security_policy_management_project: policy_management_project,
      project: project
    )
  end

  before do
    sign_in(owner)
  end

  it_behaves_like 'creating scan execution policy with valid properties'

  context 'with quarantine', quarantine: {
    issue: [
      'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/6956',
      'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/6955',
      'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/6954'
    ]
  } do
    it_behaves_like 'creating scan execution policy with invalid properties'
  end
end

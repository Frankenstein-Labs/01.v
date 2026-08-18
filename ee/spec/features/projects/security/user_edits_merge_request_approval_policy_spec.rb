# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "User edits merge request approval policy", :js, feature_category: :security_policy_management do
  let_it_be(:owner) { create(:user, :with_namespace) }
  let_it_be(:project) { create(:project, :repository, namespace: owner.namespace) }
  let_it_be(:policy_management_project) { create(:project, :repository, owners: owner) }
  let_it_be(:policy_yaml) do
    Gitlab::Config::Loader::Yaml.new(fixture_file('security_orchestration/merge_request_approval_policy.yml',
      dir: 'ee')).load!
  end

  let_it_be(:policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      security_policy_management_project: policy_management_project,
      project: project
    )
  end

  let_it_be(:policy_path) { project_security_policies_path(project) }

  it_behaves_like 'editing merge request approval policy with invalid properties'
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "User reads security policies list", :js, feature_category: :security_policy_management do
  let_it_be(:owner) { create(:user) }
  let_it_be(:group) { create(:group, owners: owner) }
  let_it_be(:policy_management_project) { create(:project, :repository, owners: owner) }
  let_it_be(:policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      :namespace,
      security_policy_management_project: policy_management_project,
      namespace: group
    )
  end

  let_it_be(:policy_yaml) do
    Gitlab::Config::Loader::Yaml.new(fixture_file('security_orchestration.yml', dir: 'ee')).load!
  end

  it_behaves_like 'policies list' do
    let(:path_to_policies_list) { group_security_policies_path(group) }
  end
end

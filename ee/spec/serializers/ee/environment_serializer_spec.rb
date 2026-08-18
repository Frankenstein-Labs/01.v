# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::EnvironmentSerializer, feature_category: :continuous_delivery do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :repository, developers: user) }

  before do
    stub_licensed_features(environment_alerts: true, protected_environments: true)
  end

  it_behaves_like 'avoid N+1 on environments serialization'

  def create_environment_with_associations(project)
    create(:environment, project: project).tap do |environment|
      create(:deployment, :success, environment: environment, project: project)
      create(:deployment, :blocked, environment: environment, project: project) do |deployment|
        create(:deployment_approval, deployment: deployment)
      end
      # Mix role- and user-typed approval rules so the test exercises both the
      # rule-array collapse in `associated_approval_rules` and the per-rule
      # access checks reached from `can_approve_deployment` / `find_approval_rule_for`.
      create(:protected_environment, :maintainers_can_deploy, :maintainers_can_approve,
        name: environment.name, project: project, required_approval_count: 2,
        require_users_to_approve: [create(:user)]
      )
      create(:alert_management_alert, :triggered, :prometheus, project: project, environment: environment)
    end
  end
end

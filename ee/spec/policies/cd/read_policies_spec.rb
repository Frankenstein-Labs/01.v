# frozen_string_literal: true

require 'spec_helper'

# These models all expose a read-only GraphQL layer. Each type authorizes on
# the read permission of the nearest resource that has one: a record without
# its own read inherits its parent's (for example a version inherits the
# artifact source's read_cd_artifact_source). Every permission resolves through
# delegation up to the organization, where it is enabled for owners/admins.
RSpec.describe 'Cd read policies', feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }

  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:environment) { create(:cd_environment, organization: organization) }
  let_it_be(:service) { create(:cd_service, application: application) }
  let_it_be(:artifact_source) { create(:cd_artifact_source, service: service) }
  let_it_be(:version) { create(:cd_version, artifact_source: artifact_source) }
  let_it_be(:version_set) { create(:cd_version_set, application: application) }
  let_it_be(:version_set_entry) { create(:cd_version_set_entry, version_set: version_set, version: version) }
  let_it_be(:application_flow_definition) { create(:cd_application_flow_definition, application: application) }
  let_it_be(:application_link) { create(:cd_application_link, application: application) }
  let_it_be(:rollout) { create(:cd_rollout, version_set: version_set, application: application) }
  let_it_be(:rollout_transition) { create(:cd_rollout_transition, rollout: rollout) }
  let_it_be(:rollout_environment) { create(:cd_rollout_environment, rollout: rollout) }
  let_it_be(:deployment) { create(:cd_deployment, service: service, rollout_environment: rollout_environment) }
  let_it_be(:deployment_transition) { create(:cd_deployment_transition, deployment: deployment) }
  let_it_be(:driver_binding) { create(:cd_environment_driver_binding, environment: environment) }
  let_it_be(:service_environment_health) do
    create(:cd_service_environment_health, service: service, environment: environment)
  end

  using RSpec::Parameterized::TableSyntax

  where(:policy_class, :record, :ability) do
    Cd::ServicePolicy                    | ref(:service)                     | :read_cd_service
    Cd::ArtifactSourcePolicy             | ref(:artifact_source)             | :read_cd_artifact_source
    Cd::VersionPolicy                    | ref(:version)                     | :read_cd_artifact_source
    Cd::VersionSetPolicy                 | ref(:version_set)                 | :read_cd_version_set
    Cd::VersionSetEntryPolicy            | ref(:version_set_entry)           | :read_cd_version_set
    Cd::ApplicationFlowDefinitionPolicy  | ref(:application_flow_definition) | :read_cd_application_flow_definition
    Cd::ApplicationLinkPolicy            | ref(:application_link)            | :read_cd_application_link
    Cd::RolloutPolicy                    | ref(:rollout)                     | :read_cd_rollout
    Cd::RolloutTransitionPolicy          | ref(:rollout_transition)          | :read_cd_rollout
    Cd::RolloutEnvironmentPolicy         | ref(:rollout_environment)         | :read_cd_rollout
    Cd::DeploymentPolicy                 | ref(:deployment)                  | :read_cd_rollout
    Cd::DeploymentTransitionPolicy       | ref(:deployment_transition)       | :read_cd_rollout
    Cd::ServiceEnvironmentHealthPolicy   | ref(:service_environment_health)  | :read_cd_service
    Cd::EnvironmentDriverBindingPolicy   | ref(:driver_binding)              | :read_cd_environment
  end

  with_them do
    subject { policy_class.new(current_user, record) }

    context 'when the user is an organization owner' do
      let(:current_user) { organization_owner }

      it { expect_allowed(ability) }
    end

    context 'when the user is a non-owner organization member' do
      let(:current_user) { organization_member }

      it { expect_disallowed(ability) }
    end
  end
end

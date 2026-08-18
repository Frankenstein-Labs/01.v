# frozen_string_literal: true

require 'spec_helper'

# These nested resolvers all share the same shape: they expose a read-only
# association of their parent object and are gated behind the ai_native_deploy
# feature flag. This spec exercises both the enabled and disabled branches for
# each resolver.
RSpec.describe 'Cd nested read resolvers', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:organization_user, :owner, organization: organization).user }

  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:environment) { create(:cd_environment, organization: organization) }
  let_it_be(:service) { create(:cd_service, application: application) }
  let_it_be(:artifact_source) { create(:cd_artifact_source, service: service) }
  let_it_be(:version) { create(:cd_version, artifact_source: artifact_source) }
  let_it_be(:version_set) { create(:cd_version_set, application: application) }
  let_it_be(:version_set_entry) { create(:cd_version_set_entry, version_set: version_set, version: version) }
  let_it_be(:application_flow_definition) { create(:cd_application_flow_definition, application: application) }
  let_it_be(:rollout) { create(:cd_rollout, version_set: version_set, application: application) }
  let_it_be(:rollout_transition) { create(:cd_rollout_transition, rollout: rollout) }
  let_it_be(:rollout_environment) { create(:cd_rollout_environment, rollout: rollout, environment: environment) }
  let_it_be(:deployment) do
    create(:cd_deployment, service: service, rollout_environment: rollout_environment)
  end

  let_it_be(:deployment_transition) { create(:cd_deployment_transition, deployment: deployment) }
  let_it_be(:rollout_step) { create(:cd_rollout_step, rollout: rollout) }
  let_it_be(:driver_binding) { create(:cd_environment_driver_binding, environment: environment) }
  let_it_be(:service_environment_health) do
    create(:cd_service_environment_health, service: service, environment: environment)
  end

  using RSpec::Parameterized::TableSyntax

  where(:resolver_class, :object, :expected_record) do
    ::Resolvers::Cd::ServicesResolver                  | ref(:application)        | ref(:service)
    ::Resolvers::Cd::ArtifactSourcesResolver           | ref(:service)            | ref(:artifact_source)
    ::Resolvers::Cd::VersionSetsResolver               | ref(:application)        | ref(:version_set)
    ::Resolvers::Cd::RolloutsResolver                  | ref(:application)        | ref(:rollout)
    ::Resolvers::Cd::ApplicationFlowDefinitionsResolver | ref(:application)       | ref(:application_flow_definition)
    ::Resolvers::Cd::VersionsResolver                  | ref(:artifact_source)    | ref(:version)
    ::Resolvers::Cd::VersionSetEntriesResolver         | ref(:version_set)        | ref(:version_set_entry)
    ::Resolvers::Cd::RolloutTransitionsResolver        | ref(:rollout)            | ref(:rollout_transition)
    ::Resolvers::Cd::RolloutEnvironmentsResolver       | ref(:rollout)            | ref(:rollout_environment)
    ::Resolvers::Cd::RolloutStepsResolver              | ref(:rollout)            | ref(:rollout_step)
    ::Resolvers::Cd::DeploymentsResolver               | ref(:rollout_environment) | ref(:deployment)
    ::Resolvers::Cd::DeploymentTransitionsResolver     | ref(:deployment)         | ref(:deployment_transition)
    ::Resolvers::Cd::ServiceEnvironmentHealthsResolver | ref(:environment)        | ref(:service_environment_health)
    ::Resolvers::Cd::EnvironmentDriverBindingsResolver | ref(:environment)        | ref(:driver_binding)
    ::Resolvers::Cd::ApplicationEnvironmentsResolver   | ref(:application)        | ref(:environment)
    ::Resolvers::Cd::ApplicationDeploymentsResolver    | ref(:application)        | ref(:deployment)
    ::Resolvers::Cd::VersionEnvironmentsResolver       | ref(:version)            | ref(:environment)
    ::Resolvers::Cd::ServiceEnvironmentDeployedVersionsResolver | ref(:service_environment_health) | ref(:version)
  end

  with_them do
    subject(:resolved) do
      result = resolve(resolver_class, obj: object, ctx: { current_user: user })
      # VersionEnvironmentsResolver and ServiceEnvironmentDeployedVersionsResolver return
      # batched (lazy) values; the others return a plain relation/array that Lazy.force
      # passes through unchanged.
      ::Gitlab::Graphql::Lazy.force(result)
    end

    context 'when the ai_native_deploy feature flag is enabled' do
      it 'returns the associated records' do
        expect(resolved).to include(expected_record)
      end
    end

    context 'when the ai_native_deploy feature flag is disabled' do
      before do
        stub_feature_flags(ai_native_deploy: false)
      end

      it 'returns nil' do
        expect(resolved).to be_nil
      end
    end
  end
end

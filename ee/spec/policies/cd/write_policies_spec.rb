# frozen_string_literal: true

require 'spec_helper'

# These abilities authorize the create/update GraphQL mutations for the CD
# write layer. They are enabled on the organization and reached through each
# model's policy delegation chain (up to the parent Application/Environment
# and ultimately the Organization).
RSpec.describe 'Cd write policies', feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }

  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:environment) { create(:cd_environment, organization: organization) }
  let_it_be(:service) { create(:cd_service, application: application) }
  let_it_be(:version_set) { create(:cd_version_set, application: application) }
  let_it_be(:rollout) { create(:cd_rollout, version_set: version_set, application: application) }

  using RSpec::Parameterized::TableSyntax

  # Create abilities are authorized against the parent object the new record will
  # belong to (an Application for services/version sets/flow definitions, a
  # Service for artifact sources); update abilities are authorized against the
  # record itself.
  where(:policy_class, :record, :ability) do
    Cd::ApplicationPolicy    | ref(:application)     | :update_cd_application
    Cd::EnvironmentPolicy    | ref(:environment)     | :update_cd_environment
    Cd::ApplicationPolicy    | ref(:application)     | :create_cd_service
    Cd::ServicePolicy        | ref(:service)         | :update_cd_service
    Cd::ServicePolicy        | ref(:service)         | :create_cd_artifact_source
    Cd::ApplicationPolicy    | ref(:application)     | :create_cd_version_set
    Cd::ApplicationPolicy    | ref(:application)     | :create_cd_application_flow_definition
    Cd::RolloutPolicy        | ref(:rollout)         | :resolve_cd_rollout_gate
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

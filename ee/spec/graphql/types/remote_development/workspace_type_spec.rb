# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Workspace'], feature_category: :workspaces do
  let(:fields) do
    %i[
      actual_state
      actual_state_updated_at
      cluster_agent
      created_at
      deployment_resource_version

      desired_state
      desired_state_updated_at
      devfile
      devfile_path
      devfile_ref
      devfile_web_url
      editor
      force_include_all_resources
      id
      max_hours_before_termination
      name
      namespace
      processed_devfile
      project_id
      project_ref
      responded_to_agent_at
      updated_at
      url
      user
      workspace_variables
      workspaces_agent_config_version
    ]
  end

  specify { expect(described_class.graphql_name).to eq('Workspace') }

  specify { expect(described_class).to have_graphql_fields(fields) }

  specify { expect(described_class).to require_graphql_authorizations(:read_workspace) }
end

# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe GitlabSchema.types['WorkspacesAgentConfig'], feature_category: :workspaces do
  let(:fields) do
    %i[
      id cluster_agent project_id enabled dns_zone network_policy_enabled gitlab_workspaces_proxy_namespace
      workspaces_quota workspaces_per_user_quota allow_privilege_escalation use_kubernetes_user_namespaces
      default_runtime_class annotations labels default_resources_per_workspace_container
      max_resources_per_workspace network_policy_egress image_pull_secrets created_at updated_at
    ]
  end

  specify { expect(described_class.graphql_name).to eq('WorkspacesAgentConfig') }

  specify { expect(described_class).to have_graphql_fields(fields) }

  specify { expect(described_class).to require_graphql_authorizations(:read_workspaces_agent_config) }
end

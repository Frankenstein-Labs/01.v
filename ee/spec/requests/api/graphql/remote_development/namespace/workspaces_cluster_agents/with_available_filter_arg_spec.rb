# frozen_string_literal: true

require "spec_helper"
require_relative "./shared"

RSpec.describe "Query.namespace.remote_development_cluster_agents(filter: AVAILABLE)", feature_category: :workspaces do
  let(:filter) { :AVAILABLE }
  let(:agent) { available_agent }
  let(:expected_agents) { [available_agent] }
  let_it_be(:authorized_user_project_access_level) { :developer }
  let_it_be(:authorized_user_namespace_access_level) { nil }
  let_it_be(:unauthorized_user_project_access_level) { :reporter }
  let_it_be(:unauthorized_user_namespace_access_level) { nil }

  include_context "with filter argument"
  include_context "for a Query.namespace.workspaces_cluster_agents query"

  it_behaves_like "multiple agents in namespace query"
end

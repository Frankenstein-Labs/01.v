# frozen_string_literal: true

require "spec_helper"
require_relative "./shared"

RSpec.describe "Query.namespace.remote_development_cluster_agents(filter: DIRECTLY_MAPPED)", feature_category: :workspaces do
  let(:filter) { :DIRECTLY_MAPPED }
  let(:agent) { directly_mapped_agent }
  let(:expected_agents) { [directly_mapped_agent, available_agent] }
  let_it_be(:authorized_user_project_access_level) { nil }
  let_it_be(:authorized_user_namespace_access_level) { :maintainer }
  let_it_be(:unauthorized_user_project_access_level) { nil }
  let_it_be(:unauthorized_user_namespace_access_level) { :developer }

  include_context "with filter argument"
  include_context "for a Query.namespace.remote_development_cluster_agents query"

  it_behaves_like "multiple agents in namespace query"
end

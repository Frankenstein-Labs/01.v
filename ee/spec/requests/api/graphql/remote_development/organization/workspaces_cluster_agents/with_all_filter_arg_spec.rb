# frozen_string_literal: true

require "spec_helper"
require_relative "./shared"

RSpec.describe "Query.organization.workspaces_cluster_agents(filter: ALL)", feature_category: :workspaces do
  let(:filter) { :ALL }
  let(:expected_agents) { [mapped_agent, unmapped_agent] }

  include_context "with agents and users setup in an organization"
  include_context "for a Query.organization.workspaces_cluster_agents query"

  it_behaves_like "multiple agents in organization query"
end

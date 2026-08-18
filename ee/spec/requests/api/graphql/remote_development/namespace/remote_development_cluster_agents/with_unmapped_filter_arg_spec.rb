# frozen_string_literal: true

require 'spec_helper'
require_relative './shared'

RSpec.describe 'Query.namespace.remote_development_cluster_agents(filter: UNMAPPED)', feature_category: :workspaces do
  let(:filter) { :UNMAPPED }
  let(:agent) { unmapped_agent }
  let(:expected_agents) { [unmapped_agent] }
  let_it_be(:authorized_user_project_access_level) { nil }
  let_it_be(:authorized_user_namespace_access_level) { :maintainer }
  let_it_be(:unauthorized_user_project_access_level) { nil }
  let_it_be(:unauthorized_user_namespace_access_level) { :developer }

  include_context "with filter argument"
  include_context "for a Query.namespace.remote_development_cluster_agents query"

  it_behaves_like "multiple agents in namespace query"
end

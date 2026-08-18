# frozen_string_literal: true

require 'spec_helper'
require_relative './shared'

RSpec.describe 'Query.project.clusterAgent.workspaces(actual_states: [GraphQL::Types::String])', feature_category: :workspaces do
  include_context 'with actual_states argument'
  include_context 'for a Query.project.clusterAgent.workspaces query'
  include_context 'with non_matching_workspace associated with same agent'

  it_behaves_like 'multiple workspaces query'
end

# frozen_string_literal: true

require 'spec_helper'
require_relative './shared'

RSpec.describe 'Query.project.clusterAgent.workspaces (with no arguments)', feature_category: :workspaces do
  include_context 'with no arguments'
  include_context 'for a Query.project.clusterAgent.workspaces query'
  include_context 'with non_matching_workspace associated with other agent created'

  it_behaves_like 'multiple workspaces query'
end

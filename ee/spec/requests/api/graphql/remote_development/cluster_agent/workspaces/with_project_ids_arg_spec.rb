# frozen_string_literal: true

require 'spec_helper'
require_relative './shared'

RSpec.describe 'Query.project.clusterAgent.workspaces(project_ids: [::Types::GlobalIDType[Project]!])', feature_category: :workspaces do
  include_context 'with project_ids argument'
  include_context 'for a Query.project.clusterAgent.workspaces query'

  it_behaves_like 'multiple workspaces query'
end

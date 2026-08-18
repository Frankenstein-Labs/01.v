# frozen_string_literal: true

require 'spec_helper'
require_relative './shared'

# NOTE: Even though this `single workspacesAgentConfig` spec only has no fields to test, we still use similar
#       shared examples patterns and structure as the other multi-model query specs, for consistency.

RSpec.describe 'Query.project.clusterAgent.workspacesAgentConfig', feature_category: :workspaces do
  include_context 'for a Query.project.clusterAgent.workspacesAgentConfig query'

  it_behaves_like 'single workspacesAgentConfig query'
end

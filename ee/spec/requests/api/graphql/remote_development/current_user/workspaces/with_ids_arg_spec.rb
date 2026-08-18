# frozen_string_literal: true

require 'spec_helper'
require_relative './shared'

RSpec.describe 'Query.currentUser.workspaces(ids: [RemoteDevelopmentWorkspaceID!])', feature_category: :workspaces do
  include_context 'with ids argument'
  include_context 'for a Query.currentUser.workspaces query'

  it_behaves_like 'multiple workspaces query'
end

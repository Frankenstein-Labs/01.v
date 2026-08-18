# frozen_string_literal: true

require 'spec_helper'
require_relative './shared'

RSpec.describe 'Query.currentUser.workspaces (with no arguments)', feature_category: :workspaces do
  include_context 'with no arguments'
  include_context 'for a Query.currentUser.workspaces query'

  # create workspace owned by different user, to ensure it is not returned by the query
  let_it_be_with_reload(:non_matching_workspace) { create(:workspace, name: 'non-matching-workspace') }

  it_behaves_like 'multiple workspaces query'
end

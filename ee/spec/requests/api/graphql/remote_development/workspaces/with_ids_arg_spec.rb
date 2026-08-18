# frozen_string_literal: true

require 'spec_helper'
require_relative './shared'

RSpec.describe 'Query.workspaces(ids: [RemoteDevelopmentWorkspaceID!])', feature_category: :workspaces do
  include_context 'with ids argument'
  include_context 'for a Query.workspaces query'

  it_behaves_like 'multiple workspaces query', authorized_user_is_admin: true
end

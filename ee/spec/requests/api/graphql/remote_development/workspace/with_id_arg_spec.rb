# frozen_string_literal: true

require 'spec_helper'
require_relative './shared'

# NOTE: Even though this single-workspace spec only has one field scenario to test, we still use similar
#       shared examples patterns and structure as the other multi-workspace query specs, for consistency.

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe 'Query.workspace(id: RemoteDevelopmentWorkspaceID!)', feature_category: :workspaces do
  include_context 'with id arg'
  include_context 'for a Query.workspace query'

  context 'with non-admin user' do
    let_it_be(:authorized_user) { workspace.user }
    let_it_be(:unauthorized_user) { create(:user) }

    it_behaves_like 'single workspace query'
  end

  context 'with admin user' do
    let_it_be(:authorized_user) { create(:admin) }
    let_it_be(:unauthorized_user) { create(:user) }

    it_behaves_like 'single workspace query', authorized_user_is_admin: true
  end
end

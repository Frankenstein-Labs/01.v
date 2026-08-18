# frozen_string_literal: true

require 'spec_helper'
require_relative './shared'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe 'Query.workspace.workspaceVariables (with no arguments)', feature_category: :workspaces do
  include_context 'for a Query.workspace.workspaceVariables query'

  context 'with non-admin user' do
    let_it_be(:authorized_user) { workspace.user }
    let_it_be(:unauthorized_user) { create(:user) }

    it_behaves_like 'multiple workspace_variables query'
  end

  context 'with admin user' do
    let_it_be(:authorized_user) { create(:admin) }
    let_it_be(:unauthorized_user) { create(:user) }

    it_behaves_like 'multiple workspace_variables query', authorized_user_is_admin: true
  end
end

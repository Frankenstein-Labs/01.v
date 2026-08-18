# frozen_string_literal: true

require_relative 'helper_shared_examples'

# In another spec file that might test a different method with similar behavior
RSpec.describe RemoteDevelopment::TreeHelper, feature_category: :workspaces do
  include_examples "workspace_helper_data", helper_method: :vue_tree_workspace_data
end

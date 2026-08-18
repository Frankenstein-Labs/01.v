# frozen_string_literal: true

require 'spec_helper'
require_relative './shared'

RSpec.describe 'Query.workspaces (with no arguments)', feature_category: :workspaces do
  include_context 'with no arguments'
  include_context 'for a Query.workspaces query'

  it_behaves_like 'multiple workspaces query',
    authorized_user_is_admin: true,
    expected_error_regex: /At least one filter argument must be provided/
end

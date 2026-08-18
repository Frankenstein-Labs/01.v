# frozen_string_literal: true

require 'spec_helper'
require_relative './shared'

RSpec.describe 'Query.workspaces(actual_states: [GraphQL::Types::String])', feature_category: :workspaces do
  include_context 'with actual_states argument'
  include_context 'for a Query.workspaces query'

  it_behaves_like 'multiple workspaces query', authorized_user_is_admin: true

  context 'with deprecated include_actual_states arg' do
    let(:args) { { include_actual_states: [matching_actual_state] } }

    it_behaves_like 'multiple workspaces query', authorized_user_is_admin: true
  end
end

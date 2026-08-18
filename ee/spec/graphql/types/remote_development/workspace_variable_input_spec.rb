# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['WorkspaceVariableInput'], feature_category: :workspaces do
  let(:arguments) do
    %i[
      key
      type
      value
      variableType
    ]
  end

  specify { expect(described_class.graphql_name).to eq('WorkspaceVariableInput') }
  specify { expect(described_class.arguments.deep_symbolize_keys.keys).to(match_array(arguments)) }
  specify { expect(described_class).to have_graphql_arguments(arguments) }
end

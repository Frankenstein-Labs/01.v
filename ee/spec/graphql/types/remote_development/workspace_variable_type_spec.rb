# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['WorkspaceVariable'], feature_category: :workspaces do
  let(:fields) do
    %i[
      id key value variable_type created_at updated_at
    ]
  end

  specify { expect(described_class.graphql_name).to eq('WorkspaceVariable') }

  specify { expect(described_class).to have_graphql_fields(fields) }

  specify { expect(described_class).to require_graphql_authorizations(:read_workspace_variable) }
end

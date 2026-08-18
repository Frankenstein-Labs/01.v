# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['WorkspaceResources'], feature_category: :workspaces do
  let(:fields) do
    %i[
      limits
      requests
    ]
  end

  specify { expect(described_class.graphql_name).to eq('WorkspaceResources') }
  specify { expect(described_class).to have_graphql_fields(fields) }
end

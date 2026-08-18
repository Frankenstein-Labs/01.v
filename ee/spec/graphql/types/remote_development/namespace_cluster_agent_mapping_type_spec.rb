# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['NamespaceClusterAgentMapping'], feature_category: :workspaces do
  let(:fields) do
    %i[id namespace_id cluster_agent_id creator_id created_at updated_at]
  end

  specify { expect(described_class.graphql_name).to eq('NamespaceClusterAgentMapping') }

  specify { expect(described_class).to have_graphql_fields(fields) }
end

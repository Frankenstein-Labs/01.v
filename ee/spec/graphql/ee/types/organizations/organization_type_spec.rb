# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Organization'], feature_category: :organization do
  let_it_be(:expected_fields) do
    %w[workspacesClusterAgents workItemSettings]
  end

  specify { expect(described_class).to include_graphql_fields(*expected_fields) }
end

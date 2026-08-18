# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ResourceQuotas'], feature_category: :workspaces do
  let(:fields) do
    %i[
      cpu
      memory
    ]
  end

  specify { expect(described_class.graphql_name).to eq('ResourceQuotas') }
  specify { expect(described_class).to have_graphql_fields(fields) }
end

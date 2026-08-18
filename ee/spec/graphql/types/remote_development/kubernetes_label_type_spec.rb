# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['KubernetesLabel'], feature_category: :workspaces do
  let(:fields) do
    %i[
      key
      value
    ]
  end

  specify { expect(described_class.graphql_name).to eq('KubernetesLabel') }
  specify { expect(described_class).to have_graphql_fields(fields) }
end

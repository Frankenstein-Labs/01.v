# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ImagePullSecrets'], feature_category: :workspaces do
  let(:fields) do
    %i[
      name
      namespace
    ]
  end

  specify { expect(described_class.graphql_name).to eq('ImagePullSecrets') }
  specify { expect(described_class).to have_graphql_fields(fields) }
end

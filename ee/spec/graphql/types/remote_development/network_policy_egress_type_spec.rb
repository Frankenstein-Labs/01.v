# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['NetworkPolicyEgress'], feature_category: :workspaces do
  let(:fields) do
    %i[
      allow
      except
    ]
  end

  specify { expect(described_class.graphql_name).to eq('NetworkPolicyEgress') }
  specify { expect(described_class).to have_graphql_fields(fields) }
end

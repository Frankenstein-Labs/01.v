# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['UserMemberRole'], feature_category: :permissions do
  let(:fields) do
    %w[id user memberRole]
  end

  specify { expect(described_class.graphql_name).to eq('UserMemberRole') }

  specify { expect(described_class).to have_graphql_fields(fields) }
end

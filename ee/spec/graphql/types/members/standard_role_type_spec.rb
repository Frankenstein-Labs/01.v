# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['StandardRole'], feature_category: :system_access do
  let(:fields) { %w[id accessLevel name description detailsPath] }

  specify { expect(described_class.graphql_name).to eq('StandardRole') }

  specify { expect(described_class).to have_graphql_fields(fields) }
end

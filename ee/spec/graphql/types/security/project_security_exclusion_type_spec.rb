# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ProjectSecurityExclusion'], feature_category: :secret_detection do
  it { expect(described_class.graphql_name).to eq('ProjectSecurityExclusion') }

  it do
    expect(described_class).to have_graphql_fields(
      :id,
      :scanner,
      :type,
      :value,
      :description,
      :active,
      :created_at,
      :updated_at
    )
  end
end

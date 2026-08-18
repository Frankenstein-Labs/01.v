# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['VirtualRegistriesSetting'], :aggregate_failures, feature_category: :virtual_registry do
  it 'includes virtual registries setting field' do
    expected_fields = %w[
      enabled
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  it { expect(described_class).to require_graphql_authorizations(:admin_virtual_registry) }

  it { expect(described_class.graphql_name).to eq('VirtualRegistriesSetting') }

  it { expect(described_class.description).to eq('Root group level virtual registries settings') }
end

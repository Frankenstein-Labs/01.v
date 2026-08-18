# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['MavenUpstreamRule'], feature_category: :virtual_registry do
  subject { described_class }

  it { is_expected.to require_graphql_authorizations(:read_virtual_registry) }
  it { is_expected.to have_attributes(interfaces: include(Types::VirtualRegistries::Upstream::RuleInterface)) }

  it 'exposes the expected fields' do
    expected_field_types = {
      id: 'VirtualRegistriesPackagesMavenUpstreamRuleID!',
      pattern: 'String!',
      patternType: 'MavenUpstreamPatternType!',
      targetCoordinate: 'MavenUpstreamTargetCoordinate!',
      createdAt: 'Time!'
    }

    expect(described_class).to have_graphql_fields(*expected_field_types.keys)
    expected_field_types.each do |field_name, type_signature|
      expect(described_class.fields[field_name.to_s].type.to_type_signature).to eq(type_signature)
    end
  end
end

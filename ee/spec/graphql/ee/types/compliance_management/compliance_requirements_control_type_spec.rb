# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ComplianceRequirementsControl'], feature_category: :compliance_management do
  subject { described_class }

  let(:expected_fields) do
    %w[
      id
      name
      expression
      control_type
      external_control_name
      external_url
      ping_enabled
      compliance_requirement
    ]
  end

  it { is_expected.to have_graphql_fields(expected_fields) }

  describe 'ping_enabled field' do
    let(:ping_enabled_field) { described_class.fields['pingEnabled'] }

    it 'has the correct type' do
      expect(ping_enabled_field.type.of_type).to eq(GraphQL::Types::Boolean)
    end

    it 'is not nullable' do
      expect(ping_enabled_field.type.non_null?).to be(true)
    end

    it 'has the correct description' do
      expect(ping_enabled_field.description).to eq('Whether ping is enabled for external controls.')
    end
  end
end

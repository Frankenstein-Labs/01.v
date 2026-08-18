# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::Controls::SchemaGenerator, feature_category: :compliance_management do
  let(:registry) { ComplianceManagement::ComplianceFramework::Controls::Registry }

  describe '.generate' do
    let(:schema) { described_class.generate }

    it 'generates a valid JSON schema' do
      expect(schema['$schema']).to eq('http://json-schema.org/draft-07/schema#')
      expect(schema['title']).to eq('Compliance Requirements Control Expression Schema')
      expect(schema['type']).to eq('object')
      expect(schema['properties']).to be_present
      expect(schema['required']).to eq(%w[field operator value])
      expect(schema['additionalProperties']).to be(false)
    end

    it 'includes all control fields in the schema enum' do
      expect(schema['properties']['field']['enum']).to include(*registry.schema_fields)
    end

    it 'includes all valid operators in the schema' do
      all_operators = registry::CONTROL_TYPES.values.flat_map { |t| t[:valid_operators] }.uniq

      expect(schema['properties']['operator']['enum']).to match_array(all_operators)
    end

    it 'creates type-specific validation conditions for boolean fields' do
      boolean_fields = registry.schema_field_types[:boolean]&.map { |c| (c[:field_id] || c[:id]).to_s } || []

      boolean_condition = schema['allOf'].find do |condition|
        condition.dig('if', 'properties', 'field', 'enum')&.sort == boolean_fields.sort
      end

      expect(boolean_condition).to be_present
      expect(boolean_condition.dig('then', 'properties', 'value', 'type')).to eq('boolean')
      expect(boolean_condition.dig('then', 'properties', 'operator', 'enum'))
        .to eq(registry::CONTROL_TYPES[:boolean][:valid_operators])
    end

    it 'creates type-specific validation conditions for numeric fields' do
      numeric_fields = registry.schema_field_types[:number]&.map { |c| (c[:field_id] || c[:id]).to_s } || []

      numeric_condition = schema['allOf'].find do |condition|
        condition.dig('if', 'properties', 'field', 'enum')&.sort == numeric_fields.sort
      end

      expect(numeric_condition).to be_present
      expect(numeric_condition.dig('then', 'properties', 'value', 'type')).to eq('number')
      expect(numeric_condition.dig('then', 'properties', 'operator', 'enum'))
        .to eq(registry::CONTROL_TYPES[:numeric][:valid_operators])
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Projects::DuoContextExclusionSettingsType, feature_category: :duo_code_review do
  it 'has all the required fields' do
    expect(described_class).to have_graphql_fields(:exclusion_rules)
  end

  describe '.authorization_scopes' do
    it 'allows ai_workflows scope token' do
      expect(described_class.authorization_scopes).to include(:ai_workflows)
    end
  end

  describe 'fields with :ai_workflows scope' do
    %w[exclusionRules].each do |field_name|
      it "includes :ai_workflows scope for the #{field_name} field" do
        field = described_class.fields[field_name]
        expect(field.instance_variable_get(:@scopes)).to include(:ai_workflows, :api, :read_api)
      end
    end
  end
end

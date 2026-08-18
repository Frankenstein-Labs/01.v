# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiNamespaceSettings'], feature_category: :duo_chat do
  it 'has specific fields' do
    expected_fields = %w[
      aiCatalogRestrictedToGroupHierarchy
      duoWorkflowMcpEnabled
      promptInjectionProtectionLevel
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe 'duoWorkflowMcpEnabled field' do
    it 'returns a boolean' do
      field = described_class.fields['duoWorkflowMcpEnabled']
      expect(field.type).to be_a(GraphQL::Schema::NonNull)
      expect(field.type.of_type).to eq(GraphQL::Types::Boolean)
    end
  end

  describe 'promptInjectionProtectionLevel field' do
    it 'returns the PromptInjectionProtectionLevel enum' do
      field = described_class.fields['promptInjectionProtectionLevel']
      expect(field.type).to be_a(GraphQL::Schema::NonNull)
      expect(field.type.of_type).to eq(GitlabSchema.types['PromptInjectionProtectionLevel'])
    end
  end

  describe 'fields with :ai_workflows scope' do
    %w[duoWorkflowMcpEnabled promptInjectionProtectionLevel].each do |field_name|
      it "includes :ai_workflows scope for the #{field_name} field" do
        field = described_class.fields[field_name]
        expect(field.instance_variable_get(:@scopes)).to include(:ai_workflows)
      end
    end
  end

  describe 'authorization_scopes' do
    it 'includes :ai_workflows in authorization scopes' do
      expect(described_class.authorization_scopes).to eq([:api, :read_api, :ai_workflows])
    end
  end
end

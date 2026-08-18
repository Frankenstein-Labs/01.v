# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CustomFieldSelectOption'], feature_category: :team_planning do
  let(:fields) do
    %i[id value]
  end

  specify { expect(described_class.graphql_name).to eq('CustomFieldSelectOption') }

  specify { expect(described_class).to have_graphql_fields(fields) }

  describe '.authorization_scopes' do
    it 'allows ai_workflows scope token' do
      expect(described_class.authorization_scopes).to include(:ai_workflows)
    end
  end

  describe 'fields with :ai_workflows scope' do
    %w[id value].each do |field_name|
      it "includes :ai_workflows scope for the #{field_name} field" do
        expect(described_class.fields[field_name]).to include_graphql_scopes(:ai_workflows)
      end
    end
  end
end

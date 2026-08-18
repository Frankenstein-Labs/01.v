# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CustomField'], feature_category: :team_planning do
  let(:fields) do
    %i[id name field_type active created_at created_by updated_at updated_by select_options work_item_types]
  end

  specify { expect(described_class.graphql_name).to eq('CustomField') }

  specify { expect(described_class).to have_graphql_fields(fields) }

  specify { expect(described_class).to require_graphql_authorizations(:read_custom_field) }

  describe '.authorization_scopes' do
    it 'allows ai_workflows scope token' do
      expect(described_class.authorization_scopes).to include(:ai_workflows)
    end
  end

  describe 'fields with :ai_workflows scope' do
    %w[id name fieldType active].each do |field_name|
      it "includes :ai_workflows scope for the #{field_name} field" do
        expect(described_class.fields[field_name]).to include_graphql_scopes(:ai_workflows)
      end
    end
  end
end

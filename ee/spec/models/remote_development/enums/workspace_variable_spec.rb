# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe RemoteDevelopment::Enums::WorkspaceVariable, feature_category: :workspaces do
  describe "WORKSPACE_VARIABLE_TYPES_FOR_GRAPHQL constant" do
    subject(:constant) do
      described_class::WORKSPACE_VARIABLE_TYPES_FOR_GRAPHQL
    end

    it "has correct value" do
      expect(constant).to eq({ "ENVIRONMENT" => 0 })
    end
  end
end

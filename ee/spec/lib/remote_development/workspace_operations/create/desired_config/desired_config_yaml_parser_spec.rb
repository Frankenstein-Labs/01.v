# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::DesiredConfigYamlParser, feature_category: :workspaces do
  describe "#parse" do
    # noinspection KubernetesNonEditableKeys
    let(:desired_config_yaml) do
      <<~YAML
        key1:
          k1: v1
        ---
        key2:
          k2: v2
      YAML
    end

    let(:expected_array) do
      [
        { key1: { k1: "v1" } },
        { key2: { k2: "v2" } }
      ]
    end

    let(:context) { { desired_config_yaml: desired_config_yaml } }

    subject(:result) { described_class.parse(context) }

    it "transforms the YAML to an array of hashes and adds it to the context" do
      expect(result[:desired_config_array]).to eq(expected_array)
    end
  end
end

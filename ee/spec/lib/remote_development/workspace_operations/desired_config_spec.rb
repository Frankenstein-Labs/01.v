# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe RemoteDevelopment::WorkspaceOperations::DesiredConfig, feature_category: :workspaces do
  include_context "with remote development shared fixtures"

  subject(:desired_config) { described_class.new(desired_config_array: desired_config_array) }

  describe 'validations' do
    shared_examples 'invalid non-array config' do |value_description, test_value|
      context "when desired_config is #{value_description}" do
        let(:desired_config_array) { test_value }

        it 'fails' do
          expect(desired_config).to be_invalid
          expect(desired_config.errors[:desired_config_array]).to include("value at root is not an array")
        end
      end
    end

    include_examples 'invalid non-array config', 'a hash', {}
    include_examples 'invalid non-array config', 'nil', nil

    context 'when desired_config_array is empty' do
      let(:desired_config_array) { [] }

      it 'fails' do
        expect(desired_config).to be_invalid
        expect(desired_config.errors[:desired_config_array]).to include("can't be blank")
      end
    end

    context 'when desired_config is valid' do
      let(:desired_config_array) { create_desired_config_array }

      it 'passes' do
        expect(desired_config).to be_valid
      end
    end

    context 'when items in desired_config violate JSON schema' do
      let(:desired_config_array) do
        create_desired_config_array.map do |config|
          config.merge("invalid-field" => "value")
        end
      end

      it 'fails', :unlimited_max_formatted_output_length do
        expect(desired_config).to be_invalid

        # This validation does not fail for other kinds except for ConfigMap
        # because they do not have "additionalProperties": false
        expect(desired_config.errors[:desired_config_array])
          .to include(
            "object property at `/0/invalid-field` is a disallowed additional property",
            "object property at `/7/invalid-field` is a disallowed additional property",
            "object property at `/8/invalid-field` is a disallowed additional property"
          )
      end
    end
  end

  describe "#symbolized_desired_config_array" do
    let(:desired_config_array) { create_desired_config_array }

    it { expect(desired_config.symbolized_desired_config_array).to eq(desired_config_array) }
    it { expect(desired_config.symbolized_desired_config_array).to be_kind_of(Array) }
  end

  describe '#==(other)' do
    let(:desired_config_array) { create_desired_config_array }

    context 'when both DesiredConfig instances have the same desired_config_array' do
      let(:other_desired_config) { described_class.new(desired_config_array: create_desired_config_array) }

      it { expect(desired_config == other_desired_config).to be(true) }
    end

    context 'when DesiredConfig instances have different desired_config_array' do
      let(:other_desired_config) { described_class.new(desired_config_array: []) }

      it { expect(desired_config == other_desired_config).to be(false) }
    end
  end

  describe "#diff(other)" do
    let(:desired_config_array) { create_desired_config_array }

    context 'when other is not of DesiredConfig type' do
      using RSpec::Parameterized::TableSyntax
      where(:other_value, :actual_class_name) do
        # @formatter:off - RubyMine does not format table well
        []  | 'Array'
        nil | 'NilClass'
        # @formatter:on
      end

      with_them do
        it 'raises an error with a clear message' do
          expect { desired_config.diff(other_value) }
            .to raise_error(ArgumentError, "Expected #{desired_config.class}, got #{actual_class_name}")
        end
      end
    end

    context "when the other instance has same desired_config_array" do
      let(:other_desired_config) { described_class.new(desired_config_array: create_desired_config_array) }

      it "returns an empty array" do
        expect(desired_config.diff(other_desired_config)).to eq([])
      end
    end

    context "when the other instance has a different desired_config_array" do
      let(:other_desired_config) do
        config_array = create_desired_config_array
        config_array.pop
        described_class.new(desired_config_array: config_array)
      end

      let(:expected_difference) do
        [
          [
            "-", "[11]",
            {
              apiVersion: "v1",
              data: {},
              kind: "Secret",
              metadata: {
                annotations: {
                  environment: "production",
                  team: "engineering",
                  "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
                  "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.dev.test",
                  "workspaces.gitlab.com/id": "993",
                  "workspaces.gitlab.com/max-resources-per-workspace-sha256":
                    "24aefc317e11db538ede450d1773e273966b9801b988d49e1219f2a9bf8e7f66"
                },
                labels: {
                  app: "workspace",
                  tier: "development",
                  "agent.gitlab.com/id": "991"
                },
                name: "workspace-991-990-fedcba-file",
                namespace: "gl-rd-ns-991-990-fedcba"
              }
            }
          ]
        ]
      end

      let(:difference) { desired_config.diff(other_desired_config) }

      it "returns array with the difference" do
        expect(difference).not_to be_empty
        expect(difference).to eq(expected_difference)
      end
    end
  end
end

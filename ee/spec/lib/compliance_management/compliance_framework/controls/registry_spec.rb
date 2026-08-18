# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::Controls::Registry, feature_category: :compliance_management do
  describe '.validate_registry!' do
    it 'delegates validation to RegistryValidator' do
      expect(ComplianceManagement::ComplianceFramework::Controls::RegistryValidator).to receive(:validate!)
        .with(described_class.controls, described_class::SPECIAL_CONTROLS)

      begin
        described_class.validate_registry!
      rescue ComplianceManagement::ComplianceFramework::Controls::RegistryValidator::RegistryValidationError
      end
    end

    it 'raises and error if RegistryValidator errors' do
      error_message = "Validation failed!"
      validation_error = ComplianceManagement::ComplianceFramework::Controls::RegistryValidator::RegistryValidationError
      allow(ComplianceManagement::ComplianceFramework::Controls::RegistryValidator)
        .to receive(:validate!)
        .and_raise(validation_error, error_message)

      expect { described_class.validate_registry! }.to raise_error(validation_error, error_message)
    end
  end

  describe '.controls' do
    it 'loads controls from YAML' do
      expect(described_class.controls).to be_a(Hash)
      expect(described_class.controls).not_to be_empty
    end

    it 'loads types correctly' do
      boolean_control = described_class.controls[:scanner_sast_running]
      numeric_control = described_class.controls[:minimum_approvals_required_2]

      expect(boolean_control[:type][:type]).to eq(:boolean)
      expect(numeric_control[:type][:type]).to eq(:number)

      project_visibility_control = described_class.controls[:project_visibility_not_internal]
      expect(project_visibility_control[:type][:type]).to eq(:boolean)
    end
  end

  describe 'REGISTRY structure' do
    let(:yaml_path) { Rails.root.join("ee/config/compliance_management/compliance_controls.yml") }
    let(:yaml_data) { YAML.safe_load(File.read(yaml_path), symbolize_names: true) }
    let(:expected_ids) { yaml_data[:controls].keys }

    it 'contains all expected control IDs from YAML' do
      expect(described_class.controls.keys).to match_array(expected_ids)
    end

    it 'preserves the order of controls from YAML' do
      expect(described_class.controls.keys).to eq(expected_ids)
    end
  end

  describe '.default_operator_for_control' do
    let(:control_with_operator) do
      id = described_class.controls.find { |_, data| data[:compliant_operator].present? }.first
      described_class.find_by_name(id)
    end

    let(:control_without_operator) do
      control = control_with_operator.dup
      control.delete(:compliant_operator)
      control
    end

    it 'returns the specified operator when present' do
      expect(described_class.default_operator_for_control(control_with_operator))
        .to eq(control_with_operator[:compliant_operator])
    end

    it 'defaults to "=" when no operator is specified' do
      expect(described_class.default_operator_for_control(control_without_operator)).to eq('=')
    end
  end

  describe '.valid_operators_for_field' do
    let(:boolean_control_id) do
      described_class.controls.find { |_, data| data[:type][:type] == :boolean }.first
    end

    let(:numeric_control_id) do
      described_class.controls.find { |_, data| data[:type][:type] == :number }.first
    end

    it 'returns the correct operators for boolean fields' do
      control = described_class.controls[boolean_control_id]
      field_id = control[:field_id] || boolean_control_id

      expect(described_class.valid_operators_for_field(field_id))
        .to eq(described_class::CONTROL_TYPES[:boolean][:valid_operators])
    end

    it 'returns the correct operators for numeric fields' do
      control = described_class.controls[numeric_control_id]
      field_id = control[:field_id] || numeric_control_id

      expect(described_class.valid_operators_for_field(field_id))
        .to eq(described_class::CONTROL_TYPES[:numeric][:valid_operators])
    end

    it 'defaults to ["="] for unknown fields' do
      expect(described_class.valid_operators_for_field(:unknown_field)).to eq(['='])
    end
  end

  describe '.enum_definitions' do
    it 'maps controls to their enum values' do
      described_class.controls.each do |id, data|
        expect(described_class.enum_definitions[id]).to eq(data[:enum_value])
      end
    end

    it 'includes external_control with fixed value' do
      expect(described_class.enum_definitions[:external_control]).to eq(10000)
    end

    context 'when adding new controls' do
      let(:original_controls) { described_class.controls }

      before do
        allow(described_class).to receive(:controls).and_return(
          original_controls.merge(
            new_test_control: {
              name: 'Test Control',
              type: described_class::CONTROL_TYPES[:boolean],
              compliant_value: true,
              field_method: :test_method?,
              enum_value: 17
            }
          )
        )
      end

      it 'assigns new controls based on their explicit enum value' do
        expect(described_class.enum_definitions[:new_test_control]).to eq(17)
      end

      it 'preserves existing values for controls' do
        expect(described_class.enum_definitions[:scanner_sast_running]).to eq(0)
        expect(described_class.enum_definitions[:auth_sso_enabled]).to eq(6)
      end
    end
  end

  describe '.field_mappings' do
    it 'maps all control fields to their methods' do
      mappings = described_class.field_mappings

      expect(mappings['default_branch_protected']).to eq(:default_branch_protected?)
      expect(mappings['project_visibility_not_internal']).to eq(:project_visibility_not_internal?)
    end

    it 'handles field_id when present' do
      _, control_data = described_class.controls.find { |_, data| data[:field_id].present? }

      expect(described_class.field_mappings[control_data[:field_id].to_s])
        .to eq(control_data[:field_method])
    end
  end

  describe '.control_definitions' do
    let(:definitions) { described_class.control_definitions }

    it 'includes all controls' do
      expect(definitions.size).to eq(described_class.controls.size)
    end

    it 'formats control definitions correctly' do
      first_id, first_data = described_class.controls.first
      first_def = definitions.find { |d| d[:id] == first_id.to_s }

      expect(first_def[:id]).to eq(first_id.to_s)
      expect(first_def[:name]).to eq(first_data[:name])
      expect(first_def[:expression]).to be_a(Hash)
      expect(first_def[:expression][:field]).to eq((first_data[:field_id] || first_id).to_s)
      expect(first_def[:expression][:value]).to eq(first_data[:compliant_value])
    end
  end

  describe '.find_by_name' do
    it 'finds a control by its name' do
      control = described_class.find_by_name(:default_branch_protected)

      expect(control).to be_present
      expect(control[:name]).to eq('Default branch protected')
    end

    it 'returns empty hash for unknown name' do
      expect(described_class.find_by_name(:unknown_control)).to eq({})
    end
  end

  describe '.find_by_field_id' do
    it 'finds a control by its field ID' do
      control = described_class.find_by_field_id(:project_visibility_not_internal)

      expect(control).to be_present
      expect(control[:id]).to eq(:project_visibility_not_internal)
    end

    it 'finds a control by its ID when field_id is not present' do
      control = described_class.find_by_field_id(:default_branch_protected)

      expect(control).to be_present
      expect(control[:id]).to eq(:default_branch_protected)
    end

    it 'returns empty hash for unknown field_id' do
      expect(described_class.find_by_field_id(:unknown_field)).to eq({})
    end
  end

  describe '.load_registry' do
    let(:test_root) { Pathname.new(Dir.mktmpdir) }
    let(:yaml_path) do
      path = test_root.join('ee/config/compliance_management/compliance_controls.yml')
      FileUtils.mkdir_p(File.dirname(path))
      path
    end

    let(:rails_double) { class_double(Rails, root: test_root) }

    before do
      stub_const('Rails', rails_double)
    end

    after do
      FileUtils.rm_rf(test_root)
    end

    context 'when the YAML file exists' do
      let(:valid_yaml_content) do
        {
          controls: {
            test_control: {
              name: 'Test Control',
              type: 'boolean',
              compliant_value: true,
              field_method: 'test_method?',
              enum_value: 100
            }
          }
        }.to_yaml
      end

      before do
        File.write(yaml_path, valid_yaml_content)
      end

      after do
        FileUtils.rm_f(yaml_path)
      end

      it 'loads and processes the registry data' do
        registry = described_class.send(:load_registry)

        expect(registry).to be_frozen
        expect(registry[:test_control]).to include(
          type: described_class::CONTROL_TYPES[:boolean]
        )
        expect(registry[:test_control][:field_method]).to eq(:test_method?)
      end
    end

    context 'when the YAML file does not exist' do
      before do
        FileUtils.rm_f(yaml_path)
      end

      it 'raises an error with specific message' do
        expected_message = "Compliance controls YAML file not found at #{yaml_path}. " \
          "This file is required for defining compliance controls."

        expect { described_class.send(:load_registry) }
          .to raise_error(RuntimeError, expected_message)
      end
    end

    context 'when YAML data is invalid' do
      before do
        File.write(yaml_path, "controls:")
      end

      after do
        FileUtils.rm_f(yaml_path)
      end

      it 'raises an error for empty controls' do
        expect { described_class.send(:load_registry) }
          .to raise_error(RuntimeError, "Invalid or empty controls data in YAML file")
      end
    end
  end
end

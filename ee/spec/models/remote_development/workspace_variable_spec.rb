# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::WorkspaceVariable, feature_category: :workspaces do
  let(:key) { 'key_1' }
  let(:current_value) { 'value_1' }
  let(:value) { current_value }
  let(:variable_type_environment) { RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE }
  let(:variable_type_file) { RemoteDevelopment::Enums::WorkspaceVariable::FILE_TYPE }
  let(:variable_type) { variable_type_file }
  let(:variable_type_values) do
    [
      variable_type_environment,
      variable_type_file
    ]
  end

  let_it_be(:workspace) { create(:workspace, :without_workspace_variables) }

  subject(:workspace_variable) do
    create(:workspace_variable, workspace: workspace, key: key, value: value, variable_type: variable_type)
  end

  describe 'associations' do
    it { is_expected.to belong_to(:workspace) }

    it 'has correct associations from factory' do
      expect(workspace_variable.workspace).to eq(workspace)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_length_of(:key).is_at_most(255) }
    it { is_expected.to validate_presence_of(:variable_type) }
    it { is_expected.to validate_inclusion_of(:variable_type).in_array(variable_type_values) }

    describe 'value length' do
      context 'with environment variable type' do
        let(:max_length) { described_class::MAX_ENVIRONMENT_VALUE_LENGTH }

        it 'is valid when value is at the limit' do
          workspace_variable = build(:workspace_variable, workspace: workspace,
            variable_type: variable_type_environment,
            value: 'a' * max_length)
          expect(workspace_variable).to be_valid
        end

        it 'is invalid when value exceeds the limit' do
          workspace_variable = build(:workspace_variable, workspace: workspace,
            variable_type: variable_type_environment,
            value: 'a' * (max_length + 1))
          expect(workspace_variable).not_to be_valid
          expect(workspace_variable.errors[:value]).to include(
            /The value of the provided variable exceeds the #{max_length} character limit/
          )
        end

        it 'does not re-validate length for existing records with oversized values' do
          record = build(:workspace_variable, workspace: workspace,
            variable_type: variable_type_environment,
            value: 'a' * (max_length + 1))
          record.save!(validate: false)
          expect(record).to be_valid
        end
      end

      context 'with file variable type' do
        let(:max_length) { described_class::MAX_FILE_VALUE_LENGTH }

        it 'is valid when value is at the limit' do
          workspace_variable = build(:workspace_variable, workspace: workspace,
            variable_type: variable_type_file,
            value: 'a' * max_length)
          expect(workspace_variable).to be_valid
        end

        it 'is invalid when value exceeds the limit' do
          workspace_variable = build(:workspace_variable, workspace: workspace,
            variable_type: variable_type_file,
            value: 'a' * (max_length + 1))
          expect(workspace_variable).not_to be_valid
          expect(workspace_variable.errors[:value]).to include(
            /The value of the provided variable exceeds the #{max_length} character limit/
          )
        end

        it 'allows values that exceed environment variable limit' do
          workspace_variable = build(:workspace_variable, workspace: workspace,
            variable_type: variable_type_file,
            value: 'a' * (described_class::MAX_ENVIRONMENT_VALUE_LENGTH + 1))
          expect(workspace_variable).to be_valid
        end

        it 'does not re-validate length for existing records with oversized values' do
          record = build(:workspace_variable, workspace: workspace,
            variable_type: variable_type_file,
            value: 'a' * (max_length + 1))
          record.save!(validate: false)
          expect(record).to be_valid
        end
      end
    end
  end

  describe '#key' do
    it 'allows keys with alphanumeric characters, hyphens, underscores, and periods' do
      %w[aA1-_.].each do |key|
        workspace_variable = build(:workspace_variable, workspace: workspace, key: key)

        expect(workspace_variable).to be_valid
      end
    end

    it 'rejects keys with special characters other than alphanumeric, hyphens, underscores, and periods' do
      %w[= $/@!*].each do |key|
        workspace_variable = build(:workspace_variable, workspace: workspace, key: key)

        expect(workspace_variable).not_to be_valid
        expect(workspace_variable.errors[:key]).to include('must contain only alphanumeric characters, -, _ or .')
      end
    end
  end

  describe '#value' do
    it 'can be decrypted' do
      expect(workspace_variable.value).to eq(value)
    end

    describe 'can be empty' do
      let(:current_value) { '' }

      it 'is saved' do
        expect(workspace_variable.value).to eq(value)
      end
    end
  end

  describe 'scopes' do
    describe 'with_variable_type_environment' do
      let(:variable_type) { variable_type_environment }

      it 'returns the record' do
        expect(described_class.with_variable_type_environment).to eq([workspace_variable])
      end
    end

    describe 'with_variable_type_file' do
      let(:variable_type) { variable_type_file }

      it 'returns the record' do
        expect(described_class.with_variable_type_file).to eq([workspace_variable])
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ControlExpression, feature_category: :compliance_management do
  let(:id) { 'test_id' }
  let(:name) { 'Test Control' }
  let(:expression) { { field: 'test_field', operator: '=', value: true } }

  subject(:control_expression) { described_class.new(id: id, name: name, expression: expression) }

  describe 'class inclusions' do
    it 'includes GlobalID::Identification' do
      expect(described_class.included_modules).to include(GlobalID::Identification)
    end
  end

  describe '.predefined_controls' do
    it 'returns a hash' do
      expect(described_class.predefined_controls).to be_a(Array)
    end

    it 'memoizes the result' do
      described_class.clear_memoization(:predefined_controls)

      expect(::Gitlab::Json).to receive(:parse).once.and_call_original

      3.times { described_class.predefined_controls }
    end
  end

  describe '.find' do
    it 'returns a ControlExpression instance for the matching id' do
      result = described_class.find('scanner_sast_running')

      expect(result).to be_a(described_class)
      expect(result.id).to eq('scanner_sast_running')
      expect(result.name).to eq('SAST running')
      expect(result.expression).to eq({ field: 'scanner_sast_running', operator: '=', value: true })
    end

    it 'returns a ControlExpression with numeric comparison operator' do
      result = described_class.find('minimum_approvals_required_2')

      expect(result).to be_a(described_class)
      expect(result.id).to eq('minimum_approvals_required_2')
      expect(result.name).to eq('At least two approvals')
      expect(result.expression).to eq({ field: 'minimum_approvals_required', operator: '>=', value: 2 })
    end

    context 'when control is not found' do
      it 'raises an error' do
        expect(described_class.find('non_existent_id')).to be_nil
      end
    end
  end

  describe '#matches_expression?' do
    context 'with boolean expressions' do
      let(:id) { 'scanner_sast_running' }
      let(:name) { 'SAST Running' }
      let(:expression) { { field: 'scanner_sast_running', operator: '=', value: true } }

      it 'returns true when expressions match exactly' do
        matching_expression = { field: 'scanner_sast_running', operator: '=', value: true }

        expect(control_expression.matches_expression?(matching_expression)).to be true
      end

      it 'returns false when field differs' do
        non_matching_expression = { field: 'different_field', operator: '=', value: true }

        expect(control_expression.matches_expression?(non_matching_expression)).to be false
      end

      it 'returns false when operator differs' do
        non_matching_expression = { field: 'scanner_sast_running', operator: '!=', value: true }

        expect(control_expression.matches_expression?(non_matching_expression)).to be false
      end

      it 'returns false when value differs' do
        non_matching_expression = { field: 'scanner_sast_running', operator: '=', value: false }

        expect(control_expression.matches_expression?(non_matching_expression)).to be false
      end
    end

    context 'with numeric comparison expressions' do
      let(:id) { 'minimum_approvals_required_2' }
      let(:name) { 'At least two approvals' }
      let(:expression) { { field: 'minimum_approvals_required', operator: '>=', value: 2 } }

      it 'returns true when expressions match exactly' do
        matching_expression = { field: 'minimum_approvals_required', operator: '>=', value: 2 }

        expect(control_expression.matches_expression?(matching_expression)).to be true
      end

      it 'returns false when value differs' do
        non_matching_expression = { field: 'minimum_approvals_required', operator: '>=', value: 3 }

        expect(control_expression.matches_expression?(non_matching_expression)).to be false
      end
    end

    context 'with string comparison expressions' do
      let(:id) { 'project_visibility_not_internal' }
      let(:name) { 'Internal visibility is forbidden' }
      let(:expression) { { field: 'project_visibility', operator: '!=', value: 'internal' } }

      it 'returns true when expressions match exactly' do
        matching_expression = { field: 'project_visibility', operator: '!=', value: 'internal' }

        expect(control_expression.matches_expression?(matching_expression)).to be true
      end

      it 'returns false when value differs' do
        non_matching_expression = { field: 'project_visibility', operator: '!=', value: 'public' }

        expect(control_expression.matches_expression?(non_matching_expression)).to be false
      end
    end
  end

  describe '#initialize' do
    it 'sets the id, name, and expression' do
      expect(control_expression.id).to eq(id)
      expect(control_expression.name).to eq(name)
      expect(control_expression.expression).to eq(expression)
    end
  end

  describe 'attribute readers' do
    it { is_expected.to respond_to(:id) }
    it { is_expected.to respond_to(:name) }
    it { is_expected.to respond_to(:expression) }
  end

  describe '#to_global_id' do
    it 'returns the id as a string' do
      expect(control_expression.to_global_id).to eq(id.to_s)
    end
  end
end

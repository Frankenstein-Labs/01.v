# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::Controls::RegistryValidator, feature_category: :compliance_management do
  let(:registry) { ComplianceManagement::ComplianceFramework::Controls::Registry }
  let(:control_types) { ComplianceManagement::ComplianceFramework::Controls::Registry::CONTROL_TYPES }
  let(:special_controls_from_registry) do
    ComplianceManagement::ComplianceFramework::Controls::Registry::SPECIAL_CONTROLS
  end

  def build_control(enum_value, field_id: nil, type: :boolean)
    {
      name: "Control #{enum_value}",
      type: control_types[type],
      compliant_value: true,
      enum_value: enum_value
    }.tap do |control|
      control[:field_id] = field_id if field_id
    end
  end

  describe '.validate!' do
    let(:valid_controls) do
      {
        control_a: build_control(1, type: :boolean),
        control_b: build_control(2, type: :numeric),
        control_c: build_control(3, field_id: :shared_field, type: :numeric),
        control_d: build_control(4, type: :enum)
      }
    end

    let(:valid_special_controls) { { special_x: 10, special_y: 11 } }

    it 'passes when registry has no duplicates and no conflicts' do
      expect(described_class.validate!(valid_controls, valid_special_controls)).to be_truthy
    end

    it 'passes with actual registry data' do
      loaded_controls = registry.controls
      expect(described_class.validate!(loaded_controls, special_controls_from_registry)).to be_truthy
    end

    it 'handles empty controls gracefully' do
      expect(described_class.validate!({}, valid_special_controls)).to be_truthy
    end

    it 'handles empty special controls gracefully' do
      expect(described_class.validate!(valid_controls, {})).to be_truthy
    end

    it 'handles nil controls gracefully' do
      expect(described_class.validate!(nil, valid_special_controls)).to be_truthy
    end

    it 'handles nil special controls gracefully' do
      expect(described_class.validate!(valid_controls, nil)).to be_truthy
    end

    it 'handles both nil controls and special controls gracefully' do
      expect(described_class.validate!(nil, nil)).to be_truthy
    end

    it 'raises an error when there are duplicate field IDs (explicit field_id)' do
      controls_with_duplicate_field_id = valid_controls.merge(
        control_e: build_control(5, field_id: :shared_field)
      )

      expect { described_class.validate!(controls_with_duplicate_field_id, valid_special_controls) }
        .to raise_error(described_class::RegistryValidationError, /Duplicate field IDs detected: shared_field/)
    end

    it 'raises an error when there are duplicate field IDs (implicit field_id from key)' do
      controls_with_duplicate_field_id = valid_controls.merge(
        control_f: build_control(6, field_id: :control_a)
      )

      expect { described_class.validate!(controls_with_duplicate_field_id, valid_special_controls) }
        .to raise_error(described_class::RegistryValidationError, /Duplicate field IDs detected: control_a/)
    end

    it 'raises an error when there are duplicate enum values within the registry' do
      controls_with_duplicate_enum = valid_controls.merge(
        control_g: build_control(1)
      )

      expect { described_class.validate!(controls_with_duplicate_enum, valid_special_controls) }
        .to raise_error(described_class::RegistryValidationError,
          /Duplicate enum values detected within registry: 1: control_a, control_g/)
    end

    it 'raises an error with multiple duplicate enum values within the registry' do
      controls_with_duplicates = {
        c1: build_control(100),
        c2: build_control(101),
        c3: build_control(100),
        c4: build_control(102),
        c5: build_control(101)
      }

      expect { described_class.validate!(controls_with_duplicates, {}) }
        .to raise_error(described_class::RegistryValidationError) do |error|
          expect(error.message).to match(/Duplicate enum values detected within registry:/)
          expect(error.message).to include('100: c1, c3')
          expect(error.message).to include('101: c2, c5')
        end
    end

    context 'when validating enum values between registry and special controls' do
      let(:registry_controls_with_conflict) do
        {
          safe_control: build_control(50),
          conflict_control_1: build_control(100),
          conflict_control_2: build_control(101)
        }
      end

      let(:special_controls_for_conflict) do
        {
          special_a: 100,
          special_b: 101,
          safe_external: 102
        }
      end

      it 'identifies multiple conflicts and includes them in error message' do
        expected_message = "Duplicate enum values detected between registry and special controls:\n" \
          "Registry controls (conflict_control_1, conflict_control_2) conflict with " \
          "special controls (special_a, special_b)."

        expect { described_class.validate!(registry_controls_with_conflict, special_controls_for_conflict) }
          .to raise_error(described_class::RegistryValidationError, expected_message)
      end

      it 'identifies a single conflict and includes it in error message' do
        single_conflict_controls = {
          control_x: build_control(200),
          control_y: build_control(100)
        }
        expected_message = "Duplicate enum values detected between registry and special controls:\n" \
          "Registry controls (control_y) conflict with " \
          "special controls (special_a)."

        expect { described_class.validate!(single_conflict_controls, special_controls_for_conflict) }
          .to raise_error(described_class::RegistryValidationError, expected_message)
      end
    end
  end

  describe '.find_duplicates' do
    subject { described_class.send(:find_duplicates, array) }

    context 'with duplicates' do
      let(:array) { [1, 2, 3, 1, 4, 2, 5, 2] }

      it { is_expected.to match_array([1, 2]) }
    end

    context 'with no duplicates' do
      let(:array) { [1, 2, 3, 4, 5] }

      it { is_expected.to be_empty }
    end

    context 'with an empty array' do
      let(:array) { [] }

      it { is_expected.to be_empty }
    end

    context 'with nil values (should treat them distinctly unless multiple nils)' do
      let(:array) { [1, nil, 2, 1, nil] }

      it { is_expected.to match_array([1, nil]) }
    end
  end

  describe '.find_control_names' do
    subject { described_class.send(:find_control_names, controls, values, key) }

    let(:controls) do
      {
        control_1: { enum_value: 1, name: 'One' },
        control_2: { enum_value: 2, name: 'Two' },
        control_3: { enum_value: 1, name: 'One Again' },
        control_4: { name: 'No Enum' },
        control_5: { enum_value: 3, name: 'Three' }
      }
    end

    context 'when using with a key (nested value lookup)' do
      let(:key) { :enum_value }

      context 'when values match some entries' do
        let(:values) { [1, 3] }

        it { is_expected.to eq('control_1, control_3, control_5') }
      end

      context 'when values match a single entry' do
        let(:values) { [2] }

        it { is_expected.to eq('control_2') }
      end

      context 'when values match no entries' do
        let(:values) { [99, 100] }

        it { is_expected.to eq('') }
      end

      context 'when values array is empty' do
        let(:values) { [] }

        it { is_expected.to eq('') }
      end

      context 'when searching by a different key' do
        let(:key) { :name }
        let(:values) { %w[Two Three] }

        it { is_expected.to eq('control_2, control_5') }
      end
    end

    context 'when using without a key (direct value lookup)' do
      let(:key) { nil }
      let(:controls) { { special_1: 10, special_2: 20, special_3: 30 } }

      context 'when values match all entries' do
        let(:values) { [10, 20, 30] }

        it { is_expected.to eq('special_1, special_2, special_3') }
      end

      context 'when values match some entries' do
        let(:values) { [10, 30] }

        it { is_expected.to eq('special_1, special_3') }
      end

      context 'when values match a single entry' do
        let(:values) { [20] }

        it { is_expected.to eq('special_2') }
      end

      context 'when values match no entries' do
        let(:values) { [99] }

        it { is_expected.to eq('') }
      end

      context 'when values array is empty' do
        let(:values) { [] }

        it { is_expected.to eq('') }
      end

      context 'when controls hash is empty' do
        let(:controls) { {} }
        let(:values) { [10] }

        it { is_expected.to eq('') }
      end
    end
  end
end

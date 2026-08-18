# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CustomRoles::Definition, feature_category: :permissions do
  standard_yaml_files = Dir.glob(Rails.root.join("ee/config/custom_abilities/*.yml"))
  admin_yaml_files = Dir.glob(Rails.root.join("ee/config/custom_abilities/admin/*.yml"))

  def defined_abilities(files, include_wip: true)
    files.filter_map do |file|
      data = YAML.safe_load_file(file)
      next if !include_wip && data['wip']

      File.basename(file, '.yml').to_sym
    end
  end

  let_it_be(:defined_standard_abilities) { defined_abilities(standard_yaml_files) }
  let_it_be(:defined_admin_abilities) { defined_abilities(admin_yaml_files) }
  let_it_be(:all_defined_abilities) { defined_standard_abilities + defined_admin_abilities }

  let_it_be(:defined_standard_abilities_without_wip) do
    defined_abilities(standard_yaml_files, include_wip: false)
  end

  let_it_be(:defined_admin_abilities_without_wip) do
    defined_abilities(admin_yaml_files, include_wip: false)
  end

  let_it_be(:all_defined_abilities_without_wip) do
    defined_standard_abilities_without_wip + defined_admin_abilities_without_wip
  end

  describe '.all' do
    subject(:abilities) { described_class.all }

    it 'returns the defined abilities including wip' do
      expect(abilities.keys).to match_array(all_defined_abilities)
    end

    it 'does not have overlapping role names' do
      admin_abilities = described_class.admin.keys
      standard_abilities = described_class.standard.keys

      expect(standard_abilities & admin_abilities).to be_empty
    end

    context 'when not initialized' do
      before do
        described_class.instance_variable_set(:@standard_definitions, nil)
        described_class.instance_variable_set(:@admin_definitions, nil)
        described_class.instance_variable_set(:@all_definitions, nil)
      end

      it 'reloads the abilities from the yaml files' do
        expect(described_class).to receive(:load_definitions)
          .with(described_class.send(:standard_path)).and_call_original
        expect(described_class).to receive(:load_definitions)
          .with(described_class.send(:admin_path)).and_call_original

        abilities
      end

      it 'returns the defined abilities' do
        expect(abilities.keys).to match_array(all_defined_abilities)
      end
    end
  end

  describe '.admin' do
    subject(:abilities) { described_class.admin }

    it 'returns the defined abilities including wip' do
      expect(abilities.keys).to match_array(defined_admin_abilities)
    end
  end

  describe '.standard' do
    subject(:abilities) { described_class.standard }

    it 'returns the defined abilities including wip' do
      expect(abilities.keys).to match_array(defined_standard_abilities)
    end
  end

  describe 'wip filtering' do
    context 'with :disable_wip_custom_abilities metadata', :disable_wip_custom_abilities do
      it 'excludes abilities with wip: true from .all' do
        expect(described_class.all.keys).to match_array(all_defined_abilities_without_wip)
      end

      it 'excludes abilities with wip: true from .standard' do
        expect(described_class.standard.keys).to match_array(defined_standard_abilities_without_wip)
      end

      it 'excludes abilities with wip: true from .admin' do
        expect(described_class.admin.keys).to match_array(defined_admin_abilities_without_wip)
      end
    end

    context 'without the metadata' do
      it 'includes abilities with wip: true' do
        expect(described_class.all.keys).to match_array(all_defined_abilities)
      end
    end
  end

  describe '.load_abilities!' do
    before do
      described_class.instance_variable_set(:@standard_definitions, { old_std: 'ability' })
      described_class.instance_variable_set(:@admin_definitions, { old_admin: 'ability' })
      described_class.instance_variable_set(:@all_definitions, { old_std: 'ability', old_admin: 'ability' })
    end

    after do
      described_class.load_abilities!
    end

    it 'reloads the abilities' do
      expect { described_class.load_abilities! }.to change { described_class.admin.keys }
        .from(%i[old_admin]).to(array_including(defined_admin_abilities)).and change { described_class.standard.keys }
        .from(%i[old_std]).to(array_including(defined_standard_abilities)).and change { described_class.all.keys }
        .from(%i[old_std old_admin]).to(array_including(all_defined_abilities))
    end
  end

  describe '.sanitize' do
    let(:project_levels) { [10, 20] }
    let(:group_levels) { [30, 40] }

    let(:definition) do
      {
        'name' => 'test_ability',
        'title' => 'Test',
        'enabled_for_project_access_levels' => project_levels,
        'enabled_for_group_access_levels' => group_levels
      }
    end

    subject(:result) { described_class.send(:load_from_file, 'fake_path.yml') }

    before do
      allow(YAML).to receive(:safe_load).and_return(definition)
      allow(File).to receive(:read).and_return('')
    end

    context 'with invalid access levels' do
      let(:project_levels) { [10, 20, 99999] }
      let(:group_levels) { [30, 40, 88888] }

      it 'removes them' do
        expect(result[:enabled_for_project_access_levels]).to include(10, 20)
        expect(result[:enabled_for_project_access_levels]).not_to include(99999)
        expect(result[:enabled_for_group_access_levels]).to include(30, 40)
        expect(result[:enabled_for_group_access_levels]).not_to include(88888)
      end
    end

    context 'with security manager access level' do
      let(:project_levels) { [10, 20, 25] }
      let(:group_levels) { [25, 30, 40] }

      it 'retains it when enabled' do
        expect(result[:enabled_for_project_access_levels]).to match_array([10, 20, 25])
        expect(result[:enabled_for_group_access_levels]).to match_array([25, 30, 40])
      end

      context 'when disabled', :disable_security_manager do
        it 'strips it' do
          expect(result[:enabled_for_project_access_levels]).to include(10, 20)
          expect(result[:enabled_for_project_access_levels]).not_to include(25)
          expect(result[:enabled_for_group_access_levels]).to include(30, 40)
          expect(result[:enabled_for_group_access_levels]).not_to include(25)
        end
      end
    end
  end

  describe 'validations' do
    let(:validator) { JSONSchemer.schema(Pathname.new(Rails.root.join(validator_path))) }

    def validate(ability_file)
      data = YAML.load_file(ability_file)
      validator.validate(data).pluck('error')
    end

    describe 'for standard abilities' do
      let(:validator_path) { 'ee/config/custom_abilities/type_schema.json' }

      standard_yaml_files.each do |ability_file|
        it "validates #{ability_file}" do
          expect(validate(ability_file)).to be_empty
        end
      end
    end

    describe 'for admin abilities' do
      let(:validator_path) { 'ee/config/custom_abilities/admin/type_schema.json' }

      admin_yaml_files.each do |ability_file|
        it "validates #{ability_file}" do
          expect(validate(ability_file)).to be_empty
        end
      end
    end
  end
end

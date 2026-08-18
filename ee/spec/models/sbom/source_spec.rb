# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Source, type: :model, feature_category: :dependency_management do
  let(:source_types) { { dependency_scanning: 0, container_scanning: 1, container_scanning_for_registry: 2 } }

  describe 'enums' do
    it { is_expected.to define_enum_for(:source_type).with_values(source_types) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to have_many(:occurrences) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:source_type) }
    it { is_expected.to validate_presence_of(:source) }
  end

  describe 'source validation' do
    subject { build(:sbom_source, source_type: source_type, source: source_attributes) }

    context 'with dependency scanning source' do
      let(:source_type) { :dependency_scanning }

      context 'when source is valid' do
        let(:source_attributes) do
          {
            'category' => 'development',
            'input_file' => { 'path' => 'package-lock.json' },
            'source_file' => { 'path' => 'package.json' },
            'package_manager' => { 'name' => 'npm' },
            'language' => { 'name' => 'JavaScript' }
          }
        end

        it { is_expected.to be_valid }
      end

      context 'when optional attributes are missing' do
        let(:source_attributes) do
          {
            'input_file' => { 'path' => 'package-lock.json' }
          }
        end

        it { is_expected.to be_valid }
      end

      context 'when files attribute is present and valid' do
        let(:source_attributes) do
          {
            'input_file' => { 'path' => 'package-lock.json' },
            'files' => [
              { 'path' => 'requirements.txt', 'type' => 'requirements', 'in_repository' => true },
              { 'path' => 'Gemfile.lock', 'type' => 'lockfile' },
              { 'path' => 'deps.graph', 'type' => 'graphfile' }
            ]
          }
        end

        it { is_expected.to be_valid }
      end

      context 'when a file item is missing the required type' do
        let(:source_attributes) do
          {
            'input_file' => { 'path' => 'package-lock.json' },
            'files' => [
              { 'path' => 'requirements.txt' }
            ]
          }
        end

        it { is_expected.to be_invalid }
      end

      context 'when a file item has an invalid type value' do
        let(:source_attributes) do
          {
            'input_file' => { 'path' => 'package-lock.json' },
            'files' => [
              { 'path' => 'requirements.txt', 'type' => 'unknown_type' }
            ]
          }
        end

        it { is_expected.to be_invalid }
      end

      context 'when a file item has an invalid path' do
        let(:source_attributes) do
          {
            'input_file' => { 'path' => 'package-lock.json' },
            'files' => [
              { 'path' => '', 'type' => 'requirements' }
            ]
          }
        end

        it { is_expected.to be_invalid }
      end

      context 'when required attribute input_file is missing' do
        let(:source_attributes) do
          {
            'package_manager' => { 'name' => 'npm' },
            'language' => { 'name' => 'JavaScript' }
          }
        end

        it { is_expected.to be_invalid }
      end

      context 'when attributes have wrong type' do
        let(:source_attributes) do
          {
            'category' => 'development',
            'input_file' => { 'path' => 1 },
            'source_file' => { 'path' => 'package.json' },
            'package_manager' => { 'name' => 2 },
            'language' => { 'name' => 3 }
          }
        end

        it { is_expected.to be_invalid }
      end
    end

    shared_examples 'valid source' do
      context 'when source is valid' do
        let(:source_attributes) do
          {
            'category' => 'development',
            'image' => {
              'name' => 'photon',
              'tag' => '5.0-20231007'
            },
            'operating_system' => {
              'name' => 'Photon OS',
              'version' => '5.0'
            }
          }
        end

        it { is_expected.to be_valid }
      end

      context 'when operating system data is missing' do
        let(:source_attributes) do
          {
            'image' => {
              'name' => 'photon',
              'tag' => '5.0-20231007'
            }
          }
        end

        it { is_expected.to be_valid }
      end

      context 'when operating system version is missing' do
        let(:source_attributes) do
          {
            'image' => {
              'name' => 'photon',
              'tag' => '5.0-20231007'
            },
            'operating_system' => {
              'name' => 'Photon OS'
            }
          }
        end

        it { is_expected.to be_invalid }
      end
    end

    context 'with container scanning source' do
      let(:source_type) { :container_scanning }

      include_examples 'valid source'
    end

    context 'with container scanning for registry source' do
      let(:source_type) { :container_scanning_for_registry }

      include_examples 'valid source'
    end
  end

  describe 'readers' do
    let(:source) { build(:sbom_source, source_type: source_type, source: source_attributes) }

    context 'for dependency scanning' do
      let(:source_type) { :dependency_scanning }
      let(:source_attributes) do
        {
          'category' => 'development',
          'input_file' => { 'path' => 'package-lock.json' },
          'source_file' => { 'path' => 'package.json' },
          'package_manager' => { 'name' => 'npm' },
          'language' => { 'name' => 'JavaScript' }
        }
      end

      describe '#packager' do
        subject { source.packager }

        it { is_expected.to eq('npm') }
      end

      describe '#input_file_path' do
        subject { source.input_file_path }

        it { is_expected.to eq('package-lock.json') }
      end

      describe '#source_file_path' do
        subject { source.source_file_path }

        it { is_expected.to eq('package.json') }
      end
    end

    shared_examples 'common container readers' do
      describe "#image_name" do
        subject { source.image_name }

        it { is_expected.to eq("rhel") }
      end

      describe "#image_tag" do
        subject { source.image_tag }

        it { is_expected.to eq("7.1") }
      end

      describe "#operating_system_name" do
        subject { source.operating_system_name }

        it { is_expected.to eq("Red Hat Enterprise Linux") }
      end

      describe "#operating_system_version" do
        subject { source.operating_system_version }

        it { is_expected.to eq("7") }
      end
    end

    context 'for container scanning' do
      let(:source_type) { :container_scanning }
      let(:source_attributes) do
        {
          "image" => { "name" => "rhel", "tag" => "7.1" },
          "operating_system" => { "name" => "Red Hat Enterprise Linux", "version" => "7" }
        }
      end

      include_examples 'common container readers'
    end

    context 'for container scanning for registry' do
      let(:source_type) { :container_scanning_for_registry }
      let(:source_attributes) do
        {
          "image" => { "name" => "rhel", "tag" => "7.1" },
          "operating_system" => { "name" => "Red Hat Enterprise Linux", "version" => "7" }
        }
      end

      include_examples 'common container readers'
    end
  end

  context 'with loose foreign key on sbom_sources.organization_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:organization) }
      let_it_be(:model) { create(:sbom_source, organization: parent) }
    end
  end
end

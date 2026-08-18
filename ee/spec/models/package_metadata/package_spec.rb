# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PackageMetadata::Package, type: :model, feature_category: :software_composition_analysis do
  using RSpec::Parameterized::TableSyntax

  describe 'enums' do
    it_behaves_like 'purl_types enum'
  end

  describe '#license_ids_for' do
    context 'when licenses are present' do
      let(:default) { [5, 7] }
      let(:highest) { '0.0.3' }
      let(:lowest) { '0.0.1' }
      let(:first_other_license) { [2, 4] }
      let(:other) { [[first_other_license, ['v0.0.4', 'v0.0.5']], [[3], ['v0.0.6']]] }

      context 'and the input version' do
        where(:test_case_name, :highest_version, :lowest_version, :input_version, :expected_license_ids) do
          'matches one of the versions in other licenses'        | highest | lowest | 'v0.0.4'   | first_other_license
          'matches the highest version'                          | highest | lowest | highest    | default
          'is higher than the highest version'                   | highest | lowest | '9.9.9'    | []
          'matches the lowest version'                           | highest | lowest | lowest     | default
          'is lower than the lowest version'                     | highest | lowest | '0.0.0'    | []
          'is between the highest and lowest versions'           | highest | lowest | '0.0.2'    | default
          'matches the highest version'                          | highest | nil    | highest    | default
          'is higher than the highest version'                   | highest | nil    | '9.9.9'    | []
          'is lower than the highest version'                    | highest | nil    | '0.0.2'    | default
          'matches the lowest version'                           | nil     | lowest | lowest     | default
          'is lower than the lowest version'                     | nil     | lowest | '0.0.0'    | []
          'is higher than the lowest version'                    | nil     | lowest | '9.9.9'    | default
          'does not match any of the versions in other licenses' | nil     | nil    | '0.0.2'    | default
          'cannot be parsed'                                     | highest | lowest | '1.0\n2.0' | []
        end

        with_them do
          let(:package) do
            build_stubbed(:pm_package, name: "cliui", purl_type: "npm",
              licenses: [default, lowest_version, highest_version, other])
          end

          subject(:license_ids) { package.license_ids_for(version: input_version) }

          specify { expect(license_ids).to eq(expected_license_ids) }

          context 'when prefix `v` is present in input_version' do
            # Regex (/\A(?![v])/i, 'v') appends v if not present
            subject(:license_ids) { package.license_ids_for(version: input_version.sub(/\A(?![v])/i, 'v')) }

            specify { expect(license_ids).to eq(expected_license_ids) }
          end
        end
      end

      context 'when passed empty or unsupported PURL type' do
        let(:package) { build_stubbed(:pm_package, purl_type: purl_type) }
        let(:input_version) { "1.0" }

        subject(:license_ids) { package.license_ids_for(version: input_version) }

        context 'on not_provided' do
          let(:purl_type) { 'not_provided' }

          specify { expect(license_ids).to eq([]) }
        end

        context 'on unknown' do
          let(:purl_type) { 'unknown' }

          specify { expect(license_ids).to eq([]) }
        end
      end

      context 'and the PURL type is supported' do
        context 'and the input version matches the default licenses' do
          let(:license_ids) { package.license_ids_for(version: input_version) }

          where(:purl_type, :input_version) do
            'composer' | '2.2.2'
            'conan' | '2.2.2'
            'gem' | '2.2.1.rc.1'
            'golang' | '2.2.2-alpha1'
            'maven' | '2.6a1'
            'npm' | '2.2.2-alpha1'
            'nuget' | '2.2.2-alpha1'
            'pypi' | '1.11-dev1'
          end

          with_them do
            let(:package) do
              build_stubbed(:pm_package, name: "cliui", purl_type: purl_type,
                licenses: [default, lowest, highest, other])
            end

            let(:lowest) { '0.0.0' }
            let(:highest) { input_version }

            subject(:license_ids) { package.license_ids_for(version: input_version) }

            specify { expect(license_ids).to eq(default) }
          end
        end
      end

      context 'and the given version causes semver_dialects to raise an exception while parsing' do
        let(:package) do
          build_stubbed(:pm_package, name: "cliui", purl_type: "npm", licenses: [default, lowest, highest, other])
        end

        let(:input_version) { "1.0\n2.0" }

        subject(:license_ids) { package.license_ids_for(version: input_version) }

        specify { expect(license_ids).to eq([]) }
      end
    end

    context 'when licenses are not present' do
      where(:test_case_name, :licenses) do
        'licenses are nil'   | nil
        'licenses are empty' | []
      end

      with_them do
        subject(:package) { build_stubbed(:pm_package, name: "cliui", purl_type: "npm", licenses: licenses) }

        it 'returns an empty array' do
          expect(package.license_ids_for(version: "1.0.0")).to eq([])
        end
      end
    end
  end

  describe 'validation' do
    it { is_expected.to validate_presence_of(:purl_type) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_presence_of(:name) }

    describe 'for licenses' do
      subject(:package) { build_stubbed(:pm_package, licenses: licenses) }

      let(:default) { [1] }
      let(:highest) { '0.0.2' }
      let(:lowest) { '0.0.1' }
      let(:other) { [[[1, 2], ['v0.0.3', 'v0.0.4']], [[3], ['v0.0.5']]] }

      context 'when field is an empty array' do
        let(:licenses) { [] }

        it { is_expected.to be_valid }
      end

      context 'with different field value permutations' do
        # rubocop:disable Layout/LineLength
        where(:test_case_name, :valid, :default_licenses, :lowest_version, :highest_version, :other_licenses) do
          'all attributes valid'            | true  | default     | lowest      | highest     | other
          'default nil'                     | false | nil         | lowest      | highest     | other
          'default not arr'                 | false | 's'         | lowest      | highest     | other
          'default arr elts not ints'       | false | ['s']       | lowest      | highest     | other
          'default empty arr'               | false | []          | lowest      | highest     | other
          'default num elts up to max'      | true  | ([1] * 200) | lowest      | highest     | other
          'default num elts exceed max'     | false | ([1] * 201) | lowest      | highest     | other
          'lowest nil'                      | true  | default     | nil         | highest     | other
          'lowest int'                      | false | default     | 1           | highest     | other
          'lowest empty str'                | false | default     | ''          | highest     | other
          'lowest version len up to max'    | true  | default     | ('v' * 255) | highest     | other
          'lowest version len exceeds max'  | false | default     | ('v' * 256) | highest     | other
          'highest nil'                     | true  | default     | lowest      | nil         | other
          'highest int'                     | false | default     | lowest      | 1           | other
          'highest empty str'               | false | default     | lowest      | ''          | other
          'highest version len up to max'   | true  | default     | lowest      | ('v' * 255) | other
          'highest version len exceeds max' | false | default     | lowest      | ('v' * 256) | other
          'other empty arr'                 | true  | default     | lowest      | highest     | []
          'other nil'                       | false | default     | lowest      | highest     | nil
          '1st elt not arr'                 | false | default     | lowest      | highest     | [[1, ['v1']]]
          '2nd elt not arr'                 | false | default     | lowest      | highest     | [[[1], 'v1']]
          'default num tuples up to max'    | true  | default     | lowest      | highest     | Array.new(50) { [[1], ['v1']] }
          'default num tuples exceed max'   | false | default     | lowest      | highest     | Array.new(51) { [[1], ['v1']] }
          'default num licenses up to max'  | true  | default     | lowest      | highest     | [[Array.new(200) { 1 }, ['v1']]]
          'default num licenses exceed max' | false | default     | lowest      | highest     | [[Array.new(201) { 1 }, ['v1']]]
          'default num versions up to max'  | true  | default     | lowest      | highest     | [[[1], Array.new(500) { 'v1' }]]
          'default num versions exceed max' | false | default     | lowest      | highest     | [[[1], Array.new(501) { 'v1' }]]
        end
        # rubocop:enable Layout/LineLength

        with_them do
          let(:licenses) { [default_licenses, lowest_version, highest_version, other_licenses] }

          specify { expect(package.valid?).to eq(valid) }
        end
      end
    end
  end
end

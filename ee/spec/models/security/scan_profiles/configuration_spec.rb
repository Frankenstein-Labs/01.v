# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::Configuration, feature_category: :security_testing_configuration do
  describe 'associations' do
    it { is_expected.to belong_to(:scan_profile).class_name('Security::ScanProfile').required }
    it { is_expected.to belong_to(:namespace).required }
    it { is_expected.to have_many(:scan_profile_triggers).class_name('Security::ScanProfileTrigger') }
  end

  describe 'validations' do
    subject(:record) { build(:security_scan_profile_configuration) }

    it { is_expected.to be_valid }

    it 'rejects a configuration larger than the 64 KiB size limit', :aggregate_failures do
      record.configuration = { data: 'a' * 65.kilobytes }

      expect(record).not_to be_valid
      expect(record.errors[:configuration]).to include(/too large/)
    end

    describe 'configuration schema' do
      context 'when the profile is a post-processing type with a matching schema' do
        subject(:record) do
          build(:security_scan_profile_configuration,
            scan_profile: build(:security_scan_profile, :dependency_scanning_post_processing))
        end

        it 'accepts a configuration valid under the type schema' do
          record.configuration = { auto_remediation: { cooldown: 3 } }

          expect(record).to be_valid
        end

        it 'rejects unknown top-level keys', :aggregate_failures do
          record.configuration = { foo: 'bar' }

          expect(record).not_to be_valid
          expect(record.errors[:configuration]).to be_present
        end

        it 'rejects invalid enum values and out-of-range numbers', :aggregate_failures do
          invalid_diffs = [
            { severity_level: 'extreme' },
            { upgrade_policy: 'platinum' },
            { cooldown: 200 },
            { open_merge_requests_limit: 100 }
          ]

          invalid_diffs.each do |diff|
            record.configuration = { auto_remediation: diff }

            expect(record).not_to(be_valid, "expected #{diff} to be rejected by the schema")
            expect(record.errors[:configuration]).to be_present
          end
        end
      end

      context 'when the profile is a secret_detection type with a matching schema' do
        subject(:record) do
          build(:security_scan_profile_configuration,
            scan_profile: build(:security_scan_profile, scan_type: :secret_detection))
        end

        it 'accepts configurations valid under the type schema', :aggregate_failures do
          [
            {},
            { image_suffix: '' },
            { image_suffix: '-fips' },
            { historic_scan: true },
            { excluded_paths: %w[spec tmp] },
            { excluded_paths: ['a' * 1024] },
            { excluded_paths: Array.new(1024) { 'a' } },
            {
              secure_analyzers_prefix: 'registry.example.com',
              image_suffix: '-fips',
              historic_scan: false,
              log_options: 'HEAD~5..HEAD',
              excluded_paths: %w[spec tmp],
              ruleset_git_reference: 'refs/heads/main'
            }
          ].each do |configuration|
            record.configuration = configuration

            expect(record).to be_valid
          end
        end

        it 'rejects configurations that violate the schema', :aggregate_failures do
          [
            { foo: 'bar' },                              # unknown key
            { image_suffix: 'debug' },                   # outside enum
            { historic_scan: 'yes' },                    # not a boolean
            { excluded_paths: 'spec,tmp' },              # not an array
            { excluded_paths: [1, 2] },                  # not an array of strings
            { excluded_paths: ['a' * 1025] },            # item exceeds max length
            { excluded_paths: Array.new(1025) { 'a' } }, # exceeds max items
            { log_options: 'a' * 1025 },                 # exceeds max length
            { secure_analyzers_prefix: 'a' * 1025 },     # exceeds max length
            { ruleset_git_reference: 'a' * 1025 }        # exceeds max length
          ].each do |configuration|
            record.configuration = configuration

            expect(record).not_to be_valid, "expected #{configuration.inspect} to be invalid"
            expect(record.errors[:configuration]).to be_present
          end
        end
      end

      context 'when the profile has no matching schema' do
        subject(:record) do
          build(:security_scan_profile_configuration, scan_profile: build(:security_scan_profile, :sast))
        end

        it 'falls back to the strict empty schema', :aggregate_failures do
          expect(record).to be_valid # default configuration is {}

          record.configuration = { auto_remediation: { cooldown: 3 } }
          expect(record).not_to be_valid
          expect(record.errors[:configuration]).to be_present
        end
      end
    end
  end

  describe '.defaults_for' do
    using RSpec::Parameterized::TableSyntax

    let(:registered_defaults) do
      Security::ScanProfiles::Configuration::Defaults::DependencyScanningPostProcessing::VALUES
    end

    where(:input, :expected) do
      :dependency_scanning_post_processing  | ref(:registered_defaults)
      'dependency_scanning_post_processing' | ref(:registered_defaults)
      nil                                   | {}
      :unknown_scan_type                    | {}
    end

    with_them do
      it { expect(described_class.defaults_for(input)).to eq(expected) }
    end
  end

  describe '.strip_defaults' do
    let(:defaults) { described_class.defaults_for(:dependency_scanning_post_processing) }

    subject(:stripped) { described_class.strip_defaults(values, defaults) }

    context 'when values equal the defaults' do
      let(:values) { { auto_remediation: { cooldown: 7, upgrade_policy: 'minor', runner_tags: [] } } }

      it 'drops them and prunes the now-empty hash' do
        expect(stripped).to eq({})
      end
    end

    context 'when values differ from the defaults' do
      let(:values) { { auto_remediation: { cooldown: 3, upgrade_policy: 'minor', runner_tags: ['fast'] } } }

      it 'keeps only the differing leaves' do
        expect(stripped).to eq(auto_remediation: { cooldown: 3, runner_tags: ['fast'] })
      end
    end

    context 'when there are no defaults' do
      let(:defaults) { {} }
      let(:values) { { anything: { nested: true } } }

      it 'returns the values unchanged' do
        expect(stripped).to eq(anything: { nested: true })
      end
    end

    context 'with string keys' do
      let(:values) { { 'auto_remediation' => { 'cooldown' => 3, 'upgrade_policy' => 'minor' } } }

      it 'symbolizes and strips' do
        expect(stripped).to eq(auto_remediation: { cooldown: 3 })
      end
    end
  end

  describe '.effective_for' do
    let_it_be(:group) { create(:group) }
    let_it_be(:profile) do
      create(:security_scan_profile, :dependency_scanning_post_processing, namespace: group)
    end

    let(:trigger) { create(:security_scan_profile_trigger, :sbom_ingested, scan_profile: profile) }
    let(:defaults) { described_class.defaults_for(:dependency_scanning_post_processing) }

    context 'when profile is nil' do
      it 'returns an empty hash' do
        expect(described_class.effective_for(nil, trigger)).to eq({})
      end
    end

    context 'when the scan_type has registered defaults' do
      using RSpec::Parameterized::TableSyntax

      where(:stored_diff, :override) do
        nil                                                  | {}
        {}                                                   | {}
        { auto_remediation: { severity_level: 'critical' } } | { auto_remediation: { severity_level: 'critical' } }
        { auto_remediation: { cooldown: 3 } }                | { auto_remediation: { cooldown: 3 } }
      end

      with_them do
        let(:trigger) do
          create(:security_scan_profile_trigger, :sbom_ingested, scan_profile: profile,
            configuration_values: stored_diff)
        end

        it 'deep-merges the stored diff over the registered defaults' do
          expect(described_class.effective_for(profile, trigger)).to eq(defaults.deep_merge(override))
        end
      end
    end

    context 'when the trigger is nil' do
      it 'returns the scan type defaults' do
        expect(described_class.effective_for(profile, nil)).to eq(defaults)
      end
    end

    context 'when Duo overrides are applicable' do
      let(:project) { instance_double(Project, duo_dependency_bump_breaking_changes_available?: true) }

      it 'overrides auto_remediation.upgrade_policy to "major" and preserves other defaults', :aggregate_failures do
        result = described_class.effective_for(profile, trigger, project: project)

        expect(result.dig(:auto_remediation, :upgrade_policy)).to eq('major')
        expect(result.dig(:auto_remediation, :severity_level)).to eq(defaults.dig(:auto_remediation, :severity_level))
        expect(result.dig(:auto_remediation, :cooldown)).to eq(defaults.dig(:auto_remediation, :cooldown))
      end

      context 'when the trigger stores a different upgrade_policy' do
        it 'overrides the stored value to "major"' do
          config = create(:security_scan_profile_configuration, scan_profile: profile,
            configuration: { auto_remediation: { upgrade_policy: 'patch' } })
          trigger.update!(configuration: config)

          result = described_class.effective_for(profile, trigger, project: project)
          expect(result.dig(:auto_remediation, :upgrade_policy)).to eq('major')
        end
      end
    end

    context 'when Duo is disabled for the project' do
      let(:project) { instance_double(Project, duo_dependency_bump_breaking_changes_available?: false) }

      it 'does not force auto_remediation.upgrade_policy to "major"' do
        result = described_class.effective_for(profile, trigger, project: project)
        expect(result.dig(:auto_remediation, :upgrade_policy))
          .to eq(defaults.dig(:auto_remediation, :upgrade_policy))
      end
    end

    context 'when no project is provided' do
      it 'uses the default upgrade_policy' do
        expect(described_class.effective_for(profile, trigger).dig(:auto_remediation, :upgrade_policy))
          .to eq(defaults.dig(:auto_remediation, :upgrade_policy))
      end
    end

    context 'when the profile is a scanner type and a Duo-eligible project is passed' do
      let_it_be(:scanner_profile) { create(:security_scan_profile, :sast, namespace: group) }
      let(:scanner_trigger) do
        create(:security_scan_profile_trigger, scan_profile: scanner_profile, trigger_type: :default_branch_pipeline)
      end

      let(:project) { instance_double(Project, duo_dependency_bump_breaking_changes_available?: true) }

      it 'does not apply Duo overrides (guard requires post_processing?)' do
        result = described_class.effective_for(scanner_profile, scanner_trigger, project: project)
        expect(result.dig(:auto_remediation, :upgrade_policy)).to be_nil
      end
    end
  end

  describe '.resolve_dependency_bump_enabled?' do
    subject { described_class.send(:resolve_dependency_bump_enabled?, project) }

    context 'when project.duo_dependency_bump_breaking_changes_available? returns true' do
      let_it_be(:group) { build_stubbed(:group) }
      let_it_be(:project) { build_stubbed(:project, group: group) }

      before do
        allow(project).to receive(:duo_dependency_bump_breaking_changes_available?).and_return(true)
      end

      it { is_expected.to be true }
    end

    context 'when project.duo_dependency_bump_breaking_changes_available? returns false' do
      let_it_be(:group) { build_stubbed(:group) }
      let_it_be(:project) { build_stubbed(:project, group: group) }

      before do
        allow(project).to receive(:duo_dependency_bump_breaking_changes_available?).and_return(false)
      end

      it { is_expected.to be false }
    end

    context 'when the project is nil' do
      subject { described_class.send(:resolve_dependency_bump_enabled?, nil) }

      it { is_expected.to be false }
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfileTrigger, feature_category: :security_testing_configuration do
  let_it_be(:group) { create(:group) }
  let_it_be(:scan_profile) { create(:security_scan_profile, namespace: group) }

  describe 'associations' do
    it { is_expected.to belong_to(:scan_profile).class_name('Security::ScanProfile').required }
    it { is_expected.to belong_to(:namespace).required }

    it 'belongs to an autosaving, optional configuration' do
      is_expected.to belong_to(:configuration)
        .class_name('Security::ScanProfiles::Configuration').optional.autosave(true)
    end
  end

  describe 'validations' do
    subject { create(:security_scan_profile_trigger, namespace: group, scan_profile: scan_profile) }

    it { is_expected.to validate_presence_of(:trigger_type) }
    it { is_expected.to validate_uniqueness_of(:security_scan_profile_id).scoped_to(:trigger_type) }

    describe '#trigger_type_compatible_with_profile' do
      using RSpec::Parameterized::TableSyntax

      where(:scan_type, :trigger_type, :valid) do
        :sast                                | :default_branch_pipeline | true
        :sast                                | :merge_request_pipeline  | true
        :sast                                | :git_push_event          | false
        :sast                                | :sbom_ingested           | false
        :secret_detection                    | :default_branch_pipeline | true
        :secret_detection                    | :merge_request_pipeline  | true
        :secret_detection                    | :git_push_event          | true
        :secret_detection                    | :sbom_ingested           | false
        :container_scanning                  | :default_branch_pipeline | false
        :container_scanning                  | :merge_request_pipeline  | false
        :container_scanning                  | :git_push_event          | false
        :container_scanning                  | :sbom_ingested           | false
        :dependency_scanning                 | :default_branch_pipeline | true
        :dependency_scanning                 | :merge_request_pipeline  | true
        :dependency_scanning                 | :git_push_event          | false
        :dependency_scanning                 | :sbom_ingested           | false
        :dependency_scanning_post_processing | :default_branch_pipeline | false
        :dependency_scanning_post_processing | :merge_request_pipeline  | false
        :dependency_scanning_post_processing | :git_push_event          | false
        :dependency_scanning_post_processing | :sbom_ingested           | true
      end

      with_them do
        let(:profile) do
          create(:security_scan_profile, namespace: group, scan_type: scan_type, name: "#{scan_type} #{trigger_type}")
        end

        subject(:trigger) do
          build(:security_scan_profile_trigger, namespace: group, scan_profile: profile, trigger_type: trigger_type)
        end

        it 'enforces the allowed-trigger matrix', :aggregate_failures do
          expect(trigger.valid?).to eq(valid)
          expect(trigger.errors[:trigger_type]).to include("is not allowed for #{scan_type} scan profiles") unless valid
        end
      end
    end

    describe '#configuration_allowed_for_trigger_type' do
      let_it_be(:profile) do
        create(:security_scan_profile, namespace: group, scan_type: :secret_detection, name: 'Secrets')
      end

      let(:configuration_values) { { historic_scan: true } }

      let(:configuration) do
        build(:security_scan_profile_configuration, scan_profile: profile, configuration: configuration_values)
      end

      subject(:trigger) do
        build(:security_scan_profile_trigger, namespace: group, scan_profile: profile,
          trigger_type: trigger_type, configuration: configuration)
      end

      context 'with a git push event trigger' do
        let(:trigger_type) { :git_push_event }

        it 'rejects the custom configuration', :aggregate_failures do
          expect(trigger).to be_invalid
          expect(trigger.errors[:base]).to include('Configuration is not allowed for the git_push_event trigger')
        end

        context 'when the configuration is empty' do
          let(:configuration_values) { {} }

          it { is_expected.to be_valid }
        end
      end

      context 'with a merge request pipeline trigger' do
        let(:trigger_type) { :merge_request_pipeline }

        it { is_expected.to be_valid }
      end
    end

    describe 'errors copied from an autosaved configuration' do
      let_it_be(:profile) do
        create(:security_scan_profile, namespace: group, scan_type: :secret_detection, name: 'Nested errors')
      end

      let(:configuration) do
        build(:security_scan_profile_configuration, scan_profile: profile,
          configuration: { secure_analyzers_prefix: 'a' * 1025 })
      end

      subject(:trigger) do
        build(:security_scan_profile_trigger, namespace: group, scan_profile: profile,
          trigger_type: :merge_request_pipeline, configuration: configuration)
      end

      it 'names the configuration attribute once', :aggregate_failures do
        expect(trigger).to be_invalid
        expect(trigger.errors.full_messages)
          .to contain_exactly('Configuration string length at `/secure_analyzers_prefix` is greater than: 1024')
      end
    end
  end

  describe '.with_not_deleted_profile' do
    let_it_be(:deleted_profile) { create(:security_scan_profile, namespace: group, scan_type: :secret_detection) }

    let_it_be(:trigger) do
      create(:security_scan_profile_trigger, namespace: group, scan_profile: scan_profile,
        trigger_type: :merge_request_pipeline)
    end

    let_it_be(:deleted_profile_trigger) do
      create(:security_scan_profile_trigger, namespace: group, scan_profile: deleted_profile,
        trigger_type: :merge_request_pipeline)
    end

    before do
      Security::ScanProfile.find(deleted_profile.id).destroy!
    end

    it 'excludes triggers whose profile is soft-deleted' do
      expect(described_class.with_not_deleted_profile).to contain_exactly(trigger)
    end
  end

  describe '#ci_variables' do
    let_it_be(:secret_detection_profile) do
      create(:security_scan_profile, namespace: group, scan_type: :secret_detection)
    end

    context 'when the trigger has a linked configuration' do
      # Built in memory: the schema permitting these keys is added separately.
      let(:configuration) do
        build(:security_scan_profile_configuration,
          scan_profile: secret_detection_profile, configuration: { log_options: 'a..b' })
      end

      subject(:trigger) do
        build(:security_scan_profile_trigger, namespace: group, scan_profile: secret_detection_profile,
          trigger_type: :merge_request_pipeline, configuration: configuration)
      end

      it 'translates the effective configuration into CI variables' do
        expect(trigger.ci_variables).to eq('SECRET_DETECTION_LOG_OPTIONS' => 'a..b')
      end
    end

    context 'when the trigger has no configuration' do
      subject(:trigger) do
        build(:security_scan_profile_trigger, namespace: group, scan_profile: secret_detection_profile,
          trigger_type: :merge_request_pipeline)
      end

      it 'returns an empty hash' do
        expect(trigger.ci_variables).to eq({})
      end
    end
  end

  context 'with loose foreign key on namespaces.id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { group }
      let_it_be(:model) { create(:security_scan_profile_trigger, scan_profile: scan_profile, namespace: parent) }
    end
  end
end

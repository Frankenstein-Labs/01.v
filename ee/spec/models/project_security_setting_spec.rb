# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectSecuritySetting, feature_category: :software_composition_analysis do
  using RSpec::Parameterized::TableSyntax

  describe 'validations' do
    subject { build(:project_security_setting) }

    it { is_expected.to validate_presence_of(:license_configuration_source) }
  end

  describe 'associations' do
    subject { create(:project).security_setting }

    it { is_expected.to belong_to(:project) }
  end

  describe '#set_continuous_vulnerability_scans' do
    where(:value_before, :enabled, :value_after) do
      true  | false | false
      true  | true  | true
      false | true  | true
      false | false | false
    end

    with_them do
      let(:setting) { create(:project_security_setting, continuous_vulnerability_scans_enabled: value_before) }

      it 'updates the attribute and returns the new value' do
        expect(setting.set_continuous_vulnerability_scans!(enabled: enabled)).to eq(value_after)
        expect(setting.reload.continuous_vulnerability_scans_enabled).to eq(value_after)
      end
    end
  end

  describe '#set_container_scanning_for_registry' do
    where(:value_before, :enabled, :value_after) do
      true  | false | false
      true  | true  | true
      false | true  | true
      false | false | false
    end

    with_them do
      let(:setting) { create(:project_security_setting, container_scanning_for_registry_enabled: value_before) }

      it 'updates the attribute and returns the new value' do
        expect(setting.set_container_scanning_for_registry!(enabled: enabled)).to eq(value_after)
        expect(setting.reload.container_scanning_for_registry_enabled).to eq(value_after)
      end
    end

    context 'when changing container_scanning_for_registry_enabled value' do
      let(:setting) { create(:project_security_setting, container_scanning_for_registry_enabled: false) }

      it 'schedules analyzer status update worker when value changes' do
        expect(Security::AnalyzersStatus::SettingChangedUpdateWorker)
          .to receive(:perform_async).with([setting.project_id], 'container_scanning')

        setting.set_container_scanning_for_registry!(enabled: true)
      end
    end

    context 'when updating container_scanning_for_registry_enabled value to the already existing value' do
      let!(:setting) { create(:project_security_setting, container_scanning_for_registry_enabled: false) }

      it 'does not schedule worker when value does not change' do
        expect(Security::AnalyzersStatus::SettingChangedUpdateWorker)
          .not_to receive(:perform_async)

        setting.set_container_scanning_for_registry!(enabled: false)
      end
    end
  end

  shared_examples 'a CVS boolean setting' do |method_name, attribute|
    where(:value_before, :enabled, :value_after) do
      true  | false | false
      true  | true  | true
      false | true  | true
      false | false | false
    end

    with_them do
      let(:setting) { create(:project_security_setting, attribute => value_before) }

      it 'updates the attribute and returns the new value' do
        expect(setting.public_send(method_name, enabled: enabled)).to eq(value_after)
        expect(setting.reload.public_send(attribute)).to eq(value_after)
      end
    end
  end

  describe '#set_cvs_for_container_scanning!' do
    it_behaves_like 'a CVS boolean setting', :set_cvs_for_container_scanning!, :cvs_for_container_scanning_enabled
  end

  describe '#set_cvs_for_dependency_scanning!' do
    it_behaves_like 'a CVS boolean setting', :set_cvs_for_dependency_scanning!, :cvs_for_dependency_scanning_enabled
  end

  describe '#set_secret_push_protection' do
    where(:value_before, :enabled, :value_after) do
      true  | false | false
      true  | true  | true
      false | true  | true
      false | false | false
    end

    with_them do
      let(:setting) { create(:project_security_setting, secret_push_protection_enabled: value_before) }

      it 'updates the attribute and returns the new value' do
        expect(setting.set_secret_push_protection!(enabled: enabled)).to eq(value_after)
        expect(setting.reload.secret_push_protection_enabled).to eq(value_after)
      end
    end

    context 'when changing secret_push_protection_enabled value' do
      let!(:setting) { create(:project_security_setting, secret_push_protection_enabled: false) }

      it 'schedules analyzer status update worker when value changes' do
        expect(Security::AnalyzersStatus::SettingChangedUpdateWorker)
          .to receive(:perform_async).with([setting.project_id], 'secret_detection')

        setting.set_secret_push_protection!(enabled: true)
      end
    end

    context 'when updating secret_push_protection_enabled value to the already existing value' do
      let!(:setting) { create(:project_security_setting, secret_push_protection_enabled: false) }

      it 'does not schedule worker when value does not change' do
        expect(Security::AnalyzersStatus::SettingChangedUpdateWorker)
          .not_to receive(:perform_async)

        setting.set_secret_push_protection!(enabled: false)
      end
    end
  end

  describe 'validity_checks_enabled tracking' do
    let!(:setting) { create(:project_security_setting, validity_checks_enabled: false) }

    context 'when validity_checks_enabled changes from false to true' do
      it 'does not track internal event disabled_validity_checks' do
        expect(setting).not_to receive(:track_internal_event).with(
          'disabled_validity_checks',
          project: setting.project
        )

        setting.update!(validity_checks_enabled: true)
      end
    end

    context 'when validity_checks_enabled changes from true to false' do
      let!(:setting) { create(:project_security_setting, validity_checks_enabled: true) }

      it 'tracks internal event disabled_validity_checks' do
        expect(setting).to receive(:track_internal_event).with(
          'disabled_validity_checks',
          project: setting.project
        )

        setting.update!(validity_checks_enabled: false)
      end
    end

    context 'when validity_checks_enabled does not change' do
      it 'does not track internal event disabled_validity_checks when value stays the same' do
        expect(setting).not_to receive(:track_internal_event).with(
          'disabled_validity_checks',
          project: setting.project
        )

        setting.update!(validity_checks_enabled: false) # Same value
      end
    end

    context 'when updating other fields' do
      it 'does not track internal event disabled_validity_checks when other fields change' do
        expect(setting).not_to receive(:track_internal_event).with(
          'disabled_validity_checks',
          project: setting.project
        )

        setting.update!(secret_push_protection_enabled: true)
      end
    end
  end

  describe '#set_fast_dependency_paths!' do
    it_behaves_like 'a CVS boolean setting', :set_fast_dependency_paths!, :fast_dependency_paths_enabled
  end

  describe 'fast_dependency_paths_enabled tracking' do
    let!(:setting) { create(:project_security_setting, fast_dependency_paths_enabled: false) }

    context 'when fast_dependency_paths_enabled changes from false to true' do
      it 'tracks internal event enabled_fast_dependency_paths' do
        expect(setting).to receive(:track_internal_event).with(
          'enabled_fast_dependency_paths',
          project: setting.project,
          namespace: setting.project.namespace
        )

        setting.update!(fast_dependency_paths_enabled: true)
      end
    end

    context 'when fast_dependency_paths_enabled changes from true to false' do
      let!(:setting) { create(:project_security_setting, fast_dependency_paths_enabled: true) }

      it 'does not track internal event enabled_fast_dependency_paths' do
        expect(setting).not_to receive(:track_internal_event).with(
          'enabled_fast_dependency_paths',
          project: setting.project,
          namespace: setting.project.namespace
        )

        setting.update!(fast_dependency_paths_enabled: false)
      end
    end

    context 'when fast_dependency_paths_enabled does not change' do
      it 'does not track internal event enabled_fast_dependency_paths when value stays the same' do
        expect(setting).not_to receive(:track_internal_event).with(
          'enabled_fast_dependency_paths',
          project: setting.project,
          namespace: setting.project.namespace
        )

        setting.update!(fast_dependency_paths_enabled: false)
      end
    end

    context 'when updating other fields' do
      it 'does not track internal event enabled_fast_dependency_paths when other fields change' do
        expect(setting).not_to receive(:track_internal_event).with(
          'enabled_fast_dependency_paths',
          project: setting.project,
          namespace: setting.project.namespace
        )

        setting.update!(secret_push_protection_enabled: true)
      end
    end
  end

  describe '#set_validity_checks' do
    where(:value_before, :enabled, :value_after) do
      true  | false | false
      true  | true  | true
      false | true  | true
      false | false | false
    end

    with_them do
      let(:setting) { create(:project_security_setting, validity_checks_enabled: value_before) }

      it 'updates the attribute and returns the new value' do
        expect(setting.set_validity_checks!(enabled: enabled)).to eq(value_after)
        expect(setting.reload.validity_checks_enabled).to eq(value_after)
      end
    end
  end

  describe '#set_license_scanning_for_cyclonedx!' do
    where(:value_before, :enabled, :value_after) do
      true  | false | false
      true  | true  | true
      false | true  | true
      false | false | false
    end

    with_them do
      let(:setting) { create(:project_security_setting, license_scanning_for_cyclonedx_enabled: value_before) }

      it 'updates the attribute and returns the new value' do
        expect(setting.set_license_scanning_for_cyclonedx!(enabled: enabled)).to eq(value_after)
        expect(setting.reload.license_scanning_for_cyclonedx_enabled).to eq(value_after)
      end
    end
  end

  describe 'after_commit hooks' do
    where(:field, :value_before, :update_value, :worker_scheduled, :type) do
      :container_scanning_for_registry_enabled | false | true  | true  | 'container_scanning'
      :container_scanning_for_registry_enabled | true  | false | true  | 'container_scanning'
      :container_scanning_for_registry_enabled | false | false | false | 'container_scanning'
      :container_scanning_for_registry_enabled | true  | true  | false | 'container_scanning'
      :secret_push_protection_enabled          | false | true  | true  | 'secret_detection'
      :secret_push_protection_enabled          | true  | false | true  | 'secret_detection'
      :secret_push_protection_enabled          | false | false | false | 'secret_detection'
      :secret_push_protection_enabled          | true  | true  | false | 'secret_detection'
      # Different field not covered by the hook:
      :validity_checks_enabled                 | true  | false | false | nil
    end

    with_them do
      let!(:setting) { create(:project_security_setting, field => value_before) }

      it 'schedules worker appropriately when field changes' do
        if worker_scheduled
          expect(Security::AnalyzersStatus::SettingChangedUpdateWorker)
            .to receive(:perform_async).with([setting.project_id], type)
        else
          expect(Security::AnalyzersStatus::SettingChangedUpdateWorker)
            .not_to receive(:perform_async)
        end

        setting.update!(field => update_value)
      end
    end

    describe 'when creating a new project' do
      it 'schedules SettingChangedUpdateWorker worker for each analyzer status related type' do
        expect(Security::AnalyzersStatus::SettingChangedUpdateWorker)
          .to receive(:perform_async).with(anything, 'container_scanning')

        expect(Security::AnalyzersStatus::SettingChangedUpdateWorker)
          .to receive(:perform_async).with(anything, 'secret_detection')

        create(:project)
      end
    end
  end

  describe 'scopes' do
    describe '.for_projects' do
      let_it_be(:project_1) { create(:project) }
      let_it_be(:project_2) { create(:project) }
      let_it_be(:project_3) { create(:project) }

      it 'only returns security settings for selected projects' do
        expect(described_class.for_projects([project_1.id, project_2.id]))
          .to match_array([project_1.security_setting, project_2.security_setting])
      end
    end
  end
end

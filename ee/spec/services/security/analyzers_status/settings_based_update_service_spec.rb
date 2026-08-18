# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::SettingsBasedUpdateService, feature_category: :security_asset_inventories do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: root_group) }
  let_it_be_with_reload(:project1) { create(:project, group: group) }
  let_it_be_with_reload(:project2) { create(:project, group: group) }
  let_it_be_with_reload(:project3) { create(:project, group: group) }

  let(:project_ids) { [project1.id, project2.id] }
  let(:analyzer_type) { :secret_detection }
  let(:service) { described_class.new(project_ids, analyzer_type) }
  let(:inventory_filters_update_service) { class_double(Security::InventoryFilters::AnalyzerStatusUpdateService) }

  before do
    stub_const('Security::InventoryFilters::AnalyzerStatusUpdateService', inventory_filters_update_service)
    allow(inventory_filters_update_service).to receive(:execute)
  end

  shared_examples 'calls inventory filters service once' do
    it 'calls InventoryFilters service with projects and their analyzer statuses' do
      expect(inventory_filters_update_service).to receive(:execute).once

      execute
    end
  end

  describe '.execute' do
    it 'creates a new instance and calls execute' do
      expect_next_instance_of(described_class) do |instance|
        expect(instance).to receive(:execute)
      end

      described_class.execute(project_ids, analyzer_type)
    end
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'when analyzer_type is not supported' do
      let(:analyzer_type) { :unsupported_analyzer }

      it 'does not call upsert_analyzers_statuses' do
        expect(service).not_to receive(:upsert_analyzers_statuses)
        execute
      end

      it 'does not call InventoryFilters service' do
        expect(inventory_filters_update_service).not_to receive(:execute)
        execute
      end
    end

    context 'when project_ids is empty' do
      let(:project_ids) { [] }

      it 'does not call upsert_analyzers_statuses' do
        expect(service).not_to receive(:upsert_analyzers_statuses)
        execute
      end

      it 'does not call InventoryFilters service' do
        expect(inventory_filters_update_service).not_to receive(:execute)
        execute
      end
    end

    context 'when project_ids is nil' do
      let(:project_ids) { nil }

      it 'does not call upsert_analyzers_statuses' do
        expect(service).not_to receive(:upsert_analyzers_statuses)
        execute
      end

      it 'does not call InventoryFilters service' do
        expect(inventory_filters_update_service).not_to receive(:execute)
        execute
      end
    end

    shared_examples 'analyzer behavior' do |analyzer_type_sym, setting_field, expected_analyzer_type|
      let(:analyzer_type) { analyzer_type_sym }

      let(:pipeline_based_type) do
        case expected_analyzer_type
        when :secret_detection_secret_push_protection then :secret_detection_pipeline_based
        when :container_scanning_for_registry then :container_scanning_pipeline_based
        end
      end

      let(:aggregated_type) do
        case expected_analyzer_type
        when :secret_detection_secret_push_protection then :secret_detection
        when :container_scanning_for_registry then :container_scanning
        end
      end

      context 'when projects have security settings' do
        context 'when both settings are enabled (true)' do
          before do
            project1.security_setting.update!(setting_field => true)
            project2.security_setting.update!(setting_field => true)
          end

          it 'creates analyzer status records with success status' do
            expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(4) # 2 setting + 2 aggregated
            project1_status = Security::AnalyzerProjectStatus
                                .find_by(project: project1, analyzer_type: expected_analyzer_type)
            project2_status = Security::AnalyzerProjectStatus
                                .find_by(project: project2, analyzer_type: expected_analyzer_type)

            expect(project1_status).to have_attributes(status: 'success', archived: false, build_id: nil)
            expect(project2_status).to have_attributes(status: 'success', archived: false, build_id: nil)
          end

          include_examples 'calls inventory filters service once'
        end

        context 'when settings are mixed (true and false)' do
          before do
            project1.security_setting.update!(setting_field => true)
            project2.security_setting.update!(setting_field => false)
          end

          it 'creates analyzer status records with different statuses' do
            expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(4) # 2 setting + 2 aggregated
            project1_status = Security::AnalyzerProjectStatus
                                .find_by(project: project1, analyzer_type: expected_analyzer_type)
            project2_status = Security::AnalyzerProjectStatus
                                .find_by(project: project2, analyzer_type: expected_analyzer_type)

            expect(project1_status).to have_attributes(status: 'success', archived: false, build_id: nil)
            expect(project2_status).to have_attributes(status: 'not_configured', archived: false, build_id: nil)
          end

          include_examples 'calls inventory filters service once'
        end

        context 'when both settings are disabled (false)' do
          before do
            project1.security_setting.update!(setting_field => false)
            project2.security_setting.update!(setting_field => false)
          end

          it 'creates analyzer status records with not_configured status' do
            expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(4) # 2 setting + 2 aggregated
            project1_status = Security::AnalyzerProjectStatus
                                .find_by(project: project1, analyzer_type: expected_analyzer_type)
            project2_status = Security::AnalyzerProjectStatus
                                .find_by(project: project2, analyzer_type: expected_analyzer_type)

            expect(project1_status).to have_attributes(status: 'not_configured', archived: false, build_id: nil)
            expect(project2_status).to have_attributes(status: 'not_configured', archived: false, build_id: nil)
          end

          include_examples 'calls inventory filters service once'
        end

        context 'when project is archived' do
          before do
            project1.update!(archived: true)
            project1.security_setting.update!(setting_field => true)
            project2.security_setting.update!(setting_field => false)
          end

          it 'includes archived status in the analyzer status' do
            execute

            project1_status = Security::AnalyzerProjectStatus
                                .find_by(project: project1, analyzer_type: expected_analyzer_type)
            project2_status = Security::AnalyzerProjectStatus
                                .find_by(project: project2, analyzer_type: expected_analyzer_type)

            expect(project1_status).to have_attributes(status: 'success', archived: true)
            expect(project2_status).to have_attributes(status: 'not_configured', archived: false)
          end

          include_examples 'calls inventory filters service once'
        end
      end

      context 'when projects have applicable scan profiles' do
        let_it_be(:scan_profile) do
          create(:security_scan_profile, scan_type: analyzer_type_sym, namespace: root_group)
        end

        context 'when setting is disabled but project has applicable scan profile' do
          let_it_be(:profile_project_association) do
            create(:security_scan_profile_project, scan_profile: scan_profile, project: project1)
          end

          before do
            project1.security_setting.update!(setting_field => false)
            project2.security_setting.update!(setting_field => false)
          end

          it 'creates success status for project with profile and not_configured for project without' do
            execute

            project1_status = Security::AnalyzerProjectStatus
              .find_by(project: project1, analyzer_type: expected_analyzer_type)
            project2_status = Security::AnalyzerProjectStatus
              .find_by(project: project2, analyzer_type: expected_analyzer_type)

            expect(project1_status).to have_attributes(status: 'success')
            expect(project2_status).to have_attributes(status: 'not_configured')
          end

          it 'updates aggregated type status based on profile' do
            execute

            project1_aggregated = Security::AnalyzerProjectStatus
              .find_by(project: project1, analyzer_type: analyzer_type_sym)

            expect(project1_aggregated).to have_attributes(status: 'success')
          end

          include_examples 'calls inventory filters service once'
        end

        context 'when multiple projects have different profile configurations' do
          before do
            # project1: setting disabled, has profile -> success
            create(:security_scan_profile_project, scan_profile: scan_profile, project: project1)
            project1.security_setting.update!(setting_field => false)

            # project2: setting enabled, no profile -> success
            project2.security_setting.update!(setting_field => true)

            # project3: setting disabled, no profile -> not_configured
            project3.security_setting.update!(setting_field => false)
          end

          let(:project_ids) { [project1.id, project2.id, project3.id] }

          it 'creates correct statuses based on setting OR profile' do
            execute

            expect(Security::AnalyzerProjectStatus.find_by(project: project1, analyzer_type: expected_analyzer_type))
              .to have_attributes(status: 'success')
            expect(Security::AnalyzerProjectStatus.find_by(project: project2, analyzer_type: expected_analyzer_type))
              .to have_attributes(status: 'success')
            expect(Security::AnalyzerProjectStatus.find_by(project: project3, analyzer_type: expected_analyzer_type))
              .to have_attributes(status: 'not_configured')
          end

          include_examples 'calls inventory filters service once'
        end
      end

      context 'when updating existing analyzer status records' do
        let_it_be_with_reload(:existing_record1) do
          create(:analyzer_project_status, project: project1, analyzer_type: expected_analyzer_type, status: :failed)
        end

        let_it_be_with_reload(:existing_record2) do
          create(:analyzer_project_status, project: project2, analyzer_type: expected_analyzer_type, status: :success)
        end

        before do
          project1.security_setting.update!(setting_field => true)
          project2.security_setting.update!(setting_field => false)
        end

        it 'updates existing records without creating new ones' do
          expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(2) # only aggregated types created

          expect(existing_record1.reload).to have_attributes(status: 'success', archived: false, build_id: nil)
          expect(existing_record2.reload).to have_attributes(status: 'not_configured', archived: false, build_id: nil)
        end

        include_examples 'calls inventory filters service once'
      end

      context 'when some projects have existing records and others do not' do
        let_it_be_with_reload(:existing_record) do
          create(:analyzer_project_status, project: project1, analyzer_type: expected_analyzer_type, status: :failed)
        end

        before do
          project1.security_setting.update!(setting_field => true)
          project2.security_setting.update!(setting_field => false)
        end

        it 'updates existing record and creates new record' do
          expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(3) # 1 setting + 2 aggregated

          expect(existing_record.reload).to have_attributes(status: 'success')

          new_record = Security::AnalyzerProjectStatus
            .find_by(project: project2, analyzer_type: expected_analyzer_type)
          expect(new_record).to have_attributes(status: 'not_configured', archived: false, build_id: nil)
        end

        include_examples 'calls inventory filters service once'
      end

      context 'when aggregated type already exists with matching status' do
        let_it_be(:existing_setting_record) do
          create(:analyzer_project_status, project: project1, analyzer_type: expected_analyzer_type, status: :success)
        end

        let!(:existing_aggregated_record) do
          create(:analyzer_project_status, project: project1, analyzer_type: aggregated_type, status: :success)
        end

        before do
          project1.security_setting.update!(setting_field => true)
          project2.security_setting.update!(setting_field => false)
        end

        it 'updates the aggregated record when status matches' do
          travel_to(1.minute.from_now) do
            expect { execute }.to change { existing_aggregated_record.reload.updated_at }
          end
        end

        it 'creates status records for non-existing type' do
          expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(2) # 1 setting + 1 aggregated
        end

        include_examples 'calls inventory filters service once'
      end

      context 'when aggregated type exists with different status' do
        let_it_be(:existing_setting_record) do
          create(:analyzer_project_status,
            project: project1, analyzer_type: expected_analyzer_type, status: :not_configured)
        end

        let!(:existing_aggregated_record) do
          create(:analyzer_project_status, project: project1, analyzer_type: aggregated_type, status: :not_configured)
        end

        before do
          project1.security_setting.update!(setting_field => true)
          project2.security_setting.update!(setting_field => false)
        end

        it 'updates the aggregated record when status differs' do
          execute

          expect(existing_aggregated_record.reload)
            .to have_attributes(status: 'success', archived: false, build_id: nil)
        end

        it 'creates the correct number of records' do
          expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(2) # 1 setting + 1 aggregated
        end

        include_examples 'calls inventory filters service once'
      end

      context 'when aggregated type exists but other type has higher priority' do
        let_it_be(:existing_setting_record) do
          create(:analyzer_project_status,
            project: project1, analyzer_type: expected_analyzer_type, status: :not_configured)
        end

        let!(:existing_pipeline_record) do
          create(:analyzer_project_status, project: project1, analyzer_type: pipeline_based_type, status: :failed)
        end

        let!(:existing_aggregated_record) do
          create(:analyzer_project_status, project: project1, analyzer_type: aggregated_type, status: :failed)
        end

        before do
          project1.security_setting.update!(setting_field => true)
          project2.security_setting.update!(setting_field => false)
        end

        it 'does not update aggregated record when other type has higher priority' do
          original_updated_at = existing_aggregated_record.updated_at

          travel_to(1.minute.from_now) do
            execute

            expect(existing_aggregated_record.reload.updated_at.to_i).to eq(original_updated_at.to_i)
            expect(existing_aggregated_record.reload.status).to eq('failed')
          end
        end

        include_examples 'calls inventory filters service once'
      end

      context 'when aggregated type exists but pipeline-based is stale' do
        let_it_be(:existing_setting_record) do
          create(:analyzer_project_status,
            project: project1, analyzer_type: expected_analyzer_type, status: :not_configured)
        end

        let!(:existing_pipeline_record) do
          create(:analyzer_project_status, project: project1, analyzer_type: pipeline_based_type, status: :stale)
        end

        let!(:existing_aggregated_record) do
          create(:analyzer_project_status, project: project1, analyzer_type: aggregated_type, status: :stale)
        end

        before do
          project1.security_setting.update!(setting_field => true)
          project2.security_setting.update!(setting_field => false)
        end

        it 'does not update aggregated record when setting-based becomes success' do
          travel_to(1.minute.from_now) do
            expect { execute }
              .to not_change { existing_aggregated_record.reload.updated_at }
              .and not_change { existing_aggregated_record.reload.status }
          end
        end

        include_examples 'calls inventory filters service once'
      end
    end

    describe 'secret_detection analyzer' do
      include_examples 'analyzer behavior',
        :secret_detection,
        :secret_push_protection_enabled,
        :secret_detection_secret_push_protection
    end

    describe 'container_scanning analyzer' do
      include_examples 'analyzer behavior',
        :container_scanning, :container_scanning_for_registry_enabled, :container_scanning_for_registry
    end

    context 'when secret push protection is enforced at instance level' do
      let(:analyzer_type) { :secret_detection }

      before do
        stub_application_setting(secret_push_protection_enforced: true)
        project1.security_setting.update!(secret_push_protection_enabled: false)
        project2.security_setting.update!(secret_push_protection_enabled: false)
      end

      it 'reports all projects as success regardless of project-level setting' do
        execute

        project1_status = Security::AnalyzerProjectStatus
          .find_by(project: project1, analyzer_type: :secret_detection_secret_push_protection)
        project2_status = Security::AnalyzerProjectStatus
          .find_by(project: project2, analyzer_type: :secret_detection_secret_push_protection)

        expect(project1_status).to have_attributes(status: 'success')
        expect(project2_status).to have_attributes(status: 'success')
      end

      include_examples 'calls inventory filters service once'
    end

    context 'when secret push protection is not enforced at instance level' do
      let(:analyzer_type) { :secret_detection }

      before do
        stub_application_setting(secret_push_protection_enforced: false)
        project1.security_setting.update!(secret_push_protection_enabled: false)
        project2.security_setting.update!(secret_push_protection_enabled: false)
      end

      it 'reports projects as not_configured based on project-level setting' do
        execute

        project1_status = Security::AnalyzerProjectStatus
          .find_by(project: project1, analyzer_type: :secret_detection_secret_push_protection)
        project2_status = Security::AnalyzerProjectStatus
          .find_by(project: project2, analyzer_type: :secret_detection_secret_push_protection)

        expect(project1_status).to have_attributes(status: 'not_configured')
        expect(project2_status).to have_attributes(status: 'not_configured')
      end

      include_examples 'calls inventory filters service once'
    end

    context 'when instance-level enforcement does not affect container_scanning' do
      let(:analyzer_type) { :container_scanning }

      before do
        stub_application_setting(secret_push_protection_enforced: true)
        project1.security_setting.update!(container_scanning_for_registry_enabled: false)
        project2.security_setting.update!(container_scanning_for_registry_enabled: false)
      end

      it 'still reports container_scanning projects as not_configured' do
        execute

        project1_status = Security::AnalyzerProjectStatus
          .find_by(project: project1, analyzer_type: :container_scanning_for_registry)
        project2_status = Security::AnalyzerProjectStatus
          .find_by(project: project2, analyzer_type: :container_scanning_for_registry)

        expect(project1_status).to have_attributes(status: 'not_configured')
        expect(project2_status).to have_attributes(status: 'not_configured')
      end

      include_examples 'calls inventory filters service once'
    end

    context 'when projects do not have security settings' do
      let_it_be_with_reload(:project_without_settings) { create(:project, group: group) }
      let_it_be(:project_ids) { [project_without_settings.id] }

      before do
        project_without_settings.security_setting&.delete
      end

      it 'creates records with not_configured status' do
        expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(2) # 1 setting + 1 aggregated

        setting_record = Security::AnalyzerProjectStatus.find_by(
          project: project_without_settings, analyzer_type: :secret_detection_secret_push_protection
        )
        aggregated_record = Security::AnalyzerProjectStatus.find_by(
          project: project_without_settings, analyzer_type: :secret_detection)

        expect(setting_record).to have_attributes(status: 'not_configured')
        expect(aggregated_record).to have_attributes(status: 'not_configured')
      end

      context 'when project has scan profile' do
        let_it_be(:scan_profile) do
          create(:security_scan_profile, scan_type: :secret_detection, namespace: root_group)
        end

        let_it_be(:profile_project_association) do
          create(:security_scan_profile_project, scan_profile: scan_profile, project: project_without_settings)
        end

        it 'creates success status based on profile' do
          execute

          setting_record = Security::AnalyzerProjectStatus.find_by(
            project: project_without_settings, analyzer_type: :secret_detection_secret_push_protection
          )
          aggregated_record = Security::AnalyzerProjectStatus.find_by(
            project: project_without_settings, analyzer_type: :secret_detection
          )

          expect(setting_record).to have_attributes(status: 'success')
          expect(aggregated_record).to have_attributes(status: 'success')
        end
      end

      include_examples 'calls inventory filters service once'
    end

    context 'when projects have status changes' do
      before do
        project1.security_setting.update!(secret_push_protection_enabled: true)
        project2.security_setting.update!(secret_push_protection_enabled: false)
      end

      it 'calls DiffsService with correct analyzers_statuses hash structure' do
        expected_hash_structure = hash_including(
          project1 => hash_including(
            secret_detection_secret_push_protection: hash_including(
              project_id: project1.id,
              analyzer_type: :secret_detection_secret_push_protection,
              status: :success
            ),
            secret_detection: hash_including(
              project_id: project1.id,
              analyzer_type: :secret_detection,
              status: :success
            )
          ),
          project2 => hash_including(
            secret_detection_secret_push_protection: hash_including(
              project_id: project2.id,
              analyzer_type: :secret_detection_secret_push_protection,
              status: :not_configured
            ),
            secret_detection: hash_including(
              project_id: project2.id,
              analyzer_type: :secret_detection,
              status: :not_configured
            )
          )
        )

        expect(Security::AnalyzersStatus::DiffsService).to receive(:new).with(expected_hash_structure).and_call_original

        execute
      end

      it 'calls AncestorsUpdateService with correct namespace diff structure when there are changes' do
        create(:analyzer_project_status, project: project1, analyzer_type: :secret_detection_secret_push_protection,
          status: :failed)

        create(:analyzer_project_status, project: project1, analyzer_type: :secret_detection, status: :failed)

        expect(Security::AnalyzerNamespaceStatuses::AncestorsUpdateService)
          .to receive(:execute).with(hash_including(
            namespace_id: group.id,
            traversal_ids: group.traversal_ids,
            diff: hash_including(
              secret_detection_secret_push_protection: hash_including('success' => 1, 'failed' => -1),
              secret_detection: hash_including('success' => 1, 'failed' => -1)
            )))

        execute
      end

      it 'calls InventoryFilters service with projects and their statuses' do
        expect(inventory_filters_update_service).to receive(:execute).once.with(
          match_array([project1, project2]),
          match_array([
            hash_including(
              project_id: project1.id,
              analyzer_type: :secret_detection_secret_push_protection,
              status: :success
            ),
            hash_including(
              project_id: project1.id,
              analyzer_type: :secret_detection,
              status: :success
            ),
            hash_including(
              project_id: project2.id,
              analyzer_type: :secret_detection_secret_push_protection,
              status: :not_configured
            ),
            hash_including(
              project_id: project2.id,
              analyzer_type: :secret_detection,
              status: :not_configured
            )
          ])
        )

        execute
      end
    end

    context 'with multiple namespaces' do
      let_it_be(:another_root_group) { create(:group) }
      let_it_be(:another_group) { create(:group, parent: another_root_group) }
      let_it_be_with_reload(:project_in_another_namespace) { create(:project, group: another_group) }

      let(:project_ids) { [project1.id, project_in_another_namespace.id] }

      context 'when status is determined by security settings' do
        before do
          project1.security_setting.update!(secret_push_protection_enabled: true)
          project_in_another_namespace.security_setting.update!(secret_push_protection_enabled: false)
        end

        it 'calls AncestorsUpdateService once for each namespace' do
          expect(Security::AnalyzerNamespaceStatuses::AncestorsUpdateService)
            .to receive(:execute).with(hash_including(namespace_id: group.id)).once

          expect(Security::AnalyzerNamespaceStatuses::AncestorsUpdateService).to receive(:execute)
            .with(hash_including(namespace_id: another_group.id)).once

          execute
        end

        it 'calls InventoryFilters service with all projects from different namespaces' do
          expect(inventory_filters_update_service).to receive(:execute).once.with(
            match_array([project1, project_in_another_namespace]),
            anything
          )

          execute
        end
      end

      context 'when status is determined by scan profiles' do
        let_it_be(:scan_profile_1) do
          create(:security_scan_profile, scan_type: :secret_detection, namespace: root_group)
        end

        let_it_be(:scan_profile_2) do
          create(:security_scan_profile, scan_type: :secret_detection, namespace: another_root_group)
        end

        before do
          create(:security_scan_profile_project, scan_profile: scan_profile_1, project: project1)
          create(:security_scan_profile_project, scan_profile: scan_profile_2, project: project_in_another_namespace)

          project1.security_setting.update!(secret_push_protection_enabled: false)
          project_in_another_namespace.security_setting.update!(secret_push_protection_enabled: false)
        end

        it 'creates success status for both projects based on their respective scan profiles' do
          execute

          project1_status = Security::AnalyzerProjectStatus.find_by(
            project: project1, analyzer_type: :secret_detection_secret_push_protection
          )
          project_in_another_namespace_status = Security::AnalyzerProjectStatus.find_by(
            project: project_in_another_namespace, analyzer_type: :secret_detection_secret_push_protection
          )

          expect(project1_status).to have_attributes(status: 'success')
          expect(project_in_another_namespace_status).to have_attributes(status: 'success')
        end
      end
    end

    context 'without an aggregated status for some projects' do
      before do
        project1.security_setting.update!(secret_push_protection_enabled: true)

        create(:analyzer_project_status, project: project1, analyzer_type: :secret_detection_pipeline_based,
          status: :success)
      end

      it 'excludes nil aggregated statuses from the hash structure' do
        expected_hash_structure = hash_including(
          project1 => hash_including(
            secret_detection_secret_push_protection: hash_including(
              project_id: project1.id,
              analyzer_type: :secret_detection_secret_push_protection,
              status: :success
            )
          )
        )

        expect(Security::AnalyzersStatus::DiffsService).to receive(:new).with(expected_hash_structure).and_call_original

        execute
      end

      include_examples 'calls inventory filters service once'
    end
  end

  describe '#initialize' do
    context 'when project_ids count is within limit' do
      let(:project_ids) { (1..described_class::MAX_PROJECT_IDS).to_a }

      it 'does not raise an error' do
        expect { described_class.new(project_ids, analyzer_type) }.not_to raise_error
      end
    end

    context 'when project_ids count exceeds maximum limit' do
      let(:project_ids) { (1..(described_class::MAX_PROJECT_IDS + 1)).to_a }

      it 'raises TooManyProjectIdsError with correct message' do
        expect { described_class.new(project_ids, analyzer_type) }
          .to raise_error(Security::AnalyzersStatus::SettingsBasedUpdateService::TooManyProjectIdsError,
            "Cannot update analyzer statuses of more than #{described_class::MAX_PROJECT_IDS} projects")
      end
    end
  end
end

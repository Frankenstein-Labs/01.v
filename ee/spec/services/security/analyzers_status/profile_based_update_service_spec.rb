# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::ProfileBasedUpdateService, feature_category: :security_asset_inventories do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: root_group) }
  let_it_be(:build) { create(:ci_build) }
  let_it_be(:scan_profile) { create(:security_scan_profile, scan_type: :sast, namespace: root_group) }
  let_it_be_with_reload(:project1) { create(:project, group: group) }
  let_it_be_with_reload(:project2) { create(:project, group: group) }

  let(:project_ids) { [project1.id, project2.id] }
  let(:analyzer_type) { :sast }
  let(:service) { described_class.new(project_ids, analyzer_type) }
  let(:inventory_filters_update_service) { class_double(Security::InventoryFilters::AnalyzerStatusUpdateService) }

  before do
    stub_const('Security::InventoryFilters::AnalyzerStatusUpdateService', inventory_filters_update_service)
    allow(inventory_filters_update_service).to receive(:execute)
  end

  shared_examples 'performs no updates' do
    it 'does not create or update any analyzer statuses' do
      expect { execute }.not_to change { Security::AnalyzerProjectStatus.count }
    end

    it 'does not call InventoryFilters service' do
      expect(inventory_filters_update_service).not_to receive(:execute)
      execute
    end
  end

  shared_examples 'calls inventory filters service once' do
    it 'calls InventoryFilters service with projects and their analyzer statuses' do
      expect(inventory_filters_update_service).to receive(:execute).once
      execute
    end
  end

  shared_examples 'does not override pipeline-set status' do |expected_status|
    it 'does not change the existing status' do
      travel_to(1.minute.from_now) do
        expect { execute }.not_to change { existing_status.reload.updated_at }
        expect(existing_status.reload).to have_attributes(status: expected_status.to_s)
      end
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

      include_examples 'performs no updates'
    end

    context 'when project_ids is empty' do
      let(:project_ids) { [] }

      include_examples 'performs no updates'
    end

    context 'when project_ids is nil' do
      let(:project_ids) { nil }

      include_examples 'performs no updates'
    end

    describe 'coverage across all types in PROFILE_UPDATE_TYPES' do
      described_class::PROFILE_UPDATE_TYPES.each do |supported_type|
        context "when analyzer_type is :#{supported_type}" do
          let(:analyzer_type) { supported_type }
          let(:project_ids) { [project1.id] }

          before do
            profile = create(:security_scan_profile, scan_type: supported_type, namespace: root_group, name: "test")
            create(:security_scan_profile_project, scan_profile: profile, project: project1)
          end

          it 'creates a :success status record' do
            expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(1)

            expect(project1.analyzer_statuses.find_by(analyzer_type: supported_type))
              .to have_attributes(status: 'success', build_id: nil)
          end
        end
      end
    end

    context 'with the profile-based dependency_scanning_post_processing type' do
      let(:analyzer_type) { :dependency_scanning_post_processing }
      let(:project_ids) { [project1.id] }

      context 'when detaching the profile' do
        let!(:existing_status) do
          create(:analyzer_project_status, project: project1, analyzer_type: analyzer_type, status: :success)
        end

        it 'updates the status to :not_configured' do
          execute

          expect(existing_status.reload).to have_attributes(status: 'not_configured', build_id: nil)
        end
      end
    end

    context 'when attaching a profile (no previous pipeline result)' do
      context 'when project has no existing status' do
        before do
          create(:security_scan_profile_project, scan_profile: scan_profile, project: project1)
        end

        it 'creates a :success status for the project with the profile' do
          expect { execute }.to change { Security::AnalyzerProjectStatus.count }.by(1)

          expect(project1.analyzer_statuses.sast.first).to have_attributes(status: 'success', build_id: nil)
        end

        it 'does not create a record for a project without a profile' do
          execute

          expect(project2.analyzer_statuses.sast.first).to be_nil
        end

        include_examples 'calls inventory filters service once'
      end

      context 'when project has existing :not_configured status with no build_id (profile originated)' do
        let!(:existing_status) do
          create(:analyzer_project_status, project: project1, analyzer_type: analyzer_type, status: :not_configured,
            build: nil)
        end

        before do
          create(:security_scan_profile_project, scan_profile: scan_profile, project: project1)
        end

        it 'updates the status to :success' do
          expect { execute }.not_to change { Security::AnalyzerProjectStatus.count }

          expect(existing_status.reload).to have_attributes(status: 'success', build_id: nil)
        end

        include_examples 'calls inventory filters service once'
      end

      context 'when project has existing :success status with a build_id (pipeline originated)' do
        let!(:existing_status) do
          create(:analyzer_project_status, project: project1, analyzer_type: analyzer_type,
            status: :success, build: build)
        end

        before do
          create(:security_scan_profile_project, scan_profile: scan_profile, project: project1)
        end

        include_examples 'does not override pipeline-set status', :success
      end

      context 'when project has existing :failed status with a build_id (pipeline originated)' do
        let!(:existing_status) do
          create(:analyzer_project_status, project: project1, analyzer_type: analyzer_type,
            status: :failed, build: build)
        end

        before do
          create(:security_scan_profile_project, scan_profile: scan_profile, project: project1)
        end

        include_examples 'does not override pipeline-set status', :failed
      end
    end

    context 'when detaching a profile (profile removed)' do
      let!(:existing_status) do
        create(:analyzer_project_status, project: project1, analyzer_type: analyzer_type, status: :success, build: nil)
      end

      context 'when project has existing :success status with no build_id (profile originated)' do
        it 'updates the status to :not_configured' do
          execute

          expect(existing_status.reload).to have_attributes(status: 'not_configured', build_id: nil)
        end

        include_examples 'calls inventory filters service once'
      end

      context 'when project has a profile of a different scan_type' do
        let_it_be(:other_profile) do
          create(:security_scan_profile, scan_type: :dependency_scanning, namespace: root_group)
        end

        before do
          create(:security_scan_profile_project, scan_profile: other_profile, project: project1)
        end

        it 'updates the status to :not_configured' do
          execute

          expect(existing_status.reload).to have_attributes(status: 'not_configured', build_id: nil)
        end
      end

      context 'when project has existing :success status with a build_id (pipeline originated)' do
        let!(:existing_status) do
          create(:analyzer_project_status, project: project1, analyzer_type: analyzer_type,
            status: :success, build: build)
        end

        include_examples 'does not override pipeline-set status', :success
      end

      context 'when project still has another applicable profile' do
        before do
          create(:security_scan_profile_project, scan_profile: scan_profile, project: project1)
        end

        it 'keeps the status as :success' do
          execute

          expect(existing_status.reload).to have_attributes(status: 'success')
        end
      end
    end

    context 'when status changes propagate to ancestors and inventory filters' do
      before do
        create(:security_scan_profile_project, scan_profile: scan_profile, project: project1)

        create(:analyzer_project_status, project: project1, analyzer_type: :sast, status: :not_configured, build: nil)
        create(:analyzer_project_status, project: project2, analyzer_type: :sast, status: :success, build: nil)
      end

      context 'when checking ancestor namespace diff' do
        let(:project_ids) { [project1.id] } # Both project has opposing changes cancel out to net 0.

        it 'calls AncestorsUpdateService with correct namespace diff structure' do
          expect(Security::AnalyzerNamespaceStatuses::AncestorsUpdateService)
            .to receive(:execute).with(hash_including(
              namespace_id: group.id,
              traversal_ids: group.traversal_ids,
              diff: hash_including(
                sast: hash_including('success' => 1, 'not_configured' => -1)
              )))

          execute
        end
      end

      it 'calls InventoryFilters service with projects and their statuses' do
        expect(inventory_filters_update_service).to receive(:execute).once.with(
          anything,
          match_array([
            hash_including(
              project_id: project1.id,
              analyzer_type: :sast,
              status: :success
            ),
            hash_including(
              project_id: project2.id,
              analyzer_type: :sast,
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

      let_it_be(:scan_profile_2) do
        create(:security_scan_profile, scan_type: :sast, namespace: another_root_group)
      end

      let(:project_ids) { [project1.id, project_in_another_namespace.id] }

      before do
        create(:security_scan_profile_project, scan_profile: scan_profile, project: project1)
        create(:security_scan_profile_project, scan_profile: scan_profile_2, project: project_in_another_namespace)

        create(:analyzer_project_status, project: project1, analyzer_type: :sast,
          status: :not_configured, build: nil)
        create(:analyzer_project_status, project: project_in_another_namespace, analyzer_type: :sast,
          status: :not_configured, build: nil)
      end

      it 'calls AncestorsUpdateService once per namespace' do
        expect(Security::AnalyzerNamespaceStatuses::AncestorsUpdateService)
          .to receive(:execute).with(hash_including(namespace_id: group.id)).once

        expect(Security::AnalyzerNamespaceStatuses::AncestorsUpdateService)
          .to receive(:execute).with(hash_including(namespace_id: another_group.id)).once

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
          .to raise_error(described_class::TooManyProjectIdsError,
            "Cannot update analyzer statuses of more than #{described_class::MAX_PROJECT_IDS} projects")
      end
    end
  end
end

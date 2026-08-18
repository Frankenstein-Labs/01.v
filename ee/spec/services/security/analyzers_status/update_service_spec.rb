# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::UpdateService, feature_category: :security_asset_inventories do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: root_group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:pipeline) { create(:ci_empty_pipeline, project: project) }
  let_it_be(:traversal_ids) { group.traversal_ids }

  let(:service) { described_class.new(pipeline) }
  let(:diff_service) { instance_double(Security::AnalyzersStatus::DiffService) }
  let(:ancestors_update_service) { class_double(Security::AnalyzerNamespaceStatuses::AncestorsUpdateService) }
  let(:inventory_filters_update_service) { class_double(Security::InventoryFilters::AnalyzerStatusUpdateService) }
  let(:status_diff) do
    {
      namespace_id: group.id,
      traversal_ids: group.traversal_ids,
      diff: { sast: { 'success' => 1 }, dast: { 'failed' => 1 } }
    }
  end

  before do
    allow(Security::AnalyzersStatus::DiffService).to receive(:new).and_return(diff_service)
    allow(diff_service).to receive(:execute).and_return(status_diff)

    stub_const('Security::AnalyzerNamespaceStatuses::AncestorsUpdateService', ancestors_update_service)
    allow(ancestors_update_service).to receive(:execute)
    stub_const('Security::InventoryFilters::AnalyzerStatusUpdateService', inventory_filters_update_service)
    allow(inventory_filters_update_service).to receive(:execute)

    # The aggregated-types reads project.analyzer_statuses (a has_many cache); reset it
    # on both shared instances so the service sees fresh DB state in every example.
    project.association(:analyzer_statuses).reset
    pipeline.project.association(:analyzer_statuses).reset
  end

  shared_examples 'calls namespace related services' do
    it 'calls DiffService and passes diffs to NamespaceUpdateService' do
      execute

      expect(Security::AnalyzersStatus::DiffService).to have_received(:new).with(
        project,
        kind_of(Hash)
      )
      expect(diff_service).to have_received(:execute)
      expect(ancestors_update_service).to have_received(:execute).with(status_diff)
    end
  end

  shared_examples 'does not call inventory filters service' do
    it 'does not call InventoryFilters service' do
      expect(inventory_filters_update_service).not_to receive(:execute)
      execute
    end
  end

  shared_examples 'calls inventory filters service' do
    it 'calls InventoryFilters service' do
      expect(inventory_filters_update_service).to receive(:execute).once

      execute
    end
  end

  shared_examples 'creates aggregated status from pipeline-based status' do |analyzer_type, pipeline_type, status|
    it "creates #{analyzer_type} aggregated status as #{status} from #{pipeline_type}" do
      expect { execute }.to change {
        Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: analyzer_type)&.status
      }.from(nil).to(status.to_s)
    end
  end

  shared_examples 'updates aggregated status from pipeline-based status' do
    |analyzer_type, pipeline_type, old_status, new_status|
    it "updates #{analyzer_type} aggregated status from #{old_status} to #{new_status}" do
      create(:analyzer_project_status, project: project, analyzer_type: analyzer_type, status: old_status)
      create(:analyzer_project_status, project: project, analyzer_type: pipeline_type, status: old_status)

      expect { execute }.to change {
        Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: analyzer_type).status
      }.from(old_status.to_s).to(new_status.to_s)
    end
  end

  shared_examples 'preserves higher priority aggregated status' do |analyzer_type, expected_status|
    it "keeps #{analyzer_type} as #{expected_status}" do
      create(:analyzer_project_status, project: project, analyzer_type: analyzer_type, status: expected_status)

      expect { execute }.not_to change {
        Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: analyzer_type).status
      }
    end
  end

  shared_examples 'updates aggregated status based on priority' do
    |analyzer_type, pipeline_type, pipeline_status, expected_status|
    it "updates #{analyzer_type} to #{expected_status} when pipeline #{pipeline_type} is #{pipeline_status}" do
      create(:analyzer_project_status, project: project, analyzer_type: analyzer_type, status: :not_configured)
      create(:analyzer_project_status, project: project, analyzer_type: pipeline_type, status: pipeline_status)

      expect { execute }.to change {
        Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: analyzer_type).status
      }.from('not_configured').to(expected_status.to_s)
    end
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'when pipeline doesnt exist' do
      let(:service) { described_class.new(nil) }

      it 'returns nil without processing' do
        expect(execute).to be_nil
      end

      include_examples 'does not call inventory filters service'
    end

    context 'when project doesnt exist' do
      before do
        allow(pipeline).to receive(:project).and_return(nil)
      end

      it 'returns nil without processing' do
        expect(execute).to be_nil
      end

      include_examples 'does not call inventory filters service'
    end

    context 'when pipeline and project are present' do
      context 'with security scans' do
        describe 'mapping scan statuses to analyzer statuses' do
          using RSpec::Parameterized::TableSyntax

          where(:scan_status, :expected_analyzer_status) do
            described_class::SCAN_TO_ANALYZER_STATUS.map do |scan, analyzer|
              [scan.to_sym, analyzer.to_s]
            end
          end

          with_them do
            let!(:scan) do
              create(:security_scan, scan_type: :sast, pipeline: pipeline, project: project, latest: true,
                status: scan_status)
            end

            it 'creates an analyzer status with the mapped status' do
              execute

              expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast))
                .to have_attributes(status: expected_analyzer_status, build_id: scan.build_id)
            end
          end
        end

        context 'when a scan has not run' do
          let_it_be(:created_scan) do
            create(:security_scan, scan_type: :sast, pipeline: pipeline, project: project, latest: true,
              status: :created)
          end

          let_it_be(:preparing_scan) do
            create(:security_scan, scan_type: :dast, pipeline: pipeline, project: project, latest: true,
              status: :preparing)
          end

          let_it_be(:purged_scan) do
            create(:security_scan, scan_type: :dependency_scanning, pipeline: pipeline, project: project, latest: true,
              status: :purged)
          end

          it 'does not create analyzer statuses for those scan types' do
            execute

            expect(Security::AnalyzerProjectStatus.where(project: project,
              analyzer_type: [:sast, :dast, :dependency_scanning])).to be_empty
          end

          include_examples 'does not call inventory filters service'
        end

        context 'when scan_type has no corresponding analyzer group' do
          let_it_be(:sarif_scan) do
            create(:security_scan, scan_type: :sarif, pipeline: pipeline, project: project, latest: true,
              status: :succeeded)
          end

          it 'does not create an analyzer status record' do
            expect { execute }.not_to change { Security::AnalyzerProjectStatus.count }
          end

          include_examples 'does not call inventory filters service'
        end

        context 'when a sast scan has an advanced-sast build' do
          let!(:advanced_sast_build) do
            create(:ci_build, :success, pipeline: pipeline, name: 'gitlab-advanced-sast-0')
          end

          let!(:advanced_sast_scan) do
            create(:security_scan, scan_type: :sast, pipeline: pipeline, project: project, build: advanced_sast_build,
              latest: true, status: :succeeded)
          end

          it 'creates both sast and sast_advanced statuses with the correct build_id' do
            execute

            %i[sast sast_advanced].each do |type|
              expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: type))
                .to have_attributes(status: 'success', build_id: advanced_sast_build.id)
            end
          end
        end

        context 'when a sast scan has a kics-iac-sast build' do
          let!(:kics_build) do
            create(:ci_build, :success, pipeline: pipeline, name: 'kics-iac-sast-0')
          end

          let!(:kics_scan) do
            create(:security_scan, scan_type: :sast, pipeline: pipeline, project: project, build: kics_build,
              latest: true, status: :succeeded)
          end

          it 'creates only a sast_iac status' do
            execute

            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast_iac))
              .to have_attributes(status: 'success', build_id: kics_build.id)
            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast)).to be_nil
          end
        end

        context 'when a SAST scan references a deleted build through build_id' do
          let!(:advanced_sast_build) do
            create(:ci_build, :success, pipeline: pipeline, name: 'gitlab-advanced-sast-0')
          end

          let!(:sast_scan) do
            create(:security_scan, scan_type: :sast, build: advanced_sast_build, latest: true, status: :succeeded)
          end

          before do
            sast_scan.update_column(:build_id, non_existing_record_id)
          end

          it 'uses sast type status without subtype overrides' do
            execute

            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast))
              .to have_attributes(status: 'success')
            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast_advanced))
              .to be_nil
            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast_iac))
              .to be_nil
          end
        end

        context 'when a scan is not the latest' do
          let!(:non_latest_scan) do
            create(:security_scan, scan_type: :sast, pipeline: pipeline, project: project,
              latest: false, status: :succeeded)
          end

          it 'does not create an analyzer status row' do
            expect { execute }.not_to change { Security::AnalyzerProjectStatus.count }
          end

          include_examples 'does not call inventory filters service'
        end

        context 'when multiple sast scans exist with different statuses' do
          let!(:success_build) { create(:ci_build, :success, pipeline: pipeline, name: 'sast-success') }
          let!(:failed_build) { create(:ci_build, :failed, pipeline: pipeline, name: 'sast-failed') }

          let!(:success_scan) do
            create(:security_scan, scan_type: :sast, pipeline: pipeline, project: project, build: success_build,
              latest: true, status: :succeeded)
          end

          let!(:failed_scan) do
            create(:security_scan, scan_type: :sast, pipeline: pipeline, project: project, build: failed_build,
              latest: true, status: :job_failed)
          end

          it 'prioritizes the failed status' do
            execute

            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast))
              .to have_attributes(status: 'failed')
          end
        end

        context 'with various security scans' do
          let_it_be(:sast_scan) do
            create(:security_scan, scan_type: :sast, pipeline: pipeline, project: project, latest: true,
              status: :succeeded)
          end

          let_it_be(:dependency_scanning_scan) do
            create(:security_scan, scan_type: :dependency_scanning, pipeline: pipeline, project: project, latest: true,
              status: :job_failed)
          end

          let_it_be(:container_scanning_scan) do
            create(:security_scan, scan_type: :container_scanning, pipeline: pipeline, project: project, latest: true,
              status: :report_error)
          end

          let_it_be(:secret_detection_scan) do
            create(:security_scan, scan_type: :secret_detection, pipeline: pipeline, project: project, latest: true,
              status: :succeeded)
          end

          let_it_be(:kics_build) { create(:ci_build, :success, pipeline: pipeline, name: 'kics-iac-sast-0') }
          let_it_be(:kics_scan) do
            create(:security_scan, scan_type: :sast, pipeline: pipeline, project: project, build: kics_build,
              latest: true, status: :succeeded)
          end

          let_it_be(:advanced_sast_build) do
            create(:ci_build, :success, pipeline: pipeline, name: 'gitlab-advanced-sast-0')
          end

          let_it_be(:advanced_sast_scan) do
            create(:security_scan, scan_type: :sast, pipeline: pipeline, project: project, build: advanced_sast_build,
              latest: true, status: :succeeded)
          end

          it 'creates new records for analyzers with their aggregated types' do
            expect { execute }.to change { Security::AnalyzerProjectStatus.count }.from(0).to(8)
            statuses_by_type = Security::AnalyzerProjectStatus.where(project: project).index_by(&:analyzer_type)

            expect(statuses_by_type['sast'])
              .to have_attributes(status: 'success', build_id: sast_scan.build_id)

            expect(statuses_by_type['container_scanning_pipeline_based'])
              .to have_attributes(status: 'failed', build_id: container_scanning_scan.build_id)

            expect(statuses_by_type['container_scanning'])
              .to have_attributes(status: 'failed')

            expect(statuses_by_type['secret_detection_pipeline_based'])
              .to have_attributes(status: 'success', build_id: secret_detection_scan.build_id)

            expect(statuses_by_type['secret_detection'])
              .to have_attributes(status: 'success')

            expect(statuses_by_type['sast_iac'])
              .to have_attributes(status: 'success', build_id: kics_build.id)

            expect(statuses_by_type['sast_advanced'])
              .to have_attributes(status: 'success', build_id: advanced_sast_build.id)

            expect(statuses_by_type['dependency_scanning'])
              .to have_attributes(status: 'failed', build_id: dependency_scanning_scan.build_id)
          end

          it 'calls InventoryFilters service with project and analyzer statuses' do
            expect(inventory_filters_update_service).to receive(:execute).once.with(
              [project],
              array_including(
                hash_including(analyzer_type: :sast, status: :success),
                hash_including(analyzer_type: :secret_detection, status: :success)
              )
            )

            execute
          end

          include_examples 'calls namespace related services'
        end

        context 'when updating existing analyzer status rows' do
          let_it_be(:sast_build) { create(:ci_build, :success, pipeline: pipeline, started_at: nil) }
          let_it_be(:dependency_scanning_build) { create(:ci_build, :success, pipeline: pipeline) }

          let_it_be(:sast_scan) do
            create(:security_scan, scan_type: :sast, pipeline: pipeline, project: project, build: sast_build,
              latest: true, status: :succeeded)
          end

          let_it_be(:dependency_scanning_scan) do
            create(:security_scan, scan_type: :dependency_scanning, pipeline: pipeline, project: project,
              build: dependency_scanning_build, latest: true, status: :job_failed)
          end

          it 'updates existing records for analyzers in the pipeline' do
            sast_status = create(:analyzer_project_status, project: project, analyzer_type: :sast,
              status: :not_configured)
            ds_status = create(:analyzer_project_status, project: project, analyzer_type: :dependency_scanning,
              status: :success)

            expect { execute }.to change { sast_status.reload.status }.from('not_configured').to('success')
              .and change { ds_status.reload.status }.from('success').to('failed')
          end

          it 'preserves status and increments consecutive_absence_count for records not in the pipeline' do
            existing_dast_status = create(:analyzer_project_status, project: project, analyzer_type: :dast,
              status: :success, consecutive_absence_count: 0)

            expect { execute }
              .to not_change { existing_dast_status.reload.status }
              .and change { existing_dast_status.reload.consecutive_absence_count }.from(0).to(1)
          end

          it 'doesnt update existing setting based records to not_configured' do
            existing_spp_status = create(:analyzer_project_status, project: project,
              analyzer_type: :secret_detection_secret_push_protection, status: :success)

            expect { execute }.not_to change { existing_spp_status.reload.status }
          end

          it 'updates the archive column' do
            archived_status = create(:analyzer_project_status, project: project, analyzer_type: :sast,
              status: :success, archived: true)

            expect { execute }.to change { archived_status.reload.archived }.from(true).to(false)
          end

          it 'updates the last_call column' do
            sast_status = create(:analyzer_project_status, project: project, analyzer_type: :sast,
              status: :not_configured)
            ds_status = create(:analyzer_project_status, project: project, analyzer_type: :dependency_scanning,
              status: :success)

            # prefer started_at with fallback to created_at
            expect { execute }.to change { sast_status.reload.last_call }.to(sast_build.created_at)
              .and change { ds_status.reload.last_call }.to(dependency_scanning_build.started_at)
          end

          it 'updates the updated_at column' do
            old_status = create(:analyzer_project_status, project: project, analyzer_type: :cluster_image_scanning,
              status: :failed, updated_at: 1.week.ago)

            expect { execute }.to change { old_status.reload.updated_at }
          end

          include_examples 'calls namespace related services'
        end

        context 'with consecutive absence tracking' do
          let_it_be(:dast_scan) do
            create(:security_scan, scan_type: :dast, pipeline: pipeline, project: project, latest: true,
              status: :succeeded)
          end

          context 'when an absent analyzer has consecutive_absence_count below threshold' do
            let_it_be_with_reload(:sast_status) do
              create(:analyzer_project_status, project: project, analyzer_type: :sast, status: :success,
                consecutive_absence_count: 1)
            end

            it 'increments consecutive_absence_count without changing status' do
              expect { execute }
                .to change { sast_status.reload.consecutive_absence_count }.from(1).to(2)
                .and not_change { sast_status.reload.status }
            end
          end

          context 'when an absent analyzer reaches the threshold' do
            let_it_be_with_reload(:sast_status) do
              create(:analyzer_project_status, project: project, analyzer_type: :sast, status: :success,
                consecutive_absence_count: 2)
            end

            before do
              allow(Security::AnalyzersStatus::DiffService).to receive(:new).and_call_original
            end

            it 'transitions status to stale and sets consecutive_absence_count to the threshold' do
              expect { execute }
                .to change { sast_status.reload.status }.from('success').to('stale')
                .and change { sast_status.reload.consecutive_absence_count }.from(2).to(3)
            end

            it 'forwards stale transition diff to AncestorsUpdateService' do
              execute

              expect(ancestors_update_service).to have_received(:execute).with(
                hash_including(
                  diff: hash_including(
                    sast: hash_including('stale' => 1, 'success' => -1)
                  )
                )
              )
            end
          end

          context 'when a stale analyzer is ran again' do
            let!(:sast_build) { create(:ci_build, :success, pipeline: pipeline) }
            let_it_be_with_reload(:sast_scan) do
              create(:security_scan, scan_type: :sast, pipeline: pipeline, project: project, latest: true,
                status: :succeeded)
            end

            let_it_be_with_reload(:sast_status) do
              create(:analyzer_project_status, project: project, analyzer_type: :sast, status: :stale,
                consecutive_absence_count: 3)
            end

            it 'resets consecutive_absence_count to 0 and updates status from the scan' do
              expect { execute }
                .to change { sast_status.reload.status }.from('stale').to('success')
                .and change { sast_status.reload.consecutive_absence_count }.from(3).to(0)
            end
          end

          context 'when an already-stale analyzer is absent again' do
            let_it_be_with_reload(:sast_status) do
              create(:analyzer_project_status, project: project, analyzer_type: :sast, status: :stale,
                consecutive_absence_count: 3)
            end

            it 'keeps status stale and continues incrementing consecutive_absence_count' do
              expect { execute }
                .to not_change { sast_status.reload.status }
                .and change { sast_status.reload.consecutive_absence_count }.from(3).to(4)
            end
          end

          context 'when an absent analyzer preserves its last run reference' do
            let!(:previous_pipeline) { create(:ci_empty_pipeline, project: project) }
            let!(:previous_sast_build) { create(:ci_build, :sast, :success, pipeline: previous_pipeline) }
            let(:previous_last_call) { 1.week.ago }

            context 'when counting towards stale' do
              let!(:sast_status) do
                create(:analyzer_project_status, project: project, analyzer_type: :sast, status: :success,
                  consecutive_absence_count: 1, build: previous_sast_build, last_call: previous_last_call)
              end

              it 'preserves build_id and last_call from the last run' do
                expect { execute }
                  .to not_change { sast_status.reload.build_id }
                  .and not_change { sast_status.reload.last_call }
              end
            end

            context 'when transitioning to stale' do
              let!(:sast_status) do
                create(:analyzer_project_status, project: project, analyzer_type: :sast, status: :success,
                  consecutive_absence_count: 2, build: previous_sast_build, last_call: previous_last_call)
              end

              it 'preserves build_id and last_call from the last run' do
                expect { execute }
                  .to not_change { sast_status.reload.build_id }
                  .and not_change { sast_status.reload.last_call }
              end
            end

            context 'when already stale and absent again' do
              let!(:sast_status) do
                create(:analyzer_project_status, project: project, analyzer_type: :sast, status: :stale,
                  consecutive_absence_count: 3, build: previous_sast_build, last_call: previous_last_call)
              end

              it 'preserves build_id and last_call from the last run' do
                expect { execute }
                  .to not_change { sast_status.reload.build_id }
                  .and not_change { sast_status.reload.last_call }
              end
            end
          end
        end

        context 'when project has security scan profiles' do
          context 'when sast profile exists and sast scan is not in the pipeline' do
            let_it_be(:sast_profile) do
              create(:security_scan_profile, :sast, namespace: root_group, projects: [project])
            end

            let_it_be(:dast_scan) do
              create(:security_scan, scan_type: :dast, pipeline: pipeline, project: project, latest: true,
                status: :succeeded)
            end

            it 'preserves existing sast status' do
              existing_sast_status = create(:analyzer_project_status, project: project, analyzer_type: :sast,
                status: :success, consecutive_absence_count: 0)

              expect { execute }
                .to not_change { existing_sast_status.reload.status }
                .and not_change { existing_sast_status.reload.consecutive_absence_count }
            end

            it 'preserves existing sast_advanced status' do
              existing_sast_advanced_status = create(:analyzer_project_status, project: project,
                analyzer_type: :sast_advanced, status: :success, consecutive_absence_count: 0)

              expect { execute }
                .to not_change { existing_sast_advanced_status.reload.status }
                .and not_change { existing_sast_advanced_status.reload.consecutive_absence_count }
            end
          end

          context 'when sast profile exists with no dast scan' do
            let!(:sast_profile) { create(:security_scan_profile, :sast, namespace: root_group, projects: [project]) }

            it 'preserves dast status and increments its consecutive_absence_count' do
              existing_dast_status = create(:analyzer_project_status, project: project, analyzer_type: :dast,
                status: :success, consecutive_absence_count: 0)

              expect { execute }
                .to not_change { existing_dast_status.reload.status }
                .and change { existing_dast_status.reload.consecutive_absence_count }.from(0).to(1)
            end
          end
        end

        context 'when a PIPELINE_EXCLUDED_TYPE is absent from the pipeline' do
          using RSpec::Parameterized::TableSyntax

          where(:excluded_type) do
            described_class::PIPELINE_EXCLUDED_TYPES.map(&:to_sym)
          end

          with_them do
            let!(:existing_status) do
              create(:analyzer_project_status, project: project, analyzer_type: excluded_type, status: :success,
                consecutive_absence_count: 2)
            end

            it 'does not increment consecutive_absence_count or change status' do
              expect { execute }
                .to not_change { existing_status.reload.consecutive_absence_count }
                .and not_change { existing_status.reload.status }
            end
          end
        end

        context 'with aggregated type handling' do
          context 'for secret_detection aggregated type' do
            let!(:secret_detection_scan) do
              create(:security_scan, scan_type: :secret_detection, pipeline: pipeline, project: project, latest: true,
                status: :succeeded)
            end

            include_examples 'calls namespace related services'

            context 'when only pipeline-based status exists' do
              include_examples 'creates aggregated status from pipeline-based status',
                :secret_detection, :secret_detection_pipeline_based, :success

              it 'creates the pipeline-based row' do
                execute

                expect(Security::AnalyzerProjectStatus.find_by(project: project,
                  analyzer_type: :secret_detection_pipeline_based))
                  .to have_attributes(status: 'success', build_id: secret_detection_scan.build_id)
              end

              it 'calls InventoryFilters service with pipeline and aggregated statuses' do
                expect(inventory_filters_update_service).to receive(:execute).once.with(
                  [project],
                  array_including(
                    hash_including(analyzer_type: :secret_detection_pipeline_based, status: :success),
                    hash_including(analyzer_type: :secret_detection, status: :success)
                  )
                )

                execute
              end
            end

            context 'when aggregated status already exists' do
              include_examples 'updates aggregated status from pipeline-based status',
                :secret_detection, :secret_detection_pipeline_based, :not_configured, :success
            end

            context 'when both pipeline-based and setting-based statuses exist' do
              context 'when setting-based has higher priority' do
                before do
                  create(:analyzer_project_status, project: project,
                    analyzer_type: :secret_detection_secret_push_protection, status: :failed)
                end

                it 'keeps the aggregated secret_detection row at the higher-priority status' do
                  aggregated = create(:analyzer_project_status, project: project,
                    analyzer_type: :secret_detection, status: :failed)

                  expect { execute }.not_to change { aggregated.reload.status }
                end
              end

              context 'when pipeline-based has higher priority (failed)' do
                let!(:secret_detection_scan) do
                  create(:security_scan, scan_type: :secret_detection, pipeline: pipeline, project: project,
                    latest: true, status: :job_failed)
                end

                before do
                  create(:analyzer_project_status, project: project,
                    analyzer_type: :secret_detection_secret_push_protection, status: :success)
                end

                include_examples 'updates aggregated status based on priority',
                  :secret_detection, :secret_detection_pipeline_based, :failed, :failed
              end

              context 'when both have same priority (success)' do
                before do
                  create(:analyzer_project_status, project: project,
                    analyzer_type: :secret_detection_secret_push_protection, status: :success)
                end

                include_examples 'creates aggregated status from pipeline-based status',
                  :secret_detection, :secret_detection_pipeline_based, :success

                include_examples 'calls inventory filters service'
              end

              context 'when setting-based is not_configured' do
                before do
                  create(:analyzer_project_status, project: project,
                    analyzer_type: :secret_detection_secret_push_protection, status: :not_configured)
                end

                include_examples 'creates aggregated status from pipeline-based status',
                  :secret_detection, :secret_detection_pipeline_based, :success

                include_examples 'calls inventory filters service'
              end
            end
          end

          context 'for container_scanning aggregated type' do
            let!(:container_scanning_scan) do
              create(:security_scan, scan_type: :container_scanning, pipeline: pipeline, project: project,
                latest: true, status: :job_failed)
            end

            include_examples 'calls namespace related services'

            context 'when only pipeline-based status exists' do
              include_examples 'creates aggregated status from pipeline-based status',
                :container_scanning, :container_scanning_pipeline_based, :failed

              it 'creates the pipeline-based row' do
                execute

                expect(Security::AnalyzerProjectStatus.find_by(project: project,
                  analyzer_type: :container_scanning_pipeline_based))
                  .to have_attributes(status: 'failed', build_id: container_scanning_scan.build_id)
              end

              it 'calls InventoryFilters service with pipeline and aggregated statuses' do
                expect(inventory_filters_update_service).to receive(:execute).once.with(
                  [project],
                  array_including(
                    hash_including(analyzer_type: :container_scanning_pipeline_based, status: :failed),
                    hash_including(analyzer_type: :container_scanning, status: :failed)
                  )
                )

                execute
              end
            end

            context 'when aggregated status already exists' do
              include_examples 'updates aggregated status from pipeline-based status',
                :container_scanning, :container_scanning_pipeline_based, :success, :failed
            end

            context 'when both pipeline-based and setting-based statuses exist' do
              context 'when setting-based has higher priority' do
                let!(:container_scanning_scan) do
                  create(:security_scan, scan_type: :container_scanning, pipeline: pipeline, project: project,
                    latest: true, status: :succeeded)
                end

                before do
                  create(:analyzer_project_status, project: project,
                    analyzer_type: :container_scanning_for_registry, status: :failed)
                end

                include_examples 'preserves higher priority aggregated status',
                  :container_scanning, :failed

                include_examples 'calls inventory filters service'
              end

              context 'when pipeline-based has higher priority (failed)' do
                before do
                  create(:analyzer_project_status, project: project,
                    analyzer_type: :container_scanning_for_registry, status: :success)
                end

                include_examples 'updates aggregated status based on priority',
                  :container_scanning, :container_scanning_pipeline_based, :failed, :failed
              end
            end

            context 'when container_scanning_pipeline_based transitions to stale' do
              let!(:container_scanning_scan) { nil }
              let!(:dast_scan) do
                create(:security_scan, scan_type: :dast, pipeline: pipeline, project: project, latest: true,
                  status: :succeeded)
              end

              let_it_be_with_reload(:cs_pipeline_status) do
                create(:analyzer_project_status, project: project, analyzer_type: :container_scanning_pipeline_based,
                  status: :success, consecutive_absence_count: 2)
              end

              let_it_be_with_reload(:cs_aggregated_status) do
                create(:analyzer_project_status, project: project, analyzer_type: :container_scanning, status: :success)
              end

              context 'when container_scanning_for_registry is success' do
                before do
                  create(:analyzer_project_status, project: project,
                    analyzer_type: :container_scanning_for_registry, status: :success)
                end

                it 'updates container_scanning aggregated status to stale' do
                  expect { execute }
                    .to change { cs_aggregated_status.reload.status }.from('success').to('stale')
                end
              end

              context 'when container_scanning_for_registry is failed' do
                before do
                  create(:analyzer_project_status, project: project,
                    analyzer_type: :container_scanning_for_registry, status: :failed)
                end

                it 'keeps container_scanning aggregated status unchanged' do
                  expect { execute }.not_to change { cs_aggregated_status.reload.status }
                end
              end
            end
          end

          context 'when aggregated status would not change' do
            let!(:secret_detection_scan) do
              create(:security_scan, scan_type: :secret_detection, pipeline: pipeline, project: project, latest: true,
                status: :succeeded)
            end

            let(:status) do
              Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :secret_detection)
            end

            it 'updates aggregated status build and last_call when it already has the correct status' do
              create(:analyzer_project_status, project: project, analyzer_type: :secret_detection, status: :success)
              create(:analyzer_project_status, project: project,
                analyzer_type: :secret_detection_secret_push_protection, status: :not_configured)

              expect { execute }.to change { status.reload.last_call }
                .and change { status.reload.build_id }
                .and change { status.reload.updated_at }
            end
          end

          context 'when no aggregated types are configured in pipeline' do
            let_it_be(:sast_scan) do
              create(:security_scan, scan_type: :sast, pipeline: pipeline, project: project, latest: true,
                status: :succeeded)
            end

            let_it_be(:dast_scan) do
              create(:security_scan, scan_type: :dast, pipeline: pipeline, project: project, latest: true,
                status: :job_failed)
            end

            it 'does not create aggregated status records for non-aggregated types' do
              execute

              expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :secret_detection))
                .to be_nil
              expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :container_scanning))
                .to be_nil
            end
          end

          context 'with multiple aggregated types' do
            let_it_be(:secret_detection_scan) do
              create(:security_scan, scan_type: :secret_detection, pipeline: pipeline, project: project, latest: true,
                status: :succeeded)
            end

            let_it_be(:container_scanning_scan) do
              create(:security_scan, scan_type: :container_scanning, pipeline: pipeline, project: project,
                latest: true, status: :job_failed)
            end

            before do
              create(:analyzer_project_status, project: project,
                analyzer_type: :container_scanning_for_registry, status: :success)
              create(:analyzer_project_status, project: project,
                analyzer_type: :secret_detection_secret_push_protection, status: :not_configured)
              create(:analyzer_project_status, project: project,
                analyzer_type: :secret_detection, status: :not_configured)
            end

            it 'handles multiple aggregated types correctly' do
              execute

              expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :container_scanning))
                .to have_attributes(status: 'failed', build_id: container_scanning_scan.build_id)

              expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :secret_detection))
                .to have_attributes(status: 'success', build_id: secret_detection_scan.build_id)
            end

            it 'calls InventoryFilters service with correct types' do
              expect(inventory_filters_update_service).to receive(:execute).once.with(
                [project],
                array_including(
                  hash_including(analyzer_type: :secret_detection_pipeline_based),
                  hash_including(analyzer_type: :secret_detection),
                  hash_including(analyzer_type: :container_scanning_pipeline_based),
                  hash_including(analyzer_type: :container_scanning)
                )
              )

              execute
            end
          end
        end
      end

      context 'when no security scans are found' do
        it 'preserves analyzer statuses and increments their consecutive_absence_count' do
          sast_status = create(:analyzer_project_status, project: project, analyzer_type: :sast,
            status: :success, consecutive_absence_count: 0)
          dast_status = create(:analyzer_project_status, project: project, analyzer_type: :dast,
            status: :failed, consecutive_absence_count: 0)

          expect { execute }
            .to not_change { sast_status.reload.status }
            .and not_change { dast_status.reload.status }
            .and change { sast_status.reload.consecutive_absence_count }.from(0).to(1)
            .and change { dast_status.reload.consecutive_absence_count }.from(0).to(1)
        end

        it 'recomputes aggregated type status from preserved pipeline-based status' do
          sd_pipeline_status = create(:analyzer_project_status, project: project,
            analyzer_type: :secret_detection_pipeline_based, status: :success, consecutive_absence_count: 0)
          sd_aggregated_status = create(:analyzer_project_status, project: project,
            analyzer_type: :secret_detection, status: :failed)

          expect { execute }
            .to not_change { sd_pipeline_status.reload.status }
            .and change { sd_pipeline_status.reload.consecutive_absence_count }.from(0).to(1)
            .and change { sd_aggregated_status.reload.status }.from('failed').to('success')
        end

        include_examples 'does not call inventory filters service'
        include_examples 'calls namespace related services'
      end

      context 'when an exception occurs' do
        before do
          allow(diff_service).to receive(:execute).and_raise(StandardError.new('Test error'))
        end

        it 'tracks the exception with error tracking' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception)
            .with(an_instance_of(StandardError), hash_including(project_id: project.id, pipeline_id: pipeline.id))

          execute
        end

        it 'does not call AncestorsUpdateService' do
          allow(Gitlab::ErrorTracking).to receive(:track_exception)

          execute

          expect(ancestors_update_service).not_to have_received(:execute)
        end
      end
    end
  end
end

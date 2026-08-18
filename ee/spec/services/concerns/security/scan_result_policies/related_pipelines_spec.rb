# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::RelatedPipelines, feature_category: :security_policy_management do
  let_it_be(:target_branch) { 'main' }
  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be_with_refind(:merge_request) do
    create(:merge_request, :with_merge_request_pipeline, source_project: project)
  end

  let_it_be_with_refind(:approval_rule) do
    create(:approval_project_rule, :scan_finding)
  end

  let(:subject_class) do
    Class.new do
      include Security::ScanResultPolicies::RelatedPipelines
    end
  end

  describe '#related_pipeline_sources' do
    let(:expected_sources) { Enums::Ci::Pipeline.ci_and_security_orchestration_sources.values }

    subject(:related_pipeline_sources) { subject_class.new.related_pipeline_sources }

    it 'returns the related pipeline sources' do
      expect(related_pipeline_sources).to eq(expected_sources)
    end
  end

  describe '#target_pipeline_for_merge_request' do
    subject(:target_pipeline) do
      subject_class.new.target_pipeline_for_merge_request(merge_request, report_type, approval_rule)
    end

    before do
      merge_request.update_head_pipeline
      allow(Gitlab::AppJsonLogger).to receive(:info)
    end

    shared_examples 'target_pipeline_for_merge_request' do |report_type|
      let_it_be(:report_type) { report_type }
      let_it_be(:pipeline_report_type) do
        report_type == :scan_finding ? :with_dependency_scanning_report : :with_cyclonedx_report
      end

      context 'when there is no pipeline on target branch' do
        it 'returns nil' do
          expect(target_pipeline).to be_nil
        end
      end

      context 'when there are pipelines on target branch' do
        context 'when there are pipelines with the expected report type' do
          let_it_be(:pipeline) do
            create(:ee_ci_pipeline, :success,
              pipeline_report_type,
              project: project,
              ref: merge_request.target_branch,
              sha: merge_request.diff_base_sha
            )
          end

          let_it_be(:latest_pipeline) do
            create(:ee_ci_pipeline, :success,
              pipeline_report_type,
              project: project,
              ref: merge_request.target_branch,
              sha: merge_request.diff_base_sha
            )
          end

          it 'returns the latest pipeline on the target branch with the expected report type' do
            expect(target_pipeline).to eq(latest_pipeline)
          end

          context 'when there is a most recent pipeline without the expected report type' do
            let_it_be(:pipeline_without_security_report) do
              create(:ee_ci_pipeline, :success,
                project: project,
                ref: merge_request.target_branch,
                sha: merge_request.diff_base_sha
              )
            end

            it 'returns the latest pipeline on the target branch with the expected report type' do
              expect(target_pipeline).to eq(latest_pipeline)
            end
          end
        end

        context 'when there is no pipeline with the expected report type on the target branch' do
          let_it_be(:pipeline) do
            create(:ee_ci_pipeline, :success,
              project: project,
              ref: merge_request.target_branch,
              sha: merge_request.diff_base_sha
            )
          end

          it 'returns the latest pipeline on the target branch' do
            expect(target_pipeline).to eq(pipeline)
          end
        end
      end

      context 'when there is a comparison pipeline with the expected report type' do
        let_it_be(:comparison_pipeline) do
          create(:ee_ci_pipeline, :success,
            pipeline_report_type,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.diff_base_sha
          )
        end

        before do
          create(:ee_ci_pipeline, :success,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.diff_base_sha
          )
        end

        it 'returns the comparison pipeline with the expected report type' do
          expect(target_pipeline).to eq(comparison_pipeline)
        end
      end

      context 'when approval_rule has security_report_time_window' do
        let_it_be(:approval_policy_rule) do
          create(:approval_policy_rule, :scan_finding).tap do |rule|
            rule.security_policy.update!(
              content: {
                policy_tuning: { security_report_time_window: 60 }
              }
            )
          end
        end

        before do
          approval_rule.update!(approval_policy_rule: approval_policy_rule)
        end

        context 'when there is a reference pipeline within time window' do
          let_it_be(:pipeline_within_window) do
            create(:ee_ci_pipeline, :success,
              pipeline_report_type,
              project: project,
              ref: merge_request.target_branch,
              sha: 'previous-sha',
              created_at: 30.minutes.ago
            )
          end

          let_it_be(:reference_pipeline) do
            create(:ee_ci_pipeline, :success,
              project: project,
              ref: merge_request.target_branch,
              sha: merge_request.diff_base_sha
            )
          end

          it 'returns the pipeline within the time window' do
            expect(target_pipeline).to eq(pipeline_within_window)
          end

          it 'logs the pipeline selection with all required fields' do
            target_pipeline

            expect(Gitlab::AppJsonLogger).to have_received(:info).with(
              hash_including(
                message: 'Pipeline found within time window',
                workflow: 'approval_policy_evaluation',
                event: 'approval_policy_pipeline_selection',
                project_path: project.full_path,
                merge_request_id: merge_request.id,
                merge_request_iid: merge_request.iid,
                selected_pipeline_id: pipeline_within_window.id,
                reference_pipeline_id: reference_pipeline.id
              )
            )
          end
        end

        context 'when there is no pipeline within time window' do
          let_it_be(:pipeline_outside_window) do
            create(:ee_ci_pipeline, :success,
              pipeline_report_type,
              project: project,
              ref: merge_request.target_branch,
              sha: 'previous-sha',
              created_at: 2.hours.ago
            )
          end

          let_it_be(:reference_pipeline) do
            create(:ee_ci_pipeline, :success,
              project: project,
              ref: merge_request.target_branch,
              sha: merge_request.diff_base_sha,
              created_at: 1.hour.ago
            )
          end

          it 'returns the latest target branch pipeline' do
            expect(target_pipeline).to eq(reference_pipeline)
          end

          it 'logs that no pipeline was found within time window' do
            target_pipeline

            expect(Gitlab::AppJsonLogger).to have_received(:info).with(
              hash_including(
                message: 'Pipeline not found within time window',
                workflow: 'approval_policy_evaluation',
                event: 'approval_policy_pipeline_selection',
                project_path: project.full_path,
                merge_request_id: merge_request.id,
                merge_request_iid: merge_request.iid,
                selected_pipeline_id: nil,
                reference_pipeline_id: reference_pipeline.id
              )
            )
          end
        end
      end

      context 'when approval_rule has no security_report_time_window' do
        it 'returns the latest target branch pipeline' do
          latest_pipeline = create(:ee_ci_pipeline, :success,
            pipeline_report_type,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.diff_base_sha
          )

          expect(target_pipeline).to eq(latest_pipeline)
        end
      end
    end

    context 'when report_type is scan_finding' do
      include_examples 'target_pipeline_for_merge_request', :scan_finding
    end

    context 'when report_type is license_scanning' do
      include_examples 'target_pipeline_for_merge_request', :license_scanning
    end
  end

  describe '#related_target_pipeline_ids_for_merge_request' do
    let(:report_type) { :scan_finding }

    subject(:related_target_pipeline_ids) do
      subject_class.new.related_target_pipeline_ids_for_merge_request(merge_request, report_type, approval_rule)
    end

    context 'when there is no pipeline on target branch' do
      it 'returns an empty array' do
        expect(related_target_pipeline_ids).to be_empty
      end
    end

    context 'when there are related pipelines on target branch' do
      let_it_be(:pipeline) do
        create(:ee_ci_pipeline, :success,
          :with_dependency_scanning_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.diff_head_sha
        )
      end

      let_it_be(:another_pipeline) do
        create(:ee_ci_pipeline, :success,
          :with_dependency_scanning_report,
          project: project,
          source: Enums::Ci::Pipeline.sources[:security_orchestration_policy],
          ref: merge_request.target_branch,
          sha: merge_request.diff_head_sha
        )
      end

      it 'returns the related target pipeline ids' do
        expect(related_target_pipeline_ids).to match_array([pipeline.id, another_pipeline.id])
      end
    end
  end

  shared_context 'with related pipelines' do
    let_it_be(:pipeline) do
      create(:ee_ci_pipeline, :success,
        :with_dependency_scanning_report,
        project: project,
        ref: merge_request.source_branch,
        sha: merge_request.diff_head_sha,
        merge_requests_as_head_pipeline: [merge_request]
      )
    end

    let_it_be(:another_pipeline) do
      create(:ee_ci_pipeline, :success,
        :with_dependency_scanning_report,
        project: project,
        source: Enums::Ci::Pipeline.sources[:security_orchestration_policy],
        ref: merge_request.source_branch,
        sha: merge_request.diff_head_sha
      )
    end

    let_it_be(:unrelated_pipeline) do
      create(:ee_ci_pipeline, :success,
        project: project,
        source: Enums::Ci::Pipeline.sources[:ondemand_dast_scan],
        ref: merge_request.source_branch,
        sha: merge_request.diff_head_sha
      )
    end
  end

  describe '#related_pipeline_ids' do
    include_context 'with related pipelines'

    let(:pipeline) { merge_request.diff_head_pipeline }

    subject(:related_pipeline_ids) { subject_class.new.related_pipeline_ids(pipeline) }

    it 'returns the related pipeline ids' do
      expect(related_pipeline_ids).to match_array([pipeline.id, another_pipeline.id])
    end

    context 'when pipeline is nil' do
      let(:pipeline) { nil }

      it 'returns empty array' do
        expect(related_pipeline_ids).to be_empty
      end
    end
  end

  describe '#related_pipelines' do
    include_context 'with related pipelines'

    let(:pipeline) { merge_request.diff_head_pipeline }

    subject(:related_pipelines) { subject_class.new.related_pipelines(pipeline) }

    it 'returns the related pipeline ids' do
      expect(related_pipelines).to match_array([pipeline, another_pipeline])
    end

    context 'when pipeline is nil' do
      let(:pipeline) { nil }

      it 'returns empty collection' do
        expect(related_pipelines).to eq(Ci::Pipeline.none)
      end
    end
  end
end

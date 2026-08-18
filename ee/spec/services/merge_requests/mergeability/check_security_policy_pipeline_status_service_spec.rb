# frozen_string_literal: true

require "spec_helper"

RSpec.describe MergeRequests::Mergeability::CheckSecurityPolicyPipelineStatusService, feature_category: :security_policy_management do
  subject(:check_service) { described_class.new(merge_request: merge_request, params: params) }

  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:policy_management_project) { create(:project) }

  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let(:params) { { skip_security_policy_pipeline_check: skip_check } }
  let(:skip_check) { false }
  let(:diff_head_sha) { merge_request.diff_head_sha }

  it_behaves_like 'mergeability check service', :security_policy_pipeline_check,
    'Checks whether all pipelines have passed when security policies are configured'

  describe '#execute' do
    let(:result) { check_service.execute }

    before do
      stub_licensed_features(security_orchestration_policies: true)
      project.project_setting.update!(security_policy_pipeline_must_succeed: true)
    end

    context 'when project has no scan execution or pipeline execution policies' do
      it 'returns inactive without any policies' do
        expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
      end

      context 'when project has only approval policies' do
        let!(:policy_configuration) do
          create(:security_orchestration_policy_configuration,
            project: project,
            security_policy_management_project: policy_management_project)
        end

        let!(:approval_policy) do
          create(:security_policy, :require_approval,
            security_orchestration_policy_configuration: policy_configuration,
            linked_projects: [project])
        end

        it 'returns inactive' do
          expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
        end
      end
    end

    context 'when project has scan execution or pipeline execution policies' do
      let_it_be(:policy_configuration) do
        create(:security_orchestration_policy_configuration,
          project: project,
          security_policy_management_project: policy_management_project)
      end

      let_it_be(:security_policy) do
        create(:security_policy, :scan_execution_policy,
          security_orchestration_policy_configuration: policy_configuration,
          linked_projects: [project])
      end

      context 'when diff_head_sha is blank' do
        before do
          allow(merge_request).to receive(:diff_head_sha).and_return(nil)
        end

        it 'returns inactive' do
          expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
        end
      end

      context 'when no pipelines exist for the MR HEAD SHA' do
        it 'returns inactive' do
          expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
        end
      end

      context 'when pipelines exist' do
        let!(:mr_pipeline) do
          create(:ci_pipeline, project: project, sha: diff_head_sha,
            source: :merge_request_event, merge_request: merge_request,
            ref: merge_request.source_branch)
        end

        context 'when security_policy_pipeline_must_succeed setting is disabled' do
          before do
            project.project_setting.update!(security_policy_pipeline_must_succeed: false)
          end

          shared_examples_for 'an inactive mergeability check' do
            it 'returns inactive' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
            end
          end

          context 'when the pipeline is running' do
            before do
              mr_pipeline.update!(status: :running)
            end

            it_behaves_like 'an inactive mergeability check'
          end

          context 'when the pipeline has failed' do
            before do
              mr_pipeline.update!(status: :failed)
            end

            it_behaves_like 'an inactive mergeability check'
          end

          context 'when the pipeline has succeeded' do
            before do
              mr_pipeline.update!(status: :success)
            end

            it_behaves_like 'an inactive mergeability check'
          end
        end

        context 'with only an MR pipeline' do
          context 'when the pipeline is running' do
            before do
              mr_pipeline.update!(status: :running)
            end

            it 'returns checking' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::CHECKING_STATUS
            end
          end

          context 'when the pipeline has succeeded' do
            before do
              mr_pipeline.update!(status: :success)
            end

            it 'returns success' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
            end

            context 'when the security_policy_pipeline_check feature flag is disabled' do
              before do
                stub_feature_flags(security_policy_pipeline_check: false)
              end

              it 'returns inactive' do
                expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
              end
            end

            context 'when project does not have security orchestration policies license' do
              before do
                stub_licensed_features(security_orchestration_policies: false)
              end

              it 'returns inactive' do
                expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
              end
            end

            context 'with a pipeline execution policy' do
              let!(:security_policy) do
                create(:security_policy, :pipeline_execution_policy,
                  security_orchestration_policy_configuration: policy_configuration,
                  linked_projects: [project])
              end

              it 'is also applicable and returns success' do
                expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
              end
            end
          end

          context 'when the pipeline is skipped' do
            before do
              mr_pipeline.update!(status: :skipped)
            end

            context 'when allow_merge_on_skipped_pipeline is enabled' do
              before do
                project.update!(allow_merge_on_skipped_pipeline: true)
              end

              it 'returns success' do
                expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
              end
            end

            context 'when allow_merge_on_skipped_pipeline is disabled' do
              before do
                project.update!(allow_merge_on_skipped_pipeline: false)
              end

              context 'when "pipelines must succeed" is enabled' do
                before do
                  project.update!(only_allow_merge_if_pipeline_succeeds: true)
                end

                it 'returns failure' do
                  expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS
                end
              end

              context 'when "pipelines must succeed" is disabled' do
                before do
                  project.update!(only_allow_merge_if_pipeline_succeeds: false)
                end

                it 'returns warning' do
                  expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::WARNING_STATUS
                end
              end
            end
          end

          context 'when the pipeline has failed' do
            before do
              mr_pipeline.update!(status: :failed)
            end

            context 'when "pipelines must succeed" is enabled' do
              before do
                project.update!(only_allow_merge_if_pipeline_succeeds: true)
              end

              it 'returns failure (hard block)' do
                expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS
              end
            end

            context 'when "pipelines must succeed" is disabled' do
              before do
                project.update!(only_allow_merge_if_pipeline_succeeds: false)
              end

              it 'returns warning (soft block)' do
                expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::WARNING_STATUS
              end
            end
          end
        end

        context 'with both MR pipeline and branch pipeline' do
          let!(:branch_pipeline) do
            create(:ci_pipeline, project: project, sha: diff_head_sha,
              source: :push, ref: merge_request.source_branch)
          end

          context 'when both pipelines have succeeded' do
            before do
              mr_pipeline.update!(status: :success)
              branch_pipeline.update!(status: :success)
            end

            it 'returns success' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
            end
          end

          context 'when the MR pipeline succeeded but branch pipeline is running' do
            before do
              mr_pipeline.update!(status: :success)
              branch_pipeline.update!(status: :running)
            end

            it 'returns checking' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::CHECKING_STATUS
            end
          end

          context 'when the MR pipeline succeeded but branch pipeline failed' do
            before do
              mr_pipeline.update!(status: :success)
              branch_pipeline.update!(status: :failed)
            end

            context 'when "pipelines must succeed" is enabled' do
              before do
                project.update!(only_allow_merge_if_pipeline_succeeds: true)
              end

              it 'returns failure (hard block)' do
                expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS
              end
            end

            context 'when "pipelines must succeed" is disabled' do
              before do
                project.update!(only_allow_merge_if_pipeline_succeeds: false)
              end

              it 'returns warning (soft block)' do
                expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::WARNING_STATUS
              end
            end
          end

          context 'when both pipelines are pending' do
            before do
              mr_pipeline.update!(status: :pending)
              branch_pipeline.update!(status: :pending)
            end

            it 'returns checking' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::CHECKING_STATUS
            end
          end

          context 'when the branch pipeline failed but MR pipeline is running' do
            before do
              branch_pipeline.update!(status: :failed)
              mr_pipeline.update!(status: :running)
            end

            it 'returns checking because MR pipeline is still active' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::CHECKING_STATUS
            end
          end
        end

        context 'with only a branch pipeline (no MR pipeline)' do
          let!(:mr_pipeline) do
            create(:ci_pipeline, project: project, sha: diff_head_sha,
              source: :push, ref: merge_request.source_branch)
          end

          context 'when the branch pipeline succeeded' do
            before do
              mr_pipeline.update!(status: :success)
            end

            it 'returns success' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
            end
          end

          context 'when the branch pipeline failed' do
            before do
              mr_pipeline.update!(status: :failed)
              project.update!(only_allow_merge_if_pipeline_succeeds: true)
            end

            it 'returns failure' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS
            end
          end
        end

        context 'with pipelines from various branch sources' do
          let!(:web_pipeline) do
            create(:ci_pipeline, project: project, sha: diff_head_sha,
              source: :web, ref: merge_request.source_branch, status: :success)
          end

          let!(:api_pipeline) do
            create(:ci_pipeline, project: project, sha: diff_head_sha,
              source: :api, ref: merge_request.source_branch, status: :failed)
          end

          before do
            mr_pipeline.update!(status: :success)
            project.update!(only_allow_merge_if_pipeline_succeeds: true)
          end

          it 'evaluates the latest branch pipeline (by id)' do
            # api_pipeline is the latest branch pipeline (higher id)
            # and it failed, so this should block
            expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS
          end
        end

        context 'with an external pipeline (created via Commit Status API)' do
          context 'when only an external pipeline exists for the SHA' do
            let!(:mr_pipeline) do
              create(:ci_pipeline, project: project, sha: diff_head_sha,
                source: :external, ref: merge_request.source_branch, status: :success)
            end

            it 'returns inactive because external pipelines are excluded' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
            end
          end

          context 'when an external pipeline exists alongside a real pipeline' do
            let!(:mr_pipeline) do
              create(:ci_pipeline, project: project, sha: diff_head_sha,
                source: :merge_request_event, merge_request: merge_request,
                ref: merge_request.source_branch, status: :failed)
            end

            let!(:external_pipeline) do
              create(:ci_pipeline, project: project, sha: diff_head_sha,
                source: :external, ref: merge_request.source_branch, status: :success)
            end

            before do
              project.update!(only_allow_merge_if_pipeline_succeeds: true)
            end

            it 'ignores the external pipeline and returns failure based on the real pipeline' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS
            end
          end

          context 'when an external pipeline is the latest branch pipeline but a real branch pipeline also exists' do
            let!(:mr_pipeline) do
              create(:ci_pipeline, project: project, sha: diff_head_sha,
                source: :merge_request_event, merge_request: merge_request,
                ref: merge_request.source_branch, status: :success)
            end

            let!(:branch_pipeline) do
              create(:ci_pipeline, project: project, sha: diff_head_sha,
                source: :push, ref: merge_request.source_branch, status: :failed)
            end

            let!(:external_pipeline) do
              create(:ci_pipeline, project: project, sha: diff_head_sha,
                source: :external, ref: merge_request.source_branch, status: :success)
            end

            before do
              project.update!(only_allow_merge_if_pipeline_succeeds: true)
            end

            it 'ignores the external pipeline and evaluates only the real branch pipeline' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS
            end
          end
        end

        context 'with a dangling pipeline (e.g. scheduled SEP, duo_workflow)' do
          let!(:mr_pipeline) do
            create(:ci_pipeline, project: project, sha: diff_head_sha,
              source: :merge_request_event, merge_request: merge_request,
              ref: merge_request.source_branch, status: :success)
          end

          let!(:dangling_pipeline) do
            create(:ci_pipeline, project: project, sha: diff_head_sha,
              source: :security_orchestration_policy, ref: merge_request.source_branch, status: :failed)
          end

          before do
            project.update!(only_allow_merge_if_pipeline_succeeds: true)
          end

          it 'ignores the dangling pipeline and returns success based on the MR pipeline' do
            expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
          end
        end

        context 'with merged results pipeline (MR pipeline SHA differs from branch SHA)' do
          let(:merge_commit_sha) { 'merged_result_commit_sha_abc123' }

          # Override the MR pipeline to use a merge commit SHA (simulating merged results)
          let!(:mr_pipeline) do
            create(:ci_pipeline, project: project, sha: merge_commit_sha,
              source: :merge_request_event, merge_request: merge_request,
              ref: merge_request.source_branch,
              source_sha: diff_head_sha, target_sha: 'target_sha_xyz')
          end

          let!(:branch_pipeline) do
            create(:ci_pipeline, project: project, sha: diff_head_sha,
              source: :push, ref: merge_request.source_branch)
          end

          context 'when both pipelines succeed' do
            before do
              mr_pipeline.update!(status: :success)
              branch_pipeline.update!(status: :success)
            end

            it 'finds the MR pipeline via source_sha and returns success' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
            end
          end

          context 'when MR pipeline succeeds but branch pipeline fails' do
            before do
              mr_pipeline.update!(status: :success)
              branch_pipeline.update!(status: :failed)
              project.update!(only_allow_merge_if_pipeline_succeeds: true)
            end

            it 'returns failure' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS
            end
          end

          context 'when branch pipeline succeeds but MR pipeline is running' do
            before do
              branch_pipeline.update!(status: :success)
              mr_pipeline.update!(status: :running)
            end

            it 'returns checking' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::CHECKING_STATUS
            end
          end

          context 'when only the MR pipeline exists (no branch pipeline)' do
            let!(:branch_pipeline) { nil }

            before do
              mr_pipeline.update!(status: :failed)
              project.update!(only_allow_merge_if_pipeline_succeeds: true)
            end

            it 'finds the MR pipeline via source_sha and returns failure' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS
            end
          end
        end

        context 'when skip_branch_pipelines_for_mrs is enabled' do
          let!(:branch_pipeline) do
            create(:ci_pipeline, project: project, sha: diff_head_sha,
              source: :push, ref: merge_request.source_branch, status: :success)
          end

          before do
            allow(project.ci_cd_settings).to receive(:skip_branch_pipelines_for_mrs?).and_return(true)
          end

          context 'when only a branch pipeline exists' do
            let!(:mr_pipeline) { nil }

            it 'ignores the branch pipeline and returns inactive' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
            end
          end

          context 'when both a branch pipeline and an MR pipeline exist' do
            before do
              mr_pipeline.update!(status: :success)
            end

            it 'ignores the branch pipeline and returns success based on the MR pipeline' do
              expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
            end
          end
        end
      end
    end
  end

  describe '#skip?' do
    context 'when skip param is present' do
      let(:skip_check) { true }

      it 'returns true' do
        expect(check_service.skip?).to be true
      end
    end

    context 'when skip param is not present' do
      let(:skip_check) { false }

      it 'returns false' do
        expect(check_service.skip?).to be false
      end
    end
  end

  describe '#cacheable?' do
    it 'returns false' do
      expect(check_service.cacheable?).to be false
    end
  end
end

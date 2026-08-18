# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Standards::Gitlab::SastService,
  feature_category: :compliance_management do
  let_it_be_with_reload(:project) { create(:project, :in_group) }
  let(:params) { {} }

  let(:service) { described_class.new(project: project, params: params) }

  before do
    allow(project).to receive(:default_branch).and_return('master')
  end

  describe '#execute' do
    context 'when group_level_compliance_dashboard feature is not available' do
      let(:master_pipeline_success) { create(:ci_pipeline, :success, project: project, ref: "master") }
      let(:ci_build_master_success) { create(:ci_build, pipeline: master_pipeline_success, project: project) }

      before do
        stub_licensed_features(group_level_compliance_dashboard: false)
        create(:ci_job_artifact, :sast, project: project, job: ci_build_master_success)
      end

      it 'returns feature not available error' do
        response = service.execute

        expect(response.status).to eq(:error)
        expect(response.message).to eq('Compliance standards adherence feature not available')
      end
    end

    context 'when group_level_compliance_dashboard feature is available' do
      before do
        stub_licensed_features(group_level_compliance_dashboard: true)
      end

      shared_examples 'scanner run marked fail when no artifacts present' do
        it 'sets scanner run check as fail' do
          response = service.execute

          expect(response.status).to eq(:success)
          expect(project.compliance_standards_adherence.last)
            .to have_attributes(
              project_id: project.id,
              namespace_id: project.namespace_id,
              status: 'fail',
              check_name: 'sast',
              standard: 'gitlab'
            )
        end
      end

      context 'when project has successful pipeline for default branch' do
        let(:master_pipeline_success) { create(:ci_pipeline, :success, project: project, ref: "master") }
        let(:ci_build_master_success) { create(:ci_build, pipeline: master_pipeline_success, project: project) }

        context 'when the pipeline has sast job artifacts' do
          before do
            create(:ci_job_artifact, :sast, project: project, job: ci_build_master_success)
          end

          it 'sets scanner run as success' do
            response = service.execute

            expect(response.status).to eq(:success)
            expect(project.compliance_standards_adherence.last)
              .to have_attributes(
                project_id: project.id,
                namespace_id: project.namespace_id,
                status: 'success',
                check_name: 'sast',
                standard: 'gitlab'
              )
          end

          context 'when adherence check for scan already exists' do
            let_it_be(:adherence) do
              create(:compliance_standards_adherence, project: project, check_name: :sast, standard: :gitlab)
            end

            it 'updates the timestamp of the existing adherence check' do
              initial_updated_at = adherence.updated_at

              travel_to(2.days.from_now) do
                response = service.execute

                expect(response.status).to eq(:success)

                expect((adherence.reload.updated_at.to_date - initial_updated_at.to_date).to_i).to eq(2)
              end
            end
          end
        end

        context 'when the pipeline do not have sast job artifacts' do
          it_behaves_like 'scanner run marked fail when no artifacts present'
        end
      end

      context 'when project has failed pipeline for default branch with sast artifacts' do
        let(:master_pipeline_failed) { create(:ci_pipeline, :failed, project: project, ref: 'master') }
        let(:ci_build_master_failed) { create(:ci_build, pipeline: master_pipeline_failed, project: project) }

        before do
          create(:ci_job_artifact, :sast, project: project, job: ci_build_master_failed)
        end

        it 'sets scanner run as success' do
          response = service.execute

          expect(response.status).to eq(:success)
          expect(project.compliance_standards_adherence.last)
            .to have_attributes(
              project_id: project.id,
              namespace_id: project.namespace_id,
              status: 'success',
              check_name: 'sast',
              standard: 'gitlab'
            )
        end
      end

      context 'when project has successful pipeline for non default branch with sast artifacts' do
        let(:nonmaster_pipeline_success) { create(:ci_pipeline, :failed, project: project, ref: "nonmaster") }
        let(:ci_build_nonmaster_success) { create(:ci_build, pipeline: nonmaster_pipeline_success, project: project) }

        before do
          create(:ci_job_artifact, :sast, project: project, job: ci_build_nonmaster_success)
        end

        it_behaves_like 'scanner run marked fail when no artifacts present'
      end

      context 'when project has security_orchestration_policy pipeline with sast artifacts' do
        let(:security_policy_pipeline) do
          create(:ci_pipeline, :success, project: project, ref: 'master', source: :security_orchestration_policy)
        end

        before do
          ci_build = create(:ci_build, pipeline: security_policy_pipeline, project: project)
          create(:ci_job_artifact, :sast, project: project, job: ci_build)
        end

        it 'sets scanner run as success' do
          response = service.execute

          expect(response.status).to eq(:success)
          expect(project.compliance_standards_adherence.last)
            .to have_attributes(
              project_id: project.id,
              namespace_id: project.namespace_id,
              status: 'success',
              check_name: 'sast',
              standard: 'gitlab'
            )
        end
      end

      context 'when project has parent_pipeline with sast artifacts' do
        let(:parent_pipeline) do
          create(:ci_pipeline, :success, project: project, ref: 'master', source: :parent_pipeline)
        end

        before do
          ci_build = create(:ci_build, pipeline: parent_pipeline, project: project)
          create(:ci_job_artifact, :sast, project: project, job: ci_build)
        end

        it_behaves_like 'scanner run marked fail when no artifacts present'
      end

      context 'when project has webide pipeline with sast artifacts' do
        let(:webide_pipeline) { create(:ci_pipeline, :success, project: project, ref: 'master', source: :webide) }

        before do
          ci_build = create(:ci_build, pipeline: webide_pipeline, project: project)
          create(:ci_job_artifact, :sast, project: project, job: ci_build)
        end

        it_behaves_like 'scanner run marked fail when no artifacts present'
      end

      context 'when project has ondemand_dast_scan pipeline with sast artifacts' do
        let(:ondemand_pipeline) do
          create(:ci_pipeline, :success, project: project, ref: 'master', source: :ondemand_dast_scan)
        end

        before do
          ci_build = create(:ci_build, pipeline: ondemand_pipeline, project: project)
          create(:ci_job_artifact, :sast, project: project, job: ci_build)
        end

        it_behaves_like 'scanner run marked fail when no artifacts present'
      end
    end
  end
end

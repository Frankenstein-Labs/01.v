# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Pipeline'], feature_category: :vulnerability_management do
  it { expect(described_class.graphql_name).to eq('Pipeline') }

  it 'includes the ee specific fields' do
    expected_fields = %w[
      security_report_summary
      security_report_findings
      enabled_security_scans
      enabled_partial_security_scans
      code_quality_reports
      dast_profile
      duo_workflows
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe 'type' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :repository) }

    let(:query) do
      %(
        {
          project(fullPath: "#{project.full_path}") {
            pipeline(iid: "#{pipeline.iid}") {
              type
            }
          }
        }
      )
    end

    let(:pipeline_type) do
      GitlabSchema.execute(query, context: { current_user: user })
                  .as_json
                  .dig('data', 'project', 'pipeline', 'type')
    end

    before_all do
      project.add_developer(user)
    end

    context 'when pipeline is a merge train pipeline' do
      let_it_be(:merge_request) { create(:merge_request, source_project: project) }
      let_it_be(:pipeline) do
        create(:ci_pipeline, :merged_result_pipeline, merge_request: merge_request).tap do |p|
          p.update!(ref: merge_request.train_ref_path)
        end
      end

      it 'returns merge_train' do
        expect(pipeline_type).to eq('merge_train')
      end
    end
  end

  describe 'duo_workflows', feature_category: :duo_agent_platform do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :repository, developers: user) }
    let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            pipeline(iid: "#{pipeline.iid}") {
              duoWorkflows {
                nodes {
                  id
                }
              }
            }
          }
        }
      )
    end

    subject(:result) do
      GitlabSchema.execute(query, context: { current_user: user }).as_json
    end

    context 'when ai_workflows is not licensed' do
      before do
        stub_licensed_features(ai_workflows: false)
      end

      it 'returns nil' do
        duo_workflows = result.dig('data', 'project', 'pipeline', 'duoWorkflows')

        expect(duo_workflows).to be_nil
      end
    end

    context 'when ai_workflows is licensed' do
      before do
        stub_licensed_features(ai_workflows: true)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
        allow(project).to receive(:duo_features_enabled?).and_return(true)
      end

      context 'when no workflows are linked' do
        it 'returns an empty array' do
          nodes = result.dig('data', 'project', 'pipeline', 'duoWorkflows', 'nodes')

          expect(nodes).to eq([])
        end
      end

      context 'when workflows are linked' do
        let_it_be(:workflow) do
          create(:duo_workflows_workflow, user: user, project: project, environment: :web).tap do |w|
            create(:duo_workflows_workflow_pipeline, workflow: w, pipeline: pipeline)
          end
        end

        before do
          allow(user).to receive(:allowed_to_use?).and_return(true)
        end

        it 'returns the linked workflows' do
          nodes = result.dig('data', 'project', 'pipeline', 'duoWorkflows', 'nodes')

          expect(nodes).to contain_exactly({ 'id' => workflow.to_global_id.to_s })
        end
      end

      context 'when another user has a linked pipeline-originated workflow' do
        let_it_be(:other_user) { create(:user) }

        let_it_be(:other_workflow) do
          create(:duo_workflows_workflow, user: other_user, project: project, environment: :web).tap do |w|
            create(:duo_workflows_workflow_pipeline, workflow: w, pipeline: pipeline)
          end
        end

        before do
          allow(user).to receive(:allowed_to_use?).and_return(true)
        end

        it 'includes pipeline-originated workflows from other users' do
          nodes = result.dig('data', 'project', 'pipeline', 'duoWorkflows', 'nodes')

          expect(nodes).to contain_exactly({ 'id' => other_workflow.to_global_id.to_s })
        end
      end
    end
  end

  describe 'retryable' do
    let_it_be(:user) { create(:user) }
    let_it_be(:second_user) { create(:user) }
    let_it_be(:project) { create(:project, :repository, developers: [user, second_user]) }

    let(:query) do
      %(
        {
          project(fullPath: "#{project.full_path}") {
            pipelines {
              nodes {
                retryable
              }
            }
          }
        }
      )
    end

    it 'returns false for a completed merge train pipeline' do
      create_merge_train_pipeline

      result = GitlabSchema.execute(query, context: { current_user: user }).as_json

      expect(result.dig('data', 'project', 'pipelines', 'nodes')).to contain_exactly('retryable' => false)
    end

    it 'returns true for a completed non-merge-train pipeline' do
      pipeline = create(:ci_pipeline, :failed, project: project)
      create(:ci_build, :failed, pipeline: pipeline)

      result = GitlabSchema.execute(query, context: { current_user: user }).as_json

      expect(result.dig('data', 'project', 'pipelines', 'nodes')).to contain_exactly('retryable' => true)
    end

    it 'does not introduce N+1 queries for merge train pipelines' do
      create_merge_train_pipeline
      control = ActiveRecord::QueryRecorder.new do
        GitlabSchema.execute(query, context: { current_user: user })
      end

      create_merge_train_pipeline

      expect do
        GitlabSchema.execute(query, context: { current_user: second_user })
      end.not_to exceed_query_limit(control)
    end
  end

  describe 'security_report_finding' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :repository, :public, developers: user) }
    let_it_be(:pipeline) { create(:ci_pipeline, :success, project: project) }
    let_it_be(:build) { create(:ci_build, :success, name: 'sast', pipeline: pipeline) }
    let_it_be(:artifact) { create(:ee_ci_job_artifact, :sast, job: build) }
    let_it_be(:report) { create(:ci_reports_security_report, type: :sast) }
    let_it_be(:scan) { create(:security_scan, :latest_successful, scan_type: :sast, build: build) }

    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            pipeline(iid: "#{pipeline.iid}") {
              securityReportFinding(uuid: "#{uuid}") {
                title
                reportType
              }
            }
          }
        }
      )
    end

    before do
      stub_licensed_features(sast: true, security_dashboard: true)
    end

    subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    context 'when no security findings exist for the pipeline' do
      let(:uuid) { "any-uuid" }

      it 'returns null' do
        security_finding = subject.dig('data', 'project', 'pipeline', 'securityReportFinding')

        expect(pipeline.security_findings.count).to be_zero
        expect(security_finding).to be_nil
      end
    end

    context 'when security findings exist for the pipeline' do
      before_all do
        artifact.security_report.scan = Gitlab::Ci::Reports::Security::Scan.new(
          {
            "type" => :sast,
            "start_time" => "20241022T11:56:41",
            "end_time" => "20241022T11:57:39",
            "status" => "success"
          }
        )

        Gitlab::ExclusiveLease.skipping_transaction_check do
          Security::StoreGroupedScansService.new(
            [artifact],
            pipeline,
            'sast'
          ).execute
        end
      end

      context 'when the specified security finding is not found for the pipeline' do
        let(:uuid) { "bad-uuid" }

        it 'returns null' do
          security_finding = subject.dig('data', 'project', 'pipeline', 'securityReportFinding')

          expect(pipeline.security_findings).not_to be_empty
          expect(security_finding).to be_nil
        end
      end

      context 'when the security finding is found' do
        let(:uuid) { expected_security_finding.uuid }
        let(:expected_security_finding) { Security::Finding.first }
        let(:expected_report_finding) do
          expected_security_finding.scan.report_findings.find { |f| f.uuid == expected_security_finding.uuid }
        end

        it 'returns the security finding' do
          security_finding = subject.dig('data', 'project', 'pipeline', 'securityReportFinding')

          expect(security_finding["title"]).to eq(expected_report_finding.name)
          expect(security_finding["reportType"]).to eq(expected_report_finding.report_type.upcase)
        end
      end
    end
  end

  def create_merge_train_pipeline
    merge_request = create(:merge_request, source_project: project, source_branch: generate(:branch))
    pipeline = create(:ci_pipeline, :merged_result_pipeline, :failed, merge_request: merge_request)
    pipeline.update!(ref: merge_request.train_ref_path)
    create(:ci_build, :failed, pipeline: pipeline)
  end
end

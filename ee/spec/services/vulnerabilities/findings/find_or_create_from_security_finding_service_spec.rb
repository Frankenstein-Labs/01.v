# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Findings::FindOrCreateFromSecurityFindingService, '#execute',
  feature_category: :vulnerability_management do
  before do
    stub_licensed_features(security_dashboard: true)
  end

  let(:security_finding) { sast_security_findings.first }
  let(:security_finding_uuid) { security_finding.uuid }
  let(:params) { { security_finding_uuid: security_finding_uuid } }

  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be_with_reload(:pipeline) { create(:ci_pipeline, :success, project: project, ref: 'feature-branch') }
  let(:tracked_context) do
    create(:security_project_tracked_context, :tracked, context_name: pipeline.ref, project: project).id
  end

  let_it_be_with_reload(:build_sast) { create(:ci_build, :success, name: 'sast', pipeline: pipeline) }
  let_it_be_with_reload(:artifact_sast) do
    create(:ee_ci_job_artifact, :sast_with_signatures_and_vulnerability_flags_with_duplicate_identifiers,
      job: build_sast)
  end

  let_it_be_with_reload(:report_sast) { create(:ci_reports_security_report, pipeline: pipeline, type: :sast) }
  let_it_be_with_reload(:scan_sast) do
    create(:security_scan, :latest_successful, scan_type: :sast, build: artifact_sast.job)
  end

  let_it_be_with_reload(:pipeline_dast) { create(:ci_pipeline, project: project) }
  let_it_be_with_reload(:build_dast) { create(:ci_build, :success, name: 'dast', pipeline: pipeline_dast) }
  let_it_be_with_reload(:artifact_dast) { create(:ee_ci_job_artifact, :dast_with_evidence, job: build_dast) }
  let_it_be_with_reload(:report_dast) { create(:ci_reports_security_report, pipeline: pipeline_dast, type: :dast) }
  let_it_be_with_reload(:scan_dast) do
    create(:security_scan, :latest_successful, scan_type: :dast, build: artifact_dast.job)
  end

  let_it_be_with_reload(:user) { create(:user, developer_of: project) }
  # `freeze: false` is required here: this `let_it_be` subject is a mutable
  # Array that the before_all block pushes into; freezing it raises
  # FrozenError. Keep the opt-out (see gitlab-org/gitlab#602925).
  let_it_be(:dast_security_findings, freeze: false) { [] }
  # `freeze: false` is required here: this `let_it_be` subject is a mutable
  # Array that the before_all block pushes into; freezing it raises
  # FrozenError. Keep the opt-out (see gitlab-org/gitlab#602925).
  let_it_be(:sast_security_findings, freeze: false) { [] }

  before_all do
    sast_content = File.read(artifact_sast.file.path)
    Gitlab::Ci::Parsers::Security::Sast.parse!(sast_content, report_sast)
    report_sast.merge!(report_sast)

    dast_content = File.read(artifact_dast.file.path)
    Gitlab::Ci::Parsers::Security::Dast.parse!(dast_content, report_dast)
    report_dast.merge!(report_dast)

    dast_security_findings.push(*insert_security_findings(report_dast, scan_dast))
    sast_security_findings.push(*insert_security_findings(report_sast, scan_sast))
  end

  subject { described_class.new(project: project, current_user: user, params: params).execute }

  RSpec.shared_examples 'create vulnerability finding' do
    it 'creates a new vulnerability finding' do
      expect(subject.payload[:vulnerability_finding].uuid).to eq(security_finding_uuid)
      expect(subject.payload[:vulnerability_finding].severity).to eq(security_finding.severity)
      expect(subject.payload[:vulnerability_finding].initial_pipeline_id).to eq(security_finding.pipeline.id)
      expect(subject.payload[:vulnerability_finding].latest_pipeline_id).to eq(security_finding.pipeline.id)
    end
  end

  context 'when security finding not found' do
    let(:security_finding_uuid) { 'invalid-uuid' }

    it 'returns an error' do
      expect(subject).to be_error
      expect(subject[:message]).to eq('Security Finding not found')
    end
  end

  context 'when there is an existing vulnerability and vulnerability finding for the security finding' do
    let_it_be_with_reload(:security_finding) { sast_security_findings.first }
    let_it_be_with_reload(:finding) do
      create(:vulnerabilities_finding, :detected,
        report_type: :sast, project: project, uuid: security_finding.uuid)
    end

    let_it_be_with_reload(:vulnerability) do
      create(:vulnerability, report_type: :sast, project: project, findings: [finding])
    end

    it 'returns the existing Vulnerability::Finding with the existing vulnerability id' do
      expect(subject).to be_success
      expect(subject.payload[:vulnerability_finding].vulnerability_id).to eq(vulnerability.id)
    end

    it 'returns the security finding' do
      expect(subject.payload[:security_finding]).to eq(security_finding)
    end
  end

  context 'when there is no vulnerability for the security finding' do
    it 'creates a new Vulnerability::Finding without Vulnerability' do
      expect(subject).to be_success
      expect(subject.payload[:vulnerability_finding].vulnerability_id).to be_nil
    end
  end

  context 'when creating identifiers' do
    it 'sorts identifiers by fingerprint' do
      identifiers = subject.payload[:vulnerability_finding].identifiers.reload
      expect(identifiers.map(&:fingerprint)).to be_sorted
    end
  end

  context 'when there is an error saving the security finding' do
    let(:error_messages_array) { instance_double("Array", join: "Primary identifier can't be blank") }
    let(:security_finding_uuid) { security_finding.uuid }
    let(:errors_double) { instance_double(ActiveModel::Errors, full_messages: error_messages_array) }

    before do
      allow_next_instance_of(Vulnerabilities::Finding) do |vulnerability_finding|
        allow(vulnerability_finding).to receive(:persisted?).and_return(false)
        allow(vulnerability_finding).to receive(:errors).and_return(errors_double)
      end
      allow(errors_double).to receive(:clear)
      allow(errors_double).to receive(:add)
      allow(errors_double).to receive(:empty?)
      allow(errors_double).to receive(:uniq!)
    end

    it 'returns an error' do
      expect(subject).not_to be_success
      expect(subject[:message]).to eq('Error creating vulnerability finding: Primary identifier can\'t be blank')
    end
  end

  context 'when the report finding has signatures' do
    it 'associates the signatures' do
      expect(subject).to be_success
      expect(subject.payload[:vulnerability_finding].signatures.size).to eq(2)
    end

    it_behaves_like 'create vulnerability finding'
  end

  context 'when the report finding has evidences' do
    let(:security_finding) { dast_security_findings.first }

    it 'associates the signatures' do
      expect(subject).to be_success
      evidence_summary = subject.payload[:vulnerability_finding].finding_evidence.data['summary']
      expect(evidence_summary).to eq('Set-Cookie: JSESSIONID')
    end

    it_behaves_like 'create vulnerability finding'
  end

  context 'when there is no report finding for the security finding' do
    let_it_be_with_reload(:security_finding) { create(:security_finding, scan: scan_sast) }

    let(:security_finding_uuid) { security_finding.uuid }

    it 'returns an error' do
      expect(subject).not_to be_success
      expect(subject[:message]).to eq('Report Finding not found')
    end
  end

  context 'when sast_fp_reduction feature is available' do
    before do
      stub_licensed_features(sast_fp_reduction: true)
    end

    it_behaves_like 'create vulnerability finding'

    it 'associates the vulnerabilities flags' do
      expect(subject.payload[:vulnerability_finding].vulnerability_flags.first.flag_type).to eq('false_positive')
    end
  end

  context 'when the identifier of the finding already exists in the database' do
    let(:report_finding) { report_sast.findings.first }
    let(:report_identifier) { report_finding.identifiers.first }
    let(:persisted_identifier) { subject.payload[:vulnerability_finding].identifiers.reload.first }

    before do
      create(:vulnerabilities_identifier, project: project, fingerprint: report_identifier.fingerprint)
    end

    it_behaves_like 'create vulnerability finding'

    it 'associates the correct identifier with the new finding' do
      expect(persisted_identifier.fingerprint).to eq(report_identifier.fingerprint)
    end
  end

  context 'with vulnerabilities_across_contexts feature flag disabled' do
    before do
      stub_feature_flags(vulnerabilities_across_contexts: false)
    end

    it 'does not associates the finding with the tracked context' do
      expect(subject).to be_success
      expect(subject.payload[:vulnerability_finding].security_project_tracked_context_id).to be_nil
    end
  end

  context 'with vulnerabilities_across_contexts feature flag enabled' do
    before do
      stub_feature_flags(vulnerabilities_across_contexts: true)
    end

    context 'when tracked context exists' do
      it 'associates the finding with the tracked context' do
        expect(subject).to be_success
        tracked_context_id = Security::ProjectTrackedContext.last.id
        expect(subject.payload[:vulnerability_finding].security_project_tracked_context_id).to eq(tracked_context_id)
      end
    end

    context 'when tracked context does not exist' do
      let(:tracked_context) { nil }

      it 'creates untracked context' do
        expect { subject }.to change { Security::ProjectTrackedContext.count }.by(1)
        expect(subject).to be_success
        context = Security::ProjectTrackedContext.last
        expect(context).to have_attributes(
          is_default: false,
          state: Security::ProjectTrackedContext::STATES[:untracked])
      end

      context 'when creating vulnerability for default branch' do
        before do
          pipeline.update!(ref: project.default_branch)
        end

        it 'create context for default branch' do
          expect { subject }.to change { Security::ProjectTrackedContext.count }.by(1)
          expect(subject).to be_success
          context = Security::ProjectTrackedContext.last
          expect(context).to have_attributes(
            is_default: true,
            state: Security::ProjectTrackedContext::STATES[:tracked])
        end
      end
    end

    context 'when tracked_context_result returns an error' do
      before do
        allow_next_instance_of(Security::ProjectTrackedContexts::FindOrCreateService) do |instance|
          allow(instance).to receive(:execute).and_return(
            ServiceResponse.error(message: 'Failed to create tracked context')
          )
        end
      end

      it 'returns the error from tracked_context_result' do
        expect(subject).to be_error
        expect(subject[:message]).to eq('Failed to create tracked context')
      end
    end
  end

  def insert_security_findings(report, scan)
    report.findings.map do |finding|
      create(
        :security_finding,
        severity: finding.severity,
        uuid: finding.uuid,
        scan: scan
      )
    end
  end
end

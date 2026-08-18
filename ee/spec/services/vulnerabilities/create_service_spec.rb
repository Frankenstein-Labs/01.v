# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::CreateService, feature_category: :vulnerability_management do
  before do
    stub_licensed_features(security_dashboard: true)
  end

  let_it_be(:user) { create(:user) }

  let(:project) { create(:project) } # cannot use let_it_be here: caching causes problems with permission-related tests
  let(:finding) { create(:vulnerabilities_finding, name: finding_name, project: project) }
  let(:finding_id) { finding.id }
  let(:expected_error_messages) { { base: ['finding is not found or is already attached to a vulnerability'] } }
  let(:finding_name) { 'New title' }
  let(:solution) { 'solution' }
  let(:vulnerability) { project.vulnerabilities.last }
  let(:vulnerability_read) { Vulnerabilities::Read.last }

  subject { described_class.new(project, user, finding_id: finding_id, solution: solution).execute }

  shared_examples 'creates a vulnerability state transition record with note' do
    let(:comment) { "Dismissal comment" }
    let(:dismissal_reason) { 'false_positive' }
    let(:service) do
      described_class.new(
        project, user,
        finding_id: finding_id,
        state: "dismissed",
        comment: comment,
        dismissal_reason: dismissal_reason
      )
    end

    it 'creates a vulnerability state transition record' do
      expect { service.execute }.to change { Vulnerabilities::StateTransition.count }.from(0).to(1)

      state_transition = Vulnerabilities::StateTransition.last

      expect(state_transition.from_state).to eq(finding.state)
      expect(state_transition.to_state).to eq("dismissed")
      expect(state_transition.comment).to eq(comment)
      expect(state_transition.dismissal_reason).to eq(dismissal_reason)
      expect(state_transition.author).to eq(user)
      expect(state_transition.vulnerability_occurrence_id).to eq(finding.id)
    end

    it 'creates a note' do
      expect { service.execute }.to change { Note.count }.from(0).to(1)

      note = Note.last

      expect(note.noteable).to eq(project.vulnerabilities.last)
      expect(note.author).to eq(user)
    end
  end

  context 'with an authorized user with proper permissions' do
    before do
      project.add_maintainer(user)
    end

    it_behaves_like 'calls Vulnerabilities::Statistics::UpdateService'

    it 'creates a vulnerability from finding and attaches it to the vulnerability' do
      expect { subject }.to change { project.vulnerabilities.count }.by(1)
      vulnerability = project.vulnerabilities.last

      expect(vulnerability).to(
        have_attributes(
          author: user,
          title: finding.name,
          state: finding.state,
          severity: finding.severity,
          severity_overridden: false,
          report_type: finding.report_type,
          present_on_default_branch: true,
          finding_id: finding.id
        ))

      # Use attribute accessor to avoid receiving `finding.solution` delegation
      expect(vulnerability[:solution]).to eq(solution)
    end

    it 'creates vulnerability read record when present_on_default_branch is true' do
      expect { subject }.to change { Vulnerabilities::Read.count }.by(1)

      expect(vulnerability_read).to have_attributes(
        vulnerability_id: vulnerability.id,
        vulnerability_occurrence_id: finding.id,
        project_id: project.id,
        traversal_ids: project.namespace.traversal_ids,
        severity: finding.severity,
        state: finding.state,
        report_type: finding.report_type
      )
    end

    context 'when turn_off_vulnerability_read_create_db_trigger_function disabled' do
      before do
        stub_feature_flags(turn_off_vulnerability_read_create_db_trigger_function: false)
      end

      it 'creates vulnerability read record when present_on_default_branch is true' do
        expect { subject }.to change { Vulnerabilities::Read.count }.by(1)

        expect(vulnerability_read).to have_attributes(
          vulnerability_id: vulnerability.id,
          vulnerability_occurrence_id: finding.id,
          project_id: project.id,
          traversal_ids: project.namespace.traversal_ids,
          severity: finding.severity,
          state: finding.state,
          report_type: finding.report_type
        )
      end
    end

    context 'with vulnerabilities_across_contexts feature flag enabled' do
      before do
        stub_feature_flags(vulnerabilities_across_contexts: true)
      end

      it 'does not set security tracked context when there is not an existing tracked context' do
        subject

        expect(vulnerability_read.security_project_tracked_context_id).to be_nil
      end

      context 'when finding has tracked context' do
        let(:tracked_context) { create(:security_project_tracked_context, :tracked, project: project) }
        let(:finding) do
          create(:vulnerabilities_finding, project: project, security_project_tracked_context_id: tracked_context.id)
        end

        it 'sets the tracked context id' do
          subject

          expect(vulnerability_read.security_project_tracked_context_id).to eq(tracked_context.id)
        end
      end
    end

    context 'with vulnerabilities_across_contexts feature flag disabled' do
      before do
        stub_feature_flags(vulnerabilities_across_contexts: false)
      end

      it 'does not set tracked context id' do
        subject

        expect(vulnerability_read.security_project_tracked_context_id).to be_nil
      end
    end

    it_behaves_like 'creates a vulnerability state transition record with note'

    it 'creates a vulnerability_finding_risk_scores record' do
      expect { subject }.to change { Vulnerabilities::FindingRiskScore.count }.by(1)
    end

    context 'and finding is dismissed' do
      subject { described_class.new(project, user, finding_id: finding.id, state: state).execute }

      context 'when the state is set to dismissed' do
        let_it_be(:state) { :dismissed }

        it 'creates a vulnerability in a dismissed state and sets dismissal information' do
          freeze_time do
            expect { subject }.to change { project.vulnerabilities.count }.by(1)

            expect(vulnerability.state).to eq('dismissed')
            expect(vulnerability.dismissed_at).to be_like_time(Time.current)
            expect(vulnerability.dismissed_by_id).to eq(user.id)
          end
        end

        it 'creates vulnerability read record with dismissed state' do
          expect { subject }.to change { Vulnerabilities::Read.count }.by(1)

          vulnerability_read = Vulnerabilities::Read.last
          expect(vulnerability_read).to have_attributes(
            vulnerability_id: vulnerability.id,
            project_id: project.id,
            severity: finding.severity,
            state: 'dismissed',
            report_type: finding.report_type
          )
        end
      end
    end

    context 'when finding name is longer than 255 characters' do
      let(:finding_name) { 'a' * 256 }

      it 'truncates vulnerability title to have 255 characters' do
        expect { subject }.to change { project.vulnerabilities.count }.by(1)
        expect(vulnerability.title).to have_attributes(size: 255)
      end
    end

    context 'when the state parameter is sent' do
      let(:finding) { create(:vulnerabilities_finding, :with_dismissal_feedback, project: project) }

      subject { described_class.new(project, user, finding_id: finding.id, state: 'confirmed').execute }

      it 'creates a new vulnerability with the given state' do
        expect { subject }.to change { project.vulnerabilities.count }.by(1)
        expect(vulnerability.state).to eq('confirmed')
      end
    end

    context 'when present_on_default_branch parameter is sent' do
      subject { described_class.new(project, user, finding_id: finding.id, present_on_default_branch: false).execute }

      it 'creates a new vulnerability with the given present_on_default_branch' do
        expect { subject }.to change { project.vulnerabilities.count }.by(1)
        expect(vulnerability.present_on_default_branch).to eq(false)
      end
    end

    context 'when finding id is unknown' do
      let(:finding_id) { 0 }

      it 'adds expected error to the response' do
        expect(subject.errors.messages).to eq(expected_error_messages)
      end
    end

    context 'when finding does not belong to the vulnerability project' do
      let(:finding) { create(:vulnerabilities_finding) }

      it 'adds expected error to the response' do
        expect(subject.errors.messages).to eq(expected_error_messages)
      end

      it 'does not associate vulnerability with the finding' do
        expect(Vulnerability.where(finding_id: finding.id).count).to eq(0)
      end
    end

    context 'when a vulnerability already exists for a specific finding' do
      before do
        create(:vulnerability, findings: [finding], project: finding.project)
      end

      it 'rejects creation of a new vulnerability from this finding' do
        expect(subject.errors.messages).to eq(expected_error_messages)
      end

      it 'does not update vulnerability statistics' do
        subject

        expect(Vulnerabilities::Statistics::UpdateService).not_to receive(:update_for)
      end
    end

    context 'when security dashboard feature is disabled' do
      before do
        stub_licensed_features(security_dashboard: false)
      end

      it 'raises an "access denied" error' do
        expect { subject }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end
  end

  context 'when user does not have rights to dismiss a vulnerability' do
    before do
      project.add_reporter(user)
    end

    it 'raises an "access denied" error' do
      expect { subject }.to raise_error(Gitlab::Access::AccessDeniedError)
    end
  end
end

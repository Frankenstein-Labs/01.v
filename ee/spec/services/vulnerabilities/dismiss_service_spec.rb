# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::DismissService, feature_category: :vulnerability_management do
  include AccessMatchersGeneric

  before do
    stub_licensed_features(security_dashboard: true)
  end

  let_it_be(:user) { create(:user) }

  let(:project) { create(:project) } # cannot use let_it_be here: caching causes problems with permission-related tests
  let!(:pipeline) { create(:ee_ci_pipeline, :with_dast_report, :success, project: project) }
  let!(:build) { create(:ee_ci_build, :sast, pipeline: pipeline) }
  let(:state) { :detected }
  let(:vulnerability) { create(:vulnerability, state, :with_finding, :with_read, project: project) }
  let(:state_transition) { create(:vulnerability_state_transition, vulnerability: vulnerability) }
  let(:dismiss_findings) { true }
  let(:comment) { nil }
  let(:dismissal_reason) { nil }
  let(:service) { described_class.new(user, vulnerability, comment, dismissal_reason, dismiss_findings: dismiss_findings) }

  subject(:dismiss_vulnerability) { service.execute }

  describe 'pre-existing state policy re-evaluation' do
    before do
      project.add_maintainer(user)
    end

    it_behaves_like 'syncs pre-existing state approval policy rules on triage' do
      let(:triaged_project) { project }
      let(:perform_triage) { dismiss_vulnerability }
    end
  end

  shared_examples 'creates a vulnerability state transition record' do
    let(:comment) { "Dismissal comment" }
    let(:dismissal_reason) { 'false_positive' }

    it_behaves_like 'creating state transition record', :dismissed do
      let(:extra_attributes) { { dismissal_reason: dismissal_reason } }
    end

    context 'when a vulnerability read record exists' do
      let(:vulnerability_read) { Vulnerabilities::Read.find_by(vulnerability_id: vulnerability.id) }

      it 'updates the dismissal reason' do
        expect { dismiss_vulnerability }.to change { vulnerability_read.reload.dismissal_reason }.from(nil).to('false_positive')
      end
    end

    context 'when a vulnerability read record does not exist' do
      let(:vulnerability) { create(:vulnerability, :detected, :with_finding, project: project, present_on_default_branch: false) }
      let(:vulnerability_read) { vulnerability.vulnerability_read }

      it 'does not fail' do
        expect(vulnerability_read).to be_nil
        expect { dismiss_vulnerability }.not_to change { Vulnerabilities::Read.count }
      end
    end
  end

  context 'when vulnerability state is different from the requested state' do
    context 'with an authorized user with proper permissions' do
      before do
        project.add_maintainer(user)
      end

      it_behaves_like 'calls vulnerability statistics utility services in order'

      it_behaves_like 'creates a vulnerability state transition record'
      it_behaves_like 'triggering vulnerability webhook event'

      context 'when the `dismiss_findings` argument is false' do
        let(:dismiss_findings) { false }

        it 'dismisses only vulnerability' do
          freeze_time do
            dismiss_vulnerability

            expect(vulnerability.reload).to(
              have_attributes(state: 'dismissed', dismissed_by: user, dismissed_at: be_like_time(Time.current)))
            expect(vulnerability.findings).not_to include have_vulnerability_dismissal_feedback
          end
        end
      end

      context 'when the `dismiss_findings` argument is not false' do
        it 'dismisses a vulnerability and its associated findings with correct attributes' do
          freeze_time do
            dismiss_vulnerability

            expect(vulnerability.reload).to(
              have_attributes(state: 'dismissed', dismissed_by: user, dismissed_at: be_like_time(Time.current)))
            expect(vulnerability.findings).to all have_vulnerability_dismissal_feedback
            expect(vulnerability.finding.dismissal_feedback.finding_uuid).to eq(vulnerability.finding.uuid)
            expect(vulnerability.finding.dismissal_feedback.migrated_to_state_transition).to eq(true)
          end
        end
      end

      context 'when comment is added' do
        let(:comment) { 'Dismissal Comment' }
        let(:service) { described_class.new(user, vulnerability, comment) }

        it 'dismisses a vulnerability and its associated findings with comment', :aggregate_failures do
          freeze_time do
            dismiss_vulnerability

            aggregate_failures do
              expect(vulnerability.reload).to(
                have_attributes(state: 'dismissed', dismissed_by: user, dismissed_at: be_like_time(Time.current)))
              expect(vulnerability.findings).to all have_vulnerability_dismissal_feedback
              expect(vulnerability.findings.map(&:dismissal_feedback)).to(
                all(have_attributes(comment: comment, comment_author: user,
                  comment_timestamp: be_like_time(Time.current), pipeline_id: pipeline.id,
                  migrated_to_state_transition: true)
                   )
              )
            end
          end
        end
      end

      context 'when the dismissal_reason is added' do
        let(:dismissal_reason) { 'used_in_tests' }
        let(:service) { described_class.new(user, vulnerability, nil, dismissal_reason) }

        it 'dismisses a vulnerability and its associated findings with comment', :aggregate_failures do
          dismiss_vulnerability

          expect(vulnerability.reload).to have_attributes(state: 'dismissed', dismissed_by: user)
          expect(vulnerability.findings).to all have_vulnerability_dismissal_feedback
          expect(vulnerability.findings.map(&:dismissal_feedback)).to all(have_attributes(dismissal_reason: dismissal_reason, migrated_to_state_transition: true))
        end
      end

      context 'when turn_off_vulnerability_read_create_db_trigger_function feature flag is disabled' do
        let(:dismissal_reason) { 'false_positive' }

        before do
          stub_feature_flags(turn_off_vulnerability_read_create_db_trigger_function: false)
        end

        it 'updates the dismissal_reason via the vulnerability_read association instead of UpsertService' do
          expect(Vulnerabilities::Reads::UpsertService).not_to receive(:new)

          vulnerability_read = vulnerability.vulnerability_read
          expect(vulnerability).to receive(:vulnerability_read).at_least(:once).and_return(vulnerability_read)
          expect(vulnerability_read).to receive(:update).with(dismissal_reason: dismissal_reason).and_call_original

          dismiss_vulnerability

          expect(vulnerability_read.reload.dismissal_reason).to eq('false_positive')
        end

        context 'when vulnerability_read is nil' do
          let(:vulnerability) { create(:vulnerability, :detected, :with_finding, project: project, present_on_default_branch: false) }

          it 'does not raise an error' do
            expect(vulnerability.vulnerability_read).to be_nil
            expect { dismiss_vulnerability }.not_to raise_error
          end
        end
      end

      context 'when turn_off_vulnerability_read_create_db_trigger_function feature flag is enabled' do
        let(:dismissal_reason) { 'false_positive' }

        it 'uses UpsertService to update the dismissal_reason' do
          expect(Vulnerabilities::Reads::UpsertService).to receive(:new).with(
            vulnerability,
            { state: :dismissed, dismissal_reason: dismissal_reason },
            projects: project
          ).and_call_original

          dismiss_vulnerability

          vulnerability_read = Vulnerabilities::Read.find_by(vulnerability_id: vulnerability.id)
          expect(vulnerability_read.dismissal_reason).to eq('false_positive')
        end
      end

      it 'creates note' do
        expect(SystemNoteService).to receive(:change_vulnerability_state).with(vulnerability, user)

        dismiss_vulnerability
      end

      context 'when there is a finding dismissal error' do
        before do
          allow(service).to receive(:dismiss_vulnerability_findings).and_return(
            described_class::FindingsDismissResult.new(false, broken_finding, 'something went wrong'))
        end

        let(:broken_finding) { vulnerability.findings.first }

        it_behaves_like 'not triggering vulnerability webhook event'

        it 'responds with error' do
          expect(dismiss_vulnerability.errors.messages).to eq(
            base: ["failed to dismiss associated finding(id=#{broken_finding.id}): something went wrong"])
        end
      end

      context 'when StateTransition.create! raises ActiveRecord::RecordInvalid' do
        before do
          allow(Vulnerabilities::StateTransition).to receive(:create!).and_raise(record_invalid_error)
        end

        context 'when the error is on the to_state field' do
          let(:record_invalid_error) do
            record = Vulnerabilities::StateTransition.new
            record.errors.add(:to_state, 'is invalid')
            ActiveRecord::RecordInvalid.new(record)
          end

          it 'raises Gitlab::Graphql::Errors::ArgumentError' do
            expect { dismiss_vulnerability }.to raise_error(Gitlab::Graphql::Errors::ArgumentError)
          end
        end

        context 'when the error is not on the to_state field' do
          let(:record_invalid_error) do
            record = Vulnerabilities::StateTransition.new
            record.errors.add(:base, 'some other error')
            ActiveRecord::RecordInvalid.new(record)
          end

          it 'does not raise Gitlab::Graphql::Errors::ArgumentError' do
            expect { dismiss_vulnerability }.not_to raise_error
          end
        end
      end

      context 'when security dashboard feature is disabled' do
        before do
          stub_licensed_features(security_dashboard: false)
        end

        it 'raises an "access denied" error' do
          expect { dismiss_vulnerability }.to raise_error(Gitlab::Access::AccessDeniedError)
        end
      end
    end
  end

  context 'when vulnerability state is not different from the requested state' do
    let(:state) { :dismissed }

    before do
      create(:vulnerability_state_transition, :to_dismissed, vulnerability: vulnerability, dismissal_reason: 'false_positive')
      project.add_maintainer(user)
    end

    it { expect { dismiss_vulnerability }.not_to raise_error }

    it_behaves_like 'creates a vulnerability state transition record'
    it_behaves_like 'triggering vulnerability webhook event'

    it 'does not create a note' do
      expect(SystemNoteService).to receive(:change_vulnerability_state).with(vulnerability, user)

      dismiss_vulnerability
    end

    context 'with a different dismissal reason' do
      let(:dismissal_reason) { 'used_in_tests' }

      it 'creates note' do
        expect(SystemNoteService).to receive(:change_vulnerability_state).with(vulnerability, user)

        dismiss_vulnerability
      end
    end
  end

  describe 'permissions' do
    context 'when admin mode is enabled', :enable_admin_mode do
      it { expect { dismiss_vulnerability }.to be_allowed_for(:admin) }
    end

    context 'when admin mode is disabled' do
      it { expect { dismiss_vulnerability }.to be_denied_for(:admin) }
    end

    it { expect { dismiss_vulnerability }.to be_allowed_for(:owner).of(project) }
    it { expect { dismiss_vulnerability }.to be_allowed_for(:maintainer).of(project) }
    it { expect { dismiss_vulnerability }.to be_denied_for(:developer).of(project) }

    it { expect { dismiss_vulnerability }.to be_denied_for(:auditor) }
    it { expect { dismiss_vulnerability }.to be_denied_for(:reporter).of(project) }
    it { expect { dismiss_vulnerability }.to be_denied_for(:guest).of(project) }
    it { expect { dismiss_vulnerability }.to be_denied_for(:anonymous) }
  end
end

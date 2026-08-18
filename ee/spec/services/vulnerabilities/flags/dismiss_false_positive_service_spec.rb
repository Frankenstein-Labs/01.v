# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Flags::DismissFalsePositiveService, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
  let_it_be(:finding) { vulnerability.findings.first }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  subject(:service) { described_class.new(user, vulnerability) }

  describe '#execute' do
    context 'when user is authorized' do
      before_all do
        project.add_maintainer(user)
      end

      describe '#track_event' do
        let_it_be(:existing_ai_flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.8,
            status: :detected_as_fp,
            description: 'AI detected as false positive'
          )
        end

        it 'tracks the internal event with correct properties' do
          expect(service).to receive(:track_internal_event).with(
            'dismiss_sast_vulnerability_false_positive_analysis',
            user: user,
            project: project,
            additional_properties: hash_including(
              value: vulnerability.id,
              property: vulnerability.severity
            )
          ).and_call_original

          result = service.execute
          expect(result).to be_success
        end

        it 'includes the manual origin in the label property' do
          allow(service).to receive(:track_internal_event) do |event_name, options|
            expect(event_name).to eq('dismiss_sast_vulnerability_false_positive_analysis')
            expect(options[:user]).to eq(user)
            expect(options[:additional_properties][:label]).to start_with('manual_')
          end

          result = service.execute
          expect(result).to be_success
        end

        context 'when vulnerability is secret_detection report type' do
          let_it_be(:sd_vulnerability) do
            create(:vulnerability, :with_finding, report_type: :secret_detection, project: project)
          end

          let_it_be(:sd_finding) { sd_vulnerability.findings.first }

          let!(:existing_sd_flag) do
            create(
              :vulnerabilities_flag,
              finding: sd_finding,
              flag_type: :false_positive,
              origin: 'ai_secrets_fp_detection',
              confidence_score: 0.8,
              status: :detected_as_fp,
              description: 'AI detected as false positive'
            )
          end

          subject(:service) { described_class.new(user, sd_vulnerability) }

          it 'tracks the secret detection dismissal event' do
            expect(service).to receive(:track_internal_event).with(
              'dismiss_secret_detection_vulnerability_false_positive_analysis',
              user: user,
              project: project,
              additional_properties: hash_including(
                value: sd_vulnerability.id,
                property: sd_vulnerability.severity
              )
            ).and_call_original

            result = service.execute
            expect(result).to be_success
          end
        end

        context 'when flag fails to save' do
          before do
            allow_next_instance_of(Vulnerabilities::Flag) do |flag|
              allow(flag).to receive_messages(
                save: false,
                errors: instance_double(ActiveModel::Errors, full_messages: ['Validation failed'])
              )
            end
          end

          it 'does not track the event' do
            expect(service).not_to receive(:track_internal_event)

            result = service.execute
            expect(result).to be_error
          end
        end
      end

      describe 'audit events' do
        let_it_be(:existing_ai_flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.8,
            status: :detected_as_fp,
            description: 'AI detected as false positive'
          )
        end

        it 'creates an audit event when dismissing a false positive flag', :aggregate_failures do
          expect { service.execute }.to change { AuditEventReader.count }.by(1)

          audit_event = AuditEventReader.last

          expect(audit_event).to have_attributes(
            author: user,
            entity_type: 'Project',
            entity_id: project.id,
            target_details: "#{vulnerability.title} (ID: #{vulnerability.id})"
          )
          expect(audit_event.details).to include(
            custom_message: 'Removed false positive flag',
            event_name: 'remove_vulnerability_false_positive_flag',
            target_type: 'Vulnerability'
          )
        end

        context 'when flag save fails' do
          before do
            allow_next_instance_of(Vulnerabilities::Flag) do |flag|
              allow(flag).to receive_messages(save: false,
                errors: instance_double(ActiveModel::Errors, full_messages: ['Validation error']))
            end
          end

          it 'does not create an audit event' do
            expect { service.execute }.not_to change { AuditEventReader.count }
          end
        end
      end

      context 'when creating a new flag' do
        let_it_be(:existing_ai_flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.8,
            status: :detected_as_fp,
            description: 'AI detected as false positive'
          )
        end

        it 'creates a new vulnerability flag with correct attributes' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:is_new_flag]).to be true

          flag = result.payload[:flag]
          expect(flag).to be_persisted
          expect(flag.flag_type).to eq('false_positive')
          expect(flag.origin).to start_with('manual_')
          expect(flag.description).to eq('Manually dismissed as false positive')
          expect(flag.confidence_score).to eq(0.0)
          expect(flag.status).to eq('dismissed')
          expect(flag.project_id).to eq(project.id)
          expect(flag.finding).to eq(finding)
        end

        context 'when flag saves successfully' do
          it 'calls Vulnerabilities::EsHelper.sync_elasticsearch with vulnerability id' do
            expect(::Vulnerabilities::EsHelper)
              .to receive(:sync_elasticsearch)
                    .with([vulnerability.id])

            result = service.execute

            expect(result).to be_success
          end
        end

        context 'when vulnerability has no findings' do
          let(:vulnerability_without_findings) { create(:vulnerability, project: project) }

          subject(:service) { described_class.new(user, vulnerability_without_findings) }

          it 'does not call sync_elasticsearch' do
            expect(::Vulnerabilities::EsHelper).not_to receive(:sync_elasticsearch)
            service.execute
          end
        end

        context 'when flag fails to save' do
          before do
            allow_next_instance_of(Vulnerabilities::Flag) do |flag|
              allow(flag).to receive_messages(
                save: false,
                errors: instance_double(ActiveModel::Errors, full_messages: ['Validation failed'])
              )
            end
          end

          it 'does not call sync_elasticsearch' do
            expect(::Vulnerabilities::EsHelper).not_to receive(:sync_elasticsearch)
            service.execute
          end
        end
      end

      context 'when manual flag already exists' do
        let!(:existing_manual_flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'manual',
            confidence_score: 0.0,
            description: 'Previous manual dismissal'
          )
        end

        let!(:ai_flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.8,
            status: :detected_as_fp,
            description: 'AI detection'
          )
        end

        it 'creates a new manual flag instead of updating existing one' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:is_new_flag]).to be true

          flag = result.payload[:flag]
          expect(flag).not_to eq(existing_manual_flag)
          expect(flag.confidence_score).to eq(0.0)
          expect(flag.origin).to start_with('manual_')
          expect(flag.description).to eq('Manually dismissed as false positive')
          expect(flag.project_id).to eq(project.id)

          # Verify existing flag is unchanged
          existing_manual_flag.reload
          expect(existing_manual_flag.description).to eq('Previous manual dismissal')
        end
      end

      context 'when flag has validation errors' do
        let!(:existing_ai_flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.8,
            status: :detected_as_fp,
            description: 'AI detected as false positive'
          )
        end

        before do
          allow_next_instance_of(Vulnerabilities::Flag) do |flag|
            allow(flag).to receive_messages(save: false,
              errors: instance_double(ActiveModel::Errors, full_messages: ['Validation error']))
          end
        end

        it 'returns an error response' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq('Validation error')
        end
      end
    end

    context 'when user is not authorized' do
      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Unauthorized')
      end
    end

    context 'when vulnerability is nil' do
      subject(:service) { described_class.new(user, nil) }

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Vulnerability not found')
      end
    end

    context 'when vulnerability has no finding' do
      let(:vulnerability_without_finding) { create(:vulnerability, project: project) }

      subject(:service) { described_class.new(user, vulnerability_without_finding) }

      before_all do
        project.add_maintainer(user)
      end

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('No current finding available')
      end
    end

    context 'when vulnerability has no flags' do
      before_all do
        project.add_maintainer(user)
      end

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('No vulnerability flag available to dismiss')
      end
    end

    context 'when latest vulnerability flag has non-dismissable status' do
      let!(:existing_flag_with_not_started_status) do
        create(
          :vulnerabilities_flag,
          finding: finding,
          flag_type: :false_positive,
          origin: 'ai_sast_fp_detection',
          confidence_score: 0.0,
          status: :not_started,
          description: 'Not yet processed'
        )
      end

      before_all do
        project.add_maintainer(user)
      end

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('No vulnerability flag available to dismiss')
      end
    end

    context 'when latest vulnerability flag has dismissable status' do
      let!(:existing_flag_with_detection) do
        create(
          :vulnerabilities_flag,
          finding: finding,
          flag_type: :false_positive,
          origin: 'ai_sast_fp_detection',
          confidence_score: 0.8,
          status: :detected_as_fp,
          description: 'AI detected as false positive'
        )
      end

      before_all do
        project.add_maintainer(user)
      end

      it 'successfully creates a new manual flag' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:is_new_flag]).to be true

        flag = result.payload[:flag]
        expect(flag).to be_persisted
        expect(flag.confidence_score).to eq(0.0)
        expect(flag.origin).to start_with('manual_')
        expect(flag.status).to eq('dismissed')
      end
    end

    describe '#can_dismiss_flag?' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when finding has no flags' do
        it 'returns false' do
          expect(service.send(:can_dismiss_flag?)).to be false
        end
      end

      context 'when latest flag has status not_started' do
        let!(:flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'manual',
            confidence_score: 0.0,
            status: :not_started
          )
        end

        it 'returns false' do
          expect(service.send(:can_dismiss_flag?)).to be false
        end
      end

      context 'when latest flag has status dismissed' do
        let!(:flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'manual',
            confidence_score: 0.0,
            status: :dismissed
          )
        end

        it 'returns false' do
          expect(service.send(:can_dismiss_flag?)).to be false
        end
      end

      context 'when latest flag has status failed' do
        let!(:flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.0,
            status: :failed
          )
        end

        it 'returns false' do
          expect(service.send(:can_dismiss_flag?)).to be false
        end
      end

      context 'when latest flag has status detected_as_fp' do
        let!(:flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.7,
            status: :detected_as_fp
          )
        end

        it 'returns true' do
          expect(service.send(:can_dismiss_flag?)).to be true
        end
      end

      context 'when latest flag has status detected_as_not_fp' do
        let!(:flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.0,
            status: :detected_as_not_fp
          )
        end

        it 'returns true' do
          expect(service.send(:can_dismiss_flag?)).to be true
        end
      end

      context 'when there are multiple flags and latest has dismissable status' do
        let!(:older_flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'manual',
            confidence_score: 0.0,
            status: :not_started,
            created_at: 2.days.ago
          )
        end

        let!(:latest_flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.9,
            status: :detected_as_fp,
            created_at: 1.day.ago
          )
        end

        it 'returns true based on latest flag' do
          expect(service.send(:can_dismiss_flag?)).to be true
        end
      end
    end
  end

  describe 'private methods' do
    before_all do
      project.add_maintainer(user)
    end

    describe '#authorized?' do
      it 'returns true when user can admin vulnerability' do
        expect(service.send(:authorized?)).to be true
      end

      context 'when user cannot admin vulnerability' do
        let(:unauthorized_user) { create(:user) }

        subject(:service) { described_class.new(unauthorized_user, vulnerability) }

        it 'returns false' do
          expect(service.send(:authorized?)).to be false
        end
      end
    end

    describe '#current_finding' do
      it 'returns the last finding of the vulnerability' do
        expect(service.send(:current_finding)).to eq(finding)
      end
    end
  end
end

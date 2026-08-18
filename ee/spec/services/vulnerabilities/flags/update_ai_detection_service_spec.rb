# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Flags::UpdateAiDetectionService, feature_category: :vulnerability_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project) }
  let(:params) do
    {
      confidence_score: 85,
      description: 'AI detected this as a false positive with high confidence'
    }
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
  let_it_be(:finding) { vulnerability.findings.first }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  subject(:service) { described_class.new(user, vulnerability, params) }

  describe '#execute' do
    context 'when user is authorized' do
      before_all do
        project.add_developer(user)
      end

      describe '#track_event' do
        context 'when confidence score is provided' do
          it 'tracks the internal event with correct properties' do
            expect(service).to receive(:track_internal_event).with(
              'reported_sast_vulnerability_false_positive_analysis',
              user: user,
              project: project,
              additional_properties: {
                label: 'ai_sast_fp_detection',
                value: vulnerability.id,
                property: vulnerability.severity,
                confidence_score: 85
              }
            ).and_call_original

            result = service.execute
            expect(result).to be_success
          end
        end

        context 'when vulnerability is secret_detection report type' do
          let_it_be(:sd_vulnerability) do
            create(:vulnerability, :with_finding, report_type: :secret_detection, project: project)
          end

          subject(:service) { described_class.new(user, sd_vulnerability, params) }

          it 'tracks the secret detection event with correct properties' do
            expect(service).to receive(:track_internal_event).with(
              'reported_secret_detection_vulnerability_false_positive_analysis',
              user: user,
              project: project,
              additional_properties: {
                label: 'ai_sast_fp_detection',
                value: sd_vulnerability.id,
                property: sd_vulnerability.severity,
                confidence_score: 85
              }
            ).and_call_original

            result = service.execute
            expect(result).to be_success
          end
        end

        context 'when confidence score is not provided' do
          let(:params) { { description: 'Test description' } }

          it 'does not track the event' do
            expect(service).not_to receive(:track_internal_event)

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

      describe '#sync_elasticsearch' do
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

          subject(:service) { described_class.new(user, vulnerability_without_findings, params) }

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

      context 'when creating a new flag' do
        it 'creates a new vulnerability flag with correct attributes' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:is_new_flag]).to be true

          flag = result.payload[:flag]
          expect(flag).to be_persisted
          expect(flag.flag_type).to eq('false_positive')
          expect(flag.origin).to eq('ai_sast_fp_detection')
          expect(flag.description).to eq('AI detected this as a false positive with high confidence')
          expect(flag.confidence_score).to eq(0.85)
          expect(flag.status).to eq('detected_as_fp')
          expect(flag.project_id).to eq(project.id)
          expect(flag.finding).to eq(finding)
        end

        context 'when origin is provided' do
          let(:params) do
            {
              confidence_score: 85,
              description: 'AI detected this as a false positive with high confidence',
              origin: 'custom_ai_model'
            }
          end

          it 'creates a flag with the specified origin' do
            result = service.execute

            expect(result).to be_success
            flag = result.payload[:flag]
            expect(flag.origin).to eq('custom_ai_model')
          end
        end

        it 'normalizes confidence score from 0-100 to 0.0-1.0' do
          result = service.execute

          expect(result).to be_success
          flag = result.payload[:flag]
          expect(flag.confidence_score).to eq(0.85)
        end

        context 'with edge case confidence scores' do
          it 'handles 0 confidence score' do
            params[:confidence_score] = 0
            result = service.execute

            expect(result).to be_success
            flag = result.payload[:flag]
            expect(flag.confidence_score).to eq(0.0)
          end

          it 'handles 100 confidence score' do
            params[:confidence_score] = 100
            result = service.execute

            expect(result).to be_success
            flag = result.payload[:flag]
            expect(flag.confidence_score).to eq(1.0)
          end
        end
      end

      context 'when updating an existing flag' do
        let!(:existing_flag) do
          create(:vulnerabilities_flag, :false_positive,
            finding: finding,
            origin: 'ai_sast_fp_detection',
            description: 'Old description',
            confidence_score: 0.5,
            status: :not_started
          )
        end

        it 'updates the existing flag' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:is_new_flag]).to be false

          flag = result.payload[:flag]
          expect(flag.id).to eq(existing_flag.id)
          expect(flag.description).to eq('AI detected this as a false positive with high confidence')
          expect(flag.confidence_score).to eq(0.85)
          expect(flag.status).to eq('detected_as_fp')
        end

        context 'when only confidence_score is provided' do
          let(:params) { { confidence_score: 95 } }

          it 'updates only the confidence_score and status' do
            result = service.execute

            expect(result).to be_success
            flag = result.payload[:flag]
            expect(flag.description).to eq('Old description')
            expect(flag.confidence_score).to eq(0.95)
            expect(flag.status).to eq('detected_as_fp')
          end
        end

        context 'when only confidence_score is below threshold' do
          let(:params) { { confidence_score: 59 } }

          it 'updates status to detected as not false positive' do
            result = service.execute

            expect(result).to be_success
            flag = result.payload[:flag]
            expect(flag.status).to eq('detected_as_not_fp')
          end
        end

        context 'when only confidence_score at threshold' do
          let(:params) { { confidence_score: 60 } }

          it 'updates status to detected as false positive' do
            result = service.execute

            expect(result).to be_success
            flag = result.payload[:flag]
            expect(flag.status).to eq('detected_as_fp')
          end
        end

        context 'when only confidence_score above threshold' do
          let(:params) { { confidence_score: 61 } }

          it 'updates status to detected as false positive' do
            result = service.execute

            expect(result).to be_success
            flag = result.payload[:flag]
            expect(flag.status).to eq('detected_as_fp')
          end
        end

        context 'when origin is provided and different from existing flag' do
          let(:params) do
            {
              confidence_score: 90,
              description: 'Updated description',
              origin: 'different_origin'
            }
          end

          it 'creates a new flag with the new origin' do
            result = nil
            expect { result = service.execute }.to change { Vulnerabilities::Flag.count }.by(1)

            expect(result).to be_success
            expect(result.payload[:is_new_flag]).to be true

            flag = result.payload[:flag]
            expect(flag.origin).to eq('different_origin')
            expect(flag.confidence_score).to eq(0.9)
            expect(flag.description).to eq('Updated description')
          end
        end
      end

      context 'when vulnerability has multiple findings' do
        let!(:older_finding) { create(:vulnerabilities_finding, vulnerability: vulnerability, project: project) }
        let!(:newer_finding) { create(:vulnerabilities_finding, vulnerability: vulnerability, project: project) }

        it 'uses the most recent finding' do
          result = service.execute

          expect(result).to be_success
          flag = result.payload[:flag]
          expect(flag.finding).to eq(newer_finding)
        end
      end

      context 'when flag validation fails' do
        it 'returns an error' do
          allow_next_instance_of(Vulnerabilities::Flag) do |flag|
            allow(flag).to receive_messages(
              save: false,
              errors: instance_double(
                ActiveModel::Errors,
                full_messages: ['Description is too long']
              )
            )
          end

          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq('Description is too long')
        end
      end
    end

    context 'when user is not authorized' do
      it 'returns an unauthorized error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Unauthorized')
      end

      context 'when user is an auditor (non-member)' do
        let_it_be(:auditor_user) { create(:user, :auditor) }

        subject(:service) { described_class.new(auditor_user, vulnerability, params) }

        it 'returns an unauthorized error' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq('Unauthorized')
        end
      end
    end

    context 'when vulnerability is nil' do
      subject(:service) { described_class.new(user, nil, params) }

      it 'returns a vulnerability not found error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Vulnerability not found')
      end
    end

    context 'when vulnerability has no findings' do
      let(:vulnerability_without_findings) { create(:vulnerability, project: project) }

      subject(:service) { described_class.new(user, vulnerability_without_findings, params) }

      before_all do
        project.add_developer(user)
      end

      it 'returns a no current finding error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('No current finding available')
      end
    end

    context 'when confidence_score is nil' do
      let(:params) { { description: 'Test description' } }

      before_all do
        project.add_developer(user)
      end

      it 'sets status to failed and confidence_score to 0.0' do
        result = service.execute

        expect(result).to be_success
        flag = result.payload[:flag]
        expect(flag.confidence_score).to eq(0.0)
        expect(flag.status).to eq('failed')
      end
    end

    context 'when description exceeds maximum length' do
      let(:very_long_description) { 'a' * 1500000 }
      let(:params) do
        {
          confidence_score: 85,
          description: very_long_description
        }
      end

      before_all do
        project.add_developer(user)
      end

      it 'truncates description to 100000 characters' do
        result = service.execute

        expect(result).to be_success
        flag = result.payload[:flag]
        expect(flag.description.length).to eq(100000)
        expect(flag.description).to eq('a' * 100000)
      end
    end

    context 'when description is less than maximum length' do
      let(:max_length_description) { 'b' * 10000 }
      let(:params) do
        {
          confidence_score: 85,
          description: max_length_description
        }
      end

      before_all do
        project.add_developer(user)
      end

      it 'preserves the full description' do
        result = service.execute

        expect(result).to be_success
        flag = result.payload[:flag]
        expect(flag.description.length).to eq(10000)
        expect(flag.description).to eq(max_length_description)
      end
    end
  end
end

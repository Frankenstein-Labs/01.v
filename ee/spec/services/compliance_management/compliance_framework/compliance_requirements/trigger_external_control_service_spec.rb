# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceRequirements::TriggerExternalControlService,
  feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: group) }
  let_it_be(:compliance_requirement) { create(:compliance_requirement, namespace: group, framework: framework) }
  let_it_be(:control) do
    create(:compliance_requirements_control,
      :external,
      compliance_requirement: compliance_requirement,
      namespace: group
    )
  end

  before do
    create(:compliance_framework_project_setting, project: project,
      compliance_management_framework: framework)
  end

  subject(:service) { described_class.new(project, control) }

  describe '#execute' do
    context 'when control is not external' do
      before do
        allow(control).to receive(:external?).and_return(false)
      end

      it 'returns nil' do
        expect(service.execute).to be_nil
      end
    end

    context 'when control is external' do
      before do
        allow(control).to receive(:external?).and_return(true)
      end

      context 'with successful HTTP request' do
        let!(:existing_status) do
          create(:project_control_compliance_status,
            project: project,
            compliance_requirements_control: control,
            namespace_id: project.namespace_id,
            compliance_requirement_id: control.compliance_requirement.id,
            status: :pending
          )
        end

        let(:success_response) { instance_double(Gitlab::HTTP::Response, success?: true, code: 200) }

        before do
          allow(Gitlab::HTTP).to receive(:post).and_return(success_response)
        end

        it 'makes a POST request to the external URL with correct data' do
          project_control_compliance_status = ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus
                                                .for_project_and_control(project.id, control.id).last

          project_data = ProjectSerializer.new.represent(project, serializer: :project_details)
          project_data[:project_control_compliance_status] = project_control_compliance_status.as_json
          encoded_data = Gitlab::Json::LimitedEncoder.encode(project_data)

          expect(Gitlab::HTTP).to receive(:post) do |url, params|
            expect(url).to eq(control.external_url)
            expect(params[:headers]['Content-Type']).to eq('application/json')

            actual_json = ::Gitlab::Json.parse(params[:body])
            expected_json = ::Gitlab::Json.parse(encoded_data)
            expect(actual_json).to eq(expected_json)

            expected_hmac = OpenSSL::HMAC.hexdigest('sha256', control.secret_token, params[:body])
            expect(params[:headers]['X-GitLab-Signature']).to eq(expected_hmac)
          end.and_return(success_response)

          service.execute
        end

        context 'when compliance status does not exist' do
          before do
            ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus.delete_all
          end

          it 'creates a new compliance status record' do
            expect { service.execute }.to change {
              ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus.count
            }.by(1)
          end

          it 'creates the record with pending status' do
            service.execute
            status = ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus.last

            expect(status.status).to eq('pending')
          end
        end

        context 'when compliance status already exists' do
          let!(:existing_status) do
            create(:project_control_compliance_status,
              project: project,
              compliance_requirements_control: control,
              namespace_id: project.namespace_id,
              compliance_requirement_id: control.compliance_requirement.id,
              status: :fail
            )
          end

          it 'does not create a new compliance status record' do
            expect { service.execute }.not_to change {
              ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus.count
            }
          end

          it 'updates the existing status to pending' do
            service.execute

            expect(existing_status.reload.status).to eq('pending')
          end
        end

        it 'schedules a timeout worker' do
          expect(ComplianceManagement::TimeoutPendingExternalControlsWorker).to receive(:perform_in)
            .with(31.minutes, { 'control_id' => control.id, 'project_id' => project.id })

          service.execute
        end

        it 'creates an audit event for successful request' do
          expect(Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'request_to_compliance_external_control_successful',
              scope: project,
              target: control
            )
          )

          service.execute
        end

        it 'returns a successful service response' do
          response = service.execute

          expect(response).to be_success
          expect(response.payload).to eq({ control: control })
        end
      end

      context 'with failed HTTP request' do
        let(:error_response) { instance_double(Gitlab::HTTP::Response, success?: false, code: 500) }

        before do
          allow(Gitlab::HTTP).to receive(:post).and_return(error_response)
        end

        it 'creates an audit event for failed request' do
          expect(Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'request_to_compliance_external_control_failed',
              scope: project,
              target: control
            )
          )

          service.execute
        end

        it 'returns an error service response' do
          response = service.execute

          expect(response).not_to be_success
          expect(response.message).to include('External control service responded with an error')
          expect(response.reason).to eq('Internal Server Error')
        end
      end

      context 'with network error' do
        before do
          allow(Gitlab::HTTP).to receive(:post).and_raise(Errno::ECONNRESET)
        end

        it 'creates an audit event for the error' do
          expect(Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'request_to_compliance_external_control_failed',
              scope: project,
              target: control
            )
          )

          service.execute
        end

        it 'returns an error service response' do
          response = service.execute

          expect(response).not_to be_success
          expect(response.message).to eq('Connection reset by peer')
          expect(response.reason).to eq(:network_error)
        end
      end

      context 'when ActiveRecord::RecordInvalid is raised' do
        let(:success_response) { instance_double(HTTParty::Response, success?: true, code: 200) }

        before do
          allow(Gitlab::HTTP).to receive(:post).and_return(success_response)
        end

        it 'retries in case of race conditions' do
          record_invalid_error = ActiveRecord::RecordInvalid.new(
            build(:project_control_compliance_status).tap do |control_status|
              control_status.errors.add(:project, :taken, message: "project taken")
            end
          )

          expect_next_instance_of(::ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus) do |cs|
            expect(cs).to receive(:save!).and_raise(record_invalid_error)
          end

          allow_next_instance_of(::ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus) do |cs|
            allow(cs).to receive(:save!).and_call_original
          end

          response = service.execute

          expect(response.status).to eq(:success)
          expect(project.project_control_compliance_statuses.last)
            .to have_attributes(
              project_id: project.id,
              namespace_id: project.namespace_id,
              compliance_requirements_control_id: control.id,
              compliance_requirement_id: control.compliance_requirement.id,
              status: 'pending'
            )
        end

        it 'does not retry for other scenarios' do
          record_invalid_error = ActiveRecord::RecordInvalid.new(
            build(:project_control_compliance_status).tap { |status| status.errors.add(:status, :blank) }
          )

          expect_next_instance_of(::ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus) do |cs|
            expect(cs).to receive(:save!).and_raise(record_invalid_error)
          end

          response = service.execute

          expect(response.status).to eq(:error)
          expect(response.message).to eq("Status can't be blank")
        end
      end
    end
  end
end

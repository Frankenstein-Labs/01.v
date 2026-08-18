# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ComplianceExternalControls, feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:project2) { create(:project, namespace: group) }
  let_it_be(:framework) { create(:compliance_framework, projects: [project], namespace: group) }
  let_it_be(:requirement) { create(:compliance_requirement, framework: framework, namespace: group) }
  let_it_be(:control) do
    create(:compliance_requirements_control, control_type: :external, secret_token: 'foo',
      compliance_requirement: requirement, external_url: 'https://example.com')
  end

  let_it_be(:project_control_status) do
    create(:project_control_compliance_status,
      project: project,
      compliance_requirements_control: control,
      compliance_requirement: requirement,
      status: 'pending')
  end

  let_it_be(:number_used_once) { SecureRandom.hex(16) }

  describe 'PATCH /projects/:id/compliance_external_controls/:control_id/status' do
    let(:path) { api("/projects/#{project.id}/compliance_external_controls/#{control.id}/status") }
    let(:mock_redis) { instance_double(Redis) }

    def generate_headers(
      path:,
      data:,
      secret: control.secret_token,
      timestamp: Time.now.to_i.to_s,
      nonce: number_used_once
    )
      sign_payload = "#{timestamp}#{nonce}#{path}#{data}"
      signature = OpenSSL::HMAC.hexdigest('SHA256', secret, sign_payload)

      {
        'X-Gitlab-Timestamp' => timestamp,
        'X-Gitlab-Nonce' => nonce,
        'X-Gitlab-Hmac-Sha256' => signature
      }
    end

    before do
      allow(Gitlab::Redis::SharedState).to receive(:with).and_yield(mock_redis)

      allow(mock_redis).to receive(:exists?)
        .with("control_statuses:nonce:#{number_used_once}")
        .and_return(false)

      allow(mock_redis).to receive(:set)
        .with("control_statuses:nonce:#{number_used_once}", '1', ex: 16)
        .and_return('OK')

      allow(mock_redis).to receive(:incr).with(any_args).and_return(1)
      allow(mock_redis).to receive(:ttl).with(any_args).and_return(3600)

      stub_licensed_features(custom_compliance_frameworks: true)
    end

    describe 'updates the control status' do
      it 'updates the control status' do
        %w[pass fail].each do |status|
          data = "status=#{status}"
          headers = generate_headers(path:, data:)

          patch path, params: { status: }, headers: headers

          aggregate_failures do
            expect(response).to have_gitlab_http_status(:ok)
            expect(response.body).to eq({ status: }.to_json)
            expect(project_control_status.reload.status).to eq(status)
          end
        end
      end

      it 'calls UpdateStatusService with correct parameters' do
        service_double = instance_double(
          ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::UpdateStatusService
        )
        expect(ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::UpdateStatusService)
          .to receive(:new)
          .with(hash_including(
            control: control,
            project: project,
            status_value: 'pass',
            params: { refresh_requirement_status: true }
          )) do |args|
            expect(args[:current_user]).to be_a(::Gitlab::Audit::UnauthenticatedAuthor)
            service_double
          end
        expect(service_double).to receive(:execute).and_return(ServiceResponse.success(payload: { status: 'pass' }))
        data = "status=pass"
        headers = generate_headers(path:, data:)

        patch path, params: { status: 'pass' }, headers: headers

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'stores the nonce in Redis' do
        expect(mock_redis).to receive(:set).with("control_statuses:nonce:#{number_used_once}", '1', ex: 16)
        headers = generate_headers(path: path, data: "status=pass")

        patch path, params: { status: 'pass' }, headers: headers

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe 'returns errors' do
      before do
        allow(project_control_status).to receive(:update!).and_raise("Unexpected update attempt")
      end

      context 'with control type restrictions' do
        let_it_be(:internal_control) { create(:compliance_requirements_control, control_type: :internal) }
        let(:path) { api("/projects/#{project.id}/compliance_external_controls/#{internal_control.id}/status") }

        it 'returns forbidden for internal controls' do
          data = "status=pass"
          headers = generate_headers(path:, data:)

          patch path, params: { status: 'pass' }, headers: headers

          aggregate_failures do
            expect(response).to have_gitlab_http_status(:forbidden)
            expect(json_response['error']).to eq('Control is not external')
          end
        end
      end

      context 'with invalid request' do
        it 'does not update the control status with invalid status' do
          data = "status=invalid"
          headers = generate_headers(path:, data:)

          patch path, params: { status: 'invalid' }, headers: headers

          aggregate_failures do
            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to eq('status does not have a valid value')
          end
        end

        it 'returns bad request when the status is not provided' do
          data = "status="
          headers = generate_headers(path:, data:)

          patch path, params: { status: }, headers: headers

          aggregate_failures do
            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to eq('status does not have a valid value')
          end
        end
      end

      context 'with resource not found' do
        it 'returns not found when the control id is not provided' do
          data = "status=pass"
          missing_control_path = "/projects/#{project.id}/compliance_external_controls/"
          headers = generate_headers(path: missing_control_path, data: data)

          patch api(missing_control_path), params: { status: 'pass' }, headers: headers

          aggregate_failures do
            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response['error']).to eq('404 Not Found')
          end
        end

        it 'returns not found when the control id is not found' do
          data = "status=pass"
          missing_control_path = "/projects/#{project.id}/compliance_external_controls/123/status"
          headers = generate_headers(path: missing_control_path, data: data)

          patch api(missing_control_path), params: { status: 'pass' }, headers: headers

          aggregate_failures do
            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response['error']).to eq('Control not found')
          end
        end

        it 'returns not found when the project id is not provided' do
          data = "status=pass"
          missing_project_path = "/projects/compliance_external_controls/#{control.id}/status"
          headers = generate_headers(path: missing_project_path, data: data)

          patch api(missing_project_path), params: { status: 'pass' }, headers: headers

          aggregate_failures do
            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response['error']).to eq('404 Not Found')
          end
        end

        it 'returns not found when the project id is not found' do
          data = "status=pass"
          missing_project_path = api("/projects/123/compliance_external_controls/#{control.id}/status")
          headers = generate_headers(path: missing_project_path, data: data)

          patch missing_project_path, params: { status: 'pass' }, headers: headers

          aggregate_failures do
            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response['error']).to eq('Project not found')
          end
        end

        it 'returns not found when the project id does not match the control id' do
          data = "status=pass"
          missing_project_path = api("/projects/#{project2.id}/compliance_external_controls/#{control.id}/status")
          headers = generate_headers(path: missing_project_path, data: data)

          patch missing_project_path, params: { status: 'pass' }, headers: headers

          aggregate_failures do
            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response['error']).to eq('Project not found')
          end
        end
      end

      context 'with unauthorized request' do
        it 'returns unauthorized when the sha256 header is missing' do
          data = "status=pass"
          headers = generate_headers(path: path, data: data)
          headers.delete('X-Gitlab-Hmac-Sha256')

          patch path, params: { status: 'pass' }, headers: headers

          aggregate_failures do
            expect(response).to have_gitlab_http_status(:unauthorized)
            expect(json_response['error']).to eq('Missing required headers')
          end
        end

        it 'returns unauthorized when secret keys do not match' do
          data = "status=pass"
          wrong_secret = 'wrong_secret'
          headers = generate_headers(path: path, data: data, secret: wrong_secret)

          patch path, params: { status: 'pass' }, headers: headers

          aggregate_failures do
            expect(response).to have_gitlab_http_status(:unauthorized)
            expect(json_response['error']).to eq('Invalid signature')
          end
        end

        it 'returns unauthorized when the timestamp is too old' do
          [15, 16].each do |duration|
            data = "status=pass"
            headers = generate_headers(path: path, data: data, timestamp: (Time.now.to_i - duration).to_s)

            patch path, params: { status: 'pass' }, headers: headers

            aggregate_failures do
              expect(response).to have_gitlab_http_status(:unauthorized)
              expect(json_response['error']).to eq('Request has expired')
            end
          end
        end

        it 'returns bad request when the nonce is invalid' do
          data = "status=pass"
          headers = generate_headers(path: path, data: data, nonce: nil)

          patch path, params: { status: 'pass' }, headers: headers

          aggregate_failures do
            expect(response).to have_gitlab_http_status(:unauthorized)
            expect(json_response['error']).to eq('Missing required headers')
          end
        end

        it 'returns unauthorized with invalid nonces' do
          ['too_short', 'a' * 64].each do |invalid_nonce|
            data = "status=pass"
            headers = generate_headers(path: path, data: data, nonce: invalid_nonce)

            patch path, params: { status: 'pass' }, headers: headers

            aggregate_failures do
              expect(response).to have_gitlab_http_status(:unauthorized)
              expect(json_response['error']).to eq('Invalid nonce')
            end
          end
        end

        it 'returns unauthorized when the nonce is already used' do
          allow(mock_redis).to receive(:exists?)
            .with("control_statuses:nonce:#{number_used_once}")
            .and_return(true)
          headers = generate_headers(path: path, data: "status=pass")

          patch path, params: { status: 'pass' }, headers: headers

          aggregate_failures do
            expect(response).to have_gitlab_http_status(:unauthorized)
            expect(json_response['error']).to eq('Invalid nonce')
          end
        end

        it 'returns unauthorized when the feature is not licensed' do
          stub_licensed_features(custom_compliance_frameworks: false)
          data = "status=pass"
          headers = generate_headers(path:, data:)

          patch path, params: { status: 'pass' }, headers: headers

          aggregate_failures do
            expect(response).to have_gitlab_http_status(:unauthorized)
            expect(json_response['error']).to eq('Not permitted to update compliance control status')
          end
        end

        it 'returns unauthorized when the timestamp is in the future' do
          [0, (Time.now.to_i + 60).to_s].each do |invalid_timestamp|
            data = "status=pass"
            headers = generate_headers(path: path, data: data, timestamp: invalid_timestamp)

            patch path, params: { status: 'pass' }, headers: headers

            aggregate_failures do
              expect(response).to have_gitlab_http_status(:unauthorized)
              expect(json_response['error']).to eq('Invalid timestamp')
            end
          end
        end
      end

      it 'returns error when the UpdateStatusService fails' do
        allow_next_instance_of(
          ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::UpdateStatusService
        ) do |instance|
          allow(instance).to receive(:execute).and_return(
            ServiceResponse.error(message: 'Failed to update status')
          )
        end
        data = "status=pass"
        headers = generate_headers(path: path, data: data)

        patch path, params: { status: 'pass' }, headers: headers

        aggregate_failures do
          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to eq('Failed to update status')
        end
      end
    end
  end
end

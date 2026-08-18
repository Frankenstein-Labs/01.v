# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Internal::SecretsManager, :gitlab_secrets_manager, :skip_openbao_setup, feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let(:sample_audit_log_json) do
    {
      "time" => "2025-09-27T15:01:27.13058Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "project_#{project.id}/users/direct/user_#{user.id}"],
        "entity_id" => "60792534-ee8a-bdc5-6416-005af4303ac4",
        "metadata" => { "correlation_id" => "01K7KVMBNNDJK2YVC729B5ERF0",
                        "namespace_id" => project.namespace.id.to_s,
                        "project_id" => project.id.to_s,
                        "user_id" => user.id.to_s }
      },
      "request" => {
        "operation" => "read",
        "path" => "secrets/kv/data/explicit/my_test_secret",
        "namespace" => { "id" => "M0zDLE", "path" => "user_#{user.id}/project_#{project.id}/" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:headers) do
    {
      'Gitlab-Openbao-Auth-Token' => 'test_token',
      'Content-Type' => 'application/json'
    }
  end

  let(:authentication_token_file_path) do
    Rails.root.join('ee/spec/fixtures/secrets_manager/gitlab_openbao_authentication_token_secret.txt')
  end

  let(:make_request) do
    post api('/internal/secrets_manager/audit_logs'), params: sample_audit_log_json, headers: headers
  end

  before do
    openbao_config = Gitlab.config.openbao
    openbao_config['authentication_token_secret_file_path'] = authentication_token_file_path
    allow(Gitlab.config).to receive(:openbao).and_return(openbao_config)
    allow(::Gitlab::Middleware::InternalApiAuthenticator).to receive(:verify!).and_return(true)
  end

  describe 'POST /internal/secrets_manager/audit_logs' do
    it 'enqueues the audit log worker with the raw payload', :aggregate_failures do
      expect(SecretsManagement::AuditLogWorker).to receive(:perform_async).with(sample_audit_log_json)

      make_request

      expect(response).to have_gitlab_http_status(:accepted)
    end

    it 'does not process the audit log synchronously' do
      expect(SecretsManagement::AuditLog).not_to receive(:new)

      make_request
    end

    context 'with a request-type audit line' do
      let(:sample_audit_log_json) do
        { "type" => "request", "request" => { "operation" => "read" } }.to_json
      end

      it 'does not enqueue the worker', :aggregate_failures do
        expect(SecretsManagement::AuditLogWorker).not_to receive(:perform_async)

        make_request

        expect(response).to have_gitlab_http_status(:accepted)
      end
    end

    context 'with an invalid JSON payload' do
      let(:sample_audit_log_json) { 'not-json' }

      it 'is rejected by the framework before reaching the endpoint', :aggregate_failures do
        expect(SecretsManagement::AuditLogWorker).not_to receive(:perform_async)

        make_request

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when secrets manager entitlement blocks the namespace' do
      before do
        stub_feature_flags(secrets_manager_paid_experience: true)
        allow(SecretsManagement::Entitlement).to receive(:for)
          .and_return(SecretsManagement::Entitlement.new(state: :ineligible))
      end

      it 'still enqueues the audit log worker (auditing is independent of entitlement)', :aggregate_failures do
        expect(SecretsManagement::AuditLogWorker).to receive(:perform_async).with(sample_audit_log_json)

        make_request

        expect(response).to have_gitlab_http_status(:accepted)
      end
    end

    context 'when the secrets_manager_async_audit_logs feature flag is disabled' do
      before do
        stub_feature_flags(secrets_manager_async_audit_logs: false)
      end

      it 'creates a new audit log entry synchronously', :aggregate_failures do
        expect(SecretsManagement::AuditLogWorker).not_to receive(:perform_async)
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: :secrets_manager_read_project_secret,
            message: "Read project secret",
            ip_address: "172.16.123.1"
          )
        ).and_call_original

        make_request

        expect(response).to have_gitlab_http_status(:accepted)
      end

      it 'invokes the billable event emitter with the audit log', :aggregate_failures do
        expect(SecretsManagement::BillableEvents::SecretsReadEmitter).to receive(:emit!)
          .with(an_instance_of(SecretsManagement::AuditLog))

        make_request

        expect(response).to have_gitlab_http_status(:accepted)
      end

      context 'when the billable event emitter raises' do
        it 'still returns 202', :aggregate_failures do
          allow(SecretsManagement::BillableEvents::SecretsReadEmitter).to receive(:emit!)
            .and_raise(StandardError, 'boom')

          expect { make_request }.not_to raise_error
          expect(response).to have_gitlab_http_status(:accepted)
        end
      end

      context 'with a billable read' do
        let(:billable_audit_log_json) do
          parsed = Gitlab::Json.safe_parse(sample_audit_log_json)
          parsed['auth']['policy_results'] = { 'allowed' => true }
          parsed.to_json
        end

        let(:make_request) do
          post api('/internal/secrets_manager/audit_logs'), params: billable_audit_log_json, headers: headers
        end

        before do
          stub_feature_flags(secrets_manager_emit_secret_read_events: true)
        end

        it 'tracks a secrets_read billing event end-to-end', :aggregate_failures do
          expect(::Gitlab::BillingEvents::Client).to receive(:track_billing_event).with(
            hash_including(
              event_type: 'secrets_read',
              unit_of_measure: 'request',
              quantity: 1,
              namespace: project.namespace,
              project: project
            )
          )

          make_request

          expect(response).to have_gitlab_http_status(:accepted)
        end

        context 'when CDot entitlement resolution raises (error or timeout)' do
          before do
            allow(SecretsManagement::Entitlement).to receive(:for!).and_raise(
              ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error, 'timed out'
            )
          end

          it 'still returns 202 and emits the event without entitlement metadata', :aggregate_failures do
            expect(::Gitlab::BillingEvents::Client).to receive(:track_billing_event).with(
              hash_including(
                event_type: 'secrets_read',
                metadata: hash_excluding(:entitlement_state, :blocked_reason)
              )
            )

            expect { make_request }.not_to raise_error

            expect(response).to have_gitlab_http_status(:accepted)
          end
        end
      end
    end

    context 'when authentication fails' do
      let(:headers) do
        {
          'Gitlab-Openbao-Auth-Token' => 'invalid_token',
          'Content-Type' => 'application/json'
        }
      end

      it 'returns unauthorized status' do
        make_request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      context 'when authentication token is not readable' do
        it 'returns unauthorized status' do
          allow_next_instance_of(Pathname) do |path|
            allow(path).to receive(:realpath).and_raise(Errno::EACCES)
          end

          make_request
          expect(response).to have_gitlab_http_status(:internal_server_error)
          expect(response.body).to include('Unable to fetch Openbao authentication token secret')
        end
      end

      context 'when the authentication token path does have NOT the default value' do
        context 'when the file path is NOT within the root folder' do
          let(:authentication_token_file_path) { '/test/path' }

          before do
            allow_next_instance_of(Pathname) do |pathname|
              allow(pathname).to receive(:realpath).and_return('/test/path')
            end
          end

          it 'raises invalid token file path error' do
            make_request
            expect(response).to have_gitlab_http_status(:internal_server_error)
            expect(response.body).to include('Invalid authentication token file path')
          end

          context 'when running in production container' do
            before do
              allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
              allow_next_instance_of(SecretsManagement::TestClient) do |audit_log|
                allow(audit_log).to receive(:log!)
              end
            end

            context 'when omnibus and CNG - the auth token file path starts with /etc/gitlab/' do
              let(:authentication_token_file_path) { '/etc/gitlab/.gitlab_openbao_authentication_token_secret_path' }

              it 'does NOT raise invalid authentication token file path error' do
                expect { make_request }.not_to raise_error
              end
            end

            context 'when self complied instalaltions - the auth token file path starts with Rails root' do
              let(:authentication_token_file_path) do
                Rails.root.join('random_path_inside_rails_root')
              end

              it 'does NOT raise invalid authentication token file path error' do
                expect { make_request }.not_to raise_error
              end
            end

            context 'when the auth token path does NOT start with /etc/gitlab/' do
              let(:authentication_token_file_path) do
                '/not_etc/gitlab/.gitlab_openbao_authentication_token_secret_path'
              end

              it 'raises invalid authentication token file path error' do
                expect(Gitlab::ErrorTracking).to receive(:track_exception).with(having_attributes(
                  class: RuntimeError,
                  message: "Invalid authentication token file path"
                ))

                make_request
              end
            end
          end
        end
      end
    end

    context 'when payload size exceeds limit' do
      it 'returns bad request status' do
        allow_next_instance_of(Grape::Request) do |request|
          allow(request).to receive(:content_length).and_return(1.megabyte + 1)
        end

        make_request

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end
  end
end

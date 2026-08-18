# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::SecretPushProtection::ResponseHandler, feature_category: :secret_detection do
  include_context 'secrets check context'

  subject(:response_handler) do
    described_class.new(
      project: project,
      changes_access: changes_access
    )
  end

  describe '#format_response' do
    context 'when response status is NOT_FOUND' do
      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::NOT_FOUND,
          results: []
        )
      end

      it 'logs secrets not found message and does not raise error' do
        expect { response_handler.format_response(response, {}) }.not_to raise_error

        expect(logged_messages[:info]).to include(
          hash_including(
            "message" => log_messages[:secrets_not_found],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end

      it 'triggers internal events and increment usage metrics' do
        expect { response_handler.format_response(response, {}) }
          .to trigger_internal_events('spp_scan_passed')
          .with(
            user: user,
            project: project,
            namespace: project.namespace,
            category: 'Gitlab::Checks::SecretPushProtection::AuditLogger'
          )
          .and increment_usage_metrics('counts.count_total_spp_scan_passed')
      end
    end

    context 'when response status is FOUND' do
      let(:finding) do
        ::Gitlab::SecretDetection::Core::Finding.new(
          blob_2_reference,
          ::Gitlab::SecretDetection::Core::Status::FOUND,
          1,
          "gitlab_personal_access_token",
          "GitLab personal access token"
        )
      end

      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::FOUND,
          results: [finding]
        )
      end

      let(:changed_path) do
        Gitlab::Git::ChangedPath.new(
          path: ".env",
          status: :ADDED,
          new_blob_id: blob_2_reference,
          commit_id: new_commit,
          old_path: ".env",
          old_blob_id: '0000000000000000000000000000000000000000',
          old_mode: '000000',
          new_mode: '100644'
        )
      end

      let(:lookup_map) do
        {
          blob_2_reference => [
            {
              commit_id: changed_path.commit_id,
              path: changed_path.path
            }
          ]
        }
      end

      it 'triggers internal events and increment usage metrics' do
        expect { response_handler.format_response(response, lookup_map) }
          .to trigger_internal_events('spp_push_blocked_secrets_found')
          .with(
            user: user,
            project: project,
            namespace: project.namespace,
            category: 'Gitlab::Checks::SecretPushProtection::AuditLogger',
            additional_properties: {
              value: response.results.size
            }
          )
          .and increment_usage_metrics('counts.count_total_spp_push_blocked_secrets_found')
          .and raise_error(::Gitlab::GitAccess::ForbiddenError)
      end

      it 'raises ForbiddenError with findings details and logs found secrets' do
        expect { response_handler.format_response(response, lookup_map) }
          .to raise_error(::Gitlab::GitAccess::ForbiddenError) do |error|
            expect(error.message).to include(log_messages[:found_secrets])
            expect(error.message).to include(log_messages[:found_secrets_post_message])
            expect(error.message).to include(log_messages[:skip_secret_detection])
            expect(error.message).to include(new_commit)
            expect(error.message).to include(".env")
            expect(error.message).to include("GitLab personal access token")
          end

        expect(logged_messages[:info]).to include(
          hash_including(
            "message" => log_messages[:found_secrets],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end

      it 'tracks findings in audit logger' do
        expect { response_handler.format_response(response, lookup_map) }
          .to trigger_internal_events('detect_secret_type_on_push')
          .with(
            user: user,
            project: project,
            namespace: project.namespace,
            category: 'Gitlab::Checks::SecretPushProtection::AuditLogger',
            additional_properties: {
              label: "GitLab personal access token"
            }
          )
          .and increment_usage_metrics('counts.count_total_detect_secret_type_on_push_monthly')
          .and raise_error(::Gitlab::GitAccess::ForbiddenError)
      end
    end

    context 'when response status is FOUND_WITH_ERRORS' do
      let(:finding) do
        ::Gitlab::SecretDetection::Core::Finding.new(
          blob_2_reference,
          ::Gitlab::SecretDetection::Core::Status::FOUND,
          1,
          "gitlab_personal_access_token",
          "GitLab personal access token"
        )
      end

      let(:error_finding) do
        ::Gitlab::SecretDetection::Core::Finding.new(
          "some_error_blob",
          ::Gitlab::SecretDetection::Core::Status::SCAN_ERROR
        )
      end

      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::FOUND_WITH_ERRORS,
          results: [finding, error_finding]
        )
      end

      let(:changed_path_1) do
        Gitlab::Git::ChangedPath.new(
          path: ".env",
          status: :ADDED,
          new_blob_id: blob_2_reference,
          commit_id: new_commit,
          old_path: ".env",
          old_blob_id: '0000000000000000000000000000000000000000',
          old_mode: '000000',
          new_mode: '100644'
        )
      end

      let(:changed_path_2) do
        Gitlab::Git::ChangedPath.new(
          path: "to_modify.txt",
          status: :MODIFIED,
          new_blob_id: blob_4_reference,
          commit_id: new_commit,
          old_path: "to_modify.txt",
          old_blob_id: '0000000000000000000000000000000000000000',
          old_mode: '100644',
          new_mode: '100644'
        )
      end

      let(:lookup_map) do
        {
          blob_2_reference => [
            {
              commit_id: changed_path_1.commit_id,
              path: changed_path_1.path
            },
            {
              commit_id: changed_path_2.commit_id,
              path: changed_path_2.path
            }
          ]
        }
      end

      it 'triggers internal events and increment usage metrics' do
        expect { response_handler.format_response(response, lookup_map) }
          .to trigger_internal_events('spp_push_blocked_secrets_found_with_errors')
          .with(
            user: user,
            project: project,
            namespace: project.namespace,
            category: 'Gitlab::Checks::SecretPushProtection::AuditLogger',
            additional_properties: {
              value: response.results.size
            }
          )
          .and increment_usage_metrics('counts.count_total_spp_push_blocked_secrets_found_with_errors')
          .and raise_error(::Gitlab::GitAccess::ForbiddenError)
      end

      it 'raises ForbiddenError with errors message and logs found secrets with errors' do
        expect { response_handler.format_response(response, lookup_map) }
          .to raise_error(::Gitlab::GitAccess::ForbiddenError) do |error|
            expect(error.message).to include(log_messages[:found_secrets_with_errors])
            expect(error.message).to include(log_messages[:found_secrets_post_message])
            expect(error.message).to include(new_commit)
            expect(error.message).to include(".env")
            expect(error.message).to include("Failed to scan blob(id: some_error_blob) due to regex error.")
          end

        expect(logged_messages[:info]).to include(
          hash_including(
            "message" => log_messages[:found_secrets_with_errors],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end
    end

    context 'when response has timeout findings' do
      let(:timeout_finding) do
        ::Gitlab::SecretDetection::Core::Finding.new(
          "some_timeout_blob",
          ::Gitlab::SecretDetection::Core::Status::PAYLOAD_TIMEOUT
        )
      end

      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::FOUND_WITH_ERRORS,
          results: [timeout_finding]
        )
      end

      it 'includes timeout error messages in the error details' do
        expect { response_handler.format_response(response, {}) }
          .to raise_error(::Gitlab::GitAccess::ForbiddenError) do |error|
            expect(error.message).to include(format(error_messages[:blob_timed_out_error],
              payload_id: "some_timeout_blob"))
          end
      end
    end

    context 'when response status is SCAN_TIMEOUT' do
      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::SCAN_TIMEOUT,
          results: []
        )
      end

      it 'logs scan timeout error and does not raise error' do
        expect { response_handler.format_response(response, {}) }.not_to raise_error

        expect(logged_messages[:error]).to include(
          hash_including(
            "message" => error_messages[:scan_timeout_error],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end

      it 'logs scan timeout audit event' do
        expect(response_handler.audit_logger).to receive(:log_spp_scan_timeout)

        response_handler.format_response(response, {})
      end
    end

    context 'when response status is INPUT_ERROR' do
      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::INPUT_ERROR,
          results: []
        )
      end

      it 'logs invalid input error and does not raise error' do
        expect { response_handler.format_response(response, {}) }.not_to raise_error

        expect(logged_messages[:error]).to include(
          hash_including(
            "message" => error_messages[:invalid_input_error],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end

      it 'logs the invalid input audit event' do
        expect(response_handler.audit_logger).to receive(:log_spp_invalid_input)

        response_handler.format_response(response, {})
      end
    end

    context 'when response status is unknown' do
      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: -1,
          results: []
        )
      end

      it 'logs invalid scan status code error and does not raise error' do
        expect { response_handler.format_response(response, {}) }.not_to raise_error

        expect(logged_messages[:error]).to include(
          hash_including(
            "message" => error_messages[:invalid_scan_status_code_error],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end
    end

    context 'when multiple findings map to the same commit in different files' do
      let(:finding1) do
        ::Gitlab::SecretDetection::Core::Finding.new(
          blob_2_reference,
          ::Gitlab::SecretDetection::Core::Status::FOUND,
          1,
          'desc1',
          'desc1'
        )
      end

      let(:finding2) do
        ::Gitlab::SecretDetection::Core::Finding.new(
          blob_3_reference,
          ::Gitlab::SecretDetection::Core::Status::FOUND,
          2,
          'desc2',
          'desc2'
        )
      end

      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::FOUND,
          results: [finding1, finding2]
        )
      end

      let(:changed_path_1) do
        Gitlab::Git::ChangedPath.new(
          path: ".env",
          status: :ADDED,
          new_blob_id: blob_2_reference,
          commit_id: new_commit,
          old_path: ".env",
          old_blob_id: '0000000000000000000000000000000000000000',
          old_mode: '000000',
          new_mode: '100644'
        )
      end

      let(:changed_path_2) do
        Gitlab::Git::ChangedPath.new(
          path: "to_modify.txt",
          status: :MODIFIED,
          new_blob_id: blob_3_reference,
          commit_id: new_commit,
          old_path: "to_modify.txt",
          old_blob_id: '0000000000000000000000000000000000000000',
          old_mode: '100644',
          new_mode: '100644'
        )
      end

      let(:lookup_map) do
        {
          blob_2_reference => [
            {
              commit_id: changed_path_1.commit_id,
              path: changed_path_1.path
            },
            {
              commit_id: changed_path_2.commit_id,
              path: changed_path_2.path
            }
          ]
        }
      end

      it 'includes findings from all affected files in the error message' do
        expect { response_handler.format_response(response, lookup_map) }
          .to raise_error(::Gitlab::GitAccess::ForbiddenError) do |error|
            expect(error.message).to include('.env')
            expect(error.message).to include('to_modify.txt')
            expect(error.message).to include('desc1')
            expect(error.message).to include('desc2')
            expect(error.message).to include(new_commit)
          end
      end
    end

    context 'when finding does not exist in the payloads path lookup map' do
      let(:unmapped_blob_id) { "unmapped_blob_123" }

      let(:finding) do
        ::Gitlab::SecretDetection::Core::Finding.new(
          unmapped_blob_id,
          ::Gitlab::SecretDetection::Core::Status::FOUND,
          1,
          "gitlab_personal_access_token",
          "GitLab personal access token"
        )
      end

      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::FOUND,
          results: [finding]
        )
      end

      let(:lookup_map) do
        {
          unmapped_blob_id => []
        }
      end

      it 'logs a warning for unmapped blob' do
        expect { response_handler.format_response(response, lookup_map) }
          .to raise_error(::Gitlab::GitAccess::ForbiddenError)

        expect(logged_messages[:warn]).to include(
          hash_including(
            "message" => "Secret Push Protection could not map " \
              "blob #{unmapped_blob_id} to commit and path"
          )
        )
      end

      it 'includes the finding as blob-only in error message' do
        expect { response_handler.format_response(response, lookup_map) }
          .to raise_error(::Gitlab::GitAccess::ForbiddenError) do |error|
            expect(error.message).to include("Secret leaked in blob: #{unmapped_blob_id}")
            expect(error.message).to include("line:1 | GitLab personal access token")
            expect(error.message).not_to include("commit")
          end
      end
    end

    context 'when two files has same content, but one is excluded' do
      let(:finding) do
        ::Gitlab::SecretDetection::Core::Finding.new(
          blob_2_reference,
          ::Gitlab::SecretDetection::Core::Status::FOUND,
          1,
          "gitlab_personal_access_token",
          "Gitlab personal access token"
        )
      end

      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::FOUND,
          results: [finding]
        )
      end

      let(:excluded_path) do
        Gitlab::Git::ChangedPath.new(
          path: ".env",
          status: :ADDED,
          new_blob_id: blob_2_reference,
          commit_id: new_commit,
          old_path: ".env",
          old_blob_id: "0000000000000000000000000000000000000000",
          old_mode: "000000",
          new_mode: "100644"
        )
      end

      let(:non_excluded_path) do
        Gitlab::Git::ChangedPath.new(
          path: "config.yml",
          status: :ADDED,
          new_blob_id: blob_2_reference,
          commit_id: "another_commit_sha",
          old_path: "config.yml",
          old_blob_id: "0000000000000000000000000000000000000000",
          old_mode: "000000",
          new_mode: "100644"
        )
      end

      let(:lookup_map) do
        {
          blob_2_reference => [
            {
              commit_id: excluded_path.commit_id,
              path: excluded_path.path
            }
          ]
        }
      end

      it 'only includes findings from the non-excluded path' do
        expect { response_handler.format_response(response, lookup_map) }
          .to raise_error(::Gitlab::GitAccess::ForbiddenError) do |error|
            expect(error.message).to include(new_commit)
            expect(error.message).to include('.env')
            expect(error.message).not_to include('another_commit_sha')
            expect(error.message).not_to include('config.yml')
          end
      end
    end

    context 'when changed paths has a blank path or commit_id' do
      let(:finding) do
        ::Gitlab::SecretDetection::Core::Finding.new(
          blob_2_reference,
          ::Gitlab::SecretDetection::Core::Status::FOUND,
          1,
          "gitlab_personal_access_token",
          "Gitlab personal access token"
        )
      end

      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::FOUND,
          results: [finding]
        )
      end

      let(:blank_path_changed_path) do
        Gitlab::Git::ChangedPath.new(
          path: '',
          status: :ADDED,
          new_blob_id: blob_2_reference,
          commit_id: new_commit,
          old_path: '',
          old_blob_id: '0000000000000000000000000000000000000000',
          old_mode: '000000',
          new_mode: '100644'
        )
      end

      let(:blank_commit_changed_path) do
        Gitlab::Git::ChangedPath.new(
          path: 'config.yml',
          status: :ADDED,
          new_blob_id: blob_2_reference,
          commit_id: '',
          old_path: 'config/secrets.yml',
          old_blob_id: '0000000000000000000000000000000000000000',
          old_mode: '000000',
          new_mode: '100644'
        )
      end

      let(:valid_changed_path) do
        Gitlab::Git::ChangedPath.new(
          path: '.env',
          status: :ADDED,
          new_blob_id: blob_2_reference,
          commit_id: new_commit,
          old_path: '.env',
          old_blob_id: '0000000000000000000000000000000000000000',
          old_mode: '000000',
          new_mode: '100644'
        )
      end

      let(:lookup_map) do
        {
          blob_2_reference => [
            {
              commit_id: blank_path_changed_path.commit_id,
              path: blank_path_changed_path.path
            },
            {
              commit_id: blank_commit_changed_path.commit_id,
              path: blank_commit_changed_path.path
            },
            {
              commit_id: valid_changed_path.commit_id,
              path: valid_changed_path.path
            }
          ]
        }
      end

      it 'skips blank entries and only uses valid metadata' do
        expect { response_handler.format_response(response, lookup_map) }
          .to raise_error(::Gitlab::GitAccess::ForbiddenError) do |error|
            expect(error.message).to include(new_commit)
            expect(error.message).to include('.env')
            expect(error.message).to include('Gitlab personal access token')
            expect(error.message).not_to include("\n-- :") # blank path
            expect(error.message).not_to include('config.yml') # blank commit
          end
      end

      context 'when changed paths are all invalid (blank path or commit)' do
        let(:lookup_map) do
          {
            blob_2_reference => [
              {
                commit_id: blank_path_changed_path.commit_id,
                path: blank_path_changed_path.path
              },
              {
                commit_id: blank_commit_changed_path.commit_id,
                path: blank_commit_changed_path.path
              }
            ]
          }
        end

        it 'removes the finding and changes status to NOT_FOUND' do
          expect { response_handler.format_response(response, lookup_map) }.not_to raise_error

          expect(logged_messages[:info]).to include(
            hash_including(
              "message" => log_messages[:secrets_not_found],
              "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
            )
          )
        end
      end
    end

    context 'when same content appears in multiple different commits' do
      let(:finding) do
        ::Gitlab::SecretDetection::Core::Finding.new(
          blob_2_reference,
          ::Gitlab::SecretDetection::Core::Status::FOUND,
          1,
          "gitlab_personal_access_token",
          "Gitlab personal access token"
        )
      end

      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::FOUND,
          results: [finding]
        )
      end

      let(:commit_1_path) do
        Gitlab::Git::ChangedPath.new(
          path: ".env",
          status: :ADDED,
          new_blob_id: blob_2_reference,
          commit_id: new_commit,
          old_path: ".env",
          old_blob_id: '0000000000000000000000000000000000000000',
          old_mode: '000000',
          new_mode: '100644'
        )
      end

      let(:commit_2_path) do
        Gitlab::Git::ChangedPath.new(
          path: ".env",
          status: :ADDED,
          new_blob_id: blob_2_reference,
          commit_id: 'different_commit',
          old_path: ".env",
          old_blob_id: '0000000000000000000000000000000000000000',
          old_mode: '000000',
          new_mode: '100644'
        )
      end

      let(:lookup_map) do
        {
          blob_2_reference => [
            {
              commit_id: commit_1_path.commit_id,
              path: commit_1_path.path
            },
            {
              commit_id: commit_2_path.commit_id,
              path: commit_2_path.path
            }
          ]
        }
      end

      it 'reports the finding under both commits separately' do
        expect { response_handler.format_response(response, lookup_map) }
          .to raise_error(::Gitlab::GitAccess::ForbiddenError) do |error|
            expect(error.message).to include(new_commit)
            expect(error.message).to include('different_commit')
            expect(error.message).to include('.env')
            expect(error.message).to include('Gitlab personal access token')
          end
      end
    end
  end

  describe '#timed_out?' do
    context 'when response has SCAN_ERROR status with Deadline Exceeded message' do
      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::SCAN_ERROR,
          metadata: { message: "Deadline Exceeded" }
        )
      end

      it { expect(response_handler.timed_out?(response)).to be true }
    end

    context 'when response has SCAN_ERROR status with different message' do
      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::SCAN_ERROR,
          metadata: { message: "Some other error" }
        )
      end

      it { expect(response_handler.timed_out?(response)).to be false }
    end

    context 'when response has SCAN_ERROR status with no metadata' do
      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::SCAN_ERROR,
          metadata: nil
        )
      end

      it { expect(response_handler.timed_out?(response)).to be false }
    end

    context 'when response has different status' do
      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::NOT_FOUND
        )
      end

      it { expect(response_handler.timed_out?(response)).to be false }
    end

    context 'when response has SCAN_ERROR status but no metadata' do
      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::SCAN_ERROR
        )
      end

      it { expect(response_handler.timed_out?(response)).to be false }
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::SecretPushProtection::SecretsCheck, feature_category: :secret_detection do
  include_context 'secrets check context'

  subject(:secrets_check) { described_class.new(changes_access) }

  let(:correlation_id) { 'test-correlation-id-123' }

  before do
    allow(Labkit::Correlation::CorrelationId).to receive(:current_id).and_return(correlation_id)
  end

  describe '#validate!' do
    context 'when application setting is disabled' do
      before do
        Gitlab::CurrentSettings.update!(secret_push_protection_available: false)
      end

      it_behaves_like 'skips the push check'
    end

    context 'when application setting is enabled' do
      before do
        Gitlab::CurrentSettings.update!(secret_push_protection_available: true)
      end

      context 'when project is private' do
        before do
          project.update!(visibility_level: Project::PRIVATE)
        end

        context 'when project has not opted in to SPP' do
          before do
            project.security_setting.update!(secret_push_protection_enabled: false)
          end

          it_behaves_like 'does not call SDS'
          it_behaves_like 'skips the push check'
        end

        context 'when project has opted in to SPP' do
          before do
            project.security_setting.update!(secret_push_protection_enabled: true)
          end

          context 'when project does not have feature license' do
            before do
              stub_licensed_features(secret_push_protection: false)
            end

            it_behaves_like 'does not call SDS'
            it_behaves_like 'skips the push check'
          end

          context 'when project does have feature license (ultimate)' do
            before do
              stub_licensed_features(secret_push_protection: true)
            end

            it_behaves_like 'diff scan passed'
            it_behaves_like 'scan detected secrets in diffs'
            it_behaves_like 'detects secrets with special characters in diffs'
            it_behaves_like 'processes hunk headers'
            it_behaves_like 'scan detected secrets but some errors occured'
            it_behaves_like 'scan timed out'
            it_behaves_like 'scan failed to initialize'
            it_behaves_like 'scan failed with invalid input'
            it_behaves_like 'scan skipped due to invalid status'
            it_behaves_like 'scan skipped when a commit has special bypass flag'
            it_behaves_like 'scan skipped when secret_push_protection.skip_all push option is passed'
            it_behaves_like 'scan discarded secrets because they match exclusions'

            # testing `secret_detection_transition_to_raw_info_gitaly_endpoint` FF (enabled by default in specs)
            it 'tracks and recovers errors when getting diff' do
              expect(repository).to receive(:diff_blobs_with_raw_info).and_raise(::GRPC::InvalidArgument)
              expect(::Gitlab::ErrorTracking).to receive(:track_exception)
                .with(instance_of(::GRPC::InvalidArgument))
              expect(secret_detection_logger).to receive(:error)
                .once
                .with(a_string_starting_with("diff_blobs_with_raw_info Gitaly call failed with args:"))

              allow(secret_detection_logger).to receive(:info)
              expect { secrets_check.validate! }.not_to raise_error
            end

            describe 'logging duration of run_validation!' do
              let(:start_time) { 100.0 }
              let(:end_time) { 102.5 }
              let(:expected_duration) { 2.5 }

              before do
                allow_next_instance_of(Gitlab::Checks::SecretPushProtection::EligibilityChecker) do |checker|
                  allow(checker).to receive(:should_scan?).and_return(true)
                end
                allow(Gitlab::Metrics::System).to receive(:monotonic_time).and_return(start_time, end_time)
                allow_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |processor|
                  allow(processor).to receive(:standardize_payloads).and_return(nil)
                end
              end

              it 'logs the duration when validation completes successfully' do
                expect_next_instance_of(Gitlab::Checks::SecretPushProtection::AuditLogger) do |logger|
                  expect(logger).to receive(:track_spp_execution_time_in_seconds).with(expected_duration)
                end

                secrets_check.validate!

                expect(logged_messages[:info]).to include(
                  hash_including(
                    'message' => 'Secret push protection validation completed',
                    'method' => 'run_validation!',
                    'duration_s' => expected_duration
                  )
                )
              end
            end

            context 'when secret_detection_transition_to_raw_info_gitaly_endpoint is disabled' do
              before do
                stub_feature_flags(secret_detection_transition_to_raw_info_gitaly_endpoint: false)
              end

              it 'tracks and recovers errors when getting diff' do
                expect(repository).to receive(:diff_blobs).and_raise(::GRPC::InvalidArgument)
                expect(::Gitlab::ErrorTracking).to receive(:track_exception)
                  .with(instance_of(::GRPC::InvalidArgument))

                allow(secret_detection_logger).to receive(:info)
                expect { secrets_check.validate! }.not_to raise_error
              end
            end

            context 'when payload processor returns nil' do
              before do
                allow_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |processor|
                  allow(processor).to receive(:standardize_payloads).and_return(nil)
                end
              end

              it_behaves_like 'does not call SDS'
              it_behaves_like 'skips the push check'
            end

            context 'when StandardError is raised during scanning' do
              before do
                allow_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |instance|
                  allow(instance).to receive(:standardize_payloads).and_raise(StandardError,
                    'Unexpected error during payload processing')
                end
              end

              it 'adds a warning message to be displayed to the user' do
                warning_instance = instance_double(Gitlab::Checks::SecretPushProtection::PostPushWarning)

                expect(Gitlab::Checks::SecretPushProtection::PostPushWarning)
                  .to receive(:new)
                  .with(project.repository, user, changes_access.protocol)
                  .and_return(warning_instance)

                expect(warning_instance).to receive(:add_message)

                expect { secrets_check.validate! }.not_to raise_error
              end

              it 'tracks the exception in telemetry' do
                expect_next_instance_of(Gitlab::Checks::SecretPushProtection::AuditLogger) do |logger|
                  expect(logger).to receive(:track_spp_standard_error_exception).with('StandardError')
                end

                allow_next_instance_of(Gitlab::Checks::SecretPushProtection::PostPushWarning) do |instance|
                  allow(instance).to receive(:add_message)
                end

                expect { secrets_check.validate! }.not_to raise_error
              end

              it 'calls the audit logger for generic scan errors' do
                expect_next_instance_of(Gitlab::Checks::SecretPushProtection::AuditLogger) do |logger|
                  expect(logger).to receive(:log_spp_generic_scan_error)
                end

                expect { secrets_check.validate! }.not_to raise_error
              end
            end

            context 'when TooManyChangedPathsError is raised during scanning' do
              let(:changed_paths_count) { 1500 }
              let(:threshold) { 1000 }
              let(:too_many_paths_error) do
                Gitlab::Checks::SecretPushProtection::TooManyChangedPathsError.new(changed_paths_count, threshold)
              end

              before do
                allow_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |instance|
                  allow(instance).to receive(:standardize_payloads).and_raise(too_many_paths_error)
                end
              end

              it 'adds a warning message to be displayed to the user' do
                warning_instance = instance_double(Gitlab::Checks::SecretPushProtection::PostPushWarning)

                expect(Gitlab::Checks::SecretPushProtection::PostPushWarning)
                  .to receive(:new)
                  .with(project.repository, user, changes_access.protocol, changed_paths_count, threshold)
                  .and_return(warning_instance)

                expect(warning_instance).to receive(:add_message)

                expect { secrets_check.validate! }.not_to raise_error
              end

              it 'emits an audit event' do
                expect_next_instance_of(Gitlab::Checks::SecretPushProtection::AuditLogger) do |logger|
                  expect(logger).to receive(:log_spp_too_many_changed_paths)
                    .with(changed_paths_count, threshold)
                end

                allow_next_instance_of(Gitlab::Checks::SecretPushProtection::PostPushWarning) do |instance|
                  allow(instance).to receive(:add_message)
                end

                expect { secrets_check.validate! }.not_to raise_error
              end

              it 'tracks the exception in telemetry' do
                expect_next_instance_of(Gitlab::Checks::SecretPushProtection::AuditLogger) do |logger|
                  expect(logger).to receive(:track_spp_too_many_changed_paths_error)
                    .with(too_many_paths_error.message, changed_paths_count)
                end

                allow_next_instance_of(Gitlab::Checks::SecretPushProtection::PostPushWarning) do |instance|
                  allow(instance).to receive(:add_message)
                end

                expect { secrets_check.validate! }.not_to raise_error
              end
            end

            context 'when TooManyLinesError is raised during scanning' do
              let(:lines_count) { 400_000 }
              let(:threshold) { 350_000 }
              let(:too_many_lines_error) do
                Gitlab::Checks::SecretPushProtection::TooManyLinesError.new(lines_count, threshold)
              end

              before do
                allow_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |instance|
                  allow(instance).to receive(:standardize_payloads).and_raise(too_many_lines_error)
                end
              end

              it 'adds a warning message to be displayed to the user' do
                warning_instance = instance_double(Gitlab::Checks::SecretPushProtection::PostPushWarning)

                expect(Gitlab::Checks::SecretPushProtection::PostPushWarning)
                  .to receive(:new)
                  .with(project.repository, user, changes_access.protocol, lines_count, threshold)
                  .and_return(warning_instance)

                expect(warning_instance).to receive(:add_message)

                expect { secrets_check.validate! }.not_to raise_error
              end

              it 'emits an audit event' do
                expect_next_instance_of(Gitlab::Checks::SecretPushProtection::AuditLogger) do |logger|
                  expect(logger).to receive(:log_spp_too_many_lines).with(lines_count, threshold)
                end

                allow_next_instance_of(Gitlab::Checks::SecretPushProtection::PostPushWarning) do |instance|
                  allow(instance).to receive(:add_message)
                end

                expect { secrets_check.validate! }.not_to raise_error
              end

              it 'tracks the exception in telemetry' do
                expect_next_instance_of(Gitlab::Checks::SecretPushProtection::AuditLogger) do |logger|
                  expect(logger).to receive(:track_spp_too_many_lines_error)
                    .with(too_many_lines_error.message, lines_count)
                end

                allow_next_instance_of(Gitlab::Checks::SecretPushProtection::PostPushWarning) do |instance|
                  allow(instance).to receive(:add_message)
                end

                expect { secrets_check.validate! }.not_to raise_error
              end
            end

            context 'when SDS should be called (on SaaS)' do
              before do
                stub_saas_features(secret_detection_service: true)
                stub_application_setting(secret_detection_service_url: 'https://example.com')
              end

              context 'when instance is Dedicated (not using SDS)' do
                before do
                  stub_application_setting(gitlab_dedicated_instance: true)
                end

                it_behaves_like 'skips sending requests to the SDS' do
                  let(:is_dedicated) { true }
                  let(:sds_ff_enabled) { true }
                end
              end

              context 'when instance is GitLab.com' do
                it_behaves_like 'sends requests to the SDS'

                context 'when SDS returns a valid response' do
                  let(:sds_response) do
                    ::Gitlab::SecretDetection::GRPC::ScanResponse.new(
                      status: ::Gitlab::SecretDetection::GRPC::ScanResponse::Status::STATUS_NOT_FOUND,
                      applied_exclusions: []
                    )
                  end

                  it 'uses the SDS response and does not fall back to gem' do
                    expect_next_instance_of(::Gitlab::SecretDetection::GRPC::Client) do |instance|
                      expect(instance).to receive(:run_scan)
                        .and_return(sds_response)
                    end

                    # Should NOT call the gem scanner
                    expect(::Gitlab::SecretDetection::Core::Scanner).not_to receive(:new)

                    # Should pass the SDS response to the response handler
                    expect_next_instance_of(Gitlab::Checks::SecretPushProtection::ResponseHandler) do |handler|
                      expect(handler).to receive(:format_response).with(sds_response, kind_of(Hash))
                    end

                    secrets_check.validate!
                  end
                end

                context 'when SDS fails and returns nil' do
                  it 'logs error and falls back to gem' do
                    expect_next_instance_of(::Gitlab::SecretDetection::GRPC::Client) do |instance|
                      expect(instance).to(
                        receive(:run_scan).and_raise(::GRPC::Unauthenticated,
                          "Expected error")
                      )
                    end

                    expect { secrets_check.validate! }.not_to raise_error

                    expect(logged_messages[:warn]).to include(
                      hash_including(
                        "message" => ::Gitlab::Checks::SecretPushProtection::SecretsCheck::ERROR_MESSAGES[:sds_timeout],
                        "class" => "Gitlab::Checks::SecretPushProtection::SecretsCheck"
                      )
                    )
                  end

                  it 'falls back to gem when response is nil' do
                    expect_next_instance_of(::Gitlab::SecretDetection::GRPC::Client) do |instance|
                      expect(instance).to receive(:run_scan).and_return(nil)
                    end

                    expect_next_instance_of(::Gitlab::SecretDetection::Core::Scanner) do |scanner|
                      expect(scanner).to receive(:secrets_scan).and_call_original
                    end

                    expect { secrets_check.validate! }.not_to raise_error

                    expect(logged_messages[:warn]).to include(
                      hash_including(
                        "message" => ::Gitlab::Checks::SecretPushProtection::SecretsCheck::ERROR_MESSAGES[:sds_timeout],
                        "class" => "Gitlab::Checks::SecretPushProtection::SecretsCheck"
                      )
                    )
                  end
                end

                context 'when SDS times out' do
                  it 'falls back to gem' do
                    timeout_response = ::Gitlab::SecretDetection::Core::Response.new(
                      status: ::Gitlab::SecretDetection::Core::Status::SCAN_ERROR,
                      metadata: { message: "Deadline Exceeded" }
                    )

                    expect_next_instance_of(::Gitlab::SecretDetection::GRPC::Client) do |instance|
                      expect(instance).to receive(:run_scan).and_return(timeout_response)
                    end

                    expect_next_instance_of(::Gitlab::SecretDetection::Core::Scanner) do |scanner|
                      expect(scanner).to receive(:secrets_scan).and_call_original
                    end

                    expect { secrets_check.validate! }.not_to raise_error

                    expect(logged_messages[:warn]).to include(
                      hash_including(
                        "message" => ::Gitlab::Checks::SecretPushProtection::SecretsCheck::ERROR_MESSAGES[:sds_timeout],
                        "class" => "Gitlab::Checks::SecretPushProtection::SecretsCheck"
                      )
                    )
                  end
                end

                context 'when `use_secret_detection_service` feature flag is disabled' do
                  it_behaves_like 'skips sending requests to the SDS' do
                    before do
                      stub_feature_flags(use_secret_detection_service: false)
                    end
                  end
                end
              end
            end

            context 'when SDS should not be called (Self-Managed)' do
              it_behaves_like 'skips sending requests to the SDS' do
                let(:saas_feature_enabled) { false }
                let(:sds_ff_enabled) { true }
              end
            end

            context 'when deleting the branch' do
              # We instantiate the described class with delete_changes_access object to ensure
              # this spec example works as it uses repository.blank_ref to denote a branch deletion.
              subject(:secrets_check) { described_class.new(delete_changes_access) }

              it_behaves_like 'skips the push check'
            end

            context 'when the protocol is web' do
              subject(:secrets_check) { described_class.new(changes_access_web) }

              context 'when changes_access.gitaly_context enable_secrets_check is false' do
                it_behaves_like 'skips the push check'
              end

              context 'when changes_access.gitaly_context enable_secrets_check is true' do
                subject(:secrets_check) { described_class.new(changes_access_web_secrets_check_enabled) }

                it_behaves_like 'diff scan passed'
                it_behaves_like 'scan detected secrets in diffs'
                it_behaves_like 'detects secrets with special characters in diffs'
              end
            end
          end
        end
      end

      context 'when project is public' do
        before do
          project.update!(visibility_level: Project::PUBLIC)
        end

        context 'when project has opted in to SPP' do
          before do
            project.security_setting.update!(secret_push_protection_enabled: true)
          end

          context 'when project does not have feature license' do
            before do
              stub_licensed_features(secret_push_protection: false)
            end

            it_behaves_like 'calls SDS'
            it_behaves_like 'skips the push check'
          end

          context 'when project does have feature license' do
            before do
              Gitlab::CurrentSettings.update!(secret_push_protection_available: true)
              stub_licensed_features(secret_push_protection: true)
            end

            it_behaves_like 'diff scan passed'
          end
        end

        context 'when project has not opted in to SPP' do
          before do
            project.security_setting.update!(secret_push_protection_enabled: false)
          end

          it 'does not call run_validation!' do
            expect(secrets_check).not_to receive(:run_validation!)

            secrets_check.validate!
          end

          context 'when payload processor returns nil' do
            before do
              allow_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |instance|
                allow(instance).to receive(:standardize_payloads).and_return(nil)
              end
            end

            it_behaves_like 'does not call SDS'
            it_behaves_like 'skips the push check'
          end

          context 'when project does not have feature license' do
            let(:expected_extra_headers) { { 'x-correlation-id': correlation_id, 'x-request-type': 'dark-launch' } }

            before do
              stub_licensed_features(secret_push_protection: false)
            end

            it_behaves_like 'calls SDS'
            it_behaves_like 'skips the push check'

            describe 'logging duration' do
              let(:start_time) { 100.0 }
              let(:end_time) { 102.5 }
              let(:expected_duration) { 2.5 }

              before do
                allow(Gitlab::Metrics::System).to receive(:monotonic_time).and_return(start_time, end_time)
                allow_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |processor|
                  allow(processor).to receive(:standardize_payloads).and_return(nil)
                end
              end

              it 'logs the duration when validation completes successfully' do
                expect_next_instance_of(Gitlab::Checks::SecretPushProtection::AuditLogger) do |logger|
                  expect(logger).to receive(:track_spp_execution_time_in_seconds).with(expected_duration)
                end

                secrets_check.validate!

                expect(logged_messages[:info]).to include(
                  hash_including(
                    'message' => 'Secret push protection validation completed',
                    'method' => 'run_validation_dark_launch!',
                    'duration_s' => expected_duration
                  )
                )
              end
            end

            context 'when unexpected exceptions are raised' do
              where(:method_name, :target_class, :exception, :exception_msg) do
                [
                  [:send_request_to_sds, Gitlab::Checks::SecretPushProtection::SecretDetectionServiceClient,
                    StandardError, 'Unexpected error'],
                  [:standardize_payloads, Gitlab::Checks::SecretPushProtection::PayloadProcessor, GRPC::Internal,
                    'waiting for git-diff-pairs: exit status 128']
                ]
              end

              with_them do
                it "logs the error" do
                  allow_next_instance_of(target_class) do |instance|
                    allow(instance).to receive(method_name).and_raise(exception, exception_msg)
                  end

                  expect(::Gitlab::ErrorTracking).to receive(:track_exception)
                    .with(instance_of(exception))
                  expect(secret_detection_logger).to receive(:error)
                      .once
                      .with(
                        hash_including(
                          "message" => include('Secret push protection failed:'),
                          'class' => 'Gitlab::Checks::SecretPushProtection::SecretsCheck',
                          'error_class' => exception.to_s
                        )
                      )
                  expect { secrets_check.validate! }.not_to raise_error
                end
              end
            end
          end

          context 'when project does have feature license' do
            before do
              stub_licensed_features(secret_push_protection: true)
            end

            it_behaves_like 'calls SDS'
            it_behaves_like 'skips the push check'
          end
        end
      end

      # The two contexts above are in fact testing the `secret_detection_enable_spp_for_public_projects`
      # feature flag since all FFs are enabled by default in specs. When the flag is removed, please
      # remember to remove the context below.

      context 'when secret_detection_enable_spp_for_public_projects is disabled' do
        before do
          stub_feature_flags(secret_detection_enable_spp_for_public_projects: false)
        end

        context 'when project is public' do
          before do
            project.update!(visibility_level: Project::PUBLIC)
          end

          context 'when project does not have feature license' do
            before do
              stub_licensed_features(secret_push_protection: false)
            end

            it_behaves_like 'does not call SDS'
          end
        end
      end
    end
  end
end

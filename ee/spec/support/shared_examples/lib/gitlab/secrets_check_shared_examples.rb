# frozen_string_literal: true

RSpec.shared_examples 'calls SDS' do
  include_context 'secrets check context'
  it 'calls SDS' do
    expect_next_instance_of(Gitlab::Checks::SecretPushProtection::SecretDetectionServiceClient) do |instance|
      expectation = expect(instance).to receive(:send_request_to_sds)

      if defined?(expected_extra_headers) && expected_extra_headers
        expectation.with(anything, hash_including(extra_headers: hash_including(expected_extra_headers)))
      end
    end

    secrets_check.validate!
  end
end

RSpec.shared_examples 'does not call SDS' do
  include_context 'secrets check context'
  it 'does not call SDS' do
    expect(Gitlab::Checks::SecretPushProtection::SecretDetectionServiceClient).not_to receive(:new)

    secrets_check.validate!
  end
end

RSpec.shared_examples 'skips the push check' do
  include_context 'secrets check context'
  it "does not call format_response on the next instance" do
    expect(Gitlab::Checks::SecretPushProtection::ResponseHandler).not_to receive(:new)

    secrets_check.validate!
  end
end

RSpec.shared_examples 'skips sending requests to the SDS' do
  include_context 'secrets check context'

  it 'does not create the SDS client' do
    expect(::Gitlab::SecretDetection::GRPC::Client).not_to receive(:new)
    msg = format(::Gitlab::Checks::SecretPushProtection::SecretDetectionServiceClient::LOG_MESSAGES[:sds_disabled],
      {
        sds_ff_enabled: sds_ff_enabled,
        saas_feature_enabled: saas_feature_enabled,
        is_not_dedicated: !is_dedicated
      })

    expect { subject.validate! }.not_to raise_error

    expect(logged_messages[:info]).to include(
      hash_including(
        "message" => msg,
        "class" => "Gitlab::Checks::SecretPushProtection::SecretDetectionServiceClient"
      ),
      hash_including(
        "message" => log_messages[:secrets_not_found],
        "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
      )
    )
  end
end

RSpec.shared_examples 'sends requests to the SDS' do
  include_context 'secrets check context'

  describe '#send_request_to_sds' do
    it 'without exclusions' do
      expect_next_instance_of(::Gitlab::SecretDetection::GRPC::Client) do |instance|
        expect(instance).to receive(:run_scan)
      end

      expect { subject.validate! }.not_to raise_error

      expect(logged_messages[:info]).to include(
        hash_including(
          "message" => log_messages[:secrets_not_found],
          "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
        )
      )
    end

    context 'with exclusions' do
      let(:payload) do
        ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
          id: 'da66bef46dbf0ad7fdcbeec97c9eaa24c2846dda',
          data: 'BASE_URL=https://foo.bar',
          offset: 1,
          timeout_secs: ::Gitlab::SecretDetection::GRPC::Client::REQUEST_TIMEOUT_SECONDS
        )
      end

      let(:payload1) do
        ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
          id: 'ed426f4235de33f1e5b539100c53e0002e143e3f',
          data: 'VAR=new',
          offset: 1
        )
      end

      let(:exclusion) do
        ::Gitlab::SecretDetection::GRPC::Exclusion.new(
          exclusion_type: ::Gitlab::SecretDetection::GRPC::ExclusionType::EXCLUSION_TYPE_PATH,
          value: 'file-exclusion-1.rb'
        )
      end

      let(:expected_request) do
        ::Gitlab::SecretDetection::GRPC::ScanRequest.new(
          payloads: [payload, payload1],
          exclusions: [exclusion],
          tags: []
        )
      end

      before do
        create(:project_security_exclusion, :active, :with_path, project: project, value: "file-exclusion-1.rb")
      end

      it 'includes them in the request' do
        expect_next_instance_of(::Gitlab::SecretDetection::GRPC::Client) do |instance|
          expect(instance).to receive(:run_scan).with(request: match(expected_request), auth_token: nil,
            extra_headers: { "x-correlation-id": correlation_id }).and_return(
              ::Gitlab::SecretDetection::GRPC::ScanResponse.new(
                status: ::Gitlab::SecretDetection::GRPC::ScanResponse::Status::STATUS_NOT_FOUND,
                applied_exclusions: [exclusion]
              )
            )
        end

        expect { subject.validate! }.not_to raise_error

        expect(logged_messages[:info]).to include(
          hash_including(
            "message" => log_messages[:secrets_not_found],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end
    end
  end

  context 'when errors are raised' do
    context 'when creating a new instance' do
      it 'catches and logs' do
        expect(::Gitlab::SecretDetection::GRPC::Client).to(
          receive(:new).and_raise(::GRPC::Unauthenticated, "Expected error")
        )

        expect(::Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(::GRPC::Unauthenticated))

        expect { subject.validate! }.not_to raise_error

        expect(logged_messages[:info]).to include(
          hash_including(
            "message" => log_messages[:secrets_not_found],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end
    end

    context 'when calling #run_scan' do
      it 'catches and logs' do
        expect_next_instance_of(::Gitlab::SecretDetection::GRPC::Client) do |instance|
          expect(instance).to(
            receive(:run_scan).and_raise(::GRPC::Unauthenticated, "Expected error")
          )
        end

        expect(::Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(::GRPC::Unauthenticated))

        expect { subject.validate! }.not_to raise_error

        expect(logged_messages[:info]).to include(
          hash_including(
            "message" => log_messages[:secrets_not_found],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end
    end
  end
end

RSpec.shared_examples 'diff scan passed' do
  include_context 'secrets check context'

  let(:passed_scan_response) do
    ::Gitlab::SecretDetection::Core::Response.new(
      status: ::Gitlab::SecretDetection::Core::Status::NOT_FOUND
    )
  end

  let(:new_payload) do
    ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
      id: blob_2_reference,
      data: "BASE_URL=https://foo.bar",
      offset: 1
    )
  end

  let(:update_payload) do
    ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
      id: "ed426f4235de33f1e5b539100c53e0002e143e3f",
      data: "VAR=new",
      offset: 1
    )
  end

  let(:diff_blob) do
    ::Gitlab::GitalyClient::DiffBlob.new(
      left_blob_id: ::Gitlab::Git::SHA1_BLANK_SHA,
      right_blob_id: blob_2_reference,
      patch: "@@ -0,0 +1 @@\n+BASE_URL=https://foo.bar\n\\ No newline at end of file\n",
      status: :STATUS_END_OF_PATCH,
      binary: false,
      over_patch_bytes_limit: false
    )
  end

  let(:move_diff_blob) do
    ::Gitlab::GitalyClient::DiffBlob.new(
      left_blob_id: "5d3962935b09208cd00252b050e632c75f9e7d7d",
      right_blob_id: "5d3962935b09208cd00252b050e632c75f9e7d7d",
      patch: "",
      status: :STATUS_END_OF_PATCH,
      binary: false,
      over_patch_bytes_limit: false)
  end

  let(:update_diff_blob) do
    ::Gitlab::GitalyClient::DiffBlob.new(
      left_blob_id: "0d8457bf235000469845078c31d3371cb86209e7",
      right_blob_id: "ed426f4235de33f1e5b539100c53e0002e143e3f",
      patch: "@@ -1 +1 @@\n-VAR=initial\n\\ No newline at end of file\n+VAR=new\n\\ No newline at end of file\n",
      status: :STATUS_END_OF_PATCH,
      binary: false,
      over_patch_bytes_limit: false)
  end

  let(:changed_path_1) do
    Gitlab::Git::ChangedPath.new(
      path: ".env",
      status: :ADDED,
      new_blob_id: blob_2_reference,
      commit_id: new_commit,
      old_path: ".env",
      old_blob_id: '0000000000000000000000000000000000000000',
      old_mode: '0',
      new_mode: '100644'
    )
  end

  it 'gets and parses diffs' do
    expect_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |instance|
      expect(instance).to receive(:get_diffs)
        .at_least(:once)
        .and_call_original

      expect(instance).to receive(:parse_diffs)
        .with(diff_blob)
        .at_least(:once)
        .and_call_original

      expect(instance).to receive(:parse_diffs)
        .with(move_diff_blob)
        .at_least(:once)
        .and_call_original

      expect(instance).to receive(:parse_diffs)
        .with(update_diff_blob)
        .at_least(:once)
        .and_call_original
    end

    expect { subject.validate! }.not_to raise_error

    expect(logged_messages[:info]).to include(
      hash_including(
        "message" => log_messages[:secrets_not_found],
        "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
      )
    )
  end

  it 'scans diffs' do
    expect_next_instance_of(::Gitlab::SecretDetection::Core::Scanner) do |instance|
      expect(instance).to receive(:secrets_scan)
        .with(
          [new_payload, update_payload],
          timeout: kind_of(Float),
          exclusions: kind_of(Hash)
        )
        .once
        .and_call_original
    end

    expect_next_instance_of(Gitlab::Checks::SecretPushProtection::ResponseHandler) do |instance|
      expect(instance).to receive(:format_response)
        .with(passed_scan_response, kind_of(Hash))
        .once
        .and_call_original
    end

    expect { subject.validate! }.not_to raise_error

    expect(logged_messages[:info]).to include(
      hash_including(
        "message" => log_messages[:secrets_not_found],
        "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
      )
    )
  end
end

RSpec.shared_examples 'processes hunk headers' do
  using RSpec::Parameterized::TableSyntax

  let(:hunk_header_regex) { Gitlab::Checks::SecretPushProtection::PayloadProcessor::HUNK_HEADER_REGEX }

  context 'with valid hunk headers' do
    where(:hunk_header, :expected_offset) do
      [
        ['@@ -5 +15 @@', 15],
        ['@@ -0,0 +10 @@', 10],
        ['@@ -45,7 +60,8 @@', 60],
        ['@@ -20 +25 @@ def my_method(args)', 25],
        ['@@ -500,50 +600,55 @@ # comment !@@#$%^&*()', 600],
        ["@@ -10 +15 @@\toptional section heading", 15],
        ['@@ -15 +20 @@    optional section heading', 20]
      ]
    end

    with_them do
      it 'processes valid hunk header with correct offset' do
        hunk_info = hunk_header_regex.match(hunk_header)
        offset = hunk_info[2].to_i

        expect(hunk_header).to match(hunk_header_regex)
        expect(offset).to eq(expected_offset)

        diff_blob = ::Gitlab::GitalyClient::DiffBlob.new(
          left_blob_id: ::Gitlab::Git::SHA1_BLANK_SHA,
          right_blob_id: blob_2_reference,
          patch: "#{hunk_header}\n+BASE_URL=https://foo.bar\n\\ No newline at end of file\n",
          status: :STATUS_END_OF_PATCH,
          binary: false,
          over_patch_bytes_limit: false
        )

        expected_payload = { id: blob_2_reference, data: 'BASE_URL=https://foo.bar', offset: expected_offset }

        expect_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |instance|
          expect(instance).to receive(:get_diffs)
            .once
            .and_return([diff_blob])

          expect(instance).to receive(:parse_diffs).once.and_wrap_original do |m, *args|
            result = m.call(*args)
            expect(result).to eq([expected_payload])
            result
          end
        end

        expect { subject.validate! }.not_to raise_error

        expect(logged_messages[:info]).to include(
          hash_including(
            "message" => log_messages[:secrets_not_found],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end
    end
  end

  context 'with invalid hunk headers' do
    where(:hunk_header) do
      [
        ['@@ -1 +1'],
        ['@@ malformed header @@'],
        ['@@ - + @@ class MyClass'],
        ['@@ -1 + @@'],
        ['@@ -a +b @@'],
        ['@@ -1 +1 +1 @@']
      ]
    end

    with_them do
      it 'does not match invalid hunk header and skips parsing the diff' do
        error_msg = "Could not process hunk header: #{hunk_header.strip}, skipped parsing diff: #{blob_2_reference}"

        diff_blob = ::Gitlab::GitalyClient::DiffBlob.new(
          left_blob_id: ::Gitlab::Git::SHA1_BLANK_SHA,
          right_blob_id: blob_2_reference,
          patch: "#{hunk_header}\n+BASE_URL=https://foo.bar\n\\ No newline at end of file\n",
          status: :STATUS_END_OF_PATCH,
          binary: false,
          over_patch_bytes_limit: false
        )

        expect(hunk_header).not_to match(hunk_header_regex)

        expect_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |instance|
          expect(instance).to receive(:get_diffs)
            .once
            .and_return([diff_blob])
        end

        expect { subject.validate! }.not_to raise_error

        expect(logged_messages[:error]).to include(
          hash_including(
            "message" => error_msg,
            "class" => "Gitlab::Checks::SecretPushProtection::PayloadProcessor"
          )
        )
      end
    end
  end

  context 'with valid and invalid hunk headers' do
    it 'skips parsing the diff and logs an error when an invalid hunk header is present' do
      valid_header = "@@ -1 +1 @@"
      invalid_header = "@@ malformed header @@"
      valid_header2 = "@@ -22,1 +22,1 @@"

      patch = "#{valid_header}\n+line 1\n#{invalid_header}\n+line 2\n#{valid_header2}\n+line 3\n"

      error_msg = "Could not process hunk header: #{invalid_header.strip}, skipped parsing diff: #{blob_2_reference}"

      diff_blob = ::Gitlab::GitalyClient::DiffBlob.new(
        left_blob_id: ::Gitlab::Git::SHA1_BLANK_SHA,
        right_blob_id: blob_2_reference,
        patch: patch,
        status: :STATUS_END_OF_PATCH,
        binary: false,
        over_patch_bytes_limit: false
      )

      expect_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |instance|
        expect(instance).to receive(:get_diffs)
          .once
          .and_return([diff_blob])
      end

      expect { subject.validate! }.not_to raise_error

      expect(logged_messages[:error]).to include(
        hash_including(
          "message" => error_msg,
          "class" => "Gitlab::Checks::SecretPushProtection::PayloadProcessor"
        )
      )
    end
  end
end

RSpec.shared_examples 'scan detected secrets in diffs' do
  include_context 'secrets check context'

  let(:new_payload) do
    ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
      data: "SECRET=glpat-JUST20LETTERSANDNUMB", # gitleaks:allow
      id: blob_5_reference,
      offset: 1
    )
  end

  # The new commit must have a secret, so create a commit with one.
  let_it_be(:new_commit, freeze: false) do
    create_commit('.env' => 'SECRET=glpat-JUST20LETTERSANDNUMB') # gitleaks:allow
  end

  let(:successful_scan_response) do
    ::Gitlab::SecretDetection::Core::Response.new(
      status: ::Gitlab::SecretDetection::Core::Status::FOUND,
      results:
      [
        ::Gitlab::SecretDetection::Core::Finding.new(
          blob_5_reference,
          ::Gitlab::SecretDetection::Core::Status::FOUND,
          1,
          "gitlab_personal_access_token",
          "GitLab personal access token"
        )
      ]
    )
  end

  let(:diff_blob) do
    ::Gitlab::GitalyClient::DiffBlob.new(
      left_blob_id: ::Gitlab::Git::SHA1_BLANK_SHA,
      right_blob_id: blob_5_reference,
      patch: "@@ -0,0 +1 @@\n+SECRET=glpat-JUST20LETTERSANDNUMB\n\\ No newline at end of file\n", # gitleaks:allow
      status: :STATUS_END_OF_PATCH,
      binary: false,
      over_patch_bytes_limit: false
    )
  end

  let(:changed_path_1) do
    Gitlab::Git::ChangedPath.new(
      path: ".env",
      status: :ADDED,
      new_blob_id: blob_5_reference,
      commit_id: new_commit,
      old_path: ".env",
      old_blob_id: '0000000000000000000000000000000000000000',
      old_mode: '0',
      new_mode: '100644'
    )
  end

  let(:lookup_map) do
    {
      blob_5_reference => [
        {
          commit_id: changed_path_1.commit_id,
          path: changed_path_1.path
        }
      ]
    }
  end

  it 'gets and parses diffs' do
    expect_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |instance|
      expect(instance).to receive(:get_diffs)
        .once
        .and_return([diff_blob])
    end

    expect { subject.validate! }.to raise_error(::Gitlab::GitAccess::ForbiddenError)

    expect(logged_messages[:info]).to include(
      hash_including(
        "message" => log_messages[:found_secrets],
        "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
      )
    )
  end

  it 'scans diffs' do
    expect_next_instance_of(::Gitlab::SecretDetection::Core::Scanner) do |instance|
      expect(instance).to receive(:secrets_scan)
        .with(
          [new_payload],
          timeout: kind_of(Float),
          exclusions: kind_of(Hash)
        )
        .once
        .and_return(successful_scan_response)
    end

    expect { subject.validate! }.to raise_error do |error|
      expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
      expect(error.message).to include(
        log_messages[:found_secrets],
        finding_message_header,
        finding_message_path,
        finding_message_occurrence_line,
        log_messages[:found_secrets_post_message],
        found_secrets_docs_link
      )
    end

    expect(logged_messages[:info]).to include(
      hash_including(
        "message" => log_messages[:found_secrets],
        "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
      )
    )
  end

  context 'when multiple hunks exist in a single diff patch leading to multiple payloads' do
    let(:new_payloads) do
      [
        ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
          data: "SECRET=glpat-JUST20LETTERSANDNUMB", # gitleaks:allow
          id: blob_5_reference,
          offset: 1
        ),
        ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
          data: "TOKEN=glpat-JUST20LETTERSANDNUMB", # gitleaks:allow
          id: blob_5_reference,
          offset: 11
        )
      ]
    end

    let(:hunk1) { "@@ -1,0 +1,2 @@\n" }
    let(:newline1) { "+SECRET=glpat-JUST20LETTERSANDNUMB\n" } # gitleaks:allow
    let(:context_line) { " context line\n" }
    let(:hunk2) { "@@ -10,0 +11,1 @@\n" }
    let(:newline2) { "+TOKEN=glpat-JUST20LETTERSANDNUMB\n" } # gitleaks:allow
    let(:no_newline) { "\\ No newline at end of file\n" }

    let(:encounter_hunk_header_patch) do
      "#{hunk1}#{newline1}#{hunk2}#{newline2}#{no_newline}"
    end

    let(:encounter_context_line_patch) do
      "#{hunk1}#{newline1}#{context_line}#{hunk2}#{newline2}#{no_newline}"
    end

    let(:successful_scan_response) do
      ::Gitlab::SecretDetection::Core::Response.new(
        status: ::Gitlab::SecretDetection::Core::Status::FOUND,
        results:
        [
          ::Gitlab::SecretDetection::Core::Finding.new(
            blob_5_reference,
            ::Gitlab::SecretDetection::Core::Status::FOUND,
            1,
            "gitlab_personal_access_token",
            "GitLab personal access token"
          ),
          ::Gitlab::SecretDetection::Core::Finding.new(
            blob_5_reference,
            ::Gitlab::SecretDetection::Core::Status::FOUND,
            11,
            "gitlab_personal_access_token",
            "GitLab personal access token"
          )
        ]
      )
    end

    context 'when encountering a new hunk header' do
      let(:diff_blob) do
        ::Gitlab::GitalyClient::DiffBlob.new(
          left_blob_id: ::Gitlab::Git::SHA1_BLANK_SHA,
          right_blob_id: blob_5_reference,
          patch: encounter_hunk_header_patch,
          status: :STATUS_END_OF_PATCH,
          binary: false,
          over_patch_bytes_limit: false
        )
      end

      it 'gets and parses diffs' do
        expect_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |instance|
          expect(instance).to receive(:get_diffs)
            .once
            .and_return([diff_blob])
        end

        expect { subject.validate! }.to raise_error(::Gitlab::GitAccess::ForbiddenError)

        expect(logged_messages[:info]).to include(
          hash_including(
            "message" => log_messages[:found_secrets],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end

      it 'scans diffs' do
        expect_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |instance|
          expect(instance).to receive(:get_diffs)
            .once
            .and_wrap_original do |_, lookup_map_arg|
              # we pass lookup_map by reference, so need to make sure it's populated
              lookup_map_arg[blob_5_reference] = [
                {
                  commit_id: changed_path_1.commit_id,
                  path: changed_path_1.path
                }
              ]

              [diff_blob]
            end
        end

        expect_next_instance_of(::Gitlab::SecretDetection::Core::Scanner) do |instance|
          expect(instance).to receive(:secrets_scan)
            .with(
              new_payloads,
              timeout: kind_of(Float),
              exclusions: kind_of(Hash)
            )
            .once
            .and_return(successful_scan_response)
        end

        expect { subject.validate! }.to raise_error do |error|
          expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
          expect(error.message).to include(
            log_messages[:found_secrets],
            finding_message_header,
            finding_message_multiple_hunks_in_same_diff,
            log_messages[:found_secrets_post_message],
            found_secrets_docs_link
          )
        end

        expect(logged_messages[:info]).to include(
          hash_including(
            "message" => log_messages[:found_secrets],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end
    end

    context 'when encountering a context line' do
      let(:diff_blob) do
        ::Gitlab::GitalyClient::DiffBlob.new(
          left_blob_id: ::Gitlab::Git::SHA1_BLANK_SHA,
          right_blob_id: blob_5_reference,
          patch: encounter_context_line_patch,
          status: :STATUS_END_OF_PATCH,
          binary: false,
          over_patch_bytes_limit: false
        )
      end

      it 'gets and parses diffs' do
        expect_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |instance|
          expect(instance).to receive(:get_diffs)
            .once
            .and_return([diff_blob])
        end

        expect { subject.validate! }.to raise_error(::Gitlab::GitAccess::ForbiddenError)

        expect(logged_messages[:info]).to include(
          hash_including(
            "message" => log_messages[:found_secrets],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end

      it 'scans diffs' do
        expect_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |instance|
          expect(instance).to receive(:get_diffs)
            .once
            .and_wrap_original do |_, lookup_map_arg|
              # we pass lookup_map by reference, so need to make sure it's populated
              lookup_map_arg[blob_5_reference] = [
                {
                  commit_id: changed_path_1.commit_id,
                  path: changed_path_1.path
                }
              ]

              [diff_blob]
            end
        end

        expect_next_instance_of(::Gitlab::SecretDetection::Core::Scanner) do |instance|
          expect(instance).to receive(:secrets_scan)
            .with(
              new_payloads,
              timeout: kind_of(Float),
              exclusions: kind_of(Hash)
            )
            .once
            .and_return(successful_scan_response)
        end

        expect { subject.validate! }.to raise_error do |error|
          expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
          expect(error.message).to include(
            log_messages[:found_secrets],
            finding_message_header,
            finding_message_multiple_hunks_in_same_diff,
            log_messages[:found_secrets_post_message],
            found_secrets_docs_link
          )
        end

        expect(logged_messages[:info]).to include(
          hash_including(
            "message" => log_messages[:found_secrets],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end
    end
  end
end

RSpec.shared_examples 'scan detected secrets but some errors occured' do
  include_context 'secrets check context'

  let(:successful_scan_with_errors_response) do
    ::Gitlab::SecretDetection::Core::Response.new(
      status: ::Gitlab::SecretDetection::Core::Status::FOUND_WITH_ERRORS,
      results:
      [
        ::Gitlab::SecretDetection::Core::Finding.new(
          blob_5_reference,
          ::Gitlab::SecretDetection::Core::Status::FOUND,
          1,
          "gitlab_personal_access_token",
          "GitLab personal access token"
        ),
        ::Gitlab::SecretDetection::Core::Finding.new(
          blob_6_reference,
          ::Gitlab::SecretDetection::Core::Status::PAYLOAD_TIMEOUT
        ),
        ::Gitlab::SecretDetection::Core::Finding.new(
          blob_7_reference,
          ::Gitlab::SecretDetection::Core::Status::SCAN_ERROR
        )
      ]
    )
  end

  let_it_be(:new_commit, freeze: false) do
    create_commit('.env' => "SECRET=glpat-JUST20LETTERSANDNUMB") # gitleaks:allow
  end

  let_it_be(:timed_out_commit, freeze: false) do
    create_commit('.test.env' => "TOKEN=glpat-JUST20LETTERSANDNUMB") # gitleaks:allow
  end

  let_it_be(:failed_to_scan_commit, freeze: false) do
    create_commit('.dev.env' => "GLPAT=glpat-JUST20LETTERSANDNUMB") # gitleaks:allow
  end

  let(:changes) do
    [
      { oldrev: initial_commit, newrev: new_commit, ref: 'refs/heads/master' },
      { oldrev: new_commit, newrev: timed_out_commit, ref: 'refs/heads/master' },
      { oldrev: timed_out_commit, newrev: failed_to_scan_commit, ref: 'refs/heads/master' }
    ]
  end

  let(:new_payload) do
    ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
      data: "SECRET=glpat-JUST20LETTERSANDNUMB", # gitleaks:allow
      id: blob_5_reference,
      offset: 1
    )
  end

  let(:timed_out_payload) do
    ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
      data: "TOKEN=glpat-JUST20LETTERSANDNUMB", # gitleaks:allow
      id: blob_6_reference,
      offset: 1
    )
  end

  let(:failed_to_scan_payload) do
    ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
      data: "GLPAT=glpat-JUST20LETTERSANDNUMB", # gitleaks:allow
      id: blob_7_reference,
      offset: 1
    )
  end

  let(:changed_path_1) do
    Gitlab::Git::ChangedPath.new(
      path: ".env",
      status: :ADDED,
      new_blob_id: blob_5_reference,
      commit_id: new_commit,
      old_path: ".env",
      old_blob_id: '0000000000000000000000000000000000000000',
      old_mode: '0',
      new_mode: '100644'
    )
  end

  let(:changed_path_2) do
    Gitlab::Git::ChangedPath.new(
      path: ".test.env",
      status: :ADDED,
      new_blob_id: blob_6_reference,
      commit_id: timed_out_commit,
      old_path: ".test.env",
      old_blob_id: '0000000000000000000000000000000000000000',
      old_mode: '0',
      new_mode: '100644'
    )
  end

  let(:changed_path_3) do
    Gitlab::Git::ChangedPath.new(
      path: ".dev.env",
      status: :ADDED,
      new_blob_id: blob_7_reference,
      commit_id: failed_to_scan_commit,
      old_path: ".dev.env",
      old_blob_id: '0000000000000000000000000000000000000000',
      old_mode: '0',
      new_mode: '100644'
    )
  end

  it 'scans diffs' do
    expect_next_instance_of(::Gitlab::SecretDetection::Core::Scanner) do |instance|
      expect(instance).to receive(:secrets_scan)
        .with(
          array_including(new_payload, timed_out_payload, failed_to_scan_payload),
          timeout: kind_of(Float),
          exclusions: kind_of(Hash)
        )
        .once
        .and_return(successful_scan_with_errors_response)
    end

    expect_next_instance_of(Gitlab::Checks::SecretPushProtection::ResponseHandler) do |instance|
      expect(instance).to receive(:format_response).with(
        successful_scan_with_errors_response,
        hash_including(
          blob_5_reference => [
            {
              commit_id: changed_path_1.commit_id,
              path: changed_path_1.path
            }
          ],
          blob_6_reference => [
            {
              commit_id: changed_path_2.commit_id,
              path: changed_path_2.path
            }
          ],
          blob_7_reference => [
            {
              commit_id: changed_path_3.commit_id,
              path: changed_path_3.path
            }
          ]
        )
      ).once.and_call_original
    end

    expect { subject.validate! }.to raise_error do |error|
      expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
      expect(error.message).to include(
        log_messages[:found_secrets_with_errors],
        finding_message_header,
        finding_message_path,
        finding_message_occurrence_line,
        blob_timed_out_error,
        failed_to_scan_regex_error,
        log_messages[:found_secrets_post_message],
        found_secrets_docs_link
      )
    end

    expect(logged_messages[:info]).to include(
      hash_including(
        "message" => log_messages[:found_secrets_with_errors],
        "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
      )
    )
  end

  context 'when a blob has multiple secrets' do
    let_it_be(:new_commit, freeze: false) do
      create_commit('.env' => "SECRET=glpat-JUST20LETTERSANDNUMB\nTOKEN=glpat-JUST20LETTERSANDNUMB") # gitleaks:allow
    end

    let(:blob_5_reference) { '59ef300b246861163ee1e2ab4146e16144e4770f' }

    let(:new_payload) do
      ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
        data: "SECRET=glpat-JUST20LETTERSANDNUMB\nTOKEN=glpat-JUST20LETTERSANDNUMB", # gitleaks:allow
        id: blob_5_reference,
        offset: 1
      )
    end

    let(:successful_scan_with_multiple_findings_and_errors_response) do
      ::Gitlab::SecretDetection::Core::Response.new(
        status: ::Gitlab::SecretDetection::Core::Status::FOUND_WITH_ERRORS,
        results:
        [
          ::Gitlab::SecretDetection::Core::Finding.new(
            blob_5_reference,
            ::Gitlab::SecretDetection::Core::Status::FOUND,
            1,
            "gitlab_personal_access_token",
            "GitLab personal access token"
          ),
          ::Gitlab::SecretDetection::Core::Finding.new(
            blob_5_reference,
            ::Gitlab::SecretDetection::Core::Status::FOUND,
            2,
            "gitlab_personal_access_token",
            "GitLab personal access token"
          ),
          ::Gitlab::SecretDetection::Core::Finding.new(
            blob_6_reference,
            ::Gitlab::SecretDetection::Core::Status::PAYLOAD_TIMEOUT
          ),
          ::Gitlab::SecretDetection::Core::Finding.new(
            blob_7_reference,
            ::Gitlab::SecretDetection::Core::Status::SCAN_ERROR
          )
        ]
      )
    end

    it 'displays all findings with their corresponding commit sha/filepath' do
      expect_next_instance_of(::Gitlab::SecretDetection::Core::Scanner) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            array_including(new_payload, timed_out_payload, failed_to_scan_payload),
            timeout: kind_of(Float),
            exclusions: kind_of(Hash)
          )
          .once
          .and_return(successful_scan_with_multiple_findings_and_errors_response)
      end

      expect_next_instance_of(Gitlab::Checks::SecretPushProtection::ResponseHandler) do |instance|
        expect(instance).to receive(:format_response).with(
          successful_scan_with_multiple_findings_and_errors_response,
          hash_including(
            blob_5_reference => [
              {
                commit_id: changed_path_1.commit_id,
                path: changed_path_1.path
              }
            ],
            blob_6_reference => [
              {
                commit_id: changed_path_2.commit_id,
                path: changed_path_2.path
              }
            ],
            blob_7_reference => [
              {
                commit_id: changed_path_3.commit_id,
                path: changed_path_3.path
              }
            ]
          )
        ).once.and_call_original
      end

      expect { subject.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets_with_errors],
          finding_message_header,
          finding_message_multiple_occurrence_lines,
          blob_timed_out_error,
          failed_to_scan_regex_error,
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end

      expect(logged_messages[:info]).to include(
        hash_including(
          "message" => log_messages[:found_secrets_with_errors],
          "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
        )
      )
    end
  end
end

RSpec.shared_examples 'scan timed out' do
  include_context 'secrets check context'

  let(:scan_timed_out_scan_response) do
    ::Gitlab::SecretDetection::Core::Response.new(status: ::Gitlab::SecretDetection::Core::Status::SCAN_TIMEOUT)
  end

  it 'logs the error and passes the check' do
    # Mock the response to return a scan timed out status.
    expect_next_instance_of(::Gitlab::SecretDetection::Core::Scanner) do |instance|
      expect(instance).to receive(:secrets_scan)
        .and_return(scan_timed_out_scan_response)
    end

    expect { subject.validate! }.not_to raise_error

    # Error bubbles up from scan class and is handled in secrets check.
    expect(logged_messages[:error]).to include(
      hash_including(
        "message" => error_messages[:scan_timeout_error],
        "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
      )
    )
  end
end

RSpec.shared_examples 'scan failed to initialize' do
  include_context 'secrets check context'

  before do
    # Intentionally set `RULESET_FILE_PATH` to an incorrect path to cause error.
    stub_const('::Gitlab::SecretDetection::Core::Ruleset::RULESET_FILE_PATH', 'gitleaks.toml')
  end

  it 'logs the error and passes the check' do
    allow(TomlRB).to receive(:load_file).and_raise(
      StandardError,
      "No such file or directory @ rb_sysopen - gitleaks.toml"
    )

    expect { subject.validate! }.not_to raise_error

    error_msg = "No such file or directory @ rb_sysopen - gitleaks.toml"
    error_string = "Failed to parse local secret detection ruleset: #{error_msg}"
    msg = format(described_class::ERROR_MESSAGES[:scan_initialization_error], { error_msg: error_msg })

    # File parsing error is written to the logger.
    # Then, error bubbles up from scan class and is handled in secrets check.
    expect(logged_messages[:error]).to include(
      hash_including(
        message: error_string
      ),
      hash_including(
        "message" => msg,
        "class" => "Gitlab::Checks::SecretPushProtection::SecretsCheck"
      )
    )
  end

  it 'calls the audit logger for ruleset errors' do
    # Due to the way `AuditLogger` is initialized across multiple classes, there's no easy
    # way to verify the right instance is the one that calls `log_spp_ruleset_error`.
    #
    # Instead, we stub the `new` method to return a specific instance of `AuditLogger` and
    # verify that instance is the one that calls `log_spp_ruleset_error`.
    audit_logger = Gitlab::Checks::SecretPushProtection::AuditLogger.new(
      project: project,
      changes_access: changes_access
    )

    allow(Gitlab::Checks::SecretPushProtection::AuditLogger)
      .to receive(:new)
      .and_return(audit_logger)

    allow(TomlRB).to receive(:load_file).and_raise(
      StandardError,
      "No such file or directory @ rb_sysopen - gitleaks.toml"
    )

    expect(audit_logger).to receive(:log_spp_ruleset_error)

    expect { subject.validate! }.not_to raise_error
  end
end

RSpec.shared_examples 'scan failed with invalid input' do
  include_context 'secrets check context'

  let(:failed_with_invalid_input_response) do
    ::Gitlab::SecretDetection::Core::Response.new(status: ::Gitlab::SecretDetection::Core::Status::INPUT_ERROR)
  end

  it 'logs the error and passes the check' do
    # Mock the response to return a scan invalid input status.
    expect_next_instance_of(::Gitlab::SecretDetection::Core::Scanner) do |instance|
      expect(instance).to receive(:secrets_scan)
        .and_return(failed_with_invalid_input_response)
    end

    expect { subject.validate! }.not_to raise_error

    # Error bubbles up from scan class and is handled in secrets check.
    expect(logged_messages[:error]).to include(
      hash_including(
        "message" => error_messages[:invalid_input_error],
        "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
      )
    )
  end
end

RSpec.shared_examples 'scan skipped due to invalid status' do
  include_context 'secrets check context'

  let(:invalid_scan_status_code) { -1 } # doesn't exist in ::Gitlab::SecretDetection::Core::Status
  let(:invalid_scan_status_code_response) do
    ::Gitlab::SecretDetection::Core::Response.new(
      status: invalid_scan_status_code
    )
  end

  it 'logs the error and passes the check' do
    # Mock the response to return a scan invalid status.
    expect_next_instance_of(::Gitlab::SecretDetection::Core::Scanner) do |instance|
      expect(instance).to receive(:secrets_scan)
        .and_return(invalid_scan_status_code_response)
    end

    expect { subject.validate! }.not_to raise_error

    # Error bubbles up from scan class and is handled in secrets check.
    expect(logged_messages[:error]).to include(
      hash_including(
        "message" => error_messages[:invalid_scan_status_code_error],
        "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
      )
    )
  end
end

RSpec.shared_examples 'scan skipped when a commit has special bypass flag' do
  include_context 'secrets check context'

  def generate_test_comparison_path(from_commit, to_commit)
    ::Gitlab::Utils.append_path(
      ::Gitlab::Routing.url_helpers.root_url,
      ::Gitlab::Routing.url_helpers.project_compare_path(project, from: from_commit, to: to_commit)
    )
  end

  let_it_be(:new_commit, freeze: false) do
    create_commit(
      { '.env' => 'SECRET=glpat-JUST20LETTERSANDNUMB' }, # gitleaks:allow
      'dummy commit [skip secret push protection]'
    )
  end

  it 'skips the scanning process' do
    expect { subject.validate! }.not_to raise_error
  end

  context 'when other commits have secrets in the same push' do
    let_it_be(:second_commit_with_secret, freeze: false) do
      create_commit('.test.env' => 'TOKEN=glpat-JUST20LETTERSANDNUMB') # gitleaks:allow
    end

    let(:changes) do
      [
        { oldrev: initial_commit, newrev: new_commit, ref: 'refs/heads/master' },
        { oldrev: initial_commit, newrev: second_commit_with_secret, ref: 'refs/heads/master' }
      ]
    end

    it 'skips the scanning process still' do
      expect { subject.validate! }.not_to raise_error
    end
  end

  context 'when this is the initial commit on a new branch' do
    let(:changes) do
      [
        { newrev: new_commit, ref: 'refs/heads/newbranch' }
      ]
    end

    it 'skips the scanning process still' do
      expect { subject.validate! }.not_to raise_error
    end
  end

  context 'when this commit is deleting the branch' do
    let(:changes) do
      [
        { oldrev: new_commit, newrev: Gitlab::Git::SHA1_BLANK_SHA, ref: 'refs/heads/deleteme' }
      ]
    end

    it 'skips the scanning process still' do
      expect { subject.validate! }.not_to raise_error
    end

    it 'does not create an AuditEvent' do
      expect { subject.validate! }.not_to change { AuditEventReader.count }.from(0)
    end
  end
end

RSpec.shared_examples 'scan skipped when secret_push_protection.skip_all push option is passed' do
  include_context 'secrets check context'

  def generate_test_comparison_path(from_commit, to_commit)
    ::Gitlab::Utils.append_path(
      ::Gitlab::Routing.url_helpers.root_url,
      ::Gitlab::Routing.url_helpers.project_compare_path(project, from: from_commit, to: to_commit)
    )
  end

  let(:changes_access) do
    ::Gitlab::Checks::ChangesAccess.new(
      changes,
      project: project,
      user_access: user_access,
      protocol: protocol,
      logger: logger,
      push_options: ::Gitlab::PushOptions.new(["secret_push_protection.skip_all"]),
      gitaly_context: gitaly_context
    )
  end

  subject(:secrets_check) { described_class.new(changes_access) }

  let_it_be(:new_commit, freeze: false) do
    create_commit(
      { '.env' => 'SECRET=glpat-JUST20LETTERSANDNUMB' } # gitleaks:allow
    )
  end

  it 'skips the scanning process' do
    expect { subject.validate! }.not_to raise_error
  end

  context 'when other commits have secrets in the same push' do
    let_it_be(:second_commit_with_secret, freeze: false) do
      create_commit('.test.env' => 'TOKEN=glpat-JUST20LETTERSANDNUMB') # gitleaks:allow
    end

    let(:changes) do
      [
        { oldrev: initial_commit, newrev: new_commit, ref: 'refs/heads/master' },
        { oldrev: initial_commit, newrev: second_commit_with_secret, ref: 'refs/heads/master' }
      ]
    end

    it 'skips the scanning process still' do
      expect { subject.validate! }.not_to raise_error
    end
  end

  context 'when this is the initial commit on a new branch' do
    let(:changes) do
      [
        { newrev: new_commit, ref: 'refs/heads/newbranch' }
      ]
    end

    it 'skips the scanning process still' do
      expect { subject.validate! }.not_to raise_error
    end
  end

  context 'when this commit is deleting the branch' do
    let(:changes) do
      [
        { oldrev: new_commit, newrev: Gitlab::Git::SHA1_BLANK_SHA, ref: 'refs/heads/deleteme' }
      ]
    end

    it 'skips the scanning process still' do
      expect { subject.validate! }.not_to raise_error
    end

    it 'does not create an AuditEvent' do
      expect { subject.validate! }.not_to change { AuditEventReader.count }.from(0)
    end
  end
end

RSpec.shared_examples 'scan discarded secrets because they match exclusions' do
  include_context 'secrets check context'

  context 'when exclusion is based on matching a file path' do
    context 'with exactly maximum numer of path exclusions allowed' do
      let_it_be(:commit_with_excluded_file_paths, freeze: false) do
        create_commit(
          'file-exclusion-1.rb' => 'KEY=glpat-JUST20LETTERSANDNUMB', # gitleaks:allow
          'file-exclusion-2-skipped.rb' => 'TOKEN=glpat-JUST20LETTERSANDNUMB' # gitleaks:allow
        )
      end

      let(:changes) do
        [
          { oldrev: initial_commit, newrev: commit_with_excluded_file_paths, ref: 'refs/heads/master' }
        ]
      end

      before do
        stub_const('::Security::ProjectSecurityExclusion::MAX_PATH_EXCLUSIONS_PER_PROJECT', 1)

        create(:project_security_exclusion, :active, :with_path, project: project, value: "file-exclusion-1.rb")
      end

      it 'excludes secrets matching file paths up to the maximum allowed' do
        expect { secrets_check.validate! }.to raise_error do |error|
          expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
          expect(error.message).to include(
            log_messages[:found_secrets],
            finding_message(
              commit_with_excluded_file_paths,
              'file-exclusion-2-skipped.rb',
              1,
              'GitLab personal access token'
            ),
            log_messages[:found_secrets_post_message],
            found_secrets_docs_link
          )
        end

        expect(logged_messages[:info]).to include(
          hash_including(
            "message" => log_messages[:found_secrets],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end
    end

    context 'with less than or equal to the path exclusions limit' do
      let_it_be(:commit_with_excluded_file_paths, freeze: false) do
        create_commit(
          # We support specifying a certain file path, e.g. `file-exclusion-1.txt`.
          'file-exclusion-1.txt' => 'SECRET=glpat-JUST20LETTERSANDNUMB', # gitleaks:allow

          # We also support simple globbing, e.g. `spec/**/*.rb`, so we try to ensure as many as possible are matched.
          'spec/file-exclusion-2.rb' => 'KEY=glpat-JUST20LETTERSANDNUMB', # gitleaks:allow
          'spec/fixtures/file-exclusion-3.rb' => 'PASS=glpat-JUST20LETTERSANDNUMB', # gitleaks:allow
          'spec/fixtures/reports/file-exclusion-4.rb' => 'TEST=glpat-JUST20LETTERSANDNUMB' # gitleaks:allow
        )
      end

      let_it_be(:commit_with_not_excluded_file_path, freeze: false) do
        create_commit('file-exclusion-4.txt' => 'TOKEN=glrt-JUST20LETTERSANDNUMB') # gitleaks:allow
      end

      let(:changes) do
        [
          { oldrev: initial_commit, newrev: commit_with_excluded_file_paths, ref: 'refs/heads/master' },
          { oldrev: initial_commit, newrev: commit_with_not_excluded_file_path, ref: 'refs/heads/master' }
        ]
      end

      before do
        create(
          :project_security_exclusion,
          :active,
          :with_path,
          project: project,
          value: 'file-exclusion-1.txt'
        )

        create(
          :project_security_exclusion,
          :active,
          :with_path,
          project: project,
          value: 'spec/**/*.rb'
        )
      end

      it 'excludes secrets matching file paths from findings' do
        expect { secrets_check.validate! }.to raise_error do |error|
          expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
          expect(error.message).to include(
            log_messages[:found_secrets],
            finding_message(
              commit_with_not_excluded_file_path,
              'file-exclusion-4.txt',
              1,
              'GitLab runner authentication token'
            ),
            log_messages[:found_secrets_post_message],
            found_secrets_docs_link
          )
        end

        expect(logged_messages[:info]).to include(
          hash_including(
            "message" => log_messages[:found_secrets],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end
    end
  end

  context 'when exclusion is based on matching a rule from default ruleset' do
    let_it_be(:commit_with_excluded_rule, freeze: false) do
      create_commit('rule-exclusion-1.txt' => 'SECRET=glpat-JUST20LETTERSANDNUMB') # gitleaks:allow
    end

    let_it_be(:commit_with_not_excluded_rule, freeze: false) do
      create_commit('rule-exclusion-2.txt' => 'TOKEN=glrt-JUST20LETTERSANDNUMB') # gitleaks:allow
    end

    let(:changes) do
      [
        { oldrev: initial_commit, newrev: commit_with_excluded_rule, ref: 'refs/heads/master' },
        { oldrev: initial_commit, newrev: commit_with_not_excluded_rule, ref: 'refs/heads/master' }
      ]
    end

    before do
      create(:project_security_exclusion, :active, :with_rule, project: project)
    end

    it 'excludes secrets matching rule from findings' do
      expect { secrets_check.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets],
          finding_message(
            commit_with_not_excluded_rule,
            'rule-exclusion-2.txt',
            1,
            'GitLab runner authentication token'
          ),
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end

      expect(logged_messages[:info]).to include(
        hash_including(
          "message" => log_messages[:found_secrets],
          "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
        )
      )
    end
  end

  context 'when exclusion is based on matching a raw value or string' do
    let_it_be(:commit_with_excluded_value, freeze: false) do
      create_commit('raw-value-exclusion-1.txt' => 'SECRET=glpat-01234567890123456789') # gitleaks:allow
    end

    let_it_be(:commit_with_not_excluded_value, freeze: false) do
      create_commit('raw-value-exclusion-2.txt' => 'TOKEN=glpat-JUST20LETTERSANDNUMB') # gitleaks:allow
    end

    let(:changes) do
      [
        { oldrev: initial_commit, newrev: commit_with_excluded_value, ref: 'refs/heads/master' },
        { oldrev: initial_commit, newrev: commit_with_not_excluded_value, ref: 'refs/heads/master' }
      ]
    end

    before do
      create(
        :project_security_exclusion,
        :active,
        :with_raw_value,
        project: project,
        value: 'glpat-01234567890123456789' # gitleaks:allow
      )
    end

    it 'excludes secrets matching raw value from findings' do
      expect { secrets_check.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets],
          finding_message(
            commit_with_not_excluded_value,
            'raw-value-exclusion-2.txt',
            1,
            'GitLab personal access token'
          ),
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end

      expect(logged_messages[:info]).to include(
        hash_including(
          "message" => log_messages[:found_secrets],
          "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
        )
      )
    end
  end
end

RSpec.shared_examples 'detects secrets with special characters in diffs' do
  include_context 'secrets check context'
  include_context 'special characters table'

  with_them do
    let(:secret_with_special_char) { "SECRET=glpat-JUST20LETTERSANDNUMB #{special_character}" } # gitleaks:allow

    let(:diff_blob) do
      ::Gitlab::GitalyClient::DiffBlob.new(
        left_blob_id: ::Gitlab::Git::SHA1_BLANK_SHA,
        right_blob_id: blob_2_reference,
        patch: "@@ -0,0 +1 @@\n+#{secret_with_special_char}\n\\ No newline at end of file\n",
        status: :STATUS_END_OF_PATCH,
        binary: false,
        over_patch_bytes_limit: false
      )
    end

    let(:new_payload) do
      ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
        data: secret_with_special_char.force_encoding("UTF-8"),
        id: blob_2_reference,
        offset: 1
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
        old_mode: '0',
        new_mode: '100644'
      )
    end

    let(:lookup_map) do
      {
        blob_2_reference => [
          {
            commit_id: changed_path_1.commit_id,
            path: changed_path_1.path
          }
        ]
      }
    end

    it "detects secret in diff containing #{params[:description]}" do
      expect_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |instance|
        expect(instance).to receive(:get_diffs)
          .once
          .and_wrap_original do |_, lookup_map_arg|
            # we pass lookup_map by reference, so need to make sure it's populated
            lookup_map_arg[blob_2_reference] = [
              {
                commit_id: changed_path_1.commit_id,
                path: changed_path_1.path
              }
            ]

            [diff_blob]
          end
      end

      expect_next_instance_of(::Gitlab::SecretDetection::Core::Scanner) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            [new_payload],
            timeout: kind_of(Float),
            exclusions: kind_of(Hash)
          )
          .once
          .and_call_original
      end

      expect { subject.validate! }.to raise_error(::Gitlab::GitAccess::ForbiddenError)

      expect(logged_messages[:info]).to include(
        hash_including(
          "message" => log_messages[:found_secrets],
          "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
        )
      )
    end
  end
end

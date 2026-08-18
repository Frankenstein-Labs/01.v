# frozen_string_literal: true

require 'spec_helper'
require 'rspec-parameterized'

RSpec.describe Gitlab::Checks::SecretPushProtection::PayloadProcessor, feature_category: :secret_detection do
  include_context 'secrets check context'
  using RSpec::Parameterized::TableSyntax

  subject(:payload_processor) do
    described_class.new(
      project: project,
      changes_access: changes_access
    )
  end

  shared_examples 'logs changed paths breakdown' do
    it 'logs unknown status when changed_path.status is nil' do
      changed_path = instance_double(
        Gitlab::Git::ChangedPath,
        status: nil,
        path: 'unknown.txt',
        old_mode: '100644',
        new_mode: '100644',
        old_blob_id: '0000000000000000000000000000000000000000',
        new_blob_id: 'abc123def456',
        old_path: 'unknown.txt',
        commit_id: ''
      )

      # We stub the other two RPC calls in order to make this work properly.
      allow(project.repository).to receive_messages(
        find_changed_paths: [changed_path],
        diff_blobs_with_raw_info: [],
        diff_blobs: []
      )

      payload_processor.standardize_payloads

      expect(logged_messages[:info]).to include(
        hash_including(
          "class" => "Gitlab::Checks::SecretPushProtection::PayloadProcessor",
          "message" => "Number of changed paths broken down by their type",
          "total_paths" => 1,
          "paths_breakdown" => {
            "unknown" => 1
          }
        )
      )
    end

    it 'logs the number and breakdown of changed paths' do
      payload_processor.standardize_payloads

      expect(logged_messages[:info]).to include(
        hash_including(
          "class" => "Gitlab::Checks::SecretPushProtection::PayloadProcessor",
          "message" => "Number of changed paths broken down by their type",
          "total_paths" => 3,
          "paths_breakdown" => {
            "added" => 1,
            "modified" => 1,
            "renamed" => 1
          }
        )
      )
    end

    it 'tracks any exception raised while logging the breakdown' do
      error = StandardError.new('log failure')

      expect(secret_detection_logger).to receive(:info)
        .with(
          hash_including(
            "message" => "Number of changed paths broken down by their type"
          )
        )
        .and_raise(error)

      expect(::Gitlab::ErrorTracking).to receive(:track_exception).with(
        error,
        project_id: project.id,
        extra: {
          context: "number_of_changed_paths_calculation"
        }
      )

      payload_processor.standardize_payloads
    end
  end

  shared_examples 'populates the lookup map' do
    it 'populates the map' do
      _, lookup_map = payload_processor.standardize_payloads

      expect(lookup_map.size).to eq(3)
      expect(lookup_map).to include(
        blob_2_reference => [
          {
            path: ".env",
            commit_id: new_commit
          }
        ],
        blob_3_reference => [
          {
            path: "to_modify.txt",
            commit_id: new_commit
          }
        ],
        blob_4_reference => [
          {
            path: "new_config.txt",
            commit_id: new_commit
          }
        ]
      )
    end

    it 'logs the map population message' do
      _, _ = payload_processor.standardize_payloads

      expect(logged_messages[:info]).to include(
        hash_including(
          "class" => "Gitlab::Checks::SecretPushProtection::PayloadProcessor",
          "message" => "Populated the lookup map used to associate a finding to " \
            "commit sha + file path",
          "total_payloads" => 3,
          "total_changed_path_entries" => 3
        )
      )
    end

    it 'handles empty paths array gracefully' do
      allow(project.repository).to receive(:find_changed_paths).and_return([])

      _, lookup_map = payload_processor.standardize_payloads

      expect(lookup_map).to be_empty

      expect(logged_messages[:info]).to include(
        hash_including(
          "message" => "Populated the lookup map used to associate a finding to " \
            "commit sha + file path",
          "total_payloads" => 0,
          "total_changed_path_entries" => 0
        )
      )
    end

    context 'for changed path entries with blank `new_blob_id`' do
      let(:changed_path_1) do
        instance_double(
          Gitlab::Git::ChangedPath,
          status: :DELETED,
          path: 'deleted_file_1.txt',
          old_mode: '100644',
          new_mode: '000000',
          old_blob_id: 'blob_id_1',
          new_blob_id: '',
          old_path: 'deleted_file_1.txt',
          commit_id: 'commit_1'
        )
      end

      let(:changed_path_2) do
        instance_double(
          Gitlab::Git::ChangedPath,
          status: :DELETED,
          path: 'deleted_file_2.txt',
          old_mode: '100644',
          new_mode: '000000',
          old_blob_id: 'blob_id_2',
          new_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
          old_path: 'deleted_file_2.txt',
          commit_id: 'commit_2'
        )
      end

      before do
        allow(project.repository).to receive_messages(
          find_changed_paths: [changed_path_1, changed_path_2],
          diff_blobs_with_raw_info: [],
          diff_blobs: []
        )
      end

      it 'skips those entries' do
        _, lookup_map = payload_processor.standardize_payloads

        expect(lookup_map).to be_empty
      end
    end

    context 'for the same blob in multiple commits' do
      let(:same_blob_path_1) do
        instance_double(
          Gitlab::Git::ChangedPath,
          status: :ADDED,
          path: 'config/secrets.yml',
          old_mode: '000000',
          new_mode: '100644',
          old_blob_id: '0000000000000000000000000000000000000000',
          new_blob_id: 'blob_id_1',
          old_path: 'config/secrets.yml',
          commit_id: 'commit_1'
        )
      end

      let(:same_blob_path_2) do
        instance_double(
          Gitlab::Git::ChangedPath,
          status: :MODIFIED,
          path: 'config/secrets.yml',
          old_mode: '100644',
          new_mode: '100644',
          old_blob_id: 'blob_id_0',
          new_blob_id: 'blob_id_1',
          old_path: 'config/secrets.yml',
          commit_id: 'commit_2'
        )
      end

      before do
        allow(project.repository).to receive_messages(
          find_changed_paths: [same_blob_path_1, same_blob_path_2],
          diff_blobs_with_raw_info: [],
          diff_blobs: []
        )
      end

      it 'handles multiple commits touching the same blob' do
        _, lookup_map = payload_processor.standardize_payloads

        # The map should have ONE key (the blob ID) with TWO entries (one per commit)
        expect(lookup_map.size).to eq(1)
        expect(lookup_map['blob_id_1'].size).to eq(2)
        expect(lookup_map['blob_id_1']).to contain_exactly(
          hash_including(
            path: 'config/secrets.yml',
            commit_id: 'commit_1'
          ), hash_including(
            path: 'config/secrets.yml',
            commit_id: 'commit_2'
          )
        )
      end
    end
  end

  describe '#standardize_payloads' do
    context 'with a valid diff blob' do
      include_examples 'logs changed paths breakdown'
      include_examples 'populates the lookup map'

      it 'returns a single GRPC payload built from the diff blob' do
        expect(project.repository).to receive(:diff_blobs_with_raw_info)
          .and_wrap_original do |method, raw_info, **kwargs|
          expect(raw_info).to be_an(Array)
          expect(raw_info.size).to eq(3)

          changed_path = raw_info.first
          expect(changed_path).to be_a(Gitaly::ChangedPaths)
          expect(changed_path.path).to eq(".env")
          expect(changed_path.status).to eq(:ADDED)
          expect(changed_path.old_mode).to eq(0)
          expect(changed_path.new_mode).to eq(33188)
          expect(changed_path.old_blob_id).to eq("0000000000000000000000000000000000000000")
          expect(changed_path.new_blob_id).to eq("da66bef46dbf0ad7fdcbeec97c9eaa24c2846dda")
          expect(changed_path.old_path).to eq("")
          expect(changed_path.commit_id).to be_present
          expect(changed_path.score).to eq(0)
          method.call(raw_info, **kwargs)
        end

        expected_diff_filters = [
          :DIFF_STATUS_ADDED,
          :DIFF_STATUS_MODIFIED,
          :DIFF_STATUS_TYPE_CHANGE,
          :DIFF_STATUS_COPIED,
          :DIFF_STATUS_RENAMED
        ]
        expect(project.repository).to receive(:find_changed_paths).with(
          anything,
          hash_including(diff_filters: expected_diff_filters)
        ).and_call_original

        payloads, _ = payload_processor.standardize_payloads
        expect(payloads).to be_an(Array)
        expect(payloads.size).to eq(2)

        payload = payloads.first
        expect(payload).to be_a(::Gitlab::SecretDetection::GRPC::ScanRequest::Payload)
        expect(payload.id).to eq(blob_2_reference)
        expect(payload.data).to include("BASE_URL=https://foo.bar")
        expect(payload.offset).to eq(1)
      end

      it 'tracks the changed paths count' do
        expect(payload_processor.audit_logger).to receive(:track_changed_paths_calculated).with(3)

        payload_processor.standardize_payloads
      end

      it 'logs the total number of lines and payload bytes across all diffs' do
        payload_processor.standardize_payloads

        expect(logged_messages[:info]).to include(
          hash_including(
            "class" => "Gitlab::Checks::SecretPushProtection::PayloadProcessor",
            "message" => "Total number of lines to scan",
            "total_lines" => 8,
            "total_payload_bytes" => 158
          )
        )
      end
    end

    context 'when diff_blobs_with_raw_info fails' do
      before do
        allow(project.repository).to receive(:diff_blobs_with_raw_info).and_raise(GRPC::Internal,
          "waiting for git-diff-pairs: exit status 128")
      end

      it 'logs the failing arguments and re-raises the error' do
        expect(secret_detection_logger).to receive(:error).with(
          a_string_starting_with("diff_blobs_with_raw_info Gitaly call failed with args:")
        )

        expect { payload_processor.standardize_payloads }.to raise_error(GRPC::Internal)
      end
    end

    context 'when secret_detection_transition_to_raw_info_gitaly_endpoint is disabled' do
      before do
        stub_feature_flags(secret_detection_transition_to_raw_info_gitaly_endpoint: false)
      end

      context 'with a valid diff blob' do
        include_examples 'logs changed paths breakdown'
        include_examples 'populates the lookup map'

        it 'returns a single GRPC payload built from the diff blob' do
          expect(project.repository).to receive(:diff_blobs).and_wrap_original do |method, blob_pairs, **kwargs|
            expect(blob_pairs).to be_an(Array)
            expect(blob_pairs.size).to eq(2)

            blob_pair = blob_pairs.first
            expect(blob_pair).to be_a(Gitaly::DiffBlobsRequest::BlobPair)
            expect(blob_pair.left_blob).to eq("0000000000000000000000000000000000000000")
            expect(blob_pair.right_blob).to eq("da66bef46dbf0ad7fdcbeec97c9eaa24c2846dda")

            blob_pair = blob_pairs[1]
            expect(blob_pair).to be_a(Gitaly::DiffBlobsRequest::BlobPair)
            expect(blob_pair.left_blob).to eq("0d8457bf235000469845078c31d3371cb86209e7")
            expect(blob_pair.right_blob).to eq("ed426f4235de33f1e5b539100c53e0002e143e3f")

            method.call(blob_pairs, **kwargs)
          end

          payloads, _ = payload_processor.standardize_payloads
          expect(payloads).to be_an(Array)
          expect(payloads.size).to eq(2)

          payload = payloads.first
          expect(payload).to be_a(::Gitlab::SecretDetection::GRPC::ScanRequest::Payload)
          expect(payload.id).to eq(blob_2_reference)
          expect(payload.data).to include("BASE_URL=https://foo.bar")

          payload = payloads[1]
          expect(payload).to be_a(::Gitlab::SecretDetection::GRPC::ScanRequest::Payload)
          expect(payload.id).to eq('ed426f4235de33f1e5b539100c53e0002e143e3f')
          expect(payload.data).to include("VAR=new")
          expect(payload.offset).to eq(1)
        end
      end
    end

    context 'when parse_diffs returns an empty array due to invalid hunk header' do
      let(:bad_diff_blob) do
        ::Gitlab::GitalyClient::DiffBlob.new(
          left_blob_id: ::Gitlab::Git::SHA1_BLANK_SHA,
          right_blob_id: blob_2_reference,
          patch: "@@ malformed header @@\n+some content\n",
          status: :STATUS_END_OF_PATCH,
          binary: false,
          over_patch_bytes_limit: false
        )
      end

      before do
        allow(payload_processor).to receive(:get_diffs).and_return([bad_diff_blob])
      end

      it 'logs an error and returns nil when no payloads remain' do
        expect(secret_detection_logger).to receive(:error).with(
          hash_including("message" => a_string_including("Could not process hunk header"))
        )

        expect(payload_processor.standardize_payloads).to eq([nil, {}])
      end
    end

    context 'when get_diffs returns nil or empty' do
      it 'returns nil' do
        allow(payload_processor).to receive(:get_diffs).and_return([])

        expect(payload_processor.standardize_payloads).to eq([nil, {}])
      end
    end

    context 'when changed paths exceeds maximum threshold' do
      before do
        stub_const('Gitlab::Checks::SecretPushProtection::PayloadProcessor::MAX_CHANGED_PATHS', 1)
      end

      it 'raises an exception' do
        expect { payload_processor.standardize_payloads }.to raise_error(
          Gitlab::Checks::SecretPushProtection::TooManyChangedPathsError
        )
      end
    end

    context 'when total lines exceeds maximum threshold' do
      before do
        stub_const('Gitlab::Checks::SecretPushProtection::PayloadProcessor::MAX_LINES_PER_REQUEST', 5)
      end

      it 'raises TooManyLinesError with correct attributes' do
        expect { payload_processor.standardize_payloads }.to raise_error do |error|
          expect(error).to be_a(Gitlab::Checks::SecretPushProtection::TooManyLinesError)
          expect(error.lines_count).to eq(8)
          expect(error.lines_threshold).to eq(5)
        end
      end
    end
  end

  describe '#parse_diffs' do
    let(:diff_blob) do
      ::Gitlab::GitalyClient::DiffBlob.new(
        left_blob_id: ::Gitlab::Git::SHA1_BLANK_SHA,
        right_blob_id: blob_2_reference,
        patch: patch,
        status: :STATUS_END_OF_PATCH,
        binary: false,
        over_patch_bytes_limit: false
      )
    end

    context 'with a valid diff patch containing two hunks' do
      let(:patch) do
        <<~DIFF
          @@ -0,0 +1,2 @@
          +one
          +two
          @@ -10,0 +11,1 @@
          +three
        DIFF
      end

      it 'returns two chunks with correct id, offset, and data' do
        parsed = payload_processor.parse_diffs(diff_blob)
        expect(parsed.pluck(:offset)).to match_array([1, 11])
        expect(parsed.pluck(:data)).to eq(%W[one\ntwo three])
        expect(parsed).to all(include(id: blob_2_reference))
      end
    end

    context 'with an invalid hunk header' do
      let(:patch) { "@@ bad header @@\n+foo\n" }

      it 'logs and returns []' do
        expect(secret_detection_logger).to receive(:error).with(
          hash_including("message" => a_string_including("Could not process hunk header"))
        )

        parsed = payload_processor.parse_diffs(diff_blob)
        expect(parsed).to eq([])
      end
    end

    context 'with special characters' do
      where(:line, :expected_data) do
        [
          ['+SECRET=glpat-123!@#$%^&*()', 'SECRET=glpat-123!@#$%^&*()'], # gitleaks:allow
          ['+TOKEN=glpat-💥💥💥', 'TOKEN=glpat-💥💥💥']
        ]
      end

      with_them do
        let(:patch) { "@@ -1,0 +1,1 @@\n#{line}\n" }

        it 'preserves emojis and special chars' do
          parsed = payload_processor.parse_diffs(diff_blob)
          expect(parsed.size).to eq(1)
          expect(parsed.first[:data]).to eq(expected_data)
        end
      end
    end
  end

  describe '#diff_blobs' do
    let(:changed_path_no_diff) do
      instance_double(
        Gitlab::Git::ChangedPath,
        old_blob_id: 'same_123',
        new_blob_id: 'same_123',
        path: 'renamed.md',
        status: :renamed,
        old_mode: '100644',
        new_mode: '100644',
        old_path: 'old_name.md',
        commit_id: 'commit_1'
      )
    end

    before do
      # We test only the case when raw_info feature flag is disabled here because it throws
      # a `GRPC::InvalidArgument: 3:request contains no file pairs to diff.` exception when
      # the `blob_pair_ids` are empty. When using `raw_info`, no `blob_pairs` are used.
      stub_feature_flags(secret_detection_transition_to_raw_info_gitaly_endpoint: false)
    end

    context 'when all changed paths have identical blob ids' do
      before do
        allow(project.repository).to receive_messages(
          new_commits: [],
          find_changed_paths: [changed_path_no_diff]
        )
      end

      it 'returns empty array without calling repository.diff_blobs' do
        expect(project.repository).not_to receive(:diff_blobs)

        result, _ = payload_processor.standardize_payloads

        expect(result).to be_nil
      end
    end

    context 'when at least one changed path has different blob ids' do
      let(:changed_path_with_diff) do
        instance_double(
          Gitlab::Git::ChangedPath,
          old_blob_id: 'old_123',
          new_blob_id: 'new_123',
          path: 'modified.rb',
          status: :modified,
          old_mode: '100644',
          new_mode: '100644',
          old_path: 'modified.rb',
          commit_id: 'commit_1'
        )
      end

      let(:diff_blob) do
        ::Gitlab::GitalyClient::DiffBlob.new(
          left_blob_id: 'old_123',
          right_blob_id: 'new_123',
          patch: "@@ -1,1 +1,1 @@\n-old content\n+new content\n",
          status: :STATUS_END_OF_PATCH,
          binary: false,
          over_patch_bytes_limit: false
        )
      end

      before do
        allow(project.repository).to receive_messages(
          new_commits: [],
          find_changed_paths: [changed_path_no_diff, changed_path_with_diff]
        )
      end

      it 'calls repository.diff_blobs with the diffable blob pair' do
        expect(project.repository).to receive(:diff_blobs)
          .and_return([diff_blob])

        payloads, _ = payload_processor.standardize_payloads

        expect(payloads).to be_an(Array)
        expect(payloads.size).to eq(1)
        expect(payloads.first.id).to eq('new_123')
      end
    end
  end

  describe '#build_payload' do
    let(:datum) { { id: 'test-blob-id', data: 'test payload data', offset: 2 } }

    context 'with valid UTF-8 data' do
      it 'returns a GRPC::ScanRequest::Payload with matching attributes' do
        payload = payload_processor.build_payload(datum)
        expect(payload).to be_a(::Gitlab::SecretDetection::GRPC::ScanRequest::Payload)
        expect(payload.id).to eq('test-blob-id')
        expect(payload.data).to eq('test payload data')
      end
    end

    context 'when data has invalid encoding' do
      let(:datum_id) { 'test-blob-id' }
      let(:datum_offset) { 2 }
      let(:original_encoding) { 'ASCII-8BIT' }

      let(:data_content) { +'encoded string' }

      let(:invalid_datum) do
        {
          id: datum_id,
          data: data_content,
          offset: datum_offset
        }
      end

      it 'returns nil and logs a warning' do
        expect(data_content).to receive(:encoding).and_return(original_encoding)
        expect(data_content).to receive(:dup).and_return(data_content)
        expect(data_content).to receive(:force_encoding).and_return(data_content)
        expect(data_content).to receive(:valid_encoding?).and_return(false)

        expect(secret_detection_logger).to receive(:warn).with(
          hash_including(
            "message" => format(
              Gitlab::Checks::SecretPushProtection::PayloadProcessor::LOG_MESSAGES[:invalid_encoding],
              { encoding: original_encoding }
            )
          )
        )

        result = payload_processor.build_payload(invalid_datum)
        expect(result).to be_nil
      end
    end

    context 'when passed an already-built payload' do
      let(:existing) do
        ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
          id: 'test-blob-id',
          data: 'test payload data',
          offset: 3
        )
      end

      it 'returns it unmodified' do
        expect(payload_processor.build_payload(existing)).to be(existing)
      end
    end
  end
end

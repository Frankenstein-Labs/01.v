# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Tools::Resolutions::DestroyReplicablesWithMissingFiles, :geo,
  feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let(:error_type) { Geo::Errors::ErrorType.find_by(name: 'file_missing_on_primary') }
  let(:failure) { 'Error during verification: File is not checksummable - file does not exist at: /var/opt/x.png' }

  # Redirect the recovery dump into a temp dir so examples neither write into the real tmp/ nor
  # see each other's files. Only the directory is stubbed, so the file naming stays under test.
  let(:dump_dir) { Dir.mktmpdir }

  # The resolution only acts on records that have failed verification repeatedly, and the
  # factories do not leave a high enough count on their own: the :upload trait sets attributes
  # only, so the count lands NULL, while the :lfs_object trait drives the state machine, which
  # records exactly one failure. So every fixture sets the count explicitly.
  let(:retry_count) { described_class::DEFAULT_MIN_RETRY_COUNT }

  subject(:resolution) { described_class.new(error_type) }

  def dump_paths
    Dir.glob(File.join(dump_dir, '*.jsonl'))
  end

  before do
    # Verification details are only persisted to the separate state tables on a primary, so
    # stub the primary node before the records are created.
    stub_current_geo_node(create(:geo_node, :primary))

    allow(resolution).to receive(:recovery_dump_dir).and_return(dump_dir)
  end

  after do
    FileUtils.remove_entry(dump_dir)
  end

  def with_retry_count(record, count = retry_count)
    record.verification_state_object.update!(verification_retry_count: count)
    record
  end

  # The catalog pattern is broad on purpose, so the resolution asks storage before destroying
  # anything. Remove the file the factory wrote to make a record genuinely unrecoverable.
  def upload_with_missing_file(verification_failure: failure, count: retry_count)
    failing_upload(verification_failure: verification_failure, count: count).tap do |upload|
      FileUtils.rm_f(upload.absolute_path)
    end
  end

  # Matches the pattern but its file is still on disk, so the storage check should skip it.
  def failing_upload(verification_failure: failure, count: retry_count)
    upload = create(:upload, :verification_failed, verification_failure: verification_failure)

    with_retry_count(upload, count)
  end

  def failing_lfs_object(count: retry_count)
    with_retry_count(create(:lfs_object, :verification_failed, verification_failure: failure), count)
  end

  # The :ee_ci_job_artifact verification traits go through the state machine, which needs a
  # partition the factory does not set, so write the state row directly like the other Geo
  # job artifact specs do.
  def job_artifact_with_missing_file
    create(:ci_job_artifact, :archive).tap do |artifact|
      artifact.job_artifact_state.update!(
        verification_state: Geo::VerificationState::VERIFICATION_STATE_VALUES[:verification_failed],
        verification_failure: failure,
        verification_retry_count: retry_count
      )
      FileUtils.rm_f(artifact.file.path)
    end
  end

  describe '#affected_count' do
    it 'counts matching records of every verifiable blob type' do
      upload_with_missing_file
      failing_lfs_object
      create(:upload, :verification_failed, verification_failure: 'Could not calculate the checksum')

      expect(resolution.affected_count).to eq(2)
    end

    it 'ignores replicables that are excluded from verification' do
      # Same "File is not checksummable" family, but the record left the verification scope with
      # its file intact, so it must never reach a destructive resolution.
      create(:upload, :verification_failed,
        verification_failure: 'File is not checksummable - Upload 1 is excluded from verification')

      expect(resolution.affected_count).to eq(0)
    end

    it 'returns the total count across all matching model types' do
      upload_with_missing_file
      upload_with_missing_file

      expect(resolution.affected_count).to eq(2)
    end

    context 'with the retry-count gate' do
      it 'ignores a record that has not failed verification often enough' do
        upload_with_missing_file(count: described_class::DEFAULT_MIN_RETRY_COUNT - 1)

        expect(resolution.affected_count).to eq(0)
      end

      it 'ignores a record that has never recorded a retry' do
        upload_with_missing_file(count: nil)

        expect(resolution.affected_count).to eq(0)
      end

      it 'counts a record at exactly the threshold' do
        upload_with_missing_file(count: described_class::DEFAULT_MIN_RETRY_COUNT)

        expect(resolution.affected_count).to eq(1)
      end

      context 'when min_retry_count is overridden' do
        it 'counts a record above the lower threshold' do
          upload_with_missing_file(count: 1)

          expect(described_class.new(error_type, min_retry_count: 1).affected_count).to eq(1)
        end

        it 'ignores a record below a higher threshold' do
          upload_with_missing_file(count: described_class::DEFAULT_MIN_RETRY_COUNT)

          expect(described_class.new(error_type, min_retry_count: 99).affected_count).to eq(0)
        end

        it 'applies no gate at all at 0, including records with no recorded retry' do
          upload_with_missing_file(count: nil)

          expect(described_class.new(error_type, min_retry_count: 0).affected_count).to eq(1)
        end
      end
    end

    context 'when the number of matches exceeds the count limit' do
      before do
        stub_const("#{described_class}::COUNT_LIMIT", 1)
      end

      it 'stops counting at the limit and reports the count as capped', :aggregate_failures do
        upload_with_missing_file
        upload_with_missing_file

        expect(resolution.affected_count).to eq(1)
        expect(resolution.count_capped?).to be(true)
      end

      it 'is not capped when the matches stay below the limit', :aggregate_failures do
        expect(resolution.affected_count).to eq(0)
        expect(resolution.count_capped?).to be(false)
      end
    end
  end

  describe '#sample' do
    it 'lists the records it can destroy and reports the other types as manual cleanup' do
      upload = upload_with_missing_file
      failing_lfs_object

      expect(resolution.sample).to contain_exactly(
        "Upload ##{upload.id}",
        a_string_including('LfsObject: 1 records need manual cleanup')
      )
    end
  end

  describe '#apply' do
    it 'destroys uploads whose file is missing and leaves other failures alone', :aggregate_failures do
      upload = upload_with_missing_file
      other_failure = create(:upload, :verification_failed, verification_failure: 'Could not calculate the checksum')

      expect(resolution.apply).to eq(1)
      expect(Upload.exists?(upload.id)).to be(false)
      expect(Upload.exists?(other_failure.id)).to be(true)
    end

    it 'creates a Geo deletion event so secondaries drop their registries' do
      # Events are only created when a secondary is listening.
      create(:geo_node)
      upload_with_missing_file

      expect { resolution.apply }.to change { Geo::Event.where(event_name: 'deleted').count }.by(1)
    end

    it 'leaves a matching record whose file is still in storage', :aggregate_failures do
      # The factory writes the file, so this record matches the pattern but is not missing.
      upload = failing_upload

      expect(resolution.apply).to eq(0)
      expect(Upload.exists?(upload.id)).to be(true)
    end

    it 'does not destroy data types without an automated cleanup path', :aggregate_failures do
      lfs_object = failing_lfs_object

      expect(resolution.apply).to eq(0)
      expect(LfsObject.exists?(lfs_object.id)).to be(true)
    end

    it 'leaves a record that has not failed verification often enough', :aggregate_failures do
      upload = upload_with_missing_file(count: described_class::DEFAULT_MIN_RETRY_COUNT - 1)

      expect(resolution.apply).to eq(0)
      expect(Upload.exists?(upload.id)).to be(true)
    end

    it 'destroys job artifacts whose file is missing' do
      job_artifact = job_artifact_with_missing_file

      expect { resolution.apply }.to change { Ci::JobArtifact.exists?(job_artifact.id) }.from(true).to(false)
    end

    it 'respects the limit' do
      upload_with_missing_file
      upload_with_missing_file

      expect { resolution.apply(limit: 1) }.to change { Upload.count }.by(-1)
    end

    it 'destroys matches spread across batches' do
      stub_const("#{described_class.superclass}::BATCH_SIZE", 1)
      upload_with_missing_file
      upload_with_missing_file

      expect { resolution.apply }.to change { Upload.count }.by(-2)
    end

    it 'writes no recovery dump when there is nothing it can destroy', :aggregate_failures do
      failing_lfs_object

      expect(resolution.apply).to eq(0)
      expect(dump_paths).to be_empty
    end

    describe 'the recovery dump' do
      it 'records one restorable line per destroyed record', :aggregate_failures do
        upload = upload_with_missing_file

        resolution.apply

        expect(dump_paths.size).to eq(1)

        lines = File.readlines(dump_paths.first).map { |line| Gitlab::Json::SafeParser.parse(line) }

        expect(lines.size).to eq(1)
        expect(lines.first['model']).to eq('Upload')
        expect(lines.first['attributes']).to include('id' => upload.id, 'path' => upload.path)
      end

      it 'is not readable by other users, because upload attributes include the secret' do
        upload_with_missing_file

        resolution.apply

        expect(File.stat(dump_paths.first).mode & 0o777).to eq(0o600)
      end

      # Without this a SIGKILL mid-run loses the buffered tail while the rows it describes are
      # already destroyed, which is the one case the dump exists for.
      it 'writes through to the OS rather than buffering in Ruby' do
        upload_with_missing_file
        synced = nil
        allow(resolution).to receive(:write_recovery_dump).and_wrap_original do |original, record|
          synced = resolution.instance_variable_get(:@recovery_dump).sync
          original.call(record)
        end

        resolution.apply

        expect(synced).to be(true)
      end

      it 'destroys nothing and names the override when the directory is not writable',
        :aggregate_failures do
        upload = upload_with_missing_file
        allow(resolution).to receive(:recovery_dump_dir).and_return('/nonexistent-dir')

        expect { resolution.apply }
          .to raise_error(%r{Cannot write the recovery dump to /nonexistent-dir.*RECOVERY_DUMP_DIR}m)
        expect(Upload.exists?(upload.id)).to be(true)
      end

      it 'honours an explicit recovery_dump_dir' do
        elsewhere = Dir.mktmpdir
        resolution = described_class.new(error_type, recovery_dump_dir: elsewhere)
        upload_with_missing_file

        resolution.apply

        expect(Dir.glob(File.join(elsewhere, '*.jsonl')).size).to eq(1)
      ensure
        FileUtils.remove_entry(elsewhere)
      end

      context 'when every candidate is skipped' do
        it 'leaves no empty dump behind and stops naming it', :aggregate_failures do
          # Matches and is destroyable, but its file is still on disk, so it is skipped.
          failing_upload

          destroyed = resolution.apply

          expect(destroyed).to eq(0)
          expect(dump_paths).to be_empty
          expect(resolution.summary(destroyed)).not_to include('Recovery dump:')
        end
      end
    end
  end

  describe '#summary' do
    it 'reports what was destroyed, skipped and left for manual cleanup' do
      upload_with_missing_file
      failing_upload
      failing_lfs_object

      destroyed = resolution.apply

      expect(resolution.summary(destroyed)).to include(
        'Destroyed 1 records whose file is missing on the primary.',
        'Skipped 1 records because their file is still in storage.',
        'LfsObject: 1 records need manual cleanup'
      )
    end

    it 'names the recovery dump so the operator knows where the undo lives' do
      upload_with_missing_file

      destroyed = resolution.apply

      expect(resolution.summary(destroyed)).to include("Recovery dump: #{dump_paths.first}")
    end

    it 'reports records that could not be destroyed' do
      upload_with_missing_file
      allow_next_found_instance_of(Upload) do |upload|
        allow(upload).to receive(:destroy!).and_raise(ActiveRecord::InvalidForeignKey)
      end

      destroyed = resolution.apply

      expect(resolution.summary(destroyed)).to include(
        '1 records could not be destroyed, see the Geo log.'
      )
    end

    it 'puts each sentence on its own line, so multiple manual-cleanup types stay readable' do
      failing_lfs_object
      create(:pages_deployment, :verification_failed, verification_failure: failure).then do |deployment|
        with_retry_count(deployment)
      end

      expect(resolution.summary(0).split("\n").size).to be > 2
    end
  end

  # Detection is meant to be wide, and the guard in verification_state_class drops any model whose
  # state table it cannot page. That drop is silent, so assert the invariant here instead: a new
  # blob replicable that breaks it fails CI rather than quietly vanishing from the report.
  describe 'the state-table invariant every blob replicable has to satisfy' do
    let(:blob_models) { resolution.send(:verification_enabled_blob_models) }

    it 'covers more than a handful of replicables' do
      expect(blob_models.size).to be > 20
    end

    it 'stores verification state in a table the cleanup tooling can filter', :aggregate_failures do
      blob_models.each do |model|
        state_class = model.verification_state_table_class

        expect(state_class).to respond_to(:with_verification_failure_matching),
          "#{model.name}: #{state_class} does not include Geo::VerificationStateDefinition"
      end
    end

    # Six state tables have their own surrogate `id` primary key, so the model id lives in a
    # different column and verification_state_model_key is the only correct way to find it.
    it 'exposes the model id in a real column named by verification_state_model_key',
      :aggregate_failures do
      blob_models.each do |model|
        state_class = model.verification_state_table_class
        column = model.verification_state_model_key.to_s

        expect(state_class.column_names).to include(column),
          "#{model.name}: #{state_class.table_name} has no #{column} column"
      end
    end

    it 'keeps every blob replicable in scope, so nothing is silently dropped', :aggregate_failures do
      blob_models.each do |model|
        expect(resolution.send(:verification_state_class, model)).to be_present,
          "#{model.name} was dropped by the verification_state_class guard"
      end
    end
  end

  # The upload partition rollout moves verification off upload_states and onto the per-partition
  # state tables. Which table this reads has to follow that switch, or the tool reports zero
  # while uploads are genuinely broken.
  # See https://gitlab.com/groups/gitlab-org/-/work_items/20933 and
  # https://gitlab.com/gitlab-org/gitlab/-/work_items/589924.
  describe 'upload coverage across the partition rollout' do
    def model_classes
      resolution.send(:model_classes)
    end

    context 'when the parent Upload replicator owns verification' do
      it 'reads upload_states once and ignores the dual-written partition tables',
        :aggregate_failures do
        expect(model_classes).to include(::Upload)
        expect(model_classes.count { |model| model <= ::Upload }).to eq(1)
        expect(model_classes).not_to include(Geo::ProjectUpload)
      end
    end

    context 'when the parent Upload replicator has been switched off' do
      before do
        stub_feature_flags(
          geo_upload_replication: false,
          geo_upload_force_primary_checksumming: false,
          geo_project_upload_replication: true
        )
      end

      it 'reads the partition state tables instead of the abandoned upload_states',
        :aggregate_failures do
        expect(model_classes).to include(Geo::ProjectUpload)
        expect(model_classes).not_to include(::Upload)
      end

      it 'still counts and destroys a partition record whose file is missing', :aggregate_failures do
        upload = upload_with_missing_file
        # The partition state row already exists: uploads are list-partitioned on model_type, so
        # a project-owned upload is routed into project_uploads and its state row is dual-written.
        Geo::ProjectUploadState.find_by!(project_upload_id: upload.id).update!(
          verification_state: Geo::VerificationState::VERIFICATION_STATE_VALUES[:verification_failed],
          verification_failure: failure,
          verification_retry_count: retry_count
        )

        expect(resolution.affected_count).to eq(1)
        expect { resolution.apply }.to change { Upload.exists?(upload.id) }.from(true).to(false)
      end
    end
  end

  context 'on a secondary site' do
    it 'acts on nothing, because this cleanup belongs to the primary', :aggregate_failures do
      upload_with_missing_file
      stub_current_geo_node(create(:geo_node))

      expect(resolution.affected_count).to eq(0)
      expect { resolution.apply }.not_to change { Upload.count }
    end
  end

  context 'when the error type has no match pattern' do
    let(:error_type) { instance_double(Geo::Errors::ErrorType, match_pattern: nil) }

    it 'acts on nothing', :aggregate_failures do
      upload_with_missing_file

      expect(resolution.affected_count).to eq(0)
      expect(resolution.sample).to eq([])
      expect { resolution.apply }.not_to change { Upload.count }
    end
  end
end

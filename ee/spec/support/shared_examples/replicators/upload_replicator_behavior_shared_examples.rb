# frozen_string_literal: true

# Include these shared examples in specs of Replicators that include
# Geo::Concerns::UploadReplicatorBehavior.
#
# Required let variables:
#
# - model_record: A valid, persisted instance of the upload partition model
#                 class (e.g. Geo::AbuseReportUpload, Geo::ProjectUpload).
#
RSpec.shared_examples 'a blob replicator with upload replicator behavior' do
  describe "#predownload_validation_failure" do
    context "when upload is valid and has an associated model/owner" do
      it "returns nil" do
        expect(replicator.predownload_validation_failure).to be_nil
      end
    end

    context "when upload is orphaned from its own model association" do
      let(:expected_error_message) do
        "The model which owns this #{replicator.replicable_name} is missing. " \
          "#{replicator.replicable_name} ID##{model_record.id}, " \
          "#{model_record.model_type} ID##{model_record.model_id}"
      end

      before do
        # break the model association on the upload
        model_record.model_id = -1
        model_record.save!(validate: false)
        model_record.reload
      end

      it "returns an error string" do
        expect(replicator.predownload_validation_failure).to eq(expected_error_message)
      end
    end
  end

  describe "#calculate_checksum override" do
    let(:upload_fixture_file_checksum) { 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' }
    let(:remote_file_size_checksum) { '065112' }

    shared_context "with remotely stored upload" do
      before do
        file_double = instance_double(CarrierWave::SanitizedFile, exists?: true, size: 65112)
        uploader = replicator.carrierwave_uploader
        allow(uploader).to receive_messages(file_storage?: false, file: file_double)
        allow(replicator).to receive(:carrierwave_uploader).and_return(uploader)
      end
    end

    context "when upload has an associated model/owner" do
      it "returns the upload file checksum" do
        expect(replicator.calculate_checksum).to eq(upload_fixture_file_checksum)
      end

      context "when the file is remotely stored" do
        include_context "with remotely stored upload"

        it "returns the file size as checksum" do
          expect(replicator.calculate_checksum).to eq(remote_file_size_checksum)
        end
      end
    end

    context "when upload is orphaned from its own model association" do
      let(:expected_error_message) do
        "The model which owns this #{replicator.replicable_name} is missing. " \
          "#{replicator.replicable_name} ID##{model_record.id}, " \
          "#{model_record.model_type} ID##{model_record.model_id}"
      end

      before do
        # break the model association on the upload
        model_record.model_id = -1
        model_record.save!(validate: false)
        model_record.reload
      end

      it "raises a clearer error" do
        expect { replicator.calculate_checksum }.to raise_error(expected_error_message)
      end
    end

    context "when the parent upload_state has not been verified yet" do
      it "falls back to the file-based checksum calculation" do
        # upload_state is pending by default
        expect(replicator.calculate_checksum).to eq(upload_fixture_file_checksum)
      end

      context "when the file is remotely stored" do
        include_context "with remotely stored upload"

        it "falls back to the object storage checksum calculation" do
          expect(replicator).not_to receive(:sha256_hexdigest)
          expect(replicator.calculate_checksum).to eq(remote_file_size_checksum)
        end
      end
    end

    context "when the parent upload_state verification has failed" do
      before do
        model_record.upload_state.update!(
          verification_state: model_record.class.verification_state_value(:verification_failed),
          verification_failure: 'Could not calculate the checksum'
        )
        model_record.reload
      end

      it "falls back to the file-based checksum calculation" do
        expect(replicator.calculate_checksum).to eq(upload_fixture_file_checksum)
      end

      context "when the file is remotely stored" do
        include_context "with remotely stored upload"

        it "falls back to the object storage checksum calculation" do
          expect(replicator).not_to receive(:sha256_hexdigest)
          expect(replicator.calculate_checksum).to eq(remote_file_size_checksum)
        end
      end
    end

    context "when the parent upload_state has been verified successfully" do
      let(:parent_checksum) { 'abc123def456abc123def456abc123def456abc123def456abc123def456abc1' }

      before do
        model_record.upload_state.update!(
          verification_state: model_record.class.verification_state_value(:verification_succeeded),
          verification_checksum: parent_checksum
        )
        model_record.reload
      end

      it "adopts the parent checksum without reading the file" do
        expect(model_record).not_to receive(:sha256_hexdigest)
        expect(replicator.calculate_checksum).to eq(parent_checksum)
      end

      context "when the file is remotely stored" do
        include_context "with remotely stored upload"

        it "adopts the parent checksum without calling format_file_size_for_checksum" do
          expect(replicator).not_to receive(:format_file_size_for_checksum)
          expect(replicator.calculate_checksum).to eq(parent_checksum)
        end
      end
    end
  end

  describe "#parent_upload_verification_succeeded?" do
    context "when the parent upload_state is nil" do
      before do
        allow(model_record).to receive(:upload_state).and_return(nil)
      end

      it "returns false" do
        expect(replicator.parent_upload_verification_succeeded?).to be(false)
      end
    end

    context "when the parent upload_state has not been verified yet" do
      it "returns false" do
        expect(replicator.parent_upload_verification_succeeded?).to be(false)
      end
    end

    context "when the parent upload_state verification has failed" do
      before do
        model_record.upload_state.update!(
          verification_state: model_record.class.verification_state_value(:verification_failed),
          verification_failure: 'Could not calculate the checksum'
        )
        model_record.reload
      end

      it "returns false" do
        expect(replicator.parent_upload_verification_succeeded?).to be(false)
      end
    end

    context "when the parent upload_state has been verified successfully" do
      before do
        model_record.upload_state.update!(
          verification_state: model_record.class.verification_state_value(:verification_succeeded),
          verification_checksum: 'abc123'
        )
        model_record.reload
      end

      it "returns true" do
        expect(replicator.parent_upload_verification_succeeded?).to be(true)
      end

      context "when the replicable is mutable" do
        before do
          allow(replicator).to receive(:immutable?).and_return(false)
        end

        it "returns false to avoid serving a potentially stale checksum" do
          expect(replicator.parent_upload_verification_succeeded?).to be(false)
        end
      end
    end
  end

  describe "#model_is_missing_error_message" do
    context "when upload has an associated model/owner" do
      it "returns nil" do
        expect(replicator.model_is_missing_error_message).to be_nil
      end
    end

    context "when upload is orphaned from its own model association" do
      let(:expected_error_message) do
        "The model which owns this #{replicator.replicable_name} is missing. " \
          "#{replicator.replicable_name} ID##{model_record.id}, " \
          "#{model_record.model_type} ID##{model_record.model_id}"
      end

      before do
        # break the model association on the upload
        model_record.model_id = -1
        model_record.save!(validate: false)
        model_record.reload
      end

      it "returns an error message" do
        expect(replicator.model_is_missing_error_message).to eq(expected_error_message)
      end
    end
  end
end

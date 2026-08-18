# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::UploadRemediationsWorker, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }

  let(:worker) { described_class.new }
  let(:diff_content) { 'diff --git a/file.txt b/file.txt' }
  let(:checksum) { Digest::SHA256.hexdigest(diff_content) }
  let(:remediation) do
    create(:vulnerabilities_remediation, project: project, checksum: checksum,
      file: Tempfile.new.tap { |f| f.write(diff_content) }, summary: 'Test Summary')
  end

  describe '#perform' do
    subject(:perform) { worker.perform(remediation_diffs_by_id) }

    context 'when remediations exist' do
      let(:remediation_diffs_by_id) { { remediation.id.to_s => diff_content } }

      it 'uploads the file for each remediation' do
        expect { perform }.not_to raise_error

        remediation.reload
        expect(remediation.diff).to eq(diff_content)
      end
    end

    context 'when a remediation does not exist' do
      let(:remediation_diffs_by_id) { { non_existing_record_id.to_s => diff_content } }

      it 'logs a warning and continues' do
        expect(Sidekiq.logger).to receive(:warn).with(hash_including(
          'message' => 'Remediation not found, skipping upload'
        ))

        perform
      end
    end

    context 'when an upload fails' do
      let(:remediation_diffs_by_id) { { remediation.id.to_s => diff_content } }

      before do
        allow(Vulnerabilities::Remediation).to receive(:find_by_id).with(remediation.id.to_s).and_return(remediation)
        allow(remediation).to receive(:update).and_raise(StandardError, 'upload error')
      end

      it 'logs an error and continues' do
        expect(Sidekiq.logger).to receive(:error).with(hash_including(
          'message' => 'Failed to upload remediation file',
          'error' => 'upload error'
        ))

        perform
      end
    end

    context 'with multiple remediations' do
      let(:diff_content_2) { 'diff --git a/other.txt b/other.txt' }
      let(:checksum_2) { Digest::SHA256.hexdigest(diff_content_2) }
      let(:remediation_2) do
        create(:vulnerabilities_remediation, project: project, checksum: checksum_2,
          file: Tempfile.new.tap { |f| f.write(diff_content_2) }, summary: 'Other Summary')
      end

      let(:remediation_diffs_by_id) do
        {
          remediation.id.to_s => diff_content,
          remediation_2.id.to_s => diff_content_2
        }
      end

      it 'uploads files for all remediations' do
        perform

        expect(remediation.reload.diff).to eq(diff_content)
        expect(remediation_2.reload.diff).to eq(diff_content_2)
      end
    end
  end
end

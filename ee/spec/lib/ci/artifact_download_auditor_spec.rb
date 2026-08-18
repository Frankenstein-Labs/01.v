# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::ArtifactDownloadAuditor, feature_category: :compliance_management do
  let_it_be(:build) { create :ci_build, :artifacts }

  describe '#execute' do
    context 'with filename' do
      it 'includes given filename in additional_details' do
        filename = 'ci_build_artifacts.zip'

        expect(Gitlab::Audit::Auditor).to receive(:audit)
          .with(hash_including(additional_details: hash_including({ filename: filename })))

        described_class.new(build: build, filename: build.job_artifacts_archive.filename).execute
      end
    end

    context 'without filename' do
      it 'defaults to UNKNOWN_FILENAME in additional_details' do
        expect(Gitlab::Audit::Auditor).to receive(:audit)
          .with(hash_including(additional_details: hash_including({ filename: described_class::UNKNOWN_FILENAME })))

        described_class.new(build: build, filename: nil).execute
      end
    end

    context 'without expiry' do
      it 'includes message with unlimited expiration' do
        expect(Gitlab::Audit::Auditor).to receive(:audit)
          .with(hash_including(name: described_class::NAME,
            message:  'Downloaded artifact ci_build_artifacts.zip (expiration: never)',
            additional_details: hash_including(expire_at: 'never')
          )).and_call_original

        described_class.new(build: build, filename: build.job_artifacts_archive.filename).execute
      end
    end

    context 'with expiry', time_travel_to: Time.zone.parse("2022-02-22 00:00:00 UTC+0") do
      let(:artifact) { create :ci_job_artifact, :archive, expire_at: Time.zone.now }
      let(:build) { artifact.job }

      it 'includes message with unlimited expiration' do
        artifact
        never_expire_msg = 'Downloaded artifact ci_build_artifacts.zip (expiration: 2022-02-22T00:00:00Z)'

        expect(Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(message: never_expire_msg))

        described_class.new(build: build, filename: build.job_artifacts_archive.filename).execute
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::SecretDetectionSha, feature_category: :vulnerability_management do
  let(:default_sha) { ::Vulnerabilities::Finding::SECRET_DETECTION_DEFAULT_COMMIT_SHA }
  let(:commit_sha) { 'abc123def456abc123def456abc123def456abc1' }

  shared_examples 'secret_detection_sha behavior' do
    subject(:secret_detection_sha) { finding.secret_detection_sha }

    context 'when the finding is not secret detection' do
      let(:finding) { non_secret_detection_finding }

      it { is_expected.to be_nil }
    end

    context 'when the finding is secret detection' do
      context 'when location contains a commit SHA' do
        let(:finding) { secret_detection_finding_with_location(commit: { sha: commit_sha }) }

        it { is_expected.to eq(commit_sha) }
      end

      context 'when location contains the placeholder SHA' do
        let(:finding) { secret_detection_finding_with_location(commit: { sha: default_sha }) }

        it { is_expected.to be_nil }
      end

      context 'when location does not contain a commit key' do
        let(:finding) { secret_detection_finding_with_location(file: 'config/secrets.yml') }

        it { is_expected.to be_nil }
      end
    end
  end

  describe '#secret_detection_sha' do
    context 'with Vulnerabilities::Finding' do
      let_it_be(:project) { create(:project, :repository) }
      let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

      let(:non_secret_detection_finding) do
        create(:vulnerabilities_finding, :sast, project: project, latest_pipeline_id: pipeline.id)
      end

      def secret_detection_finding_with_location(location_attrs)
        location = location_attrs.transform_keys(&:to_s).transform_values do |v|
          v.is_a?(Hash) ? v.transform_keys(&:to_s) : v
        end
        create(:vulnerabilities_finding, :secret_detection, project: project,
          latest_pipeline_id: pipeline.id, location: location)
      end

      include_examples 'secret_detection_sha behavior'

      context 'when location is nil' do
        let(:finding) do
          create(:vulnerabilities_finding, :secret_detection, project: project,
            latest_pipeline_id: pipeline.id, location: nil)
        end

        subject(:secret_detection_sha) { finding.secret_detection_sha }

        it { is_expected.to be_nil }
      end
    end

    context 'with Security::Finding' do
      let_it_be(:pipeline) { create(:ee_ci_pipeline) }
      let_it_be(:secret_detection_scan) do
        create(:security_scan, :latest_successful, scan_type: :secret_detection, pipeline: pipeline)
      end

      let_it_be(:sast_scan) do
        create(:security_scan, :latest_successful, scan_type: :sast, pipeline: pipeline)
      end

      let(:non_secret_detection_finding) do
        create(:security_finding, :with_finding_data, scan: sast_scan)
      end

      def secret_detection_finding_with_location(location_attrs)
        create(:security_finding, :with_finding_data, scan: secret_detection_scan,
          location: location_attrs)
      end

      include_examples 'secret_detection_sha behavior'
    end
  end
end

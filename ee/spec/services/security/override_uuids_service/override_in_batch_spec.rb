# frozen_string_literal: true

require 'rspec'
require 'securerandom'
require 'spec_helper'

RSpec.describe Security::OverrideUuidsService::OverrideInBatch, feature_category: :vulnerability_management do
  describe '#execute' do
    let(:scanner) do
      ::Gitlab::Ci::Reports::Security::Scanner.new(
        external_id: "gitlab-sast",
        name: "gitlab-sast",
        vendor: "gitlab",
        version: "1.0.0"
      )
    end

    let(:vulnscanner) do
      Vulnerabilities::Scanner.new(
        name: 'gitlab-sast',
        external_id: 'gitlab-sast'
      )
    end

    let(:scanners) { { 'gitlab-sast' => vulnscanner } }
    let(:scope_offset) { 'scope_offset' }
    let(:scope_offset_compressed) { 'scope_offset_compressed' }
    let(:location) { 'location' }

    def create_vulnerability(primary_identifier_fingerprint)
      ident = Vulnerabilities::Identifier.new(
        fingerprint: primary_identifier_fingerprint
      )

      finding = Vulnerabilities::Finding.new
      finding.uuid = ::Security::VulnerabilityUUID.generate(
        report_type: "", primary_identifier_fingerprint: SecureRandom.alphanumeric(8),
        location_fingerprint: "", project_id: "", tracked_context: nil)

      finding.primary_identifier = ident
      finding.identifiers = [ident]
      finding.scanner = vulnscanner
      finding
    end

    def create_vulnerability_with_signatures(signatures, primary_identifier_fingerprint)
      lookup_hash = {}
      finding = create_vulnerability(primary_identifier_fingerprint)
      signatures.each do |algo, sha|
        finding_signature = Vulnerabilities::FindingSignature.new(
          algorithm_type: algo,
          signature_sha: sha,
          finding: finding
        )
        lookup_hash[sha] = finding_signature
      end
      lookup_hash
    end

    def create_finding_with_signatures(signatures, initial_uuid, ident = nil)
      if ident.nil?
        ident = ::Gitlab::Ci::Reports::Security::Identifier.new(
          external_type: 'semgrep_id',
          external_id: 'external_id',
          name: 'name',
          url: ''
        )
      end

      sigs = signatures.map do |algo, sha|
        ::Gitlab::Ci::Reports::Security::FindingSignature.new(
          algorithm_type: algo,
          signature_value: sha
        )
      end

      finding = ::Gitlab::Ci::Reports::Security::Finding.new(
        name: "",
        scanner: scanner,
        signatures: sigs,
        identifiers: [ident],
        location: nil,
        evidence: nil,
        metadata_version: nil,
        original_data: nil,
        report_type: nil,
        scan: nil
      )
      finding.uuid = initial_uuid
      finding
    end

    def mocked_test_obj(pipeline_data_array, db_data_hash)
      override = described_class.new(nil, pipeline_data_array, scanners, Set.new, Set.new, nil)
      allow(override).to receive_messages(existing_signatures: db_data_hash, existing_finding_by_location: nil)
      override
    end

    def signature_key(pipeline_data)
      pipeline_data.signatures.first.signature_hex
    end

    def ident_fingerprint(pipeline_data)
      pipeline_data.identifiers.first.fingerprint
    end

    it 'override UUID with single matching algorithms' do
      pipeline_data = create_finding_with_signatures(
        [
          [scope_offset_compressed, "sig1"]
        ],
        "uuid1")
      db_data_hash = {}
      db_data_hash.merge!(
        create_vulnerability_with_signatures(
          [
            [scope_offset_compressed, signature_key(pipeline_data)]
          ],
          ident_fingerprint(pipeline_data)
        )
      )

      mocked_test_obj([pipeline_data], db_data_hash).execute

      expect(pipeline_data.uuid).not_to eq("uuid1")
      expect(pipeline_data.uuid).to eq(db_data_hash[signature_key(pipeline_data)].finding.uuid)
    end

    it '(upgrade) override UUID with matching highest priority signature in db' do
      pipeline_data = [
        create_finding_with_signatures(
          [
            [scope_offset, "sig1"]
          ],
          "uuid1"
        ),
        create_finding_with_signatures(
          [
            [scope_offset_compressed, "sig2"]
          ],
          "uuid2"
        )
      ]
      db_data_hash = {}
      db_data_hash.merge!(
        create_vulnerability_with_signatures(
          [
            [scope_offset_compressed, signature_key(pipeline_data[0])]
          ],
          ident_fingerprint(pipeline_data[0])
        )
      )

      mocked_test_obj(pipeline_data, db_data_hash).execute
      expect(pipeline_data[0].uuid).not_to eq("uuid1")
      expect(pipeline_data[0].uuid).to eq(db_data_hash[signature_key(pipeline_data[0])].finding.uuid)
      expect(pipeline_data[1].uuid).to eq("uuid2")
    end

    it 'UUID is not overwritten without a matching primary identifier' do
      pipeline_data = [
        create_finding_with_signatures(
          [
            [scope_offset, "sig1"]
          ],
          "uuid1"
        ),
        create_finding_with_signatures(
          [
            [scope_offset_compressed, "sig2"]
          ],
          "uuid2"
        ),
        create_finding_with_signatures(
          [
            [location, "sig3"]
          ],
          "uuid3"
        )
      ]
      db_data_hash = {}
      db_data_hash.merge!(
        create_vulnerability_with_signatures(
          [
            [scope_offset_compressed, signature_key(pipeline_data[0])]
          ],
          "non-matching"
        )
      )

      mocked_test_obj(pipeline_data, db_data_hash).execute
      expect(pipeline_data[0].uuid).to eq("uuid1")
      expect(pipeline_data[1].uuid).to eq("uuid2")
      expect(pipeline_data[2].uuid).to eq("uuid3")
    end

    it 'UUID is overwritten without a higher priority security finding signature' do
      pipeline_data = [
        create_finding_with_signatures(
          [
            [scope_offset, "abc"],
            [scope_offset_compressed, "cde"]
          ],
          "uuid2"
        ),
        create_finding_with_signatures(
          [
            [scope_offset, "sig1"],
            [scope_offset_compressed, "sig2"]
          ],
          "uuid1"
        )
      ]
      db_data_hash = {}
      db_data_hash.merge!(
        create_vulnerability_with_signatures(
          [
            [scope_offset, signature_key(pipeline_data[1])]
          ],
          ident_fingerprint(pipeline_data[1])
        )
      )

      mocked_test_obj(pipeline_data, db_data_hash).execute
      expect(pipeline_data[1].uuid).to eq(db_data_hash[signature_key(pipeline_data[1])].finding.uuid)
    end
  end
end

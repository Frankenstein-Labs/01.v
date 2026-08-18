# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyEntity, feature_category: :dependency_management do
  describe '#as_json' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :repository, :private, :in_group) }
    let_it_be(:group) { project.group }
    let_it_be(:sbom_occurrence) { create(:sbom_occurrence, :mit, :bundler, :with_ancestors, project: project) }
    let(:request_params) { { project: project, group: group, user: user } }
    let(:request) { EntityRequest.new(**request_params) }
    let(:params) { { request: request } }

    subject { described_class.represent(sbom_occurrence, request: request).as_json }

    before_all do
      project.add_developer(user)
    end

    before do
      stub_licensed_features(security_dashboard: true, license_scanning: true)
    end

    it 'renders the proper representation' do
      expect(subject.as_json).to eq({
        "name" => sbom_occurrence.name,
        "occurrence_count" => 1,
        "packager" => sbom_occurrence.packager,
        "policy_dismissals" => [],
        "project_count" => 1,
        "version" => sbom_occurrence.version,
        "licenses" => sbom_occurrence.licenses,
        "component_id" => sbom_occurrence.component_version_id,
        "vulnerability_count" => 0,
        "occurrence_id" => sbom_occurrence.id,
        "malware" => false
      })
    end

    context "when there are no licenses" do
      let_it_be(:sbom_occurrence) { create(:sbom_occurrence, project: project) }

      it 'returns an empty array' do
        expect(subject.as_json['licenses']).to eq([])
      end
    end

    context 'when all required features are unavailable' do
      before do
        stub_licensed_features(security_dashboard: false, license_scanning: false)
      end

      it 'does not include licenses and vulnerabilities' do
        is_expected.not_to match(hash_including(:vulnerabilities, :licenses))
      end
    end

    describe 'malware field' do
      before do
        stub_licensed_features(security_dashboard: true, license_scanning: true)
      end

      it 'exposes the return value of occurrence.malware_status' do
        allow(sbom_occurrence).to receive(:malware_status).and_return(true)
        expect(subject[:malware]).to be true
      end

      context 'when the user cannot read vulnerabilities' do
        before do
          stub_licensed_features(security_dashboard: false, license_scanning: true)
        end

        it 'does not expose the malware field' do
          expect(subject.keys).not_to include(:malware)
        end
      end
    end

    context 'when a license_override_applicator is provided in options' do
      let(:overridden_licenses) do
        [{ 'spdx_identifier' => 'Apache-2.0', 'name' => 'Apache-2.0 License', 'url' => nil }]
      end

      let(:applicator) { instance_double(Security::LicenseOverrideApplicator) }

      subject do
        described_class.represent(sbom_occurrence,
          request: request,
          license_override_applicator: applicator
        ).as_json
      end

      before do
        allow(applicator).to receive(:apply).and_return(overridden_licenses)
      end

      it 'applies license overrides to the licenses field' do
        expect(subject.as_json['licenses']).to include(hash_including('name' => 'Apache-2.0 License'))
      end

      context 'when the occurrence does not expose a purl' do
        before do
          allow(sbom_occurrence).to receive(:purl).and_return(nil)
        end

        it 'passes a nil purl to the applicator' do
          expect(applicator).to receive(:apply).with(sbom_occurrence.licenses,
            purl: nil).and_return(overridden_licenses)
          subject.as_json['licenses']
        end
      end
    end

    context 'when no license_override_applicator is provided' do
      it 'returns the original occurrence licenses' do
        expect(subject.as_json['licenses']).to eq(sbom_occurrence.licenses)
      end
    end
  end
end

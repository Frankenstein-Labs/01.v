# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PackageMetadata::AdvisoryDataObject, feature_category: :software_composition_analysis do
  describe '.create' do
    let(:purl_type) { 'npm' }
    let(:hash) do
      {
        "advisory" =>
          {
            "id" => "d4f176d6-0a07-46f4-9da5-22df92e5efa0",
            "source" => source,
            "title" => "Incorrect Permission Assignment for Critical Resource",
            "description" => "A missing permission check in Jenkins Google Kubernetes Engine Plugin allows attackers " \
                             "with Overall/Read permission to obtain limited information about the scope of a " \
                             "credential with an attacker-specified credentials ID.",
            "cvss_v2" => "AV:N/AC:L/Au:S/C:P/I:N/A:N",
            "cvss_v3" => "CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:L/I:N/A:N",
            "published_date" => "2019-10-16",
            "urls" => ["https://nvd.nist.gov/vuln/detail/CVE-2019-10445",
              "https://jenkins.io/security/advisory/2019-10-16/#SECURITY-1607"],
            "identifiers" =>
              [
                { "type" => "cve", "name" => "CVE-2019-10445", "value" => "CVE-2019-10445",
                  "url" => "https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2019-10445" },
                { "type" => "cwe", "name" => "CWE-1035", "value" => "1035",
                  "url" => "https://cwe.mitre.org/data/definitions/1035.html" },
                { "type" => "cwe", "name" => "CWE-862", "value" => "862",
                  "url" => "https://cwe.mitre.org/data/definitions/862.html" },
                { "type" => "cwe", "name" => "CWE-937", "value" => "937",
                  "url" => "https://cwe.mitre.org/data/definitions/937.html" }
              ]
          },
        "packages" => [
          {
            "name" => "org.jenkins-ci.plugins/google-kubernetes-engine",
            "affected_range" => "(,0.7.0]",
            "solution" => "Upgrade to version 0.8 or above.",
            "fixed_versions" => ["0.8"]
          }
        ],
        "additional_fields" => {
          "advisory" => {
            "cvss_v4" => "CVSS:4.0/AV:L/AC:L/AT:P/PR:L/UI:N/VC:H/VI:H/VA:H/SC:N/SI:N/SA:N"
          }
        }
      }
    end

    let(:source) { 'glad' }

    subject(:create) { described_class.create(hash, purl_type) }

    it { is_expected.to be_kind_of(described_class) }

    it do
      is_expected.to match(have_attributes(advisory_xid: 'd4f176d6-0a07-46f4-9da5-22df92e5efa0', source_xid: 'glad',
        title: "Incorrect Permission Assignment for Critical Resource",
        description: "A missing permission check in Jenkins Google Kubernetes Engine Plugin allows attackers with " \
                     "Overall/Read permission to obtain limited information about the scope of a credential with an " \
                     "attacker-specified credentials ID.",
        cvss_v2: "AV:N/AC:L/Au:S/C:P/I:N/A:N",
        cvss_v3: "CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:L/I:N/A:N",
        cvss_v4: "CVSS:4.0/AV:L/AC:L/AT:P/PR:L/UI:N/VC:H/VI:H/VA:H/SC:N/SI:N/SA:N",
        published_date: "2019-10-16",
        urls: ["https://nvd.nist.gov/vuln/detail/CVE-2019-10445",
          "https://jenkins.io/security/advisory/2019-10-16/#SECURITY-1607"],
        identifiers: [
          { type: "cve", name: "CVE-2019-10445", value: "CVE-2019-10445",
            url: "https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2019-10445" },
          { type: "cwe", name: "CWE-1035", value: "1035", url: "https://cwe.mitre.org/data/definitions/1035.html" },
          { type: "cwe", name: "CWE-862", value: "862", url: "https://cwe.mitre.org/data/definitions/862.html" },
          { type: "cwe", name: "CWE-937", value: "937", url: "https://cwe.mitre.org/data/definitions/937.html" }
        ],
        affected_packages: [
          have_attributes(purl_type: purl_type,
            package_name: 'org.jenkins-ci.plugins/google-kubernetes-engine', affected_range: '(,0.7.0]',
            solution: 'Upgrade to version 0.8 or above.', fixed_versions: ["0.8"])
        ],
        cve: "CVE-2019-10445"))
    end

    it 'extracts cvss_v4 from additional_fields' do
      expect(create.cvss_v4).to eq("CVSS:4.0/AV:L/AC:L/AT:P/PR:L/UI:N/VC:H/VI:H/VA:H/SC:N/SI:N/SA:N") # rubocop:disable Rails/SaveBang -- subject comes from outside of context
    end

    it 'sets cvss_v4 to nil when additional_fields is absent' do
      hash_without = hash.except('additional_fields')
      expect(described_class.create(hash_without, purl_type).cvss_v4).to be_nil
    end

    context 'when an attribute is missing' do
      using RSpec::Parameterized::TableSyntax

      subject(:create!) do
        described_class.create({ 'advisory' => hash['advisory'].except(attribute.to_s),
          'packages' => hash['packages'] }, purl_type)
      end

      context 'and it is on the advisory hash' do
        where(:attribute, :required) do
          :title | false
          :description  | false
          :cvvs_v2      | false
          :cvvs_v3      | false
          :urls         | false
          :identifiers  | false
          :cve          | false
          :id           | true
          :source       | true
        end

        with_them do
          specify do
            required ? expect { create! }.to(raise_error(ArgumentError)) : expect { create! }.not_to(raise_error)
          end
        end
      end

      context 'and it is packages' do
        subject(:create!) { described_class.create(hash.except('packages'), purl_type) }

        specify { expect { create! }.to raise_error(ArgumentError) }
      end
    end

    context 'with source attribute' do
      using RSpec::Parameterized::TableSyntax

      where(:source, :expect_source_to_be_valid) do
        'glad'          | true
        'trivy-db'      | true
        'gLad'          | false
        'tRiVy-Db'      | false
        'trivy'         | false
        'gemnasium-db'  | false
        'foo'           | false
        nil             | false
      end

      with_them do
        specify do
          if expect_source_to_be_valid
            expect(create).to be_kind_of(described_class)
          else
            expect { create }.to(raise_error(ArgumentError, /Unsupported advisory source/)) # rubocop:disable Rails/SaveBang -- subject comes from outside of context, no need to override for this case
          end
        end
      end
    end

    context 'when there is no CVE identifier' do
      let(:hash) do
        {
          "advisory" =>
            {
              "id" => "test-id",
              "source" => "glad",
              "published_date" => "2023-01-01",
              "identifiers" => [
                { "type" => "cwe", "name" => "CWE-79", "value" => "79" }
              ]
            },
          "packages" => []
        }
      end

      it 'sets cve to nil' do
        expect(described_class.create(hash, purl_type).cve).to be_nil
      end
    end

    context 'when the CVE type is in different case' do
      let(:hash) do
        {
          "advisory" =>
            {
              "id" => "test-id",
              "source" => "glad",
              "published_date" => "2023-01-01",
              "identifiers" => [
                { "type" => "CVe", "name" => "CVE-2021-5678", "value" => "CVE-2021-5678" }
              ]
            },
          "packages" => []
        }
      end

      it 'extracts the CVE name case-insensitively' do
        expect(described_class.create(hash, purl_type).cve).to eq('CVE-2021-5678')
      end
    end
  end
end

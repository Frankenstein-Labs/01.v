# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Identifier, feature_category: :vulnerability_management do
  using RSpec::Parameterized::TableSyntax

  describe 'associations' do
    it { is_expected.to have_many(:finding_identifiers).class_name('Vulnerabilities::FindingIdentifier') }
    it { is_expected.to have_many(:findings).class_name('Vulnerabilities::Finding') }
    it { is_expected.to have_many(:primary_findings).class_name('Vulnerabilities::Finding') }
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    let!(:identifier) { create(:vulnerabilities_identifier) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:external_type) }
    it { is_expected.to validate_presence_of(:external_id) }
    it { is_expected.to validate_presence_of(:fingerprint) }
    it { is_expected.to validate_length_of(:fingerprint).is_at_most(40) }
    # Uniqueness validation doesn't work with binary columns. See TODO in class file
    # it { is_expected.to validate_uniqueness_of(:fingerprint).scoped_to(:project_id) }
  end

  describe "#url" do
    context "with allowed schemas" do
      let(:identifier_http) { build(:vulnerabilities_identifier, url: "http://example.org") }
      let(:identifier_https) { build(:vulnerabilities_identifier, url: "https://example.org") }
      let(:identifier_ftp) { build(:vulnerabilities_identifier, url: "ftp://example.org") }

      it 'is valid', :aggregate_failures do
        expect(identifier_http.valid?).to be_truthy
        expect(identifier_https.valid?).to be_truthy
        expect(identifier_ftp.valid?).to be_truthy
      end
    end

    context "with scheme other than HTTP(S)" do
      let(:identifier) { build(:vulnerabilities_identifier, url: "gopher://example.org") }

      it "is not valid" do
        expect(identifier.valid?).to be_falsey
      end
    end

    context "with invalid url" do
      let(:identifier) { build(:vulnerabilities_identifier, url: "invalid:example.org") }

      it "is not valid" do
        expect(identifier.valid?).to be_falsey
      end
    end

    context "without URL" do
      let(:identifier) { build(:vulnerabilities_identifier, url: nil) }

      it "is valid" do
        expect(identifier.valid?).to be_truthy
      end
    end
  end

  describe '.with_fingerprint' do
    let(:fingerprint) { 'f5724386167705667ae25a1390c0a516020690ba' }

    subject { described_class.with_fingerprint(fingerprint) }

    context 'when identifier has the corresponding fingerprint' do
      let!(:identifier) { create(:vulnerabilities_identifier, fingerprint: fingerprint) }

      it 'selects the identifier' do
        is_expected.to match_array([identifier])
      end
    end

    context 'when identifier does not have the corresponding fingerprint' do
      let!(:identifier) { create(:vulnerabilities_identifier) }

      it 'does not select the identifier' do
        is_expected.to be_empty
      end
    end
  end

  describe '.with_external_type' do
    let(:external_type_scope) { 'cwe' }
    let(:external_type_not_in_scope) { 'cve' }

    subject { described_class.with_external_type(external_type_scope) }

    context 'when identifier has the corresponding external_type' do
      let!(:identifier) { create(:vulnerabilities_identifier, external_type: external_type_scope) }

      it 'selects the identifier' do
        is_expected.to match_array([identifier])
      end
    end

    context 'when identifier does not have the corresponding external_type' do
      let!(:identifier) { create(:vulnerabilities_identifier, external_type: external_type_not_in_scope) }

      it 'does not select the identifier' do
        is_expected.to be_empty
      end
    end
  end

  describe 'type check methods' do
    shared_examples_for 'type check method' do |method:|
      with_them do
        let(:identifier) { build_stubbed(:vulnerabilities_identifier, external_type: external_type) }

        subject { identifier.public_send(method) }

        it { is_expected.to be(expected_value) }
      end
    end

    describe '#cve?' do
      it_behaves_like 'type check method', method: :cve? do
        where(:external_type, :expected_value) do
          'CVE' | true
          'cve' | true
          'CWE' | false
          'cwe' | false
          'foo' | false
        end
      end
    end

    describe '#cwe?' do
      it_behaves_like 'type check method', method: :cwe? do
        where(:external_type, :expected_value) do
          'CWE' | true
          'cwe' | true
          'CVE' | false
          'cve' | false
          'foo' | false
        end
      end
    end

    describe '#other?' do
      it_behaves_like 'type check method', method: :other? do
        where(:external_type, :expected_value) do
          'CWE' | false
          'cwe' | false
          'CVE' | false
          'cve' | false
          'foo' | true
        end
      end
    end

    describe '.search_identifier_name' do
      let_it_be(:project) { create(:project) }
      let_it_be(:project_2) { create(:project) }

      let_it_be(:identifier) do
        create(:vulnerabilities_identifier, name: 'CVE-2023-1234',
          external_type: 'cve', external_id: 'CVE-2023-1234', project: project)
      end

      let_it_be(:identifier_2) do
        create(:vulnerabilities_identifier, name: 'CWE-1234',
          external_type: 'cwe', external_id: '1234', project: project)
      end

      let_it_be(:identifier_3) do
        create(:vulnerabilities_identifier, name: 'CVE-2019-10086',
          external_type: 'cve', external_id: 'CVE-2019-10086	', project: project_2)
      end

      context "when searching with a partial match" do
        it "returns matching identifiers for the project" do
          result = described_class.search_identifier_name(project, "-123")
          expect(result).to contain_exactly("CVE-2023-1234", 'CWE-1234')
        end
      end

      context "when searching with a case-insensitive match" do
        it "returns matching identifiers regardless of case" do
          result = described_class.search_identifier_name(project, "cve")
          expect(result).to contain_exactly("CVE-2023-1234")
        end
      end

      context "when there are no matches" do
        it "returns an empty array" do
          result = described_class.search_identifier_name(project, "Nonexistent")
          expect(result).to be_empty
        end
      end

      context "when multiple matches exist" do
        it "returns all matching identifiers sorted by name" do
          result = described_class.search_identifier_name(project, "1234")
          expect(result).to eq(%w[CVE-2023-1234 CWE-1234])
        end

        it "returns only distinct matching identifier names" do
          create(:vulnerabilities_identifier, name: 'CWE-1234',
            external_type: 'custom scanner', external_id: 'custom scanner', project: project)

          result = described_class.search_identifier_name(project, "1234")
          expect(result).to contain_exactly("CVE-2023-1234", 'CWE-1234')
        end
      end

      context "when searching in a different project" do
        it "does not return identifiers from other projects" do
          result = described_class.search_identifier_name(project_2, "1234")
          expect(result).to be_empty
        end
      end

      context "when result count exceeds the limit" do
        let(:limit) { 2 }

        before do
          stub_const("#{described_class.name}::SEARCH_RESULTS_LIMIT", limit)

          3.times do |i|
            identifier = "CVE-2023-123#{i}"
            create(:vulnerabilities_identifier, name: identifier,
              external_type: 'cve', external_id: identifier, project: project)
          end
        end

        it "limits the results" do
          result = described_class.search_identifier_name(project, "cve")
          expect(result.size).to eq(limit)
        end
      end
    end

    describe '.search_identifier_name_in_group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: group) }
      let_it_be(:other_group) { create(:group) }

      let_it_be(:group_project_1) { create(:project, group: group) }
      let_it_be(:group_project_2) { create(:project, group: group) }
      let_it_be(:subgroup_project_1) { create(:project, group: subgroup) }
      let_it_be(:other_group_project) { create(:project, group: other_group) }

      let_it_be(:group_project_1_stat) { create(:vulnerability_statistic, project: group_project_1) }
      let_it_be(:group_project_2_stat) { create(:vulnerability_statistic, project: group_project_2) }
      let_it_be(:subgroup_project_1_stat) { create(:vulnerability_statistic, project: subgroup_project_1) }
      let_it_be(:other_group_project_stat) { create(:vulnerability_statistic, project: other_group_project) }

      let_it_be(:identifier) do
        create(:vulnerabilities_identifier, name: 'CVE-2023-1234-o',
          external_type: 'cve', external_id: 'CVE-2023-1234-o', project: other_group_project)
        create(:vulnerabilities_identifier, name: 'CVE-2023-1234',
          external_type: 'cve', external_id: 'CVE-2023-1234', project: group_project_1)
      end

      let_it_be(:identifier_2) do
        create(:vulnerabilities_identifier, name: 'CWE-1234',
          external_type: 'cwe', external_id: '1234', project: group_project_2)
      end

      let_it_be(:identifier_3) do
        create(:vulnerabilities_identifier, name: 'CVE-2019-10086-o',
          external_type: 'cve', external_id: 'CVE-2019-10086-o	', project: other_group_project)
        create(:vulnerabilities_identifier, name: 'CVE-2019-10086',
          external_type: 'cve', external_id: 'CVE-2019-10086	', project: subgroup_project_1)
      end

      context "when searching with a partial match" do
        it "returns matching identifiers for the group" do
          result = described_class.search_identifier_name_in_group(group, "-123")
          expect(result).to contain_exactly("CVE-2023-1234", 'CWE-1234')
        end
      end

      context "when searching with a case-insensitive match" do
        it "returns matching identifiers regardless of case" do
          result = described_class.search_identifier_name_in_group(group, "cve")
          expect(result).to contain_exactly("CVE-2023-1234", "CVE-2019-10086")
        end
      end

      context "when there are no matches" do
        it "returns an empty array" do
          result = described_class.search_identifier_name_in_group(group, "Nonexistent")
          expect(result).to be_empty
        end
      end

      context "when multiple matches exist" do
        it "returns all matching identifiers sorted by name" do
          result = described_class.search_identifier_name_in_group(group, "1234")
          expect(result).to eq(%w[CVE-2023-1234 CWE-1234])
        end

        it "returns only distinct matching identifier names" do
          create(:vulnerabilities_identifier, name: 'CWE-1234',
            external_type: 'custom scanner', external_id: 'custom scanner', project: group_project_1)

          result = described_class.search_identifier_name_in_group(group, "1234")
          expect(result).to contain_exactly("CVE-2023-1234", 'CWE-1234')
        end
      end

      context "when searching in a subgroup" do
        it "does not return identifiers from parent groups" do
          result = described_class.search_identifier_name_in_group(subgroup, "cve")
          expect(result).to contain_exactly("CVE-2019-10086")
        end
      end

      context "when result count exceeds the limit" do
        let(:limit) { 2 }

        before do
          stub_const("#{described_class.name}::SEARCH_RESULTS_LIMIT", limit)
        end

        it "limits the results" do
          result = described_class.search_identifier_name_in_group(group, "1")
          expect(result.size).to eq(limit)
        end
      end
    end
  end

  context 'with loose foreign key on vulnerability_identifiers.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:vulnerabilities_identifier, project: parent) }
    end
  end
end

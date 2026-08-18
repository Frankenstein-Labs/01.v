# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ExternalIssueLink, feature_category: :vulnerability_management do
  describe 'associations and fields' do
    it { is_expected.to belong_to(:vulnerability) }
    it { is_expected.to belong_to(:finding).with_foreign_key(:vulnerability_occurrence_id).class_name('Vulnerabilities::Finding') }
    it { is_expected.to define_enum_for(:link_type).with_values(created: 1) }

    it 'provides the "created" as default link_type' do
      expect(create(:vulnerabilities_external_issue_link).link_type).to eq 'created'
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:vulnerability) }
    it { is_expected.to validate_presence_of(:external_issue_key) }
    it { is_expected.to validate_presence_of(:external_project_key) }
    it { is_expected.to validate_presence_of(:external_type) }

    describe 'uniqueness' do
      before do
        create(:vulnerabilities_external_issue_link)
      end

      it do
        is_expected.to(
          validate_uniqueness_of(:external_issue_key)
            .scoped_to([:vulnerability_id, :external_type, :external_project_key])
            .with_message('has already been linked to another vulnerability'))
      end
    end

    describe 'only one "created" link allowed per vulnerability' do
      let!(:existing_link) { create(:vulnerabilities_external_issue_link, :created) }

      subject(:issue_link) do
        build(:vulnerabilities_external_issue_link, :created, vulnerability: existing_link.vulnerability)
      end

      it do
        is_expected.to(
          validate_uniqueness_of(:vulnerability_id)
            .with_message('already has a "created" issue link'))
      end
    end
  end

  describe '.created_for_vulnerability' do
    let_it_be(:external_links) { create_list(:vulnerabilities_external_issue_link, 2, :created) }

    it 'gets external issue links for the specified vulnerability' do
      expect(described_class.created_for_vulnerability(external_links.first.vulnerability).take).to eq(external_links.first)
    end
  end

  describe '.by_finding' do
    let_it_be(:finding) { create(:vulnerabilities_finding) }
    let_it_be(:external_link_with_finding) { create(:vulnerabilities_external_issue_link, finding: finding) }
    let_it_be(:external_link_without_finding) { create(:vulnerabilities_external_issue_link) }

    it 'returns external issue links for the specified finding ids' do
      expect(described_class.by_finding(finding.id)).to contain_exactly(external_link_with_finding)
    end

    it 'returns external issue links for multiple finding ids' do
      other_finding = create(:vulnerabilities_finding)
      other_link = create(:vulnerabilities_external_issue_link, finding: other_finding)

      expect(described_class.by_finding([finding.id, other_finding.id])).to contain_exactly(external_link_with_finding, other_link)
    end
  end

  context 'with loose foreign key on vulnerabilities_external_issue_links.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:vulnerabilities_external_issue_link, project_id: parent.id) }
    end
  end

  context 'with loose foreign key on vulnerabilities_external_issue_links.author_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:user) }
      let_it_be(:model) { create(:vulnerabilities_external_issue_link, author_id: parent.id) }
    end
  end

  describe '.jira_issue_keys_for_vulnerabilities' do
    context 'when vulnerability_ids is blank' do
      it 'returns empty array' do
        expect(described_class.jira_issue_keys_for_vulnerabilities([])).to eq([])
        expect(described_class.jira_issue_keys_for_vulnerabilities(nil)).to eq([])
      end
    end

    context 'with no external issue links' do
      let_it_be(:vulnerability) { create(:vulnerability) }

      it 'returns empty array' do
        expect(described_class.jira_issue_keys_for_vulnerabilities([vulnerability.id])).to eq([])
      end
    end

    context 'with Jira external issue links' do
      let_it_be(:vulnerability) { create(:vulnerability) }
      let_it_be(:jira_link) do
        create(:vulnerabilities_external_issue_link,
          vulnerability: vulnerability,
          external_type: 'jira',
          external_issue_key: '123')
      end

      it 'returns Jira issue keys for the specified vulnerabilities' do
        result = described_class.jira_issue_keys_for_vulnerabilities([vulnerability.id])

        expect(result).to eq(['123'])
      end
    end

    context 'with multiple Jira external issue links' do
      let_it_be(:vulnerabilities) { create_list(:vulnerability, 2) }

      let_it_be(:jira_links) do
        vulnerabilities.each_with_index.map do |vulnerability, index|
          create(:vulnerabilities_external_issue_link,
            vulnerability: vulnerability,
            external_type: 'jira',
            external_issue_key: (index + 1).to_s)
        end
      end

      it 'returns all Jira issue keys' do
        vulnerability_ids = vulnerabilities.map(&:id)
        result = described_class.jira_issue_keys_for_vulnerabilities(vulnerability_ids)

        expect(result).to match_array(jira_links.map(&:external_issue_key))
      end
    end
  end
end

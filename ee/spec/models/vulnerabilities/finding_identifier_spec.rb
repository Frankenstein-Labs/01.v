# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::FindingIdentifier, feature_category: :vulnerability_management do
  describe 'associations' do
    it { is_expected.to belong_to(:finding).class_name('Vulnerabilities::Finding').with_foreign_key('occurrence_id') }
    it { is_expected.to belong_to(:identifier).class_name('Vulnerabilities::Identifier') }
  end

  describe 'validations' do
    let!(:finding_identifier) { create(:vulnerabilities_finding_identifier) }

    it { is_expected.to validate_presence_of(:finding) }
    it { is_expected.to validate_presence_of(:identifier) }
    it { is_expected.to validate_uniqueness_of(:identifier_id).scoped_to(:occurrence_id) }
  end

  describe '.by_finding_id' do
    let!(:finding) { create(:vulnerabilities_finding) }
    let!(:finding_identifier) { create(:vulnerabilities_finding_identifier, finding: finding) }
    let!(:another_finding_identifier) { create(:vulnerabilities_finding_identifier) }

    subject { described_class.by_finding_id(finding.id) }

    it { is_expected.to contain_exactly(finding_identifier) }
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::FindingTokenStatus, feature_category: :secret_detection do
  describe 'factory' do
    it 'creates a valid finding token status' do
      token_status = build(:finding_token_status)
      expect(token_status).to be_valid
    end

    it 'creates a finding token status with inactive status' do
      token_status = build(:finding_token_status, :inactive)
      expect(token_status).to be_valid
      expect(token_status.status_inactive?).to be true
    end

    it 'creates a finding token status with unknown status' do
      token_status = build(:finding_token_status, :unknown)
      expect(token_status).to be_valid
      expect(token_status.status_unknown?).to be true
    end
  end

  describe 'callbacks' do
    let_it_be(:project) { create(:project) }
    let_it_be(:finding) { create(:vulnerabilities_finding, project: project) }

    context 'when project_id is nil' do
      it 'sets project_id from the finding before validation' do
        token_status = described_class.new(finding: finding, status: :active)

        expect(token_status.project_id).to be_nil

        token_status.validate

        expect(token_status.project_id).to eq(finding.project_id)
      end
    end

    context 'when project_id is already set' do
      it 'does not override project_id' do
        token_status = described_class.new(finding: finding, project_id: 9999, status: :active)

        token_status.validate

        expect(token_status.project_id).to eq(9999)
      end
    end
  end

  describe 'associations' do
    it 'belongs to a finding with the correct class name, foreign key, and inverse relation' do
      is_expected.to belong_to(:finding)
        .class_name('Vulnerabilities::Finding')
        .with_foreign_key('vulnerability_occurrence_id')
        .inverse_of(:finding_token_status)
    end

    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:project_id) }
  end

  describe 'enums' do
    it 'defines the correct statuses' do
      expect(described_class.statuses).to eq({
        'unknown' => 0,
        'active' => 1,
        'inactive' => 2
      })
    end

    it 'supports _prefix for status enum' do
      status = described_class.new(status: :active)
      expect(status.status_active?).to be true
      expect(status.status_inactive?).to be false
    end
  end
end

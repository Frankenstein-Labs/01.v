# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Remediations::BatchDestroyService, '#execute',
  feature_category: :vulnerability_management do
  subject(:response) { described_class.new(remediations: remediations).execute }

  let(:remediations) { Vulnerabilities::Remediation.where.missing(:findings) }

  before do
    create_list(:vulnerabilities_remediation, 2, findings: [])
  end

  it 'deletes remediations and returns a count for number of rows deleted' do
    expect(response.success?).to eq true
    expect(response.payload).to eq(rows_deleted: 2)
    expect(Vulnerabilities::Remediation.count).to eq(0)
    expect(Upload.count).to eq(0)
  end

  context 'when there are un-related remediations' do
    let(:remediations) { Vulnerabilities::Remediation.all.limit(1) }

    it 'does not delete them' do
      expect(response.success?).to eq true
      expect(response.payload).to eq(rows_deleted: 1)
      expect(Vulnerabilities::Remediation.count).to eq(1)
      expect(Upload.count).to eq(1)
    end
  end

  context 'when nil is passed' do
    subject(:response) { described_class.new(remediations: nil).execute }

    it 'returns a success response' do
      expect(response.success?).to eq true
      expect(response.payload).to eq(rows_deleted: 0)
    end
  end

  context 'when empty relation is passed' do
    let(:remediations) { Vulnerabilities::Remediation.where(id: non_existing_record_id) }

    it 'returns a success response' do
      expect(response.success?).to eq true
      expect(response.payload).to eq(rows_deleted: 0)
    end
  end

  context 'when remediations is not an ActiveRecord::Relation' do
    let(:remediations) { Vulnerabilities::Remediation.first }

    it 'raises an error' do
      expect { response }.to raise_error ArgumentError
    end
  end
end

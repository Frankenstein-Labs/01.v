# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Remediations::CreateService, '#execute',
  feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:diff) { "Some Diff" }
  let_it_be(:finding) { create(:vulnerabilities_finding, project: project) }
  let(:findings) { [finding] }
  let(:summary) { "A summary" }
  let(:params) { {} }

  subject(:result) { described_class.new(project: project, diff: diff, findings: findings, summary: summary).execute }

  context 'when no findings are passed' do
    let(:findings) { nil }

    it 'raises an error' do
      expect(result[:status]).to eq :error
      expect(result[:message]).to eq "No findings given to relate remediation to"
    end
  end

  context 'when all needed params are passed' do
    context 'with a summary' do
      it 'creates a remediation' do
        expect(result[:status]).to eq :success
        expect(result.payload[:remediation]).to be_instance_of(Vulnerabilities::Remediation)
        expect(result.payload[:remediation].diff).to eq diff
        expect(result.payload[:remediation].summary).to eq summary
      end
    end

    context 'without a summary' do
      let(:summary) { nil }

      it 'creates a remediation' do
        expect(result[:status]).to eq :success
        expect(result.payload[:remediation]).to be_instance_of(Vulnerabilities::Remediation)
        expect(result.payload[:remediation].diff).to eq diff
        expect(result.payload[:remediation].summary).to eq "Vulnerability Remediation"
      end
    end

    context 'when remediation already exists' do
      let_it_be(:existing_remediation) do
        create(:vulnerabilities_remediation, project: project, checksum: Digest::SHA256.hexdigest(diff))
      end

      it 'returns the existing remediation' do
        expect(result[:status]).to eq :success
        expect(result.payload[:remediation]).to eq(existing_remediation)
      end
    end
  end

  context 'when creation fails' do
    let(:double) { instance_double(Vulnerabilities::Remediation) }

    before do
      allow(Vulnerabilities::Remediation).to receive(:new).and_return(double)
      allow(double).to receive(:save).and_return(false)
    end

    it 'raises an error' do
      expect(result[:status]).to eq :error
      expect(result[:message]).to eq "Remediation creation failed"
    end
  end
end

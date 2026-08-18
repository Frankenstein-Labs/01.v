# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PackageMetadata::AdvisoriesFinder, feature_category: :software_composition_analysis do
  describe '#initialize' do
    context 'when identifiers is missing' do
      it 'raises an ArgumentError' do
        expect { described_class.new({}) }.to raise_error(ArgumentError, 'identifiers argument is missing')
      end
    end

    context 'when identifiers is blank' do
      it 'raises an ArgumentError' do
        expect { described_class.new(identifiers: []) }.to raise_error(ArgumentError, 'identifiers argument is missing')
      end

      it 'raises an ArgumentError when identifiers is nil' do
        expect do
          described_class.new(identifiers: nil)
        end.to raise_error(ArgumentError, 'identifiers argument is missing')
      end

      it 'raises an ArgumentError when identifiers is empty string' do
        expect { described_class.new(identifiers: '') }.to raise_error(ArgumentError, 'identifiers argument is missing')
      end
    end

    context 'when identifiers is present' do
      it 'does not raise' do
        expect { described_class.new(identifiers: ['CVE-2026-1234']) }.not_to raise_error
      end

      it 'accepts additional parameters' do
        expect do
          described_class.new(
            identifiers: ['CVE-2026-1234'],
            created_after: 1.day.ago,
            updated_after: 2.days.ago
          )
        end.not_to raise_error
      end
    end
  end

  describe '#execute' do
    let!(:advisory1) do
      create(:pm_advisory,
        identifiers: [{ type: 'CVE', name: 'CVE-2026-1', value: 'CVE-2026-1', url: 'https://example.com/cve1' }])
    end

    let!(:advisory2) do
      create(:pm_advisory, created_at: 10.days.ago,
        identifiers: [{ type: 'CVE', name: 'CVE-2026-2', value: 'CVE-2026-2', url: 'https://example.com/cve2' }])
    end

    let!(:advisory3) do
      create(:pm_advisory, created_at: 1.day.ago,
        identifiers: [{ type: 'CVE', name: 'CVE-2026-3', value: 'CVE-2026-3', url: 'https://example.com/cve3' }])
    end

    let!(:advisory4) do
      create(:pm_advisory, created_at: 11.days.ago, updated_at: 10.days.ago,
        identifiers: [{ type: 'CVE', name: 'CVE-2026-4', value: 'CVE-2026-4', url: 'https://example.com/cve4' }])
    end

    let!(:advisory5) do
      create(:pm_advisory, created_at: 2.days.ago, updated_at: 1.day.ago,
        identifiers: [{ type: 'CVE', name: 'CVE-2026-5', value: 'CVE-2026-5', url: 'https://example.com/cve5' }])
    end

    let(:all_identifiers) { %w[CVE-2026-1 CVE-2026-2 CVE-2026-3 CVE-2026-4 CVE-2026-5] }
    let(:identifiers) { [] }
    let(:created_after) { nil }
    let(:updated_after) { nil }

    subject(:execute) do
      args = { identifiers: identifiers }
      args[:created_after] = created_after if created_after
      args[:updated_after] = updated_after if updated_after

      described_class.new(args).execute
    end

    context 'with some identifiers' do
      let(:identifiers) { %w[CVE-2026-1 CVE-2026-2] }

      it 'returns advisories matching the identifiers' do
        expect(execute).to contain_exactly(advisory1, advisory2)
      end
    end

    context 'when no identifiers match' do
      let(:identifiers) { %w[CVE-2099-0000] }

      it 'returns empty result' do
        expect(execute).to be_empty
      end
    end

    context 'with created_after parameter' do
      let(:identifiers) { all_identifiers }
      let(:created_after) { 5.days.ago }

      it 'returns advisories created after the specified date' do
        expect(execute).to contain_exactly(advisory1, advisory3, advisory5)
      end
    end

    context 'with updated_after parameter' do
      let(:identifiers) { all_identifiers }
      let(:updated_after) { 5.days.ago }

      it 'returns advisories updated after the specified date' do
        expect(execute).to contain_exactly(advisory1, advisory2, advisory3, advisory5)
      end
    end

    context 'with multiple filter parameters' do
      let(:identifiers) { all_identifiers }
      let(:created_after) { 5.days.ago }
      let(:updated_after) { 5.days.ago }

      it 'applies all filters' do
        expect(execute).to contain_exactly(advisory1, advisory3, advisory5)
      end
    end
  end
end

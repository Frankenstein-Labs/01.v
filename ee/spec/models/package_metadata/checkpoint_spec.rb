# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PackageMetadata::Checkpoint, feature_category: :software_composition_analysis do
  let(:data_types) do
    {
      advisories: 1,
      licenses: 2,
      cve_enrichment: 3,
      malware_advisories: 4
    }
  end

  let(:version_formats) do
    {
      v1: 1,
      v2: 2,
      v3: 3
    }
  end

  describe 'enums' do
    it_behaves_like 'purl_types enum'
    it { is_expected.to define_enum_for(:data_type).with_values(data_types) }
    it { is_expected.to define_enum_for(:version_format).with_values(version_formats) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:purl_type) }
    it { is_expected.to validate_presence_of(:data_type) }
    it { is_expected.to validate_presence_of(:version_format) }

    it { is_expected.to validate_presence_of(:sequence) }
    it { is_expected.to validate_numericality_of(:sequence).only_integer }

    it { is_expected.to validate_presence_of(:chunk) }
    it { is_expected.to validate_numericality_of(:chunk).only_integer }

    it 'validates uniqueness of purl_type scoped to data_type and version_format' do
      create(:pm_checkpoint)

      is_expected.to validate_uniqueness_of(
        :purl_type
      ).scoped_to([:data_type, :version_format]).ignoring_case_sensitivity
    end
  end

  describe '.with_path_components' do
    let(:checkpoints) { create_list(:pm_checkpoint, Enums::Sbom::PURL_TYPES.length) }

    it 'returns the checkpoint for the given parameters' do
      checkpoints.each do |checkpoint|
        actual = described_class.with_path_components(checkpoint.data_type,
          checkpoint.version_format, checkpoint.purl_type)
        expect(actual).to eq(checkpoint)
      end
    end
  end

  describe '.with_advisories_by_purl_type' do
    let_it_be(:checkpoints) do
      [
        create(:pm_checkpoint, :v2, :advisories, sequence: 123, purl_type: :npm),
        create(:pm_checkpoint, :v2, :advisories, sequence: 456, purl_type: :maven)
      ]
    end

    subject(:result) { described_class.advisory_purl_type_sequences }

    it 'returns the sequence for each advisory purl type' do
      is_expected.to eq({
        'maven' => 456,
        'npm' => 123
      })
    end
  end

  describe '.for_advisories' do
    subject(:for_advisories) { described_class.for_advisories }

    context 'when there are no advisory checkpoints' do
      let_it_be(:license_checkpoint) { create(:pm_checkpoint, data_type: 'licenses') }
      let_it_be(:cve_checkpoint) { create(:pm_checkpoint, data_type: 'cve_enrichment') }

      it { is_expected.to be_empty }
    end

    context 'when there is one advisory checkpoint' do
      let_it_be(:advisory_checkpoint) { create(:pm_checkpoint, data_type: 'advisories') }
      let_it_be(:license_checkpoint) { create(:pm_checkpoint, data_type: 'licenses') }

      it { is_expected.to contain_exactly(advisory_checkpoint) }
    end

    context 'when there are multiple advisory checkpoints' do
      let_it_be(:advisory_checkpoint1) { create(:pm_checkpoint, data_type: 'advisories', purl_type: 'npm') }
      let_it_be(:advisory_checkpoint2) { create(:pm_checkpoint, data_type: 'advisories', purl_type: 'maven') }
      let_it_be(:license_checkpoint) { create(:pm_checkpoint, data_type: 'licenses') }

      it 'returns all advisory checkpoints' do
        expect(for_advisories).to contain_exactly(advisory_checkpoint1, advisory_checkpoint2)
      end
    end
  end

  describe '.for_malware_advisories' do
    subject(:for_malware_advisories) { described_class.for_malware_advisories }

    context 'when there are no malware advisory checkpoints' do
      let_it_be(:advisory_checkpoint) { create(:pm_checkpoint, data_type: 'advisories') }
      let_it_be(:license_checkpoint) { create(:pm_checkpoint, data_type: 'licenses') }

      it { is_expected.to be_empty }
    end

    context 'when there are malware advisory checkpoints alongside other data types' do
      let_it_be(:malware_checkpoint1) do
        create(:pm_checkpoint, data_type: 'malware_advisories', version_format: 'v3', purl_type: 'npm')
      end

      let_it_be(:malware_checkpoint2) do
        create(:pm_checkpoint, data_type: 'malware_advisories', version_format: 'v3', purl_type: 'maven')
      end

      let_it_be(:advisory_checkpoint) { create(:pm_checkpoint, data_type: 'advisories') }

      it 'returns only the malware advisory checkpoints' do
        expect(for_malware_advisories).to contain_exactly(malware_checkpoint1, malware_checkpoint2)
      end
    end
  end

  describe '.with_purl_types' do
    let_it_be(:npm_checkpoint) { create(:pm_checkpoint, purl_type: 'npm') }
    let_it_be(:maven_checkpoint) { create(:pm_checkpoint, purl_type: 'maven') }
    let_it_be(:pypi_checkpoint) { create(:pm_checkpoint, purl_type: 'pypi') }

    subject(:with_purl_types) { described_class.with_purl_types(purl_types) }

    context 'when filtering by a single purl_type' do
      let(:purl_types) { ['npm'] }

      it { is_expected.to contain_exactly(npm_checkpoint) }
    end

    context 'when filtering by multiple purl_types' do
      let(:purl_types) { %w[npm maven] }

      it 'returns checkpoints matching any of the purl_types' do
        expect(with_purl_types).to contain_exactly(npm_checkpoint, maven_checkpoint)
      end
    end

    context 'when filtering by purl_types that do not exist' do
      let(:purl_types) { ['nonexistent'] }

      it { is_expected.to be_empty }
    end

    context 'when filtering by empty array' do
      let(:purl_types) { [] }

      it { is_expected.to be_empty }
    end

    context 'when filtering by all purl_types' do
      let(:purl_types) { %w[npm maven pypi] }

      it 'returns all checkpoints' do
        expect(with_purl_types).to contain_exactly(npm_checkpoint, maven_checkpoint, pypi_checkpoint)
      end
    end
  end

  describe '.synced_since' do
    let_it_be(:old_checkpoint) { create(:pm_checkpoint, sequence: 100) }
    let_it_be(:middle_checkpoint) { create(:pm_checkpoint, sequence: 500) }
    let_it_be(:recent_checkpoint) { create(:pm_checkpoint, sequence: 1000) }

    subject(:synced_since) { described_class.synced_since(epoch_seconds) }

    context 'when epoch_seconds is before all checkpoints' do
      let(:epoch_seconds) { 50 }

      it 'returns all checkpoints' do
        expect(synced_since).to contain_exactly(old_checkpoint, middle_checkpoint, recent_checkpoint)
      end
    end

    context 'when epoch_seconds matches a checkpoint sequence' do
      let(:epoch_seconds) { 500 }

      it 'returns checkpoints with sequence greater than or equal to epoch_seconds' do
        expect(synced_since).to contain_exactly(middle_checkpoint, recent_checkpoint)
      end
    end

    context 'when epoch_seconds is between checkpoint sequences' do
      let(:epoch_seconds) { 600 }

      it 'returns only checkpoints with sequence greater than or equal to epoch_seconds' do
        expect(synced_since).to contain_exactly(recent_checkpoint)
      end
    end

    context 'when epoch_seconds is after all checkpoints' do
      let(:epoch_seconds) { 2000 }

      it { is_expected.to be_empty }
    end

    context 'when epoch_seconds is zero' do
      let(:epoch_seconds) { 0 }

      it 'returns all checkpoints' do
        expect(synced_since).to contain_exactly(old_checkpoint, middle_checkpoint, recent_checkpoint)
      end
    end
  end

  describe '#first_sync?' do
    subject(:first_sync) { checkpoint.first_sync? }

    context 'when the checkpoint has never synced (sequence 0)' do
      let(:checkpoint) { build(:pm_checkpoint, sequence: 0, full_sync_target_sequence: nil) }

      it { expect(first_sync).to be(true) }
    end

    context 'when a full sync is in progress (full_sync_target_sequence set)' do
      let(:checkpoint) do
        build(:pm_checkpoint, sequence: 1_700_000_000, full_sync_target_sequence: 1_700_000_500)
      end

      it { expect(first_sync).to be(true) }
    end

    context 'when the checkpoint is finalized (sequence set, no marker)' do
      let(:checkpoint) { build(:pm_checkpoint, sequence: 1_700_000_000, full_sync_target_sequence: nil) }

      it { expect(first_sync).to be(false) }
    end
  end

  describe '#update' do
    let(:data_type) { 'licenses' }
    let(:version_format) { 'v1' }
    let(:purl_type) { 'npm' }

    let!(:checkpoint) do
      create(:pm_checkpoint, data_type: 'licenses', version_format: 'v1', purl_type: 'npm',
        sequence: 0, chunk: 0)
    end

    subject(:update!) do
      described_class.find_by(data_type: data_type, version_format: version_format, purl_type: purl_type)
        &.update!(sequence: 1, chunk: 1)
    end

    context 'when all attributes are the same' do
      it 'updates the checkpoint' do
        expect { update! }.to change { [checkpoint.reload.sequence, checkpoint.reload.chunk] }
          .from([0, 0])
          .to([1, 1])
      end
    end

    context 'when an attribute differs' do
      context 'and it is data_type' do
        let(:data_type) { 'advisories' }

        it 'does not update the checkpoint' do
          expect { update! }.not_to change { [checkpoint.reload.sequence, checkpoint.reload.chunk] }
        end
      end

      context 'and it is version_format' do
        let(:version_format) { 'v2' }

        it 'does not update the checkpoint' do
          expect { update! }.not_to change { [checkpoint.reload.sequence, checkpoint.reload.chunk] }
        end
      end

      context 'and it is purl_type' do
        let(:purl_type) { 'maven' }

        it 'does not update the checkpoint' do
          expect { update! }.not_to change { [checkpoint.reload.sequence, checkpoint.reload.chunk] }
        end
      end
    end
  end
end

RSpec.describe PackageMetadata::NullCheckpoint, feature_category: :software_composition_analysis do
  subject(:null_checkpoint) { described_class.new }

  describe '#update' do
    it 'accepts any number of arguments without raising an error' do
      # rubocop:disable Rails/SaveBang -- There is no `update!` method since NullCheckpoint isn't ActiveRecord
      expect { null_checkpoint.update }.not_to raise_error
      expect { null_checkpoint.update(sequence: 1, chunk: 2) }.not_to raise_error
      # rubocop:enable Rails/SaveBang
    end

    it 'returns nil' do
      expect(null_checkpoint.update).to be_nil
      expect(null_checkpoint.update(sequence: 1, chunk: 2)).to be_nil
    end
  end

  describe '#blank?' do
    it 'always returns true' do
      expect(null_checkpoint.blank?).to be true
    end
  end
end

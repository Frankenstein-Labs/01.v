# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Insights::Validators::ConfigValidator, feature_category: :value_stream_management do
  subject(:validator) { described_class.new(config) }

  describe '#valid?' do
    context 'when every entry has a title or charts' do
      let(:config) { { a: { title: 'A' }, b: { charts: [] } } }

      it { is_expected.to be_valid }
    end

    context 'when an entry is a hash without title or charts (YAML anchor)' do
      let(:config) { { a: { title: 'A' }, ".projectsOnly": { projects: { only: [] } } } }

      it { is_expected.to be_valid }
    end

    context 'when an entry is not a hash' do
      let(:config) { { a: { title: 'A' }, b: [1, 2] } }

      it { is_expected.not_to be_valid }
    end

    context 'when an entry is nil' do
      let(:config) { { a: { title: 'A' }, b: nil } }

      it { is_expected.not_to be_valid }
    end

    context 'when config is nil' do
      let(:config) { nil }

      it { is_expected.not_to be_valid }
    end

    context 'when config is an empty hash' do
      let(:config) { {} }

      it { is_expected.to be_valid }
    end
  end

  describe '#valid_entries' do
    context 'when every entry is structurally valid' do
      let(:config) { { a: { title: 'A' }, b: { charts: [] } } }

      it 'returns the full config' do
        expect(validator.valid_entries).to eq(config)
      end
    end

    context 'when entries mix renderable, anchor, and malformed shapes' do
      let(:config) do
        {
          good: { title: 'Good' },
          ".anchor": { projects: { only: [] } },
          bad_array: [1, 2],
          bad_nil: nil
        }
      end

      it 'returns only the renderable entries' do
        expect(validator.valid_entries).to eq(good: { title: 'Good' })
      end
    end

    context 'when config is not a hash' do
      let(:config) { nil }

      it 'returns an empty hash' do
        expect(validator.valid_entries).to eq({})
      end
    end
  end

  describe '#invalid_entries' do
    context 'when every entry is renderable' do
      let(:config) { { a: { title: 'A' } } }

      it 'returns an empty hash' do
        expect(validator.invalid_entries).to eq({})
      end
    end

    context 'when entries mix renderable, anchor, and malformed shapes' do
      let(:config) do
        {
          good: { title: 'Good' },
          ".anchor": { projects: { only: [] } },
          bad_array: [1, 2]
        }
      end

      it 'returns anchor and malformed entries' do
        expect(validator.invalid_entries).to eq(
          ".anchor": { projects: { only: [] } },
          bad_array: [1, 2]
        )
      end
    end

    context 'when config is not a hash' do
      let(:config) { [1, 2] }

      it 'returns an empty hash' do
        expect(validator.invalid_entries).to eq({})
      end
    end
  end
end

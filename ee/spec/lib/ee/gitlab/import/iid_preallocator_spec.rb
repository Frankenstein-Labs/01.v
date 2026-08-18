# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Import::IidPreallocator, feature_category: :importers do
  let_it_be(:group) { create(:group) }

  let(:max_iids) { {} }

  subject(:preallocator) { described_class.new(group, max_iids) }

  describe '.trackable_resources' do
    it 'includes EE resource types in addition to CE ones' do
      expect(described_class.trackable_resources.keys).to include(:epics, :iterations)
    end
  end

  describe '#execute' do
    context 'with epics' do
      let(:max_iids) { { epics: 8 } }

      it 'calls track_group_iid! on Epic with the group' do
        expect(Epic).to receive(:track_group_iid!).with(group, 8)

        preallocator.execute
      end
    end

    context 'with iterations' do
      let(:max_iids) { { iterations: 12 } }

      it 'calls track_group_iid! on Iteration with the group' do
        expect(Iteration).to receive(:track_group_iid!).with(group, 12)

        preallocator.execute
      end
    end

    context 'with both epics and iterations' do
      let(:max_iids) { { epics: 8, iterations: 12 } }

      it 'pre-allocates all EE resource types' do
        expect(Epic).to receive(:track_group_iid!).with(group, 8)
        expect(Iteration).to receive(:track_group_iid!).with(group, 12)

        preallocator.execute
      end
    end
  end
end

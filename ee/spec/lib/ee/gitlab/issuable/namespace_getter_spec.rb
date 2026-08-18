# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Issuable::NamespaceGetter, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let(:excluded_issuable_types) { [] }

  describe '#namespace_id' do
    subject(:namespace_id) do
      described_class.new(issuable, excluded_issuable_types: excluded_issuable_types).namespace_id
    end

    context 'when issuable is an Epic' do
      let_it_be(:issuable) { create(:epic, group: group) }

      it { is_expected.to eq(group.id) }

      context 'when Epic is an excluded issuable type' do
        let(:excluded_issuable_types) { [Epic] }

        it 'raises an error' do
          expect do
            namespace_id
          end.to raise_error(
            described_class::INVALID_ISSUABLE_ERROR,
            'Epic is not a supported Issuable type'
          )
        end
      end
    end
  end
end

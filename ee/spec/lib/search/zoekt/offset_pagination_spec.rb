# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::OffsetPagination, feature_category: :global_search do
  describe '.active?' do
    subject(:active) { described_class.active? }

    context 'when all nodes meet the minimum version' do
      before do
        allow(Search::Zoekt::Node).to receive(:all_at_least_version?)
          .with(described_class::MIN_VERSION)
          .and_return(true)
      end

      it { is_expected.to be(true) }
    end

    context 'when nodes do not meet the minimum version' do
      before do
        allow(Search::Zoekt::Node).to receive(:all_at_least_version?)
          .with(described_class::MIN_VERSION)
          .and_return(false)
      end

      it { is_expected.to be(false) }
    end
  end
end

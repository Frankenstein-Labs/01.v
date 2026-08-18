# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::WorkItems::Features::Weight, feature_category: :team_planning do
  it_behaves_like 'work item widget entity parity',
    described_class,
    Types::WorkItems::Widgets::WeightType,
    exceptions: %w[widget_definition]

  describe '#as_json' do
    let(:widget) do
      instance_double(
        WorkItems::Widgets::Weight,
        weight: 3,
        rolled_up_weight: 8,
        rolled_up_completed_weight: 5
      )
    end

    subject(:representation) { described_class.new(widget).as_json }

    it 'exposes weight and rolled up weights' do
      expect(representation[:weight]).to eq(3)
      expect(representation[:rolled_up_weight]).to eq(8)
      expect(representation[:rolled_up_completed_weight]).to eq(5)
    end

    context 'when weights are nil' do
      let(:widget) do
        instance_double(
          WorkItems::Widgets::Weight,
          weight: nil,
          rolled_up_weight: nil,
          rolled_up_completed_weight: nil
        )
      end

      it 'exposes nil values' do
        expect(representation[:weight]).to be_nil
        expect(representation[:rolled_up_weight]).to be_nil
        expect(representation[:rolled_up_completed_weight]).to be_nil
      end
    end
  end
end

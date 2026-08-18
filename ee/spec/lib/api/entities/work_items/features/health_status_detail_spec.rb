# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::WorkItems::Features::HealthStatusDetail, feature_category: :team_planning do
  it_behaves_like 'work item widget entity parity',
    described_class,
    Types::WorkItems::Widgets::HealthStatusType

  describe '#as_json' do
    let(:rolled_up_health_status) do
      [
        { health_status: 'on_track', count: 3 },
        { health_status: 'needs_attention', count: 2 }
      ]
    end

    let(:widget) do
      instance_double(
        WorkItems::Widgets::HealthStatus,
        health_status: 'needs_attention',
        rolled_up_health_status: rolled_up_health_status
      )
    end

    subject(:representation) { described_class.new(widget).as_json }

    it 'exposes health_status and rolled_up_health_status' do
      expect(representation[:health_status]).to eq('needs_attention')
      expect(representation[:rolled_up_health_status]).to contain_exactly(
        { health_status: 'on_track', count: 3 },
        { health_status: 'needs_attention', count: 2 }
      )
    end

    context 'when health_status is nil' do
      let(:widget) do
        instance_double(
          WorkItems::Widgets::HealthStatus,
          health_status: nil,
          rolled_up_health_status: []
        )
      end

      it 'exposes nil health_status and empty rolled_up_health_status' do
        expect(representation[:health_status]).to be_nil
        expect(representation[:rolled_up_health_status]).to eq([])
      end
    end
  end
end

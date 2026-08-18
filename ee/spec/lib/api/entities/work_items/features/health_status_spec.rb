# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::WorkItems::Features::HealthStatus, feature_category: :team_planning do
  it_behaves_like 'work item widget entity parity',
    described_class,
    Types::WorkItems::Widgets::HealthStatusType,
    exceptions: Set.new(%w[rolled_up_health_status])

  describe '#as_json' do
    let(:widget) do
      instance_double(
        WorkItems::Widgets::HealthStatus,
        health_status: 'needs_attention'
      )
    end

    subject(:representation) { described_class.new(widget).as_json }

    it 'exposes the health_status' do
      expect(representation[:health_status]).to eq('needs_attention')
    end

    context 'when health_status is nil' do
      let(:widget) do
        instance_double(
          WorkItems::Widgets::HealthStatus,
          health_status: nil
        )
      end

      it 'exposes nil health_status' do
        expect(representation[:health_status]).to be_nil
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::WorkItems::Features::Progress, feature_category: :team_planning do
  it_behaves_like 'work item widget entity parity',
    described_class,
    Types::WorkItems::Widgets::ProgressType

  describe '#as_json' do
    let(:updated_at) { Time.zone.parse('2024-02-12T09:45:00Z') }
    let(:widget) do
      instance_double(
        WorkItems::Widgets::Progress,
        progress: 65,
        updated_at: updated_at,
        current_value: 13,
        start_value: 0,
        end_value: 20
      )
    end

    subject(:representation) { described_class.new(widget).as_json }

    it 'exposes the progress fields' do
      expect(representation).to include(
        progress: 65,
        updated_at: updated_at,
        current_value: 13,
        start_value: 0,
        end_value: 20
      )
    end

    context 'when progress is nil' do
      let(:widget) do
        instance_double(
          WorkItems::Widgets::Progress,
          progress: nil,
          updated_at: nil,
          current_value: nil,
          start_value: nil,
          end_value: nil
        )
      end

      it 'exposes nil for all fields' do
        expect(representation).to include(
          progress: nil,
          updated_at: nil,
          current_value: nil,
          start_value: nil,
          end_value: nil
        )
      end
    end
  end
end

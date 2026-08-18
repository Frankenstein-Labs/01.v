# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::WorkItems::Features::Iteration, feature_category: :team_planning do
  it_behaves_like 'work item widget entity parity',
    described_class,
    Types::WorkItems::Widgets::IterationType

  describe '#as_json' do
    let_it_be(:iteration) { build_stubbed(:iteration) }
    let(:widget) { instance_double(WorkItems::Widgets::Iteration, iteration: iteration) }

    subject(:representation) { described_class.new(widget).as_json }

    it 'exposes the iteration' do
      expect(representation[:iteration]).to include(id: iteration.id, title: iteration.title)
    end

    context 'when iteration is nil' do
      let(:widget) { instance_double(WorkItems::Widgets::Iteration, iteration: nil) }

      it 'exposes nil' do
        expect(representation[:iteration]).to be_nil
      end
    end
  end
end

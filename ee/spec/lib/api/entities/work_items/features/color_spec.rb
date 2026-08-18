# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::WorkItems::Features::Color, feature_category: :team_planning do
  it_behaves_like 'work item widget entity parity',
    described_class,
    Types::WorkItems::Widgets::ColorType

  describe '#as_json' do
    let(:color) { '#A8DADC' }
    let(:text_color) { '#1D3557' }
    let(:widget) { instance_double(WorkItems::Widgets::Color, color: color, text_color: text_color) }

    subject(:representation) { described_class.new(widget).as_json }

    it 'exposes the color' do
      expect(representation[:color]).to eq('#A8DADC')
      expect(representation[:text_color]).to eq('#1D3557')
    end

    context 'when color is nil' do
      let(:color) { nil }
      let(:text_color) { nil }

      it 'exposes nil' do
        expect(representation[:color]).to be_nil
        expect(representation[:text_color]).to be_nil
      end
    end
  end
end

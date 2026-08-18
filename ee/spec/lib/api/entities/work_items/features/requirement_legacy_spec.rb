# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::WorkItems::Features::RequirementLegacy, feature_category: :portfolio_management do
  it_behaves_like 'work item widget entity parity',
    described_class,
    Types::WorkItems::Widgets::RequirementLegacyType,
    exceptions: %w[widget_definition]

  describe '#as_json' do
    let(:widget) do
      instance_double(WorkItems::Widgets::RequirementLegacy, legacy_iid: 5)
    end

    subject(:representation) { described_class.new(widget).as_json }

    it 'exposes legacy_iid' do
      expect(representation[:legacy_iid]).to eq(5)
    end

    context 'when legacy_iid is nil' do
      let(:widget) do
        instance_double(WorkItems::Widgets::RequirementLegacy, legacy_iid: nil)
      end

      it 'exposes nil legacy_iid' do
        expect(representation[:legacy_iid]).to be_nil
      end
    end
  end
end

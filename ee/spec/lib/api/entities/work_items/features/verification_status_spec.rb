# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::WorkItems::Features::VerificationStatus, feature_category: :portfolio_management do
  it_behaves_like 'work item widget entity parity',
    described_class,
    Types::WorkItems::Widgets::VerificationStatusType,
    exceptions: %w[widget_definition]

  describe '#as_json' do
    let(:widget) do
      instance_double(WorkItems::Widgets::VerificationStatus, verification_status: 'satisfied')
    end

    subject(:representation) { described_class.new(widget).as_json }

    it 'exposes the verification_status' do
      expect(representation[:verification_status]).to eq('satisfied')
    end

    context 'when verification_status is unverified' do
      let(:widget) do
        instance_double(WorkItems::Widgets::VerificationStatus, verification_status: 'unverified')
      end

      it 'exposes unverified status' do
        expect(representation[:verification_status]).to eq('unverified')
      end
    end
  end
end

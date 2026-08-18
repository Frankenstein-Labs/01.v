# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::Notes::MeasureCommentTemperatureService, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let_it_be(:resource) { create(:group) }

  let(:options) { {} }

  describe '#valid?' do
    using RSpec::Parameterized::TableSyntax

    where(:measure_comment_temperature, :result) do
      true   | true
      false  | false
    end

    with_them do
      before do
        allow(Ability)
          .to receive(:allowed?)
          .and_return(measure_comment_temperature)
        allow(user).to receive(:allowed_to_use?).with(:measure_comment_temperature).and_return(true)
      end

      subject(:service) { described_class.new(user, resource, options) }

      it { expect(service.valid?).to eq(result) }
    end
  end

  describe '#execute' do
    subject(:service) { described_class.new(user, resource, options) }

    before do
      allow(Llm::CompletionWorker).to receive(:perform_for)
    end

    context 'when valid' do
      before do
        allow(service).to receive_messages(valid?: true)
      end

      it_behaves_like 'schedules completion worker' do
        let(:action_name) { :measure_comment_temperature }
      end
    end

    context 'when invalid' do
      before do
        allow(service).to receive(:valid?).and_return(false)
      end

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq(Llm::BaseService::INVALID_MESSAGE)
        expect(Llm::CompletionWorker).not_to have_received(:perform_for)
      end
    end
  end
end

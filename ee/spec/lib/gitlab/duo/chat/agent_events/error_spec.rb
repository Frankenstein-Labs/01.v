# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Chat::AgentEvents::Error, feature_category: :duo_chat do
  describe '#message' do
    subject { described_class.new(data).message }

    let(:data) { { 'message' => 'hello' } }

    it { is_expected.to eq('hello') }
  end

  describe '#retryable?' do
    subject { described_class.new(data).retryable? }

    context 'with retryable in data' do
      let(:data) { { 'retryable' => 'true' } }

      it { is_expected.to be_truthy }
    end

    context 'with no retryable' do
      let(:data) { { 'other_info' => 'hello' } }

      it { is_expected.to be_falsey }
    end
  end
end

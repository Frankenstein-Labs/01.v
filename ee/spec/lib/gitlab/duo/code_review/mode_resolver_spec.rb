# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::CodeReview::ModeResolver, feature_category: :duo_code_review do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:container) { build_stubbed(:group) }

  subject(:active_mode) { described_class.new(user: user, container: container) }

  shared_context 'with DAP mode active' do
    before do
      allow_next_instance_of(Gitlab::Duo::CodeReview::Modes::Dap) do |instance|
        allow(instance).to receive(:active?).and_return(true)
      end
    end
  end

  shared_context 'with Classic mode active' do
    before do
      allow_next_instance_of(Gitlab::Duo::CodeReview::Modes::Classic) do |instance|
        allow(instance).to receive(:active?).and_return(true)
      end
    end
  end

  shared_context 'when disabled' do
    before do
      allow_next_instance_of(Gitlab::Duo::CodeReview::Modes::Dap) do |instance|
        allow(instance).to receive(:active?).and_return(false)
      end

      allow_next_instance_of(Gitlab::Duo::CodeReview::Modes::Classic) do |instance|
        allow(instance).to receive(:active?).and_return(false)
      end
    end
  end

  describe '#mode' do
    context 'when DAP mode is active' do
      include_context 'with DAP mode active'

      it 'returns :dap' do
        expect(active_mode.mode).to eq(:dap)
      end
    end

    context 'when Classic mode is active' do
      include_context 'with Classic mode active'

      it 'returns :classic' do
        expect(active_mode.mode).to eq(:classic)
      end
    end

    context 'when both DAP and Classic mode are not active' do
      include_context 'when disabled'

      it 'returns :disabled' do
        expect(active_mode.mode).to eq(:disabled)
      end
    end
  end

  describe '#enabled?' do
    context 'when DAP mode is active' do
      include_context 'with DAP mode active'

      it 'is enabled' do
        expect(active_mode).to be_enabled
      end
    end

    context 'when Classic mode is active' do
      include_context 'with Classic mode active'

      it 'is enabled' do
        expect(active_mode).to be_enabled
      end
    end

    context 'when both DAP and Classic mode are not active' do
      include_context 'when disabled'

      it 'is disabled' do
        expect(active_mode).not_to be_enabled
      end
    end
  end
end

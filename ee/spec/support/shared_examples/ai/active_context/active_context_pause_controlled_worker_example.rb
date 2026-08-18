# frozen_string_literal: true

RSpec.shared_examples 'active_context pause-controlled worker' do
  it 'is a pause_control worker' do
    expect(described_class.get_pause_control).to eq(:active_context)
  end

  it 'checks the Ai::ActiveContext.paused?', :sidekiq_inline do
    # we return false value since we don't need to do any further tests
    # around the worker's actual `perform` method
    expect(::Ai::ActiveContext).to receive(:paused?).at_least(:once).and_return(false)

    described_class.perform_async(*worker_params)
  end
end

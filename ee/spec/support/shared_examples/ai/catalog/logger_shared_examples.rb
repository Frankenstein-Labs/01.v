# frozen_string_literal: true

RSpec.shared_examples 'initializes Ai::Catalog::Logger but does not log to it' do
  it 'initializes Ai::Catalog::Logger but does not log to it', :aggregate_failures do
    mock_logger = instance_double(Ai::Catalog::Logger)
    allow(mock_logger).to receive(:context).and_return(mock_logger)

    %w[info error debug warn].each do |level|
      expect(mock_logger).not_to receive(level)
    end

    expect(Ai::Catalog::Logger).to receive(:build).at_least(:once).and_return(mock_logger)

    subject
  end
end

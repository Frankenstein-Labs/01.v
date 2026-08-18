# frozen_string_literal: true

RSpec.shared_examples 'external destination streamer' do
  it 'does not make any external calls' do
    expect(Gitlab::HTTP).not_to receive(:post)
    expect(Aws::S3::Client).not_to receive(:put_object)
    expect(AuditEvents::GoogleCloud::LoggingService::Logger).not_to receive(:log)

    streamer.stream_to_destinations
  end
end

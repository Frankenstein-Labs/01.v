# frozen_string_literal: true

RSpec.shared_examples 'schedules completion worker' do
  let(:expected_options) { options }

  before do
    allow(SecureRandom).to receive(:uuid).and_return('uuid')
    allow(::Llm::CompletionWorker).to receive(:perform_for)
  end

  it 'asynchronously with correct params' do
    expect(::Llm::CompletionWorker)
      .to receive(:perform_for)
            .with(
              an_object_having_attributes(user: user, resource: resource, ai_action: action_name, request_id: 'uuid'),
              hash_including(**expected_options)
            )

    expect(subject.execute).to be_success
  end
end

RSpec.shared_examples 'does not schedule completion worker' do
  before do
    allow(SecureRandom).to receive(:uuid).and_return('uuid')
  end

  it 'asynchronously with correct params' do
    expect(::Llm::CompletionWorker).not_to receive(:perform_for)

    expect(subject.execute).not_to be_success
  end
end

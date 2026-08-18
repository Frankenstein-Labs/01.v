# frozen_string_literal: true

RSpec.shared_examples 'llm service caches user request' do
  it 'caches response' do
    expect_next_instance_of(::Gitlab::Llm::ChatStorage) do |cache|
      expect(cache).to receive(:add).with(kind_of(::Gitlab::Llm::ChatMessage))
    end

    subject.execute
  end

  context 'when a special reset message is used' do
    let(:content) { '/reset' }

    before do
      allow(subject).to receive(:content).and_return(content)
    end

    it 'only stores the message in cache' do
      expect(::Llm::CompletionWorker).not_to receive(:perform_for)

      expect_next_instance_of(::Gitlab::Llm::ChatStorage) do |cache|
        expect(cache).to receive(:add).with(kind_of(::Gitlab::Llm::ChatMessage))
      end

      subject.execute
    end
  end

  context 'when a special clear message is used' do
    let(:content) { '/clear' }

    before do
      allow(subject).to receive(:content).and_return(content)
    end

    it 'deletes all cache messages' do
      expect(::Llm::CompletionWorker).not_to receive(:perform_for)

      expect_next_instance_of(::Gitlab::Llm::ChatStorage) do |cache|
        expect(cache).to receive(:clear!)
      end

      subject.execute
    end
  end
end

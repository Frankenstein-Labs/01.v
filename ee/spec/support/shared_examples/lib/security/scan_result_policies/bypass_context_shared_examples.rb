# frozen_string_literal: true

RSpec.shared_examples 'a bypass context with push options bypass reason' do
  describe '#bypass_reason' do
    context 'when push_options is nil' do
      subject(:context) { described_class.new }

      it 'returns nil' do
        expect(context.bypass_reason).to be_nil
      end
    end

    context 'when push_options has a bypass reason' do
      subject(:context) do
        described_class.new(push_options: Gitlab::PushOptions.new(['security_policy.bypass_reason=Emergency fix']))
      end

      it 'returns the sanitized reason' do
        expect(context.bypass_reason).to eq('Emergency fix')
      end
    end

    context 'when push_options has a bypass reason with HTML' do
      subject(:context) do
        described_class.new(
          push_options: Gitlab::PushOptions.new(
            ['security_policy.bypass_reason=<script>alert("xss")</script>Emergency fix']
          )
        )
      end

      it 'returns the sanitized reason' do
        expect(context.bypass_reason).to eq('Emergency fix')
      end
    end

    context 'when push_options has no bypass reason' do
      subject(:context) { described_class.new(push_options: Gitlab::PushOptions.new([])) }

      it 'returns nil' do
        expect(context.bypass_reason).to be_nil
      end
    end
  end
end

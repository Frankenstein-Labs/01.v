# frozen_string_literal: true

RSpec.shared_examples 'audit event streaming header' do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_length_of(:key).is_at_most(255) }
    it { is_expected.to validate_length_of(:value).is_at_most(2000) }

    describe 'protected header key validation' do
      context 'when key is the protected streaming token header' do
        it 'is invalid with exact case match' do
          header = described_class.new(key: 'X-Gitlab-Event-Streaming-Token', value: 'some-value')
          header.valid?

          expect(header.errors[:key]).to include('cannot be X-Gitlab-Event-Streaming-Token')
        end

        it 'is invalid with lowercase' do
          header = described_class.new(key: 'x-gitlab-event-streaming-token', value: 'some-value')
          header.valid?

          expect(header.errors[:key]).to include('cannot be X-Gitlab-Event-Streaming-Token')
        end

        it 'is invalid with uppercase' do
          header = described_class.new(key: 'X-GITLAB-EVENT-STREAMING-TOKEN', value: 'some-value')
          header.valid?

          expect(header.errors[:key]).to include('cannot be X-Gitlab-Event-Streaming-Token')
        end

        it 'is invalid with mixed case' do
          header = described_class.new(key: 'x-GiTLaB-EvEnT-sTrEaMiNg-ToKeN', value: 'some-value')
          header.valid?

          expect(header.errors[:key]).to include('cannot be X-Gitlab-Event-Streaming-Token')
        end
      end

      context 'when key is similar but not exactly the protected header' do
        it 'is valid with partial match' do
          header = described_class.new(key: 'X-Gitlab-Event', value: 'some-value')

          expect(header).to be_valid
        end

        it 'is valid with prefix' do
          header = described_class.new(key: 'Prefix-X-Gitlab-Event-Streaming-Token', value: 'some-value')

          expect(header).to be_valid
        end

        it 'is valid with suffix' do
          header = described_class.new(key: 'X-Gitlab-Event-Streaming-Token-Suffix', value: 'some-value')

          expect(header).to be_valid
        end
      end

      context 'when key is a regular header' do
        it 'is valid' do
          header = described_class.new(key: 'Authorization', value: 'Bearer token', active: true)

          expect(header).to be_valid
        end

        it 'is valid with custom headers' do
          header = described_class.new(key: 'X-Custom-Header', value: 'custom-value', active: true)

          expect(header).to be_valid
        end
      end

      context 'when key is nil or empty' do
        it 'has standard validation error for nil key' do
          header = described_class.new(key: nil, value: 'some-value')
          header.valid?

          expect(header.errors[:key]).to include("can't be blank")
          expect(header.errors[:key]).not_to include('cannot be X-Gitlab-Event-Streaming-Token')
        end

        it 'has standard validation error for empty key' do
          header = described_class.new(key: '', value: 'some-value')
          header.valid?

          expect(header.errors[:key]).to include("can't be blank")
          expect(header.errors[:key]).not_to include('cannot be X-Gitlab-Event-Streaming-Token')
        end
      end
    end

    describe 'active field validation' do
      it 'is valid when active is true' do
        header = described_class.new(key: 'foo', value: 'bar', active: true)

        expect(header).to be_valid
      end

      it 'is valid when active is false' do
        header = described_class.new(key: 'foo', value: 'bar', active: false)

        expect(header).to be_valid
      end

      it 'is invalid when active is nil' do
        header = described_class.new(key: 'foo', value: 'bar', active: nil)
        header.valid?

        expect(header.errors[:active]).to include('must be a boolean value')
      end
    end
  end

  describe '#to_hash' do
    it 'returns the correct hash' do
      expect(subject.to_hash).to eq({ 'foo' => 'bar' })
    end

    it 'returns hash with actual key and value' do
      header = described_class.new(key: 'Authorization', value: 'Bearer token123')

      expect(header.to_hash).to eq({ 'Authorization' => 'Bearer token123' })
    end
  end

  describe 'preventing modification of existing protected headers' do
    context 'when trying to update an existing header to use protected key' do
      it 'prevents changing key to protected value' do
        # Save the subject first with a different key
        subject.key = 'Regular-Header'
        subject.save!

        # Try to change to protected key
        subject.key = 'X-Gitlab-Event-Streaming-Token'

        expect(subject).not_to be_valid
        expect(subject.errors[:key]).to include('cannot be X-Gitlab-Event-Streaming-Token')
      end
    end
  end
end

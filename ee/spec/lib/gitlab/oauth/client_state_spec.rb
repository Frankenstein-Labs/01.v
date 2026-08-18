# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Oauth::ClientState, feature_category: :workflow_catalog do
  let(:salt) { 'b9653b6aa2ff6b54' }
  # A pre-encoded token generated at `timestamp` with the above salt, return_to, and data.
  # Computed inside the around block so time is already frozen to `timestamp`.
  let(:token) do
    described_class.new(return_to: return_to, data: data, salt: salt).encode.split(':', 3)[1]
  end

  let(:return_to) { 'http://example.com/dashboard?foo=bar#section' }
  let(:data) { { mcp_server_id: '42' } }
  let(:timestamp) { Time.utc(2024, 1, 1, 12, 0, 0) }

  around do |example|
    if example.metadata[:no_traveling]
      example.run
    else
      travel_to(timestamp) { example.run }
    end
  end

  before do
    # rubocop:disable Layout/LineLength -- long test key
    allow(Gitlab::Application.credentials).to receive(:secret_key_base)
      .and_return('712f2a504647cb8aa7b06f2273c1db026dd9d2566acf228cd44f25f7d372c165af72209f34cb9df6623780425ce717884cf0c7f85c1deb108bd45a8cd2c93427')
    # rubocop:enable Layout/LineLength
  end

  describe '.from_state' do
    it 'returns an invalid instance when state is nil' do
      expect(described_class.from_state(nil)).not_to be_valid
    end

    it 'returns an invalid instance when state is empty' do
      expect(described_class.from_state('')).not_to be_valid
    end

    it 'returns a valid instance when state is valid' do
      encoded = "#{salt}:#{token}:/dashboard?foo=bar#section"
      expect(described_class.from_state(encoded)).to be_valid
    end
  end

  describe '#valid?' do
    it 'returns false when return_to is nil' do
      expect(described_class.new(return_to: nil, data: data)).not_to be_valid
    end

    it 'returns false when token is nil' do
      expect(described_class.new(return_to: return_to, data: data, salt: salt, token: nil)).not_to be_valid
    end

    it 'returns false when token is empty' do
      expect(described_class.new(return_to: return_to, data: data, salt: salt, token: '')).not_to be_valid
    end

    it 'returns false when salt does not match' do
      expect(described_class.new(return_to: return_to, data: data, salt: 'wrong-salt', token: token)).not_to be_valid
    end

    it 'returns false when token is tampered' do
      expect(described_class.new(return_to: return_to, data: data, salt: salt, token: 'invalid-token')).not_to be_valid
    end

    it 'returns false when return_to does not match the token', :no_traveling do
      state = travel_to(timestamp) do
        described_class.new(return_to: return_to, data: data, salt: salt, token: token)
      end

      tampered = described_class.new(return_to: '/other', data: data, salt: salt, token: state.encode.split(':', 3)[1])
      expect(tampered).not_to be_valid
    end

    it 'returns false when data does not match the token', :no_traveling do
      state = travel_to(timestamp) do
        described_class.new(return_to: return_to, data: data, salt: salt, token: token)
      end

      tampered = described_class.new(return_to: return_to, data: { mcp_server_id: '99' }, salt: salt,
        token: state.encode.split(':', 3)[1])
      expect(tampered).not_to be_valid
    end

    it 'returns false when token has expired', :no_traveling do
      state = travel_to(timestamp) do
        described_class.new(return_to: return_to, data: data, salt: salt, token: token)
      end

      # Needs to be at least 120 seconds: 60s expiry + 60s leeway
      travel_to(timestamp + 125.seconds) do
        expect(state).not_to be_valid
      end
    end

    it 'returns true when token matches' do
      expect(described_class.new(return_to: return_to, data: data, salt: salt, token: token)).to be_valid
    end
  end

  describe '#encode' do
    it 'does not raise an error when return_to is nil' do
      expect { described_class.new(return_to: nil, data: data).encode }.not_to raise_error
    end

    it 'returns a colon-separated string of salt, token, and return_to' do
      state = described_class.new(return_to: return_to, data: data)
      parts = state.encode.split(':', 3)

      expect(parts[0]).not_to be_blank
      expect(parts[1]).not_to be_blank
      expect(parts[2]).to eq('/dashboard?foo=bar#section')
    end
  end

  describe '#return_to' do
    it 'returns nil when return_to is nil' do
      expect(described_class.new(return_to: nil).return_to).to be_nil
    end

    it 'returns an empty string when return_to is empty' do
      expect(described_class.new(return_to: '').return_to).to eq('')
    end

    it 'strips the domain and returns only the path' do
      expect(described_class.new(return_to: return_to).return_to).to eq('/dashboard?foo=bar#section')
    end
  end

  describe '#[]' do
    it 'returns the data value for a symbol key' do
      state = described_class.new(return_to: return_to, data: data, salt: salt, token: token)

      expect(state[:mcp_server_id]).to eq('42')
    end

    it 'returns the data value for a string key' do
      state = described_class.new(return_to: return_to, data: data, salt: salt, token: token)

      expect(state['mcp_server_id']).to eq('42')
    end

    it 'returns nil for an unknown key' do
      state = described_class.new(return_to: return_to, data: data, salt: salt, token: token)

      expect(state[:unknown]).to be_nil
    end

    it 'returns nil when the token cannot be decoded (JWT::DecodeError)' do
      state = described_class.new(return_to: return_to, data: data, salt: salt, token: 'invalid-token')

      expect(state[:mcp_server_id]).to be_nil
    end

    it 'returns nil when the token is absent' do
      state = described_class.new(return_to: return_to, data: data, salt: salt, token: nil)

      expect(state[:mcp_server_id]).to be_nil
    end
  end
end

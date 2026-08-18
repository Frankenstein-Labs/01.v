# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::Keys, :models, feature_category: :system_access do
  describe 'validations' do
    subject(:key_record) { create(:cloud_connector_keys) }

    it { is_expected.to be_valid }

    context 'when secret_key is nil' do
      before do
        key_record.secret_key = nil
      end

      it { is_expected.to be_valid }
    end

    context 'when secret_key is not a valid RSA key' do
      before do
        key_record.secret_key = ''
      end

      it { is_expected.not_to be_valid }
    end
  end

  shared_examples 'serving valid keys' do
    context 'when there are no records' do
      it { is_expected.to be_empty }
    end

    context 'when there are records but the key is nil' do
      let_it_be(:key_record) { create(:cloud_connector_keys, secret_key: nil) }

      it { is_expected.to be_empty }
    end

    context 'when there are valid records' do
      let_it_be(:key_record) { create_list(:cloud_connector_keys, 2) }

      it { is_expected.to have_attributes(size: 2) }
    end
  end

  describe '.valid' do
    subject(:keys) { described_class.valid }

    include_examples 'serving valid keys'
  end

  describe '.ordered_by_date' do
    subject(:keys) { described_class.ordered_by_date }

    let_it_be(:first_key) { create(:cloud_connector_keys, created_at: Time.current - 1.minute) }
    let_it_be(:second_key) { create(:cloud_connector_keys) }

    it { is_expected.to eq([first_key, second_key]) }
  end

  describe '.all_as_pem' do
    subject(:keys) { described_class.all_as_pem }

    include_examples 'serving valid keys'

    context 'when there are valid records' do
      let_it_be(:key_record) { create_list(:cloud_connector_keys, 2) }

      it { is_expected.to all(match(/^-----BEGIN RSA PRIVATE KEY-----/)) }
    end
  end

  describe '.current' do
    subject(:jwk) { described_class.current }

    context 'when there are no records' do
      it { is_expected.to be_nil }
    end

    context 'when there are records' do
      context 'and the key is nil' do
        let_it_be(:key_record) { create(:cloud_connector_keys, secret_key: nil) }

        it { is_expected.to be_nil }
      end

      context 'and they are valid' do
        let_it_be(:key_record) { create(:cloud_connector_keys) }

        context 'and there is exactly one record' do
          it { is_expected.to eq(key_record) }
        end

        context 'and there are multiple records', :freeze_time do
          it 'returns the oldest record' do
            oldest_record = create(:cloud_connector_keys, created_at: key_record.created_at - 1.day)

            expect(jwk).to eq(oldest_record)
          end
        end
      end
    end
  end

  describe '.create_new_key!' do
    it 'creates a new valid key' do
      expect { described_class.create_new_key! }.to change { described_class.valid.count }.from(0).to(1)
    end
  end

  describe '.rotate!' do
    subject(:rotate) { described_class.rotate! }

    let_it_be(:first_key) { create(:cloud_connector_keys, created_at: Time.current - 1.minute) }

    context 'when fewer than 2 keys exist' do
      it { expect { rotate }.to raise_error(StandardError, 'Key rotation requires exactly 2 keys, found 1') }
    end

    context 'when more than 2 keys exist' do
      before do
        create_list(:cloud_connector_keys, 2)
      end

      it { expect { rotate }.to raise_error(StandardError, 'Key rotation requires exactly 2 keys, found 3') }
    end

    context 'when exactly 2 keys exist' do
      let_it_be(:second_key) { create(:cloud_connector_keys) }

      it 'swaps the keys' do
        expect { rotate }.to change { described_class.valid.pluck(:secret_key) }
          .from([first_key.secret_key, second_key.secret_key])
          .to([second_key.secret_key, first_key.secret_key])
      end
    end
  end

  describe '.trim!' do
    subject(:trimmed_key) { described_class.trim! }

    context 'with no keys' do
      it { is_expected.to be_nil }
    end

    context 'with a single key' do
      let_it_be(:key) { create(:cloud_connector_keys) }

      it { expect { trimmed_key }.to raise_error(StandardError, 'Refusing to remove single key, as it is in use') }
    end

    context 'with more than 1 key' do
      let_it_be(:first_key) { create(:cloud_connector_keys, created_at: Time.current - 1.minute) }
      let_it_be(:second_key) { create(:cloud_connector_keys) }

      it 'removes the newest key' do
        expect(trimmed_key).to eq(second_key)
        expect(described_class.all).to contain_exactly(first_key)
      end
    end
  end

  describe '#truncated_pem' do
    subject(:short_pem) { build(:cloud_connector_keys).truncated_pem }

    it 'truncates the PEM string to 90 characters' do
      expect(short_pem.length).to eq(90)
    end
  end

  describe '#to_jwk' do
    let(:key) { build(:cloud_connector_keys) }

    subject(:jwk) { key.to_jwk }

    it 'returns the key as JWK' do
      expect(jwk).to be_instance_of(JWT::JWK::RSA)
    end

    it 'uses RFC 7638 thumbprint key generator to compute kid' do
      expect(::JWT::JWK).to receive(:new)
        .with(kind_of(OpenSSL::PKey::RSA), kid_generator: ::JWT::JWK::Thumbprint)
        .and_call_original

      expect(jwk.kid).to be_an_instance_of(String)
    end

    context 'when the stored key is null' do
      before do
        key.secret_key = nil
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#public_key' do
    let(:key) { build(:cloud_connector_keys) }

    subject(:public_key) { key.public_key }

    it 'returns the public key' do
      expect(public_key).to be_instance_of(OpenSSL::PKey::RSA)
      expect(public_key.private?).to be(false)
    end

    context 'when the stored key is null' do
      before do
        key.secret_key = nil
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#decode_token' do
    let(:key) { build(:cloud_connector_keys) }
    let(:claims) do
      {
        issuer: 'test',
        audience: ['audience'],
        subject: 'subject',
        realm: 'realm',
        scopes: ['scope'],
        ttl: 3600
      }
    end

    let(:token) do
      Gitlab::CloudConnector::JsonWebToken.new(**claims).encode(key.to_jwk)
    end

    subject(:decoded_token) { key.decode_token(token) }

    it 'decodes the token' do
      payload, header = decoded_token

      # We don't need to verify all components again here, this is tested in the Cloud Connector
      # gem itself. We only want to verify we can decode it successfully and obtain both
      # the payload and header.
      expect(header).to include('typ' => 'JWT', 'alg' => 'RS256', 'kid' => key.to_jwk.kid)
      expect(payload).to include('iss' => 'test')
    end
  end

  # See https://gitlab.com/gitlab-org/gitlab/-/work_items/585384
  context 'when accessing keys stored using a different key provider' do
    let_it_be(:legacy_keys_class) do
      Class.new(ApplicationRecord) do
        self.table_name = 'cloud_connector_keys'

        encrypts :secret_key, key_provider: ActiveRecord::Encryption::EnvelopeEncryptionKeyProvider.new
      end
    end

    before do
      # Create a record using the key provider we used in versions prior to GitLab 18.9
      legacy_keys_class.create!(secret_key: OpenSSL::PKey::RSA.new(2048).to_pem)
    end

    it 'can decrypt records using default provider when keys were stored using EnvelopeEncryptionProvider' do
      expect { described_class.first.secret_key }.not_to raise_error
    end
  end
end

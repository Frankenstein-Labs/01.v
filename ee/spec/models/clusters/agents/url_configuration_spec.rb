# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Clusters::Agents::UrlConfiguration, feature_category: :deployment_management do
  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:agent, freeze: false) { create(:cluster_agent) }

  subject { create(:cluster_agent_url_configuration, agent: agent) }

  it { is_expected.to belong_to(:agent).class_name('::Clusters::Agent').required }
  it { is_expected.to belong_to(:project).class_name('::Project').required }
  it { is_expected.to belong_to(:created_by_user).class_name('User').optional }

  it { is_expected.to define_enum_for(:status).with_values(active: 0, revoked: 1) }
  it { is_expected.to nullify_if_blank(:client_cert, :client_key, :ca_cert, :tls_host) }

  describe 'after hooks' do
    subject(:record) { build(:cluster_agent_url_configuration, agent: agent) }

    context 'when model is created' do
      it 'sets agent as receptive' do
        expect(record.agent.is_receptive).to be(true)
      end
    end

    context 'when model is destroyed' do
      it 'unsets agent as receptive' do
        record.destroy!

        expect(agent.is_receptive).to be(false)
      end
    end
  end

  describe 'validations' do
    describe 'url' do
      subject(:record) { build(:cluster_agent_url_configuration, agent: agent) }

      before do
        record.url = url
        record.validate
      end

      context 'with a valid url' do
        let(:url) { 'grpc://agent.example.com' }

        it do
          expect(record.errors[:url]).to be_empty
        end
      end

      context 'with an invalid url' do
        let(:url) { 'https://agent.example.com' }

        it do
          expect(record.errors[:url]).to eq(['is not a valid URL'])
        end
      end
    end

    describe 'public_key and private_key length validations' do
      it 'rejects oversized public_key' do
        url_configuration = create(:cluster_agent_url_configuration, agent: agent)
        url_configuration.public_key = "\x00" * (described_class::PUBLIC_KEY_MAX_LENGTH + 1)

        expect(url_configuration).not_to be_valid
      end

      it 'rejects oversized private_key' do
        url_configuration = create(:cluster_agent_url_configuration, :public_key_auth, agent: agent)
        url_configuration.private_key = "\x00" * (described_class::PRIVATE_KEY_MAX_LENGTH + 1)

        expect(url_configuration).not_to be_valid
      end

      it 'does not invalidate existing records' do
        url_configuration = create(:cluster_agent_url_configuration, :public_key_auth, agent: agent)
        url_configuration.public_key = 'A' * (described_class::PUBLIC_KEY_MAX_LENGTH + 1)
        url_configuration.private_key = 'A' * (described_class::PRIVATE_KEY_MAX_LENGTH + 1)
        url_configuration.save!(validate: false)

        expect(url_configuration.reload).to be_valid
      end
    end

    context 'for certificate auth' do
      subject(:record) { build(:cluster_agent_url_configuration, :certificate_auth, agent: agent) }

      describe 'client_cert' do
        before do
          record.client_cert = cert
          record.validate
        end

        context 'with an invalid certificate' do
          let(:cert) { 'invalid' }

          it do
            expect(record.errors[:client_cert]).to eq(['must be a valid PEM certificate'])
          end
        end

        context 'with a valid certificate' do
          let(:cert) { File.read(Rails.root.join('spec/fixtures/clusters/sample_cert.pem')) }

          it do
            expect(record.errors[:client_cert]).to be_empty
          end
        end
      end

      describe 'client_key' do
        before do
          record.client_key = key
          record.validate
        end

        context 'with an invalid key' do
          let(:key) { 'invalid' }

          it do
            expect(record.errors[:client_key]).to eq(['must be a valid PEM private key'])
          end
        end

        context 'with a valid key' do
          let(:key) { File.read(Rails.root.join('spec/fixtures/clusters/sample_key.key')) }

          it do
            expect(record.errors[:client_key]).to be_empty
          end
        end
      end

      it { is_expected.to validate_absence_of(:private_key) }
    end

    context 'for public key auth' do
      subject { create(:cluster_agent_url_configuration, :public_key_auth, agent: agent) }

      it { is_expected.to validate_presence_of(:private_key) }

      it { is_expected.to validate_absence_of(:client_cert) }
      it { is_expected.to validate_absence_of(:client_key) }
    end

    describe 'ca_cert' do
      subject(:record) { build(:cluster_agent_url_configuration, agent: agent) }

      before do
        record.ca_cert = cert
        record.validate
      end

      context 'with an invalid certificate' do
        let(:cert) { 'invalid' }

        it do
          expect(record.errors[:ca_cert]).to eq(['must be a valid PEM certificate'])
        end
      end

      context 'with a valid certificate' do
        let(:cert) { File.read(Rails.root.join('spec/fixtures/clusters/sample_cert.pem')) }

        it do
          expect(record.errors[:ca_cert]).to be_empty
        end
      end

      context 'with an empty cert' do
        let(:cert) { nil }

        it do
          expect(record.errors[:ca_cert]).to be_empty
        end
      end
    end

    describe 'tls_host' do
      subject(:record) { build(:cluster_agent_url_configuration, agent: agent) }

      before do
        record.tls_host = host
        record.validate
      end

      context 'with an invalid host' do
        let(:host) { 'https://exmple.com/path' }

        it do
          expect(record.errors[:tls_host]).to eq(['must be a valid hostname!'])
        end
      end

      context 'with a valid host' do
        let(:host) { 'host.example.com' }

        it do
          expect(record.errors[:tls_host]).to be_empty
        end
      end

      context 'with an empty host' do
        let(:host) { nil }

        it do
          expect(record.errors[:tls_host]).to be_empty
        end
      end
    end
  end
end

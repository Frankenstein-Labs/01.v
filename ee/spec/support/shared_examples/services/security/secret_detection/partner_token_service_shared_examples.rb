# frozen_string_literal: true

RSpec.shared_examples 'partner token service' do
  let_it_be(:project, freeze: false) { create(:project) }

  describe '.finding_type' do
    it 'returns expected value' do
      expect(described_class.finding_type).to eq(expected_finding_type)
    end
  end

  describe '.token_status_model' do
    it 'returns expected model' do
      expect(described_class.token_status_model).to eq(expected_token_status_model)
    end
  end

  describe '.unique_by_column' do
    it 'returns expected column' do
      expect(described_class.unique_by_column).to eq(expected_unique_by_column)
    end
  end

  describe '.process_finding_async' do
    before do
      findings.each { |f| allow(f).to receive(:token_type).and_return('AWS') }
      allow(Security::SecretDetection::PartnerTokens::Registry)
        .to receive(:partner_for).with('AWS').and_return('AWS')
    end

    it 'passes correct arguments to worker' do
      captured_args_proc = nil

      allow(Security::SecretDetection::PartnerTokenVerificationWorker)
        .to receive(:bulk_perform_async_with_contexts) do |_findings, options|
          captured_args_proc = options[:arguments_proc]
        end

      described_class.process_finding_async([findings.first], project)

      args = captured_args_proc.call(findings.first)
      expect(args).to match_array([findings.first.id, expected_finding_type])
    end

    it 'enqueues worker for each partner token' do
      expect(Security::SecretDetection::PartnerTokenVerificationWorker)
        .to receive(:bulk_perform_async_with_contexts)
        .once
        .with(
          findings,
          hash_including(
            arguments_proc: kind_of(Proc),
            context_proc: kind_of(Proc)
          )
        )

      described_class.process_finding_async(findings, project)
    end

    context 'with non-partner tokens' do
      before do
        findings.each { |f| allow(f).to receive(:token_type).and_return('some_other_token') }
        allow(Security::SecretDetection::PartnerTokens::Registry)
          .to receive(:partner_for).with('some_other_token').and_return(nil)
      end

      it 'does not enqueue worker' do
        expect(Security::SecretDetection::PartnerTokenVerificationWorker)
          .not_to receive(:bulk_perform_async_with_contexts)

        described_class.process_finding_async(findings, project)
      end
    end
  end

  describe '.process_partner_finding' do
    let(:client) { instance_double(Security::SecretDetection::PartnerTokensClient) }
    let(:result) do
      Security::SecretDetection::PartnerTokens::BaseClient::TokenStatus.new(
        status: :active,
        metadata: { verified_at: Time.current }
      )
    end

    before do
      allow(Security::SecretDetection::PartnerTokensClient).to receive(:new).and_return(client)
    end

    context 'when all checks pass' do
      before do
        allow(client).to receive_messages(valid_config?: true, rate_limited?: false, verify_token: result)
      end

      it 'calls partner API and saves result' do
        expect(described_class).to receive(:save_result).with(finding, result)

        described_class.process_partner_finding(finding)
      end
    end

    context 'when config is invalid' do
      before do
        allow(client).to receive(:valid_config?).and_return(false)
      end

      it 'does not call verify_token' do
        expect(client).not_to receive(:verify_token)

        described_class.process_partner_finding(finding)
      end
    end

    context 'when rate limited' do
      before do
        allow(client).to receive_messages(valid_config?: true, rate_limited?: true)
      end

      it 'does not call verify_token' do
        expect(client).not_to receive(:verify_token)

        described_class.process_partner_finding(finding)
      end
    end
  end

  describe '.partner_token?' do
    using RSpec::Parameterized::TableSyntax

    where(:token_type, :partner, :expected) do
      'AWS' | 'AWS' | true
      'GCP API key' | 'GCP' | true
      'Postman API token' | 'Postman' | true
      'some_other_token' | nil | false
    end

    with_them do
      before do
        allow(Security::SecretDetection::PartnerTokens::Registry)
          .to receive(:partner_for).with(token_type).and_return(partner)
      end

      it 'returns correct value' do
        expect(described_class.partner_token?(token_type)).to eq(expected)
      end
    end
  end

  describe '.save_result' do
    let(:result) do
      Security::SecretDetection::PartnerTokens::BaseClient::TokenStatus.new(
        status: :active,
        metadata: { verified_at: Time.current }
      )
    end

    it 'saves to correct model with correct attributes' do
      described_class.save_result(finding, result)

      token_status = expected_token_status_model.find_by(expected_unique_by_column => finding.id)
      expect(token_status).to be_present
      expect(token_status.project_id).to eq(finding.project_id)
      expect(token_status.status).to eq('active')
    end

    it 'includes verified_at timestamp' do
      verified_time = Time.current
      result_with_time = Security::SecretDetection::PartnerTokens::BaseClient::TokenStatus.new(
        status: :inactive,
        metadata: { verified_at: verified_time }
      )

      described_class.save_result(finding, result_with_time)

      token_status = expected_token_status_model.find_by(expected_unique_by_column => finding.id)
      expect(token_status.last_verified_at).to be_within(1.second).of(verified_time)
    end
  end
end

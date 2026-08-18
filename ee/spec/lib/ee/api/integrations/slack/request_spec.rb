# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Integrations::Slack::Request, feature_category: :notifications do
  describe '.verify!', :freeze_time do
    let(:signing_secret) { 'test_signing_secret' }
    let(:timestamp) { Time.current.to_i.to_s }
    let(:body) { 'test_request_body' }
    let(:basestring) { "v0:#{timestamp}:#{body}" }
    let(:signature) do
      hmac = OpenSSL::HMAC.hexdigest('sha256', signing_secret, basestring)
      "v0=#{hmac}"
    end

    let(:request) do
      instance_double(ActionDispatch::Request,
        headers: {
          described_class::VERIFICATION_TIMESTAMP_HEADER => timestamp,
          described_class::VERIFICATION_SIGNATURE_HEADER => signature
        },
        body: StringIO.new(body)
      )
    end

    subject(:verify!) { described_class.verify!(request) }

    before do
      allow(Gitlab::CurrentSettings)
        .to receive(:slack_app_signing_secret)
        .and_return(signing_secret)
    end

    it { is_expected.to be(true) }

    context 'when GitLab for Slack app integration is blocked by settings' do
      before do
        allow(Integrations::GitlabSlackApplication).to receive(:blocked_by_settings?).and_return(true)
      end

      it { is_expected.to be(false) }
    end
  end
end

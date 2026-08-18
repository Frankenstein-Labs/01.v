# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::SelfHosted::CodeSuggestionsLicenseProbe, feature_category: :duo_setting do
  let(:probe) { described_class.new(user) }
  let(:user) { build(:user) }

  describe '#execute' do
    context 'when user has access to code suggestions' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :access_code_suggestions).and_return(true)
      end

      it 'returns a success result' do
        result = probe.execute

        expect(result.success).to be true
        expect(result.message).to match('License includes access to Code Suggestions.')
      end
    end

    context 'when user does not have access to code suggestions' do
      before do
        stub_licensed_features(code_suggestions: true)
        allow(Ability).to receive(:allowed?).with(user, :access_code_suggestions).and_return(false)
      end

      it 'returns a failure result' do
        result = probe.execute

        expect(result.success).to be false
        expect(result.message).to match(
          'License includes access to Code Suggestions, but you lack the necessary ' \
            'permissions to use this feature.'
        )
      end
    end

    context 'when license does not provide access to code suggestions' do
      before do
        stub_licensed_features(code_suggestions: false)
      end

      it 'returns a failure result' do
        result = probe.execute

        expect(result.success).to be false
        expect(result.message).to match('License does not provide access to Code Suggestions.')
      end
    end

    context 'on collecting details' do
      let(:license) { build(:license, cloud: false) }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'collects the instance details' do
        result = probe.execute

        expect(result.details[:instance_id]).to eq(Gitlab::GlobalAnonymousId.instance_id)
        expect(result.details[:gitlab_version]).to eq(Gitlab::VERSION)
      end

      it 'collects the license details' do
        result = probe.execute

        expect(result.details[:license]).to eq(License.current.license.as_json)
      end
    end
  end
end

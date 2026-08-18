# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::CloudConnector, feature_category: :system_access do
  describe '.gitlab_realm' do
    subject { described_class.gitlab_realm }

    context 'when the current instance is gitlab.com', :saas do
      it { is_expected.to eq(described_class::GITLAB_REALM_SAAS) }
    end

    context 'when the current instance is not saas' do
      it { is_expected.to eq(described_class::GITLAB_REALM_SELF_MANAGED) }
    end
  end

  describe '.deployment_type' do
    subject { described_class.deployment_type }

    context 'when the current instance is gitlab.com', :saas do
      it { is_expected.to eq(described_class::GITLAB_REALM_COM) }
    end

    context 'when the current instance is not saas' do
      it { is_expected.to eq(described_class::GITLAB_REALM_SELF_MANAGED) }
    end

    context 'when the current instance is dedicated' do
      before do
        stub_application_setting(gitlab_dedicated_instance?: true)
      end

      it { is_expected.to eq(described_class::GITLAB_REALM_DEDICATED) }
    end
  end

  shared_examples 'building HTTP headers' do
    let(:expected_headers) do
      {
        'x-gitlab-host-name' => Gitlab.config.gitlab.host,
        'x-gitlab-instance-id' => an_instance_of(String),
        'x-gitlab-realm' => ::CloudConnector::GITLAB_REALM_SELF_MANAGED,
        'x-gitlab-deployment-type' => ::CloudConnector::GITLAB_REALM_SELF_MANAGED,
        'x-gitlab-version' => Gitlab.version_info.to_s
      }
    end

    subject(:headers) { described_class.headers(user) }

    context 'when the the user is present' do
      let(:user) { build(:user, id: 1) }

      it 'generates a hash with the required fields based on the user' do
        user_headers = {
          'x-gitlab-global-user-id' => an_instance_of(String),
          'x-gitlab-user-id' => user.id.to_s
        }
        expect(headers).to match(expected_headers.merge(user_headers))
      end
    end

    context 'when the the user argument is nil' do
      let(:user) { nil }

      it 'generates a hash without `X-Gitlab-Global-User-Id` and `X-Gitlab-User-Id`' do
        expect(headers).to match(expected_headers)
      end
    end
  end

  describe '.headers' do
    it_behaves_like 'building HTTP headers'
  end

  describe '.ai_headers' do
    let(:namespace_ids) { [1, 42] }
    let(:user) { build(:user) }

    subject(:ai_headers) { described_class.ai_headers(user, namespace_ids: namespace_ids) }

    it_behaves_like 'building HTTP headers'

    it 'includes namespace ids and subject type' do
      expect(ai_headers).to include(
        'x-gitlab-feature-enabled-by-namespace-ids' => namespace_ids.join(','),
        'x-gitlab-subject-type' => 'human'
      )
    end

    context 'when user is a service account' do
      let(:user) { build(:user, :service_account) }

      it 'sets x-gitlab-subject-type to service_account' do
        expect(ai_headers['x-gitlab-subject-type']).to eq('service_account')
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'sets x-gitlab-subject-type to empty string' do
        expect(ai_headers['x-gitlab-subject-type']).to eq('')
      end
    end

    context 'when a subject is provided' do
      let(:service_account) { build(:user, :service_account) }

      subject(:ai_headers) do
        described_class.ai_headers(user, namespace_ids: namespace_ids, subject: service_account)
      end

      it 'derives x-gitlab-subject-type from the subject and keeps user identity headers on the user',
        :aggregate_failures do
        expect(ai_headers['x-gitlab-subject-type']).to eq('service_account')
        expect(ai_headers).to include(
          'x-gitlab-user-id' => user.id.to_s,
          'x-gitlab-global-user-id' => Gitlab::GlobalAnonymousId.user_id(user)
        )
      end
    end
  end

  describe '.self_managed_cloud_connected?' do
    subject(:self_managed_cloud_connected?) { described_class.self_managed_cloud_connected? }

    context 'when on saas' do
      it 'returns false' do
        allow(::Gitlab).to receive(:org_or_com?).and_return(true)
        allow(::Gitlab::AiGateway).to receive(:self_hosted_url).and_return('http::test.com')

        expect(self_managed_cloud_connected?).to be(false)
      end
    end

    context 'when self-hosted and cloud connected' do
      it 'returns true' do
        allow(::Gitlab).to receive(:org_or_com?).and_return(false)
        allow(::Gitlab::AiGateway).to receive(:self_hosted_url).and_return(nil)

        expect(self_managed_cloud_connected?).to be(true)
      end
    end

    context 'when self-hosted and not cloud connected' do
      it 'returns false' do
        allow(::Gitlab).to receive(:org_or_com?).and_return(false)
        allow(::Gitlab::AiGateway).to receive(:self_hosted_url).and_return('http::test.com')

        expect(self_managed_cloud_connected?).to be(false)
      end
    end
  end
end

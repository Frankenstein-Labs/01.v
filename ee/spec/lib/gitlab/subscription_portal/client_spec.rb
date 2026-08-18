# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SubscriptionPortal::Client, feature_category: :consumables_cost_management do
  subject { described_class }

  it { is_expected.to include_module Gitlab::SubscriptionPortal::Clients::Graphql }
  it { is_expected.to include_module Gitlab::SubscriptionPortal::Clients::Rest }

  describe ".license_checksum_headers" do
    subject(:license_checksum_headers) { described_class.license_checksum_headers }

    context "with the license" do
      it "returns the `X-License-Token` header with the license checksum as value" do
        is_expected.to include({
          "X-License-Token" => License.current.checksum
        })
      end
    end

    context "without license", :without_license do
      it "raises the `No active license` error" do
        expect do
          license_checksum_headers
        end.to raise_error(/No active license/)
      end
    end
  end

  describe '.default_headers' do
    subject(:default_headers) { described_class.send(:default_headers) }

    context 'when subscription portal URL differs from staging URL' do
      before do
        allow(::Gitlab::Routing.url_helpers).to receive_messages(
          subscription_portal_url: 'https://customers.gitlab.com',
          subscription_portal_staging_url: 'https://customers.staging.gitlab.com'
        )
      end

      it 'sets User-Agent to the GitLab version' do
        expect(default_headers).to eq({ "User-Agent" => "GitLab/#{Gitlab::VERSION}" })
      end

      context 'when GITLAB_QA_USER_AGENT is set' do
        before do
          stub_env('GITLAB_QA_USER_AGENT', 'GitLab/QA')
        end

        it 'still sets User-Agent to the GitLab version' do
          expect(default_headers).to eq({ "User-Agent" => "GitLab/#{Gitlab::VERSION}" })
        end
      end
    end

    context 'when subscription portal URL matches staging URL' do
      before do
        allow(::Gitlab::Routing.url_helpers).to receive_messages(
          subscription_portal_url: 'https://customers.staging.gitlab.com',
          subscription_portal_staging_url: 'https://customers.staging.gitlab.com'
        )
      end

      context 'when GITLAB_QA_USER_AGENT is set' do
        before do
          stub_env('GITLAB_QA_USER_AGENT', 'GitLab/QA')
        end

        it 'sets User-Agent to the QA user agent' do
          expect(default_headers).to eq({ "User-Agent" => "GitLab/QA" })
        end
      end

      context 'when GITLAB_QA_USER_AGENT is not set' do
        before do
          stub_env('GITLAB_QA_USER_AGENT', nil)
        end

        it 'falls back to the GitLab version' do
          expect(default_headers).to eq({ "User-Agent" => "GitLab/#{Gitlab::VERSION}" })
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::ApplicationRateLimiter, feature_category: :system_access do
  let(:supported_rate_limits) { Gitlab::ApplicationRateLimiter::LabkitAdapter::SupportedRateLimits }

  describe 'rate limit values' do
    context 'when application-level rate limits are configured' do
      using RSpec::Parameterized::TableSyntax

      before do
        stub_application_setting(max_number_of_repository_downloads: 1)
        stub_application_setting(max_number_of_repository_downloads_within_time_period: 60)
        stub_application_setting(soft_phone_verification_transactions_daily_limit: 60)
        stub_application_setting(hard_phone_verification_transactions_daily_limit: 100)
        stub_application_setting(dependency_scanning_sbom_scan_api_upload_limit: 500)
        stub_application_setting(dependency_scanning_sbom_scan_api_download_limit: 500)
      end

      where(:key, :threshold, :interval) do
        :ai_catalog_item_report | 10 | 1.minute
        :unique_project_downloads_for_application | 1 | 1.minute
        :code_suggestions_api_endpoint | 60 | 1.minute
        :code_suggestions_direct_access | 50 | 1.minute
        :code_suggestions_connection_details | 10 | 1.minute
        :duo_workflow_direct_access | 50 | 1.minute
        :create_duo_otel_workflow | 5 | 1.minute
        :soft_phone_verification_transactions_limit | 60 | 1.day
        :hard_phone_verification_transactions_limit | 100 | 1.day
        :container_scanning_for_registry_scans | 50 | 1.day
        :dependency_scanning_sbom_scan_api_throttling | 50 | 1.hour
        :dependency_scanning_sbom_scan_api_upload | 500 | 1.hour
        :dependency_scanning_sbom_scan_api_download | 500 | 1.hour
        :virtual_registries_endpoints_api_limit | 4000 | 15.seconds
        :partner_aws_api | 400 | 1.second
        :partner_gcp_api | 500 | 1.second
        :partner_postman_api | 4 | 1.second
      end

      with_them do
        it "includes values for #{params[:key]}" do
          expect(supported_rate_limits.limit_for(key)).to eq threshold
          expect(supported_rate_limits.period_for(key)).to eq interval
        end
      end
    end

    context 'with partner API rate limits' do
      shared_examples 'partner rate limit configuration' do |key, expected_threshold, expected_interval|
        it "configures #{key} correctly" do
          expect(supported_rate_limits.limit_for(key)).to eq(expected_threshold)
          expect(supported_rate_limits.period_for(key)).to eq(expected_interval)
        end
      end

      it_behaves_like 'partner rate limit configuration', :partner_aws_api, 400, 1.second
      it_behaves_like 'partner rate limit configuration', :partner_gcp_api, 500, 1.second
      it_behaves_like 'partner rate limit configuration', :partner_postman_api, 4, 1.second
    end

    context 'when namespace-level rate limits are configured' do
      it 'includes fixed default values for unique_project_downloads_for_namespace', :aggregate_failures do
        expect(supported_rate_limits.limit_for(:unique_project_downloads_for_namespace)).to eq 0
        expect(supported_rate_limits.period_for(:unique_project_downloads_for_namespace)).to eq 0
      end

      it 'includes fixed default values for soft_phone_verification_transactions_limit' do
        expect(supported_rate_limits.limit_for(:soft_phone_verification_transactions_limit)).to eq(16000)
        expect(supported_rate_limits.period_for(:soft_phone_verification_transactions_limit)).to eq(1.day)
      end

      it 'includes fixed default values for hard_phone_verification_transactions_limit' do
        expect(supported_rate_limits.limit_for(:hard_phone_verification_transactions_limit)).to eq(20000)
        expect(supported_rate_limits.period_for(:hard_phone_verification_transactions_limit)).to eq(1.day)
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::SyncServiceTokenWorker, type: :worker, feature_category: :system_access do
  describe '#perform' do
    let(:service) { instance_double(CloudConnector::SyncCloudConnectorAccessService) }
    let(:service_response) { ServiceResponse.success }

    let_it_be(:license) { create(:license) }
    let(:job_args) { [] }

    before do
      allow_next_instance_of(CloudConnector::SyncCloudConnectorAccessService, license) do |service|
        allow(service).to receive(:execute).and_return(service_response)
      end
    end

    include_examples 'an idempotent worker' do
      let(:worker) { described_class.new }

      subject(:sync_service_token) { perform_multiple(job_args, worker: worker) }

      context 'when license ID is passed' do
        let(:job_args) { [{ 'license_id' => license.id }] }

        it 'executes the SyncCloudConnectorAccessService with given license' do
          expect(::License).not_to receive(:current)
          expect(worker).not_to receive(:log_extra_metadata_on_done)

          sync_service_token
        end
      end

      context 'when no arguments are passed' do
        it 'executes the SyncCloudConnectorAccessService with current license' do
          expect(::License).to receive(:current).at_least(:once).and_return(license)
          expect(worker).not_to receive(:log_extra_metadata_on_done)

          sync_service_token
        end
      end

      context 'when SyncCloudConnectorAccessService fails' do
        let(:service_response) { ServiceResponse.error(message: 'Error') }

        it { expect { sync_service_token }.not_to raise_error }

        it 'logs the error' do
          expect(worker).to receive(:log_extra_metadata_on_done)
                              .with(:error_message, service_response[:message]).twice

          sync_service_token
        end
      end

      context 'when the last valid token is valid for less than 2 days', :freeze_time do
        let!(:service_access_token) { create(:service_access_token, expires_at: 1.day.from_now) }

        it 'executes the SyncCloudConnectorAccessService' do
          expect_next_instance_of(::CloudConnector::SyncCloudConnectorAccessService) do |instance|
            expect(instance).to receive(:execute).and_return(service_response)
          end
          expect(worker).not_to receive(:log_extra_metadata_on_done)

          sync_service_token
        end
      end

      context 'when the last valid token is valid for more than 2 days', :freeze_time do
        let!(:service_access_token) { create(:service_access_token, expires_at: 3.days.from_now) }

        context 'when there is a force: true param' do
          let(:job_args) { [{ 'force' => true }] }

          it 'executes the SyncCloudConnectorAccessService' do
            expect_next_instance_of(::CloudConnector::SyncCloudConnectorAccessService) do |instance|
              expect(instance).to receive(:execute).and_return(service_response)
            end
            expect(worker).not_to receive(:log_extra_metadata_on_done)

            sync_service_token
          end
        end

        it 'does not execute the SyncCloudConnectorAccessService' do
          expect(::CloudConnector::SyncCloudConnectorAccessService).not_to receive(:new)
          expect(worker).to receive(:log_extra_metadata_on_done)
                              .with(:result, 'skipping token refresh').twice

          sync_service_token
        end
      end
    end
  end
end

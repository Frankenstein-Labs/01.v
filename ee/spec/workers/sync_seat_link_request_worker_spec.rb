# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SyncSeatLinkRequestWorker, type: :worker, feature_category: :plan_provisioning do
  describe '#perform' do
    subject(:sync_seat_link) do
      described_class.new.perform('2020-01-01T01:20:12+02:00', license_key, 5, 4)
    end

    let(:license_key) { '123' }
    let(:subscription_portal_url) { ::Gitlab::Routing.url_helpers.subscription_portal_url }
    let(:seat_link_url) { [subscription_portal_url, '/api/v1/seat_links'].join }
    let(:body) { { success: true } }

    let(:future_subscriptions) { nil }
    let(:new_subscription) { nil }

    let_it_be(:organization) { create(:organization) }

    before do
      stub_request(:post, seat_link_url).to_return_json(
        status: 200,
        body: body.to_json
      )
    end

    shared_examples 'call service to update license dependencies' do
      it 'calls the service to update license dependencies with the correct params' do
        expect_next_instance_of(
          GitlabSubscriptions::UpdateLicenseDependenciesService,
          future_subscriptions: future_subscriptions,
          license: body.has_key?(:license) ? an_instance_of(License) : nil,
          new_subscription: new_subscription
        ) do |service|
          expect(service).to receive(:execute).and_call_original
        end

        sync_seat_link
      end
    end

    it 'makes an HTTP POST request with passed params' do
      allow(Gitlab::CurrentSettings).to receive(:uuid).and_return('one-two-three')
      allow(Gitlab::GlobalAnonymousId).to receive(:instance_uuid).and_return('three-two-one')

      sync_seat_link

      expect(WebMock).to have_requested(:post, seat_link_url).with(
        body: {
          gitlab_version: Gitlab::VERSION,
          timestamp: '2020-01-01T01:20:12+02:00',
          license_key: '123',
          max_historical_user_count: 5,
          billable_users_count: 4,
          hostname: Gitlab.config.gitlab.host,
          instance_id: 'one-two-three',
          unique_instance_id: 'three-two-one',
          add_on_metrics: []
        }.to_json
      )
    end

    context 'when response contains a license' do
      let(:subscription_name) { 'A-S00000001' }
      let(:license_key) { build(:gitlab_license, :cloud, subscription_name: subscription_name).export }
      let(:body) { { success: true, license: license_key } }

      shared_examples 'clearing license cache' do
        it 'resets the current license cache', :request_store do
          # called twice because the current license cache is reset before checking the up to date current license
          # within this class and then again with the `after_commit :reset_current` when creating the new license
          expect(License).to receive(:reset_current).twice.and_call_original

          sync_seat_link
        end
      end

      shared_examples 'successful license creation' do
        it 'persists the new license' do
          freeze_time do
            expect { sync_seat_link }.to change { License.count }.by(1)
            expect(License.current).to have_attributes(
              data: license_key,
              cloud: true
            )
          end
        end
      end

      shared_examples 'does not persist or apply the license' do
        it 'does not create a license' do
          expect { sync_seat_link }.not_to change { License.count }
        end

        it 'does not change the current license' do
          expect { sync_seat_link }.not_to change { License.current&.id }
        end

        it 'does not reset the current license cache' do
          expect(License).not_to receive(:reset_current)

          sync_seat_link
        end

        it 'does not call the service to update license dependencies' do
          expect(GitlabSubscriptions::UpdateLicenseDependenciesService).not_to receive(:new)

          sync_seat_link
        end

        context 'when refresh_token is true' do
          subject(:sync_seat_link) do
            described_class.new.perform('2020-01-01T01:20:12+02:00', license_key, 5, 4, true)
          end

          it 'does not perform Cloud Connector access data sync' do
            expect(CloudConnector::SyncServiceTokenWorker).not_to receive(:perform_async)

            sync_seat_link
          end
        end
      end

      context 'when there is no previous license' do
        before do
          License.delete_all
        end

        it_behaves_like 'does not persist or apply the license'
      end

      context 'when there is a previous license' do
        before do
          License.current # set up license cache
        end

        context 'when the subscription_name matches the active license' do
          let!(:current_license) { create(:license, subscription_name: subscription_name) }

          context 'when it is a cloud license' do
            context 'when the current license key does not match the one returned from sync' do
              let!(:current_license) do
                create(:license, cloud: true, last_synced_at: 1.day.ago, subscription_name: subscription_name)
              end

              it_behaves_like 'clearing license cache'
              it_behaves_like 'call service to update license dependencies'

              it 'creates a new license', :freeze_time do
                expect { sync_seat_link }.to change { License.cloud.count }.by(1)

                new_current_license = License.current
                expect(new_current_license.id).not_to eq(current_license.id)
                expect(new_current_license).to have_attributes(
                  data: license_key,
                  cloud: true,
                  last_synced_at: Time.current
                )
              end

              context 'when persisting fails' do
                # an expired license will fail the validation `validate :not_expired`
                let(:license_key) { build(:gitlab_license, :cloud, :expired, subscription_name: 'A-S00000001').export }

                it 'resets the current license cache', :request_store do
                  allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).and_call_original

                  # called only once because no new license is created and the `after_commit :reset_current` isn't executed
                  expect(License).to receive(:reset_current).once.and_call_original

                  expect { sync_seat_link }.to raise_error ActiveRecord::RecordInvalid
                end

                it 'does not delete the current license and logs error' do
                  expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).and_call_original

                  expect { sync_seat_link }.to raise_error ActiveRecord::RecordInvalid

                  expect(License).to exist(current_license.id)
                end

                it 'does not call the service to update license dependencies' do
                  expect(GitlabSubscriptions::UpdateLicenseDependenciesService).not_to receive(:new)

                  expect { sync_seat_link }.to raise_error ActiveRecord::RecordInvalid
                end
              end
            end

            context 'when the current license key matches the one returned from sync' do
              let!(:current_license) { create(:license, cloud: true, data: license_key, last_synced_at: 1.day.ago) }

              it_behaves_like 'clearing license cache'
              it_behaves_like 'call service to update license dependencies'

              it 'reuses the current license and updates the last_synced_at', :request_store, :freeze_time do
                expect { sync_seat_link }.not_to change { License.cloud.count }

                expect(License.current).to have_attributes(
                  id: current_license.id,
                  data: license_key,
                  cloud: true,
                  last_synced_at: Time.current
                )
              end
            end
          end

          context 'when it is not a cloud license' do
            it_behaves_like 'clearing license cache'
            it_behaves_like 'successful license creation'
            it_behaves_like 'call service to update license dependencies'
          end

          context 'when response contains reconciliation dates' do
            let(:body) { { success: true, next_reconciliation_date: today.to_s, display_alert_from: (today - 7.days).to_s } }
            let(:today) { Date.current }

            it 'creates reconciliation record with correct attributes' do
              sync_seat_link
              upcoming_reconciliation = GitlabSubscriptions::UpcomingReconciliation.next

              expect(upcoming_reconciliation.next_reconciliation_date).to eq(today)
              expect(upcoming_reconciliation.display_alert_from).to eq(today - 7.days)
              expect(upcoming_reconciliation.organization_id).to eq(organization.id)
            end

            context 'when an upcoming_reconciliation already exists' do
              it 'updates the upcoming_reconciliation' do
                upcoming_reconciliation = create(:upcoming_reconciliation, :self_managed, next_reconciliation_date: today + 2.days, display_alert_from: today + 1.day)

                sync_seat_link

                upcoming_reconciliation.reload

                expect(upcoming_reconciliation.next_reconciliation_date).to eq(today)
                expect(upcoming_reconciliation.display_alert_from).to eq(today - 7.days)
              end
            end
          end

          context 'when response contains future subscription information' do
            let(:body) { { success: true, future_subscriptions: future_subscriptions } }
            let(:today) { Date.current }

            context 'when future subscription information is present in the response' do
              let(:future_subscriptions) { [{ 'foo' => 'bar' }] }

              it_behaves_like 'call service to update license dependencies'
            end

            context 'when future subscription information is not present in the response' do
              let(:future_subscriptions) { [] }

              it_behaves_like 'call service to update license dependencies'
            end
          end

          context 'when response contains new subscription information' do
            let(:body) { { success: true, new_subscription: new_subscription } }

            context 'when new subscription is true' do
              let(:new_subscription) { true }

              it_behaves_like 'call service to update license dependencies'
            end

            context 'when new subscription is false' do
              let(:new_subscription) { false }

              it_behaves_like 'call service to update license dependencies'
            end
          end

          context 'when the response does not contain reconciliation dates' do
            let(:body) do
              {
                success: true,
                next_reconciliation_date: nil,
                display_alert_from: nil
              }
            end

            it 'destroys the existing upcoming reconciliation record for the instance' do
              create(:upcoming_reconciliation, :self_managed)

              expect { sync_seat_link }
                .to change { GitlabSubscriptions::UpcomingReconciliation.count }
                .by(-1)
            end

            it 'does not change anything when there is no existing record' do
              expect { sync_seat_link }.not_to change { GitlabSubscriptions::UpcomingReconciliation.count }
            end
          end

          context 'when refresh_token is false' do
            subject(:sync_seat_link) do
              described_class.new.perform('2020-01-01T01:20:12+02:00', license_key, 5, 4, false)
            end

            it 'does not perform Cloud Connector access data sync' do
              expect(CloudConnector::SyncServiceTokenWorker).not_to receive(:perform_async)

              sync_seat_link
            end
          end

          context 'when refresh_token is true' do
            subject(:sync_seat_link) do
              described_class.new.perform('2020-01-01T01:20:12+02:00', license_key, 5, 4, true)
            end

            it 'performs Cloud Connector access data sync' do
              allow(CloudConnector::SyncServiceTokenWorker).to receive(:perform_async)

              sync_seat_link

              expect(CloudConnector::SyncServiceTokenWorker).to have_received(:perform_async).with(
                'license_id' => License.current.id,
                'force' => true
              )
            end
          end
        end

        context 'when the subscription_name differs from the active license' do
          let(:subscription_name) { 'A-S00000002' }
          let!(:current_license) do
            create(:license, cloud: true, last_synced_at: 1.day.ago, subscription_name: 'A-S00000001')
          end

          it_behaves_like 'does not persist or apply the license'
        end

        context 'when the response license is invalid' do
          let(:license_key) { 'invalid-key' }

          it_behaves_like 'does not persist or apply the license'
        end
      end
    end

    context 'when the request is not successful' do
      let(:body) { { success: false, error: "Bad Request" } }

      before do
        stub_request(:post, seat_link_url)
          .to_return_json(status: 400, body: body)
      end

      it 'does not call CloudConnector::SyncServiceTokenWorker' do
        expect(CloudConnector::SyncServiceTokenWorker).not_to receive(:perform_async)

        expect { sync_seat_link }.to raise_error(
          described_class::RequestError,
          'HTTP status code: 400'
        )
      end
    end

    shared_examples 'unsuccessful request' do
      context 'when the request is not successful' do
        before do
          stub_request(:post, seat_link_url)
            .to_return_json(status: 400, body: { success: false, error: "Bad Request" })
        end

        it 'raises an error with the expected message' do
          expect { sync_seat_link }.to raise_error(
            described_class::RequestError,
            'HTTP status code: 400'
          )
        end
      end
    end

    it_behaves_like 'unsuccessful request'
  end

  describe 'sidekiq_retry_in_block' do
    it 'is at least 1 hour in the first retry' do
      expect(
        described_class.sidekiq_retry_in_block.call(0, nil)
      ).to be >= 1.hour
    end
  end
end

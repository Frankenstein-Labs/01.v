# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::StorageUsageExportWorker, type: :worker, feature_category: :consumables_cost_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:job_args) { ['free', user.id] }

  let(:worker) { described_class.new }

  it 'defines the loggable_arguments' do
    expect(described_class.loggable_arguments).to match_array([0])
  end

  describe '#perform' do
    context 'with a valid user' do
      subject(:export) { worker.perform(*job_args) }

      context 'when the export is successful' do
        before do
          allow_next_instance_of(Namespaces::Storage::UsageExportService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.success(payload: 'csv,data,here')
            )
          end
        end

        it 'triggers an email' do
          perform_enqueued_jobs do
            expect { export }
              .to change { ActionMailer::Base.deliveries.count }
              .from(0)
              .to(1)
          end
        end

        include_examples 'an idempotent worker'
      end

      context 'when the export is unsuccessful' do
        before do
          allow_next_instance_of(Namespaces::Storage::UsageExportService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'no csv generated')
            )
          end
        end

        it 'does not trigger an email' do
          perform_enqueued_jobs do
            expect(Sidekiq.logger).to receive(:error).with(/Failed to export namespace storage usage/)

            expect { export }.not_to change { ActionMailer::Base.deliveries.count }
          end
        end
      end
    end

    context 'with an invalid user' do
      subject(:export) { worker.perform('free', non_existing_record_id) }

      it 'does not trigger an email' do
        perform_enqueued_jobs do
          expect(Sidekiq.logger).to receive(:error).with(/due to no user/)

          expect { export }.not_to change { ActionMailer::Base.deliveries.count }
        end
      end
    end
  end
end

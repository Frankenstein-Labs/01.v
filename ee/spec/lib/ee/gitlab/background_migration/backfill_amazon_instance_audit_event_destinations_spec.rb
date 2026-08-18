# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillAmazonInstanceAuditEventDestinations,
  feature_category: :audit_events do
  describe '#perform' do
    it 'is a no-op' do
      connection = ApplicationRecord.connection
      migration = described_class.new(
        start_id: 1,
        end_id: 10,
        batch_table: :audit_events_instance_amazon_s3_configurations,
        batch_column: :id,
        sub_batch_size: 2,
        pause_ms: 0,
        connection: connection
      )

      allow_next_instance_of(Gitlab::Utils::BatchedBackgroundMigrationsDictionary) do |instance|
        allow(instance).to receive(:entry).and_return(nil)
      end

      expect { migration.perform }.not_to change {
        connection.select_value("SELECT COUNT(*) FROM audit_events_instance_external_streaming_destinations")
      }
    end
  end
end

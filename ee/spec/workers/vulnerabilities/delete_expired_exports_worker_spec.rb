# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::DeleteExpiredExportsWorker, feature_category: :vulnerability_management do
  describe '#perform' do
    let!(:expired_now) { create(:vulnerability_export, :with_csv_file, expires_at: Time.zone.now) }
    let!(:expired_recently) { create(:vulnerability_export, :with_csv_file, expires_at: 1.hour.ago) }
    let!(:expiring_soon) { create(:vulnerability_export, expires_at: 1.hour.from_now) }
    let!(:not_set) { create(:vulnerability_export, expires_at: nil) }

    subject(:perform) { described_class.new.perform }

    def exists?(record)
      Vulnerabilities::Export.exists?(record.id)
    end

    it 'deletes expired exports', :freeze_time do
      expect { perform }.to change { exists?(expired_now) }.from(true).to(false)
        .and change { exists?(expired_recently) }.from(true).to(false)
        .and not_change { exists?(expiring_soon) }
        .and not_change { exists?(not_set) }
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::DeleteExpiredExportsWorker, feature_category: :dependency_management do
  describe '#perform' do
    let!(:expired_now) { create(:dependency_list_export, expires_at: Time.zone.now) }
    let!(:expired_recently) { create(:dependency_list_export, :with_file, expires_at: 1.hour.ago) }
    let!(:expiring_soon) { create(:dependency_list_export, expires_at: 1.hour.from_now) }
    let!(:not_set) { create(:dependency_list_export, expires_at: nil) }

    subject(:perform) { described_class.new.perform }

    def exists?(record)
      Dependencies::DependencyListExport.exists?(record.id)
    end

    it 'deletes expired exports', :freeze_time do
      expect { perform }.to change { exists?(expired_now) }.from(true).to(false)
        .and change { exists?(expired_recently) }.from(true).to(false)
        .and not_change { exists?(expiring_soon) }
        .and not_change { exists?(not_set) }
    end

    it 'deletes the file from the file storage', :sidekiq_inline do
      files = Upload.all.map(&:absolute_path)

      expect { perform }.to change { files.map { |f| File.exist?(f) }.uniq }.from([true]).to([false])
    end
  end
end

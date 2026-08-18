# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Archival::Export::PurgeService, feature_category: :vulnerability_management do
  describe '.purge' do
    let(:archive_export) { create(:vulnerability_archive_export, :with_csv_file) }

    subject(:purge) { described_class.purge(archive_export) }

    it 'changes the status of the record' do
      expect { purge }.to change { archive_export.reload.status }.to('purged')
    end

    it 'deletes the file associated with the record' do
      expect { purge }.to change { archive_export.reload.file.file }.to(nil)
    end
  end
end

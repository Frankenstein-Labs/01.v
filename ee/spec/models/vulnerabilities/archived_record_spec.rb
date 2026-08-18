# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ArchivedRecord, feature_category: :vulnerability_management do
  subject { build(:vulnerability_archived_record) }

  it { is_expected.to belong_to(:project).required }
  it { is_expected.to belong_to(:archive).class_name('Vulnerabilities::Archive').required }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:vulnerability_identifier) }
    it { is_expected.to validate_presence_of(:data) }
  end

  describe '#archive=' do
    let(:archived_record) { build(:vulnerability_archived_record, archive: nil) }
    let(:archive) { create(:vulnerability_archive) }

    subject(:set_archive) { archived_record.archive = archive }

    it 'sets the archive and the date' do
      expect { set_archive }.to change { archived_record.archive }.from(nil).to(archive)
                            .and change { archived_record.date }.from(nil).to(archive.date)
    end
  end
end

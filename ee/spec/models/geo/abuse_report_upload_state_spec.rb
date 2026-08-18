# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::AbuseReportUploadState, :geo, feature_category: :geo_replication do
  it { is_expected.to belong_to(:abuse_report_upload).inverse_of(:abuse_report_upload_state) }
  it { is_expected.to validate_presence_of(:verification_state) }
  it { is_expected.to validate_presence_of(:abuse_report_upload) }
end

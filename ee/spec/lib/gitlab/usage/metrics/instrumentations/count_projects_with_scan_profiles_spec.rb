# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountProjectsWithScanProfiles, feature_category: :security_testing_configuration do
  RSpec.shared_examples 'a correct secure type instrumented metric value' do |params|
    let(:expected_value) { params[:expected_value] }

    before do
      Enums::Security.security_profile_types.each_key do |name|
        create(:security_scan_profile, scan_type: name)
        create(:security_scan_profile_project,
          scan_profile: Security::ScanProfile.where(scan_type: name).first,
          created_at: 45.days.ago)
        create(:security_scan_profile_project,
          scan_profile: Security::ScanProfile.where(scan_type: name).first,
          created_at: 3.days.ago)
      end
    end

    Enums::Security.security_profile_types.each do |name, scan_type|
      context "with scan_type #{name}" do
        let(:scan_type) { scan_type }
        let(:expected_query) do
          # rubocop:disable Layout/LineLength -- queries are very long
          if params[:time_frame] == 'all'
            %{SELECT COUNT(DISTINCT "security_scan_profiles_projects"."project_id") FROM "security_scan_profiles_projects" INNER JOIN "security_scan_profiles" ON "security_scan_profiles"."id" = "security_scan_profiles_projects"."security_scan_profile_id" WHERE "security_scan_profiles"."scan_type" = #{scan_type}}
          else
            %{SELECT COUNT(DISTINCT "security_scan_profiles_projects"."project_id") FROM "security_scan_profiles_projects" INNER JOIN "security_scan_profiles" ON "security_scan_profiles"."id" = "security_scan_profiles_projects"."security_scan_profile_id" WHERE "security_scan_profiles_projects"."created_at" BETWEEN '#{start}' AND '#{finish}' AND "security_scan_profiles"."scan_type" = #{scan_type}}
          end
          # rubocop:enable Layout/LineLength
        end

        it_behaves_like 'a correct instrumented metric value and query',
          { time_frame: params[:time_frame], data_source: 'database', options: { scan_type: name.to_s } }
      end
    end
  end

  context 'with time_frame all' do
    it_behaves_like 'a correct secure type instrumented metric value', { time_frame: 'all', expected_value: 2 }
  end

  context 'with time_frame 28d' do
    let(:start) { 30.days.ago.to_fs(:db) }
    let(:finish) { 2.days.ago.to_fs(:db) }

    it_behaves_like 'a correct secure type instrumented metric value', { time_frame: '28d', expected_value: 1 }
  end

  it 'raises an exception if scan_type option is not present' do
    expect do
      described_class.new(time_frame: 'all')
    end.to raise_error(ArgumentError, /scan_type must be present/)
  end

  it 'raises an exception if scan_type option is invalid' do
    expect do
      described_class.new(options: { scan_type: 'invalid_type' }, time_frame: 'all')
    end.to raise_error(ArgumentError, /scan_type must be present/)
  end
end

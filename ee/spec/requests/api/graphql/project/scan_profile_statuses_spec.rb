# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).scanProfileStatuses', feature_category: :security_testing_configuration do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:scan_profile) do
    create(:security_scan_profile, namespace: group, scan_type: :sast, name: 'Default SAST')
  end

  let(:current_user) { developer }

  let(:query) do
    <<~GQL
      query {
        project(fullPath: "#{project.full_path}") {
          scanProfileStatuses {
            scanProfile {
              name
              scanType
            }
            status
            consecutiveFailureCount
            consecutiveSuccessCount
            lastScanAt
            buildId
          }
        }
      }
    GQL
  end

  let(:statuses_data) { graphql_data_at(:project, :scan_profile_statuses) }

  before do
    stub_licensed_features(security_scan_profiles: true)
  end

  context 'when project has profile statuses' do
    let_it_be(:status_record) do
      create(:scan_profile_project_status,
        project: project,
        scan_profile: scan_profile,
        status: :success,
        consecutive_success_count: 5,
        consecutive_failure_count: 0,
        last_scan_at: 1.day.ago
      )
    end

    it 'returns profile statuses' do
      post_graphql(query, current_user: current_user)

      expect(statuses_data).to be_present
      expect(statuses_data.size).to eq(1)

      status = statuses_data.first
      expect(status).to include(
        'status' => 'ACTIVE',
        'consecutiveFailureCount' => 0,
        'consecutiveSuccessCount' => 5,
        'scanProfile' => {
          'name' => 'Default SAST',
          'scanType' => 'SAST'
        }
      )
      expect(status['lastScanAt']).to be_present
    end
  end

  context 'when project has no profile statuses' do
    it 'returns an empty array' do
      post_graphql(query, current_user: current_user)

      expect(statuses_data).to eq([])
    end
  end

  context 'when a status belongs to a soft-deleted scan profile' do
    let_it_be(:live_status) do
      create(:scan_profile_project_status, project: project, scan_profile: scan_profile, status: :success,
        last_scan_at: 1.day.ago)
    end

    let_it_be(:deleted_profile) do
      create(:security_scan_profile, namespace: group, scan_type: :secret_detection, name: 'Deleted SD')
    end

    let_it_be(:deleted_profile_status) do
      create(:scan_profile_project_status, project: project, scan_profile: deleted_profile, status: :success,
        last_scan_at: 1.day.ago)
    end

    before do
      # Re-find to avoid mutating the frozen let_it_be record.
      Security::ScanProfile.find(deleted_profile.id).destroy!
    end

    it 'excludes statuses for the soft-deleted profile' do
      post_graphql(query, current_user: current_user)

      expect(statuses_data.size).to eq(1)
      expect(statuses_data.first['scanProfile']).to include('name' => 'Default SAST')
    end
  end

  context 'when license is not available' do
    before do
      stub_licensed_features(security_scan_profiles: false)
    end

    it 'returns null' do
      post_graphql(query, current_user: current_user)

      expect(statuses_data).to be_nil
    end
  end

  context 'when user does not have access' do
    let(:current_user) { create(:user) }

    it 'returns null' do
      post_graphql(query, current_user: current_user)

      expect(statuses_data).to be_nil
    end
  end

  describe 'lookahead preloading' do
    let_it_be(:trigger) do
      create(:security_scan_profile_trigger, scan_profile: scan_profile)
    end

    let_it_be(:second_profile) do
      create(:security_scan_profile, namespace: group, scan_type: :secret_detection, name: 'Default SD')
    end

    let_it_be(:second_trigger) do
      create(:security_scan_profile_trigger, scan_profile: second_profile)
    end

    let_it_be(:status_one) do
      create(:scan_profile_project_status, project: project, scan_profile: scan_profile, status: :success,
        last_scan_at: 1.day.ago)
    end

    let_it_be(:status_two) do
      create(:scan_profile_project_status, project: project, scan_profile: second_profile, status: :success,
        last_scan_at: 1.day.ago)
    end

    context 'when scanProfile is not requested' do
      let(:query) do
        <<~GQL
          query {
            project(fullPath: "#{project.full_path}") {
              scanProfileStatuses {
                status
                consecutiveFailureCount
              }
            }
          }
        GQL
      end

      it 'returns statuses without loading scan profiles' do
        post_graphql(query, current_user: current_user)

        expect(statuses_data.size).to eq(2)
        expect(statuses_data).to all(include('status' => 'ACTIVE'))
      end
    end

    context 'when scanProfile with triggers is requested' do
      let(:query) do
        <<~GQL
          query {
            project(fullPath: "#{project.full_path}") {
              scanProfileStatuses {
                scanProfile {
                  name
                  triggers
                }
                status
              }
            }
          }
        GQL
      end

      it 'avoids N+1 queries' do
        control = ActiveRecord::QueryRecorder.new do
          post_graphql(query, current_user: current_user)
        end

        third_profile = create(:security_scan_profile, namespace: group, scan_type: :dependency_scanning)
        create(:security_scan_profile_trigger, scan_profile: third_profile)
        create(:scan_profile_project_status, project: project, scan_profile: third_profile, status: :success,
          last_scan_at: 1.day.ago)

        expect { post_graphql(query, current_user: current_user) }.not_to exceed_query_limit(control)
      end

      it 'returns triggers for each profile' do
        post_graphql(query, current_user: current_user)

        expect(statuses_data.size).to eq(2)
        statuses_data.each do |status|
          expect(status['scanProfile']['triggers']).to be_present
        end
      end
    end
  end

  describe 'status resolution' do
    using RSpec::Parameterized::TableSyntax

    let(:failed_threshold) { Security::ScanProfileProjectStatus::FAILED_THRESHOLD }
    let(:stale_time) { (Security::ScanProfileProjectStatus::STALE_THRESHOLD_DAYS + 1).days.ago }

    where(:db_status, :failure_count, :last_scan_at, :expected_status) do
      :success        | 0                        | 1.day.ago        | 'ACTIVE'
      :success        | 0                        | nil              | 'PENDING'
      :success        | 0                        | ref(:stale_time) | 'STALE'
      :warning        | 2                        | 1.day.ago        | 'WARNING'
      :warning        | 2                        | ref(:stale_time) | 'STALE'
      :failed         | ref(:failed_threshold)   | 1.day.ago        | 'FAILED'
      :failed         | ref(:failed_threshold)   | ref(:stale_time) | 'STALE'
      :not_configured | 0                        | nil              | 'NOT_CONFIGURED'
    end

    with_them do
      let!(:status_record) do
        create(:scan_profile_project_status,
          project: project,
          scan_profile: scan_profile,
          status: db_status,
          consecutive_failure_count: failure_count,
          consecutive_success_count: 0,
          last_scan_at: last_scan_at
        )
      end

      it "returns #{params[:expected_status]}" do
        post_graphql(query, current_user: current_user)

        expect(statuses_data.first['status']).to eq(expected_status)
      end
    end
  end
end

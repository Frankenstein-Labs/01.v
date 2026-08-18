# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting group information', feature_category: :groups_and_projects do
  include GraphqlHelpers

  let(:user) { create(:user) }

  describe "Query group(fullPath)" do
    def group_query(group)
      graphql_query_for('group', 'fullPath' => group.full_path)
    end

    context 'when Group SSO is enforced' do
      let(:group) { create(:group, :private) }

      before do
        stub_licensed_features(group_saml: true)
        saml_provider = create(:saml_provider, enforced_sso: true, group: group)
        create(:group_saml_identity, saml_provider: saml_provider, user: user)
        group.add_guest(user)
      end

      it 'returns null data when not authorized' do
        post_graphql(group_query(group))

        expect(graphql_data['group']).to be_nil
      end

      it 'allows access via session' do
        post_graphql(group_query(group), current_user: user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_data['group']['id']).to eq(group.to_global_id.to_s)
      end

      it 'allows access via bearer token' do
        token = create(:personal_access_token, user: user).token
        post_graphql(group_query(group), headers: { 'Authorization' => "Bearer #{token}" })

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_data['group']['id']).to eq(group.to_global_id.to_s)
      end
    end

    context 'when loading vulnerabilityGrades alongside with Vulnerability.userNotesCount' do
      let_it_be(:private_group) { create(:group, :private) }
      let_it_be(:public_group) { create(:group, :public) }

      let(:fields_public_group) do
        <<~QUERY
        vulnerabilityGrades {
          grade
          count
          projects {
            nodes {
              vulnerabilities {
                nodes {
                  id
                  userNotesCount
                }
              }
            }
          }
        }
        QUERY
      end

      let(:fields_private_group) do
        <<~QUERY
        vulnerabilityGrades {
          grade
          count
          projects {
            nodes {
              confirmedVulnerabilities: vulnerabilities(state: CONFIRMED) {
                nodes {
                  id
                  userNotesCount
                }
              }
              dismissedVulnerabilities: vulnerabilities(state: DISMISSED) {
                nodes {
                  id
                  userNotesCount
                }
              }
            }
          }
        }
        QUERY
      end

      let(:queries) do
        [
          { query: graphql_query_for('group', { 'fullPath' => private_group.full_path }, fields_private_group) },
          { query: graphql_query_for('group', { 'fullPath' => public_group.full_path }, fields_public_group) }
        ]
      end

      let_it_be(:public_project) { create(:project, group: public_group) }
      let_it_be(:private_project) { create(:project, group: private_group) }

      let_it_be(:vulnerability_1) { create(:vulnerability, :dismissed, :critical_severity, :with_notes, :with_finding, notes_count: 2, project: public_project) }
      let_it_be(:vulnerability_2) { create(:vulnerability, :confirmed, :high_severity, :with_notes, :with_finding, notes_count: 3, project: public_project) }
      let_it_be(:vulnerability_3) { create(:vulnerability, :dismissed, :medium_severity, :with_notes, :with_finding, notes_count: 4, project: private_project) }
      let_it_be(:vulnerability_4) { create(:vulnerability, :confirmed, :low_severity, :with_notes, :with_finding, notes_count: 7, project: private_project) }

      let_it_be(:vulnerability_statistic_1) { create(:vulnerability_statistic, :grade_c, project: public_project) }
      let_it_be(:vulnerability_statistic_2) { create(:vulnerability_statistic, :grade_d, project: private_project) }

      let(:first_graphql_data) do
        json_response.first['data']
      end

      let(:second_graphql_data) do
        json_response.last['data']
      end

      let(:empty_grade_entry) do
        ->(grade) do
          {
            'grade' => grade,
            'count' => 0,
            'projects' => { 'nodes' => [] }
          }
        end
      end

      let(:expected_private_group_response) do
        grades = %w[A B C D F]

        grades.map do |grade|
          case grade
          when 'D'
            {
              'grade' => 'D',
              'count' => 1,
              'projects' => {
                'nodes' => [
                  {
                    'confirmedVulnerabilities' => {
                      'nodes' => [
                        { 'id' => vulnerability_4.to_global_id.to_s, 'userNotesCount' => 7 }
                      ]
                    },
                    'dismissedVulnerabilities' => {
                      'nodes' => [
                        { 'id' => vulnerability_3.to_global_id.to_s, 'userNotesCount' => 4 }
                      ]
                    }
                  }
                ]
              }
            }
          when 'C'
            {
              'grade' => 'C',
              'count' => 0,
              'projects' => { 'nodes' => [] }
            }
          else
            empty_grade_entry.call(grade)
          end
        end
      end

      let(:expected_public_group_response) do
        grades = %w[A B C D F]

        grades.map do |grade|
          case grade
          when 'C'
            {
              'grade' => 'C',
              'count' => 1,
              'projects' => {
                'nodes' => [
                  {
                    'vulnerabilities' => {
                      'nodes' => [
                        { 'id' => vulnerability_1.to_global_id.to_s, 'userNotesCount' => 2 },
                        { 'id' => vulnerability_2.to_global_id.to_s, 'userNotesCount' => 3 }
                      ]
                    }
                  }
                ]
              }
            }
          when 'D'
            {
              'grade' => 'D',
              'count' => 0,
              'projects' => { 'nodes' => [] }
            }
          else
            empty_grade_entry.call(grade)
          end
        end
      end

      before do
        public_group.add_developer(user)
        private_group.add_developer(user)
        stub_licensed_features(security_dashboard: true)

        post_multiplex(queries, current_user: user)
      end

      it 'finds vulnerability grades for only projects that were added to instance security dashboard', :aggregate_failures do
        expect(first_graphql_data.dig('group', 'vulnerabilityGrades')).to match_array(expected_private_group_response)
        expect(second_graphql_data.dig('group', 'vulnerabilityGrades')).to match_array(expected_public_group_response)
      end

      it 'returns a successful response', :aggregate_failures do
        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to eq([nil, nil])
      end
    end

    context 'when loading multiple epics' do
      let_it_be_with_reload(:group) { create(:group) }

      before do
        stub_licensed_features(epics: true)
        query_epics(1)
      end

      it 'can lookahead to eliminate N+1 queries', :use_clean_rails_memory_store_caching do
        create_list(:epic, 3, group: group)
        group.reload

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          query_epics(1)
        end

        expect { query_epics(3) }.not_to exceed_all_query_limit(control)
      end
    end

    def query_epics(number)
      epics_field = <<~NODE
        epics(first: #{number}) {
          edges {
            node {
              title
            }
          }
        }
      NODE

      post_graphql(
        graphql_query_for('group', { 'fullPath' => group.full_path }, epics_field),
        current_user: user
      )
    end

    context 'when loading release statistics' do
      let_it_be(:guest_user) { create(:user) }
      let_it_be(:public_user) { create(:user) }

      let(:query_fields) do
        <<~QUERY
        stats {
          releaseStats {
            releasesCount
            releasesPercentage
          }
        }
        QUERY
      end

      let(:query) do
        graphql_query_for('group', { 'fullPath' => group.full_path }, query_fields)
      end

      let(:release_stats) do
        graphql_data.with_indifferent_access.dig(:group, :stats, :releaseStats)
      end

      before do
        stub_licensed_features(group_ci_cd_analytics_releases: true)
        group.add_guest(guest_user)

        post_graphql(query, current_user: current_user)
      end

      shared_examples 'no access to release statistics' do
        it 'returns data about release utilization within the group' do
          expect(release_stats).to be_nil
        end
      end

      shared_examples 'full access to release statistics' do
        context 'when there are no releases' do
          it 'returns 0 for both statistics' do
            expect(release_stats).to match(
              releasesCount: 0,
              releasesPercentage: 0
            )
          end
        end

        context 'when there are some releases' do
          let_it_be(:subgroup) { create(:group, :private, parent: group) }
          let_it_be_with_reload(:project_in_group) { create(:project, group: group) }
          let_it_be_with_reload(:project_in_subgroup) { create(:project, group: subgroup) }
          let_it_be(:another_project_in_subgroup) { create(:project, group: subgroup) }
          let_it_be_with_reload(:project_in_unrelated_group) { create(:project) }
          let_it_be_with_reload(:release_1) { create(:release, project: project_in_group) }
          let_it_be_with_reload(:release_2) { create(:release, project: project_in_subgroup) }
          let_it_be(:release_3) { create(:release, project: project_in_subgroup) }
          let_it_be_with_reload(:release_4) { create(:release, project: project_in_unrelated_group) }

          it 'returns data about release utilization within the group' do
            expect(release_stats).to match(
              releasesCount: 3,
              releasesPercentage: 67
            )
          end
        end
      end

      shared_examples 'correct access to release statistics' do
        context 'when the user is not logged in' do
          let(:current_user) { nil }

          it_behaves_like 'no access to release statistics'
        end

        context 'when the user is not a member of the group' do
          let(:current_user) { public_user }

          it_behaves_like 'no access to release statistics'
        end

        context 'when the user is at least a guest' do
          let(:current_user) { guest_user }

          it_behaves_like 'full access to release statistics'
        end
      end

      context 'when the group is private' do
        let_it_be_with_reload(:group) { create(:group, :private) }

        it_behaves_like 'correct access to release statistics'
      end

      context 'when the group is public' do
        let_it_be_with_reload(:group) { create(:group, :public) }

        it_behaves_like 'correct access to release statistics'
      end
    end

    context 'when loading pending members' do
      let_it_be_with_reload(:group) { create(:group, :private) }

      let(:query_fields) do
        <<~QUERY
        pendingMembers {
          nodes {
            id
            name
            username
            email
            webUrl
            invited
            avatarUrl
            approved
          }
        }
        QUERY
      end

      let(:query) do
        graphql_query_for('group', { 'fullPath' => group.full_path }, query_fields)
      end

      let(:pending_members) do
        graphql_data.with_indifferent_access.dig(:group, :pendingMembers, :nodes)
      end

      context 'when user does not have permission' do
        it 'does not return pending members of the group' do
          create(:group_member, :awaiting, group: group)

          post_graphql(query, current_user: user)

          expect(pending_members).to be_nil
        end
      end

      context 'when user has permission' do
        before do
          group.add_owner(user)
        end

        it 'returns pending members of the group' do
          pending_member = create(:group_member, :awaiting, group: group)

          post_graphql(query, current_user: user)

          expect(pending_members).not_to be_empty
          expect(pending_members.first[:name]).to eq(pending_member.user.name)
          expect(pending_members.first[:username]).to eq(pending_member.user.username)
          expect(pending_members.first[:email]).to eq(pending_member.user.public_email)
          expect(pending_members.first[:webUrl]).to eq(Gitlab::Routing.url_helpers.user_url(pending_member.user))
          expect(pending_members.first[:avatarUrl]).to eq(GravatarService.new.execute(pending_member.user.email))
          expect(pending_members.first[:approved]).to eq(pending_member.active?)
          expect(pending_members.first[:invited]).to eq(pending_member.invite?)
        end

        it 'returns pending project members' do
          project = create(:project, namespace: group)
          pending_member = create(:project_member, :awaiting, project: project)

          post_graphql(query, current_user: user)

          expect(pending_members).not_to be_empty
          expect(pending_members.first[:username]).to eq(pending_member.user.username)
        end

        context 'when pending member has public email visibility' do
          let(:user_with_public_email) { create(:user, :public_email, email: 'public@example.com') }

          before do
            create(:group_member, :awaiting, group: group, user: user_with_public_email)
          end

          it 'returns the actual email' do
            post_graphql(query, current_user: user)

            expect(pending_members).not_to be_empty
            expect(pending_members.first[:email]).to eq('public@example.com')
          end
        end

        it 'does not produce N+1 queries' do
          create(:group_member, :awaiting, group: group)

          baseline = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: user) }

          create(:group_member, :awaiting, group: group)
          create(:group_member, :awaiting, group: group)

          expect { post_graphql(query, current_user: user) }.not_to exceed_query_limit(baseline)
        end
      end
    end
  end

  describe 'pagination' do
    let_it_be(:current_user) { create(:user) }
    let_it_be_with_reload(:project_1) { create(:project) }
    let_it_be_with_reload(:project_2) { create(:project) }
    let_it_be_with_reload(:group) { create(:group, projects: [project_1, project_2]) }

    let(:data_path) { [:group, :codeCoverageActivities] }

    def pagination_query(params)
      graphql_query_for(
        :group, { full_path: group.full_path },
        <<~QUERY
        codeCoverageActivities(startDate: "#{start_date}" #{params}) {
          #{page_info}
          nodes { averageCoverage }
        }
        QUERY
      )
    end

    context 'when default sorting' do
      let_it_be(:cov_1) { create(:ci_daily_build_group_report_result, project: project_1, coverage: 77.0, group: group) }
      let_it_be(:cov_2) { create(:ci_daily_build_group_report_result, project: project_2, coverage: 88.8, date: 1.week.ago, group: group) }
      let_it_be(:cov_3) { create(:ci_daily_build_group_report_result, project: project_1, coverage: 66.6, date: 2.weeks.ago, group: group) }
      let_it_be(:cov_4) { create(:ci_daily_build_group_report_result, project: project_2, coverage: 99.9, date: 3.weeks.ago, group: group) }
      let_it_be(:cov_5) { create(:ci_daily_build_group_report_result, project: project_1, coverage: 44.4, date: 4.weeks.ago, group: group) }
      let_it_be(:cov_6) { create(:ci_daily_build_group_report_result, project: project_1, coverage: 100.0, date: 6.weeks.ago, group: group) }

      let(:start_date) { 5.weeks.ago.to_date.to_s }

      it_behaves_like 'sorted paginated query' do
        include_context 'no sort argument'

        let(:node_path) { ['averageCoverage'] }
        let(:first_param) { 2 }
        let(:all_records) { [cov_1, cov_2, cov_3, cov_4, cov_5].reverse.map(&:coverage) }
      end
    end
  end

  describe 'autocompleteUsers.duoStatus field' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:project) { create(:project, :repository, :public, group: group) }
    let_it_be(:current_user) { create(:user, guest_of: group) }

    let(:params) { {} }
    let(:query) do
      graphql_query_for(
        'group',
        { 'fullPath' => group.full_path },
        query_graphql_field(
          'autocompleteUsers',
          params,
          <<~QUERY
          username
          duoStatus {
            disabled
            disabledReason
            flowTriggerEvents
          }
          QUERY
        )
      )
    end

    let(:user) { current_user }
    let(:user_data) { graphql_data.dig('group', 'autocompleteUsers').find { |u| u['username'] == user.username } }

    context 'when user type is human' do
      it 'returns null' do
        post_graphql(query, current_user: current_user)

        expect(user_data['username']).to eq(user.username)
        expect(user_data['duoStatus']).to be_nil
      end
    end

    context 'when user is a regular service account' do
      let!(:user) do
        create(:user, :service_account, guest_of: project, composite_identity_enforced: false)
      end

      it 'returns null' do
        post_graphql(query, current_user: current_user)

        expect(user_data['username']).to eq(user.username)
        expect(user_data['duoStatus']).to be_nil
      end
    end

    context 'when user is a composite identity user' do
      let_it_be(:user) do
        create(:composite_identity_service_account_for_project, project: project)
      end

      let_it_be(:flow_catalog_item) { create(:ai_catalog_item, :flow) }
      let_it_be(:group_consumer) do
        create(
          :ai_catalog_item_consumer,
          group: group,
          item: flow_catalog_item,
          service_account: user
        )
      end

      let_it_be(:another_project) do
        create(:project, :repository, :public, group: group)
      end

      let_it_be(:project_consumer_with_mention_trigger) do
        create(
          :ai_catalog_item_consumer,
          :with_triggers,
          parent_item_consumer: group_consumer,
          project: project,
          item: flow_catalog_item,
          event_types: [0]
        )
      end

      let_it_be(:another_project_with_assign_trigger) do
        create(
          :ai_catalog_item_consumer,
          :with_triggers,
          parent_item_consumer: group_consumer,
          project: another_project,
          item: flow_catalog_item,
          event_types: [1]
        )
      end

      before do
        allow_next_instance_of(
          ::Ai::UsageQuotaService,
          user: current_user
        ) do |instance|
          allow(instance).to receive(:execute).and_return(
            ServiceResponse.error(reason: :usage_quota_exceeded, message: 'No credits available')
          )
        end
      end

      it 'returns the Duo status' do
        post_graphql(query, current_user: current_user)

        expect(user_data['username']).to eq(user.username)
        expect(user_data['duoStatus']).to match(
          'disabled' => true,
          'disabledReason' => 'Unavailable - no credits',
          'flowTriggerEvents' => %w[MENTION ASSIGN]
        )
      end
    end
  end
end

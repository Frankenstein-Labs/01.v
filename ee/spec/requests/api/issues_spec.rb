# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Issues, :mailer, :aggregate_failures, feature_category: :team_planning do
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:project, freeze: false) do
    create(:project, :public, creator_id: user.id, namespace: user.namespace, reporters: user)
  end

  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:epic, freeze: false) { create(:epic, group: group) }
  let_it_be(:group_project, freeze: false) { create(:project, :public, creator_id: user.id, namespace: group) }

  let_it_be(:user2, freeze: false) { create(:user) }

  let_it_be(:author, freeze: false) { create(:author) }
  let_it_be(:assignee, freeze: false) { create(:assignee) }

  shared_examples 'exposes epic' do
    context 'with epics feature' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'contains epic_iid in response' do
        subject

        expect(response).to have_gitlab_http_status(:success)
        expect(issue_response_by_id(issue_with_epic.id)['epic_iid']).to eq(epic.iid)
      end

      it 'contains epic in response' do
        subject

        expect(response).to have_gitlab_http_status(:success)
        expect(issue_response_by_id(issue_with_epic.id)['epic']).to eq({ "id" => epic.id,
                                                                         "iid" => epic.iid,
                                                                         "group_id" => epic.group_id,
                                                                         "title" => epic.title,
                                                                         "url" => group_epic_path(epic.group, epic) })
      end

      context 'and epic issue is not present' do
        it 'exposes epic as nil' do
          issue_with_epic.epic_issue.destroy!

          subject

          response = issue_response_by_id(issue_with_epic.id)
          expect(response['epic']).to be_nil
          expect(response['epic_id']).to be_nil
        end
      end
    end

    context 'without epics feature' do
      before do
        stub_licensed_features(epics: false)
      end

      it 'does not contain epic_iid in response' do
        subject

        expect(response).to have_gitlab_http_status(:success)
        expect(issue_response_by_id(issue_with_epic.id)).not_to have_key('epic_iid')
      end

      it 'does not contain epic_iid in response' do
        subject

        expect(response).to have_gitlab_http_status(:success)
        expect(issue_response_by_id(issue_with_epic.id)).not_to have_key('epic')
      end
    end
  end

  shared_examples 'exposes iteration' do
    let_it_be(:cadence, freeze: false) { create(:iterations_cadence, group: group) }
    let_it_be(:iteration, freeze: false) { create(:iteration, iterations_cadence: cadence) }
    let_it_be(:issue_with_iteration, freeze: false) { create(:issue, project: group_project, iteration: iteration) }

    context 'with iteration feature' do
      before do
        stub_licensed_features(iterations: true)
      end

      it 'contains iteration in response' do
        subject

        expect(response).to have_gitlab_http_status(:success)

        iteration_data = issue_response_by_id(issue_with_iteration.id)['iteration']

        # Use a json schema fixture
        # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/355842
        expect(iteration_data["id"]).to eq(iteration.id)
        expect(iteration_data["iid"]).to eq(iteration.iid)
        expect(iteration_data["group_id"]).to eq(iteration.group_id)
        expect(iteration_data["state"]).to eq(Iteration::STATE_ENUM_MAP[iteration.state])
        expect(iteration_data["title"]).to eq(iteration.title)
        expect(iteration_data["sequence"]).to eq(iteration.sequence)
        expect(iteration_data["description"]).to eq(iteration.description)
        expect(iteration_data["web_url"]).to eq(group_iteration_url(iteration.group, iteration.id))
        expect(iteration_data["start_date"]).to be_present
        expect(iteration_data["due_date"]).to be_present
        expect(iteration_data["created_at"]).to be_present
        expect(iteration_data["updated_at"]).to be_present
      end
    end

    context 'without iterations feature' do
      before do
        stub_licensed_features(iterations: false)
      end

      it 'does not contain iteration in response' do
        subject

        expect(response).to have_gitlab_http_status(:success)
        expect(issue_response_by_id(issue_with_iteration.id)).not_to have_key('iteration')
      end
    end
  end

  shared_examples 'filtering by epic_id' do
    let_it_be(:epic1, freeze: false) { create :epic, group: group_project.namespace }
    let_it_be(:epic2, freeze: false) { create :epic, group: group_project.namespace }
    let_it_be(:issue1, freeze: false) { create(:issue, { author: user, epic: epic1, project: group_project }) }
    let_it_be(:issue2, freeze: false) { create(:issue, { author: user, epic: epic2, project: group_project }) }
    let_it_be(:issue3, freeze: false) { create(:issue, { author: user, project: group_project }) }

    before do
      stub_licensed_features(epics: true)
    end

    it 'returns issues without epic when epic_id is "None"' do
      get api(endpoint, user), params: { epic_id: 'None', scope: 'all' }

      expect_response_contain_exactly(issue3.id)
    end

    it 'returns issues with any epic when epic_id is "Any"' do
      get api(endpoint, user), params: { epic_id: 'Any', scope: 'all' }

      expect_response_contain_exactly(issue1.id, issue2.id)
    end

    it 'returns issues with any epic when epic_id is specific' do
      get api(endpoint, user), params: { epic_id: epic1.id, scope: 'all' }

      expect_response_contain_exactly(issue1.id)
    end
  end

  describe "GET /issues" do
    context "when authenticated" do
      it 'matches V4 response schema' do
        get api('/issues', user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/issues', dir: 'ee')
      end

      context "blocking issues count" do
        let_it_be(:issue, freeze: false) { create :issue, author: user, project: project }

        it 'returns a blocking issues count of 0 if there are no blocking issues' do
          get api('/issues', user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.first).to include('blocking_issues_count' => 0)
        end

        it 'returns a blocking issues count of 1 if there exists a blocking issue' do
          blocked_issue = build(:issue, author: user2, project: project, created_at: 1.day.ago)
          create(:issue_link, source: issue, target: blocked_issue, link_type: IssueLink::TYPE_BLOCKS)

          get api('/issues', user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.first).to include('blocking_issues_count' => 1)
        end
      end

      context "filtering by weight" do
        let_it_be(:issue, freeze: false) do
          create(:issue, author: user2, project: project, weight: nil, created_at: 4.days.ago)
        end

        let_it_be(:issue1, freeze: false) do
          create(:issue, author: user2, project: project, weight: 1, created_at: 3.days.ago)
        end

        let_it_be(:issue2, freeze: false) do
          create(:issue, author: user2, project: project, weight: 5, created_at: 2.days.ago)
        end

        let_it_be(:issue3, freeze: false) do
          create(:issue, author: user2, project: project, weight: 3, created_at: 1.day.ago)
        end

        it 'returns issues with specific weight' do
          get api('/issues', user), params: { weight: 5, scope: 'all' }

          expect_paginated_array_response(issue2.id)
        end

        it 'returns issues with no weight' do
          get api('/issues', user), params: { weight: 'None', scope: 'all' }

          expect_paginated_array_response(issue.id)
        end

        it 'returns issues with any weight' do
          get api('/issues', user), params: { weight: 'Any', scope: 'all' }

          expect_paginated_array_response([issue3.id, issue2.id, issue1.id])
        end

        it 'returns issues without specific weight' do
          get api('/issues', user), params: { scope: 'all', not: { weight: 5 } }

          expect_paginated_array_response([issue3.id, issue1.id, issue.id])
        end
      end

      context "filtering by health status" do
        let_it_be(:issue, freeze: false) { create(:issue, author: user2, project: project, health_status: nil) }
        let_it_be(:issue1, freeze: false) { create(:issue, author: user2, project: project, health_status: :at_risk) }
        let_it_be(:issue2, freeze: false) { create(:issue, author: user2, project: project, health_status: :at_risk) }
        let_it_be(:issue3, freeze: false) do
          create(:issue, author: user2, project: project, health_status: :needs_attention)
        end

        it 'returns issues with specific health_status' do
          get api('/issues', user), params: { health_status: 'AT_risk', scope: 'all' }

          expect_paginated_array_response([issue2.id, issue1.id])
        end

        it 'returns issues with any health_status' do
          get api('/issues', user), params: { health_status: 'ANY', scope: 'all' }

          expect_paginated_array_response([issue3.id, issue2.id, issue1.id])
        end

        it 'returns issues with no health_status' do
          get api('/issues', user), params: { health_status: 'none', scope: 'all' }

          expect_paginated_array_response([issue.id])
        end

        it 'returns bad request when unsupported value is supplied' do
          get api('/issues', user), params: { health_status: 'nonsense', scope: 'all' }

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'filtering by assignee_username' do
        let_it_be(:another_assignee, freeze: false) { create(:assignee) }
        let_it_be(:issue1, freeze: false) do
          create(:issue, author: user2, project: project, weight: 1, created_at: 3.days.ago)
        end

        let_it_be(:issue2, freeze: false) do
          create(:issue, author: user2, project: project, weight: 5, created_at: 2.days.ago)
        end

        let_it_be(:issue3, freeze: false) do
          create(:issue, author: user2, assignees: [assignee, another_assignee], project: project, weight: 3,
            created_at: 1.day.ago)
        end

        it 'returns issues with multiple assignees' do
          get api("/issues", user),
            params: { assignee_username: [assignee.username, another_assignee.username], scope: 'all' }

          expect_paginated_array_response(issue3.id)
        end
      end

      it_behaves_like 'filtering by epic_id' do
        let(:endpoint) { '/issues' }
      end

      context 'filtering by iteration' do
        let_it_be(:iteration_1, freeze: false) do
          create(:iteration, :with_title, iterations_cadence: create(:iterations_cadence, group: group),
            start_date: Date.current)
        end

        let_it_be(:iteration_2, freeze: false) do
          create(:iteration, iterations_cadence: create(:iterations_cadence, group: group))
        end

        let_it_be(:iteration_1_issue, freeze: false) { create(:issue, project: group_project, iteration: iteration_1) }
        let_it_be(:iteration_2_issue, freeze: false) { create(:issue, project: group_project, iteration: iteration_2) }
        let_it_be(:no_iteration_issue, freeze: false) { create(:issue, project: group_project) }

        it 'returns issues with specific iteration' do
          get api('/issues', user), params: { iteration_id: iteration_1.id }

          expect_response_contain_exactly(iteration_1_issue.id)
        end

        it 'returns issues with no iteration' do
          get api('/issues', user), params: { iteration_id: 'None' }

          expect_response_contain_exactly(no_iteration_issue.id)
        end

        it 'returns issues with any iteration' do
          get api('/issues', user), params: { iteration_id: 'Any' }

          expect_response_contain_exactly(iteration_1_issue.id, iteration_2_issue.id)
        end

        it 'returns no issues on user dashboard issues list' do
          get api('/issues', user), params: { iteration_id: 'Current' }

          expect(json_response).to be_empty
        end

        it 'returns issues with a specific iteration title' do
          get api('/issues', user), params: { iteration_title: iteration_1.title }

          expect_response_contain_exactly(iteration_1_issue.id)
        end
      end

      context "filtering by IP-restricted projects" do
        let_it_be(:current_user, freeze: false) { user }
        let_it_be(:allowed_cidr_range, freeze: false) { '10.0.0.0/8' }
        let_it_be(:denied_ip, freeze: false) { '192.168.0.2' }
        let_it_be(:allowed_ip, freeze: false) { '10.0.0.1' }
        let_it_be(:ip_restricted_group, freeze: false) do
          create(:group).tap do |group|
            create(:ip_restriction, group: group, range: allowed_cidr_range)
          end
        end

        let_it_be(:unrestricted_group, freeze: false) { group }

        let_it_be(:restricted_project, freeze: false) do
          create(:project, namespace: ip_restricted_group, developers: [current_user])
        end

        let_it_be(:unrestricted_project, freeze: false) { group_project }

        let_it_be(:restricted_issue, freeze: false) do
          create(:issue, project: restricted_project, assignees: [current_user])
        end

        let_it_be(:unrestricted_issue, freeze: false) do
          create(:issue, project: unrestricted_project, assignees: [current_user])
        end

        let(:user_ip) { allowed_ip }

        before do
          stub_licensed_features(group_ip_restriction: true)
          allow(Gitlab::IpAddressState).to receive(:current).and_return(user_ip)
        end

        context "when current IP is not allowed for restricted group" do
          let(:user_ip) { denied_ip }

          it "filters out issues the user shouldn't see based on IP" do
            get api('/issues', current_user), params: { scope: 'all' }

            expect_paginated_array_response([unrestricted_issue.id])
          end
        end

        context "when IP is allowed" do
          it "includes issues from restricted project" do
            get api('/issues', current_user), params: { scope: 'all' }

            expect_paginated_array_response([restricted_issue.id, unrestricted_issue.id])
          end
        end

        context "query performance" do
          it "does not introduce N+1 queries for ability filtering" do
            control = ActiveRecord::QueryRecorder.new do
              get api('/issues', current_user), params: { scope: 'all' }
            end

            create(:issue, project: restricted_project)
            create(:issue, project: unrestricted_project)

            expect { get api('/issues', current_user) }.not_to exceed_query_limit(control)
          end
        end
      end
    end
  end

  describe 'GET /groups/:id/issues' do
    subject { get api("/groups/#{group.id}/issues", user) }

    context 'filtering by assignee_username' do
      let_it_be(:another_assignee, freeze: false) { create(:assignee) }
      let_it_be(:issue1, freeze: false) do
        create(:issue, author: user2, project: group_project, weight: 1, created_at: 3.days.ago)
      end

      let_it_be(:issue2, freeze: false) do
        create(:issue, author: user2, project: group_project, weight: 5, created_at: 2.days.ago)
      end

      let_it_be(:issue3, freeze: false) do
        create(:issue, author: user2, assignees: [assignee, another_assignee], project: group_project, weight: 3,
          created_at: 1.day.ago)
      end

      subject do
        get api("/groups/#{group.id}/issues", user),
          params: { assignee_username: [assignee.username, another_assignee.username], scope: 'all' }
      end

      it 'returns issues with multiple assignees' do
        subject

        expect_paginated_array_response(issue3.id)
      end
    end

    it_behaves_like 'filtering by epic_id' do
      let(:endpoint) { "/groups/#{group_project.group.id}/issues" }
    end

    it_behaves_like 'exposes epic' do
      let_it_be(:issue_with_epic, freeze: false) { create(:issue, project: group_project, epic: epic) }
    end

    it_behaves_like 'exposes iteration'

    context 'filtering by iteration' do
      let_it_be(:cadence, freeze: false) { create(:iterations_cadence, group: group) }
      let_it_be(:iteration_1, freeze: false) do
        create(:iteration, iterations_cadence: cadence, start_date: Time.zone.today)
      end

      let_it_be(:iteration_2, freeze: false) { create(:iteration, iterations_cadence: cadence) }
      let_it_be(:iteration_1_issue, freeze: false) { create(:issue, project: group_project, iteration: iteration_1) }
      let_it_be(:iteration_2_issue, freeze: false) { create(:issue, project: group_project, iteration: iteration_2) }
      let_it_be(:no_iteration_issue, freeze: false) { create(:issue, project: group_project) }

      it 'returns issues with Current iteration' do
        get api("/groups/#{group.id}/issues", user), params: { iteration_id: 'Current', scope: 'all' }

        expect_response_contain_exactly(iteration_1_issue.id)
      end
    end

    it 'avoids N+1 queries with epics' do
      stub_licensed_features(epics: true)

      group.add_developer(user)

      subgroup_1 = create(:group, parent: group)
      subgroup_1_project = create(:project, group: subgroup_1)

      create(:issue, project: subgroup_1_project, epic: create(:epic, group: subgroup_1))

      get api("/groups/#{group.id}/issues", user)

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { get api("/groups/#{group.id}/issues", user) }

      subgroup_2 = create(:group, parent: group)
      subgroup_2_project = create(:project, group: subgroup_2)

      create(:issue, project: subgroup_2_project, epic: create(:epic, group: subgroup_2))

      expect do
        get api("/groups/#{group.id}/issues", user)
      end.not_to exceed_query_limit(control).allow_skip_cache_inconsistency
    end

    it 'avoids N+1 queries with iterations' do
      stub_licensed_features(iterations: true)

      group.add_developer(user)

      subgroup_1 = create(:group, parent: group)
      subgroup_1_project = create(:project, group: subgroup_1)

      create(:issue, project: subgroup_1_project,
        iteration: create(:iteration, iterations_cadence: create(:iterations_cadence, group: subgroup_1)))

      get api("/groups/#{group.id}/issues", user)

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { get api("/groups/#{group.id}/issues", user) }

      subgroup_2 = create(:group, parent: group)
      subgroup_2_project = create(:project, group: subgroup_2)

      create(:issue, project: subgroup_2_project,
        iteration: create(:iteration, iterations_cadence: create(:iterations_cadence, group: subgroup_2)))

      expect do
        get api("/groups/#{group.id}/issues", user)
      end.not_to exceed_query_limit(control).allow_skip_cache_inconsistency
    end
  end

  describe "GET /projects/:id/issues" do
    subject { get api("/projects/#{project.id}/issues", user) }

    context 'filtering by assignee_username' do
      let_it_be(:another_assignee, freeze: false) { create(:assignee) }
      let_it_be(:issue1, freeze: false) do
        create(:issue, author: user2, project: project, weight: 1, created_at: 3.days.ago)
      end

      let_it_be(:issue2, freeze: false) do
        create(:issue, author: user2, project: project, weight: 5, created_at: 2.days.ago)
      end

      let_it_be(:issue3, freeze: false) do
        create(:issue, author: user2, assignees: [assignee, another_assignee], project: project, weight: 3,
          created_at: 1.day.ago)
      end

      subject do
        get api("/projects/#{project.id}/issues", user),
          params: { assignee_username: [assignee.username, another_assignee.username], scope: 'all' }
      end

      it 'returns issues with multiple assignees' do
        subject

        expect_paginated_array_response(issue3.id)
      end
    end

    it_behaves_like 'filtering by epic_id' do
      let(:endpoint) { "/projects/#{group_project.id}/issues" }
    end

    context 'when using keyset pagination' do
      let_it_be(:issue1, freeze: false) do
        create(:issue, author: user2, project: project, weight: 1, created_at: 3.days.ago)
      end

      let_it_be(:issue2, freeze: false) do
        create(:issue, author: user2, project: project, weight: 5, created_at: 2.days.ago)
      end

      it 'orders by weight' do
        params = { pagination: 'keyset', per_page: 2, order_by: 'weight' }
        get api("/projects/#{project.id}/issues", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.first['id']).to eq(issue2.id)
      end
    end

    context 'on personal project' do
      let_it_be(:issue_with_epic, freeze: false) { create(:issue, project: project, epic: epic) }

      before do
        stub_licensed_features(epics: true)
      end

      it 'does not contain epic_iid in response' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(issue_response_by_id(issue_with_epic.id)).not_to have_key('epic_iid')
      end
    end

    context 'on group project' do
      let_it_be(:issue_with_epic, freeze: false) { create(:issue, project: group_project, epic: epic) }

      subject { get api("/projects/#{group_project.id}/issues", user) }

      it_behaves_like 'exposes epic'
      it_behaves_like 'exposes iteration'
    end

    context 'filtering by iteration' do
      let_it_be(:cadence, freeze: false) { create(:iterations_cadence, group: group) }
      let_it_be(:iteration_1, freeze: false) do
        create(:iteration, iterations_cadence: cadence, start_date: Time.zone.today)
      end

      let_it_be(:iteration_2, freeze: false) { create(:iteration, iterations_cadence: cadence) }
      let_it_be(:iteration_1_issue, freeze: false) { create(:issue, project: group_project, iteration: iteration_1) }
      let_it_be(:iteration_2_issue, freeze: false) { create(:issue, project: group_project, iteration: iteration_2) }
      let_it_be(:no_iteration_issue, freeze: false) { create(:issue, project: group_project) }

      it 'returns issues with Current iteration' do
        get api("/projects/#{group_project.id}/issues", user), params: { iteration_id: 'Current', scope: 'all' }

        expect_response_contain_exactly(iteration_1_issue.id)
      end
    end
  end

  describe 'GET /project/:id/issues/:issue_id' do
    context 'on personal project' do
      let_it_be(:issue_with_epic, freeze: false) { create(:issue, project: project, epic: epic) }

      subject { get api("/projects/#{project.id}/issues/#{issue_with_epic.iid}", user) }

      before do
        stub_licensed_features(epics: true)
      end

      it 'does not contain epic_iid in response' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(issue_response_by_id(issue_with_epic.id)).not_to have_key('epic_iid')
      end
    end

    context 'on group project' do
      let_it_be(:issue_with_epic, freeze: false) { create(:issue, project: group_project, epic: epic) }

      subject { get api("/projects/#{group_project.id}/issues/#{issue_with_epic.iid}", user) }

      it_behaves_like 'exposes epic'
    end

    context 'when specified issue is of type task' do
      let_it_be(:task, freeze: false) { create(:issue, :task, project: project) }

      it 'returns a task' do
        get api("/projects/#{project.id}/issues/#{task.iid}", user)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  shared_examples 'with epic parameter' do
    let(:params) { { title: 'issue with epic', epic_id: epic.id } }

    context 'for a group project' do
      let(:target_project) { group_project }

      context 'with epics feature' do
        before do
          stub_licensed_features(epics: true)
        end

        context 'when user can read epics' do
          before_all do
            group.add_guest(user)
          end

          context 'with epic_id parameter' do
            let(:params) { { title: 'issue with epic', epic_id: epic.id } }

            it 'sets epic on issue' do
              request

              expect(response).to have_gitlab_http_status(:success)
              expect(json_response['epic_iid']).to eq(epic.iid)
            end
          end

          context 'with deprecated epic_iid parameter' do
            let(:params) { { title: 'issue with epic', epic_iid: epic.iid } }

            it 'sets epic on issue' do
              request

              expect(response).to have_gitlab_http_status(:success)
              expect(json_response['epic_iid']).to eq(epic.iid)
            end
          end
        end

        context 'when user can not read the epic' do
          let(:epic) { build(:epic, :confidential, group: group) }

          it 'does not set the epic' do
            request

            expect(response).to have_gitlab_http_status(:success)
            expect(json_response['epic_iid']).to be_nil
          end
        end

        context 'when user can not admin_issue_relation for the issue' do
          before do
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?).with(user, :admin_issue_relation, anything).and_return(false)
          end

          it 'returns an error' do
            request

            expect(response).to have_gitlab_http_status(:forbidden)
            expect(json_response['message']).to eq('403 Forbidden')
          end
        end
      end

      context 'without epics feature' do
        before_all do
          group.add_owner(user)
        end

        before do
          stub_licensed_features(epics: false)
        end

        it 'does not set epic on issue' do
          request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 Not found')
        end
      end

      context 'when both epic_id and epic_iid is used' do
        let(:params) { { title: 'issue with epic', epic_id: epic.id, epic_iid: epic.iid } }

        it 'returns an error' do
          request

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'for a user project' do
      let(:target_project) { project }

      it 'does not set epic on issue' do
        request

        expect(response).to have_gitlab_http_status(:success)
        expect(json_response).not_to have_key('epic_iid')
      end
    end
  end

  describe "POST /projects/:id/issues" do
    it 'creates a new project issue' do
      expect do
        post api("/projects/#{project.id}/issues", user),
          params: { title: 'new issue', labels: 'label, label2', weight: 101, assignee_ids: [user2.id] }
      end.to change { Issue.count }.by(1)

      expect(response).to have_gitlab_http_status(:created)
      expect(json_response['title']).to eq('new issue')
      expect(json_response['description']).to be_nil
      expect(json_response['labels']).to eq(%w[label label2])
      expect(json_response['confidential']).to be_falsy
      expect(json_response['weight']).to eq(101)
      expect(json_response['assignee']['name']).to eq(user2.name)
      expect(json_response['assignees'].first['name']).to eq(user2.name)
      expect(Issue.last.work_item_type.base_type).to eq('issue')
    end

    it 'creates a new project task' do
      expect do
        post api("/projects/#{project.id}/issues", user),
          params: { title: 'new task', issue_type: 'task' }
      end.to change { Issue.count }.by(1)

      expect(response).to have_gitlab_http_status(:created)
      expect(Issue.last.work_item_type.base_type).to eq('task')
    end

    it_behaves_like 'with epic parameter' do
      let(:request) { post api("/projects/#{target_project.id}/issues", user), params: params }
    end

    context 'when authenticated with a token that has the ai_workflows scope' do
      it_behaves_like 'forbids quick actions for ai_workflows scope' do
        let(:method) { :post }
        let(:url) { "/projects/#{project.id}/issues" }
        let(:field) { :description }
        let(:params) { { title: 'My issue' } }
        let(:success_status) { :created }
      end
    end
  end

  describe 'PUT /projects/:id/issues/:issue_iid to update weight' do
    let_it_be(:issue, freeze: false) { create :issue, author: user, project: project }

    it 'updates an issue with no weight' do
      put api("/projects/#{project.id}/issues/#{issue.iid}", user), params: { weight: 101 }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['weight']).to eq(101)
    end

    it 'removes a weight from an issue' do
      weighted_issue = create(:issue, project: project, weight: 2)

      put api("/projects/#{project.id}/issues/#{weighted_issue.iid}", user), params: { weight: nil }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['weight']).to be_nil
    end

    it 'returns 400 if weight is less than minimum weight' do
      put api("/projects/#{project.id}/issues/#{issue.iid}", user), params: { weight: -1 }

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['message']['weight']).to be_present
    end

    it 'creates a ResourceWeightEvent' do
      expect do
        put api("/projects/#{project.id}/issues/#{issue.iid}", user), params: { weight: 9 }
      end.to change { ResourceWeightEvent.count }.by(1)
    end

    it 'does not create a system note' do
      expect do
        put api("/projects/#{project.id}/issues/#{issue.iid}", user), params: { weight: 9 }
      end.not_to change { Note.count }
    end

    it 'adds a note when the weight is changed' do
      put api("/projects/#{project.id}/issues/#{issue.iid}", user), params: { weight: 9 }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['weight']).to eq(9)
    end

    context 'issuable weights unlicensed' do
      before do
        stub_licensed_features(issue_weights: false)
      end

      it 'ignores the update' do
        put api("/projects/#{project.id}/issues/#{issue.iid}", user), params: { weight: 5 }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['weight']).to be_nil
        expect(issue.reload.read_attribute(:weight)).to be_nil
      end
    end

    context 'when authenticated with a token that has the ai_workflows scope' do
      it_behaves_like 'forbids quick actions for ai_workflows scope' do
        let(:method) { :put }
        let(:url) { "/projects/#{project.id}/issues/#{issue.iid}" }
        let(:field) { :description }
        let(:success_status) { :ok }
      end
    end
  end

  describe 'PUT /projects/:id/issues/:issue_iid to update epic' do
    it_behaves_like 'with epic parameter' do
      let(:issue_with_epic) { create(:issue, project: target_project) }
      let(:request) { put api("/projects/#{target_project.id}/issues/#{issue_with_epic.iid}", user), params: params }
    end
  end

  describe 'PUT /projects/:id/issues/:issue_iid/metric_images/authorize' do
    include_context 'workhorse headers'

    let_it_be(:issue, freeze: false) { create(:incident, project: project) }

    before_all do
      project.add_developer(user)
    end

    subject do
      post api("/projects/#{project.id}/issues/#{issue.iid}/metric_images/authorize", user), headers: workhorse_headers
    end

    it 'authorizes uploading with workhorse header' do
      subject

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.media_type.to_s).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)
    end

    it 'rejects requests that bypassed gitlab-workhorse', :verify_workhorse_jwt do
      workhorse_headers.delete(Gitlab::Workhorse::INTERNAL_API_REQUEST_HEADER)

      subject

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    context 'when using remote storage' do
      context 'when direct upload is enabled' do
        before do
          stub_uploads_object_storage(MetricImageUploader, enabled: true, direct_upload: true)
        end

        it 'responds with status 200, location of file remote store and object details' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.media_type.to_s).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)
          expect(json_response).not_to have_key('TempPath')
          expect(json_response['RemoteObject']).to have_key('ID')
          expect(json_response['RemoteObject']).to have_key('GetURL')
          expect(json_response['RemoteObject']).to have_key('StoreURL')
          expect(json_response['RemoteObject']).to have_key('DeleteURL')
          expect(json_response['RemoteObject']).to have_key('MultipartUpload')
        end
      end

      context 'when direct upload is disabled' do
        before do
          stub_uploads_object_storage(MetricImageUploader, enabled: true, direct_upload: false)
        end

        it 'handles as a local file' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.media_type.to_s).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)
          expect(json_response['TempPath']).to eq(MetricImageUploader.workhorse_local_upload_path)
          expect(json_response['RemoteObject']).to be_nil
        end
      end
    end
  end

  describe 'POST /projects/:id/issues/:issue_iid/metric_images' do
    include WorkhorseHelpers
    using RSpec::Parameterized::TableSyntax

    include_context 'workhorse headers'

    let(:issue) { create(:incident, project: project) }

    let(:file) { fixture_file_upload('spec/fixtures/rails_sample.jpg', 'image/jpg') }
    let(:file_name) { 'rails_sample.jpg' }
    let(:url) { 'http://gitlab.com' }
    let(:url_text) { 'GitLab' }

    let(:params) { { url: url, url_text: url_text } }

    subject do
      workhorse_finalize(
        api("/projects/#{project.id}/issues/#{issue.iid}/metric_images", user2),
        method: :post,
        file_key: :file,
        params: params.merge(file: file),
        headers: workhorse_headers,
        send_rewritten_field: true
      )
    end

    shared_examples 'can_upload_metric_image' do
      it 'creates a new metric image' do
        subject

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['filename']).to eq(file_name)
        expect(json_response['url']).to eq(url)
        expect(json_response['url_text']).to eq(url_text)
        expect(json_response['file_path'])
          .to match(%r{/uploads/-/system/issuable_metric_image/file/[\d+]+/#{file_name}})
        expect(json_response['created_at']).not_to be_nil
        expect(json_response['id']).not_to be_nil
      end
    end

    shared_examples 'unauthorized_upload' do
      it 'disallows the upload' do
        subject

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq('Not allowed!')
      end
    end

    where(:user_role, :own_issue, :expected_status) do
      :guest    | true  | :unauthorized_upload
      :guest    | false | :unauthorized_upload
      :reporter | true  | :can_upload_metric_image
      :reporter | false | :can_upload_metric_image
    end

    with_them do
      before do
        # Local storage
        stub_uploads_object_storage(MetricImageUploader, enabled: false)
        allow_next_instance_of(MetricImageUploader) do |instance|
          allow(instance).to receive(:file_storage?).and_return(true)
        end

        stub_licensed_features(incident_metric_upload: true)
        project.send(:"add_#{user_role}", user2)
        own_issue ? issue.update!(author: user2) : issue.update!(author: user)
      end

      it_behaves_like params[:expected_status].to_s
    end

    context 'file size too large' do
      before do
        stub_licensed_features(incident_metric_upload: true)
        allow_next_instance_of(UploadedFile) do |upload_file|
          allow(upload_file).to receive(:size).and_return(IssuableMetricImage::MAX_FILE_SIZE + 1)
        end
      end

      it 'returns an error' do
        subject

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(response.body).to match(/File is too large/)
      end
    end

    context 'object storage enabled' do
      before_all do
        project.add_developer(user2)
      end

      before do
        # Object storage
        stub_licensed_features(incident_metric_upload: true)
        stub_uploads_object_storage(MetricImageUploader)

        allow_next_instance_of(MetricImageUploader) do |instance|
          allow(instance).to receive(:file_storage?).and_return(false)
        end
      end

      it_behaves_like 'can_upload_metric_image'

      it 'uploads to remote storage' do
        subject

        last_upload = IssuableMetricImage.last.uploads.last
        expect(last_upload.store).to eq(::ObjectStorage::Store::REMOTE)
      end
    end
  end

  describe 'GET /projects/:id/issues/:issue_iid/metric_images' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:project, freeze: false) do
      create(:project, :private, creator_id: user.id, namespace: user.namespace)
    end

    let_it_be(:issue, freeze: false) { create(:incident, project: project) }

    let_it_be(:image, freeze: false) { create(:issuable_metric_image, issue: issue) }

    subject { get api("/projects/#{project.id}/issues/#{issue.iid}/metric_images", user2) }

    shared_examples 'can_read_metric_image' do
      it 'can read the metric images' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.first).to match(
          {
            id: image.id,
            created_at: image.created_at.strftime('%Y-%m-%dT%H:%M:%S.%LZ'),
            filename: image.filename,
            file_path: image.file_path,
            url: image.url,
            url_text: nil
          }.with_indifferent_access
        )
      end
    end

    shared_examples 'unauthorized_read' do
      it 'cannot read the metric images' do
        subject

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    where(:user_role, :own_issue, :issue_confidential, :expected_status) do
      :not_member | false | false | :unauthorized_read
      :guest      | false | true  | :unauthorized_read
      :guest      | true  | false | :can_read_metric_image
      :guest      | false | false | :can_read_metric_image
      :reporter   | true  | false | :can_read_metric_image
      :reporter   | false | false | :can_read_metric_image
    end

    with_them do
      before do
        stub_licensed_features(incident_metric_upload: true)
        project.send(:"add_#{user_role}", user2) unless user_role == :not_member
        issue.update!(confidential: true) if issue_confidential
        own_issue ? issue.update!(author: user2) : issue.update!(author: user)
      end

      it_behaves_like params[:expected_status].to_s
    end
  end

  describe 'PUT /projects/:id/issues/:issue_iid/metric_images/:metric_image_id' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:project, freeze: false) do
      create(:project, :public, creator_id: user.id, namespace: user.namespace)
    end

    let!(:image) { create(:issuable_metric_image, issue: issue) }
    let(:params) { { url: 'http://test.example.com', url_text: 'Example website 123' } }

    subject { put api("/projects/#{project.id}/issues/#{issue.iid}/metric_images/#{image.id}", user2), params: params }

    shared_examples 'can_update_metric_image' do
      it 'can update the metric images' do
        subject

        expect(response).to have_gitlab_http_status(:success)
        expect(json_response['url']).to eq(params[:url])
        expect(json_response['url_text']).to eq(params[:url_text])
      end
    end

    shared_examples 'unauthorized_update' do
      it 'cannot delete the metric image' do
        subject

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(image.reload).to eq(image)
      end
    end

    shared_examples 'not_found' do
      it 'cannot delete the metric image' do
        subject

        expect(response).to have_gitlab_http_status(:not_found)
        expect(image.reload).to eq(image)
      end
    end

    where(:user_role, :own_issue, :issue_confidential, :expected_status) do
      :not_member | false | false | :unauthorized_update
      :not_member | true  | false | :unauthorized_update
      :not_member | true  | true  | :unauthorized_update
      :guest      | false | true  | :not_found
      :guest      | false | false | :unauthorized_update
      :guest      | true  | false | :can_update_metric_image
      :reporter   | true  | false | :can_update_metric_image
      :reporter   | false | false | :can_update_metric_image
    end

    with_them do
      before do
        stub_licensed_features(incident_metric_upload: true)
        project.send(:"add_#{user_role}", user2) unless user_role == :not_member
      end

      let!(:issue) do
        author = own_issue ? user2 : user
        confidential = issue_confidential

        create(:incident, project: project, confidential: confidential, author: author)
      end

      it_behaves_like params[:expected_status].to_s
    end

    context 'user has access' do
      let_it_be(:issue, freeze: false) { create(:incident, project: project) }

      before_all do
        project.add_reporter(user2)
      end

      context 'metric image not found' do
        subject do
          delete api("/projects/#{project.id}/issues/#{issue.iid}/metric_images/#{non_existing_record_id}", user2)
        end

        it 'returns an error' do
          subject

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('Metric image not found')
        end
      end

      context 'metric image cannot be updated' do
        let(:params) { { url_text: 'something_long' * 100 } }

        it 'returns an error' do
          subject

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq('Metric image could not be updated')
        end
      end
    end
  end

  describe 'DELETE /projects/:id/issues/:issue_iid/metric_images/:metric_image_id' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:project, freeze: false) do
      create(:project, :public, creator_id: user.id, namespace: user.namespace)
    end

    let!(:image) { create(:issuable_metric_image, issue: issue) }

    subject { delete api("/projects/#{project.id}/issues/#{issue.iid}/metric_images/#{image.id}", user2) }

    shared_examples 'can_delete_metric_image' do
      it 'can delete the metric images' do
        subject

        expect(response).to have_gitlab_http_status(:no_content)
        expect { image.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    shared_examples 'unauthorized_delete' do
      it 'cannot delete the metric image' do
        subject

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(image.reload).to eq(image)
      end
    end

    shared_examples 'not_found' do
      it 'cannot delete the metric image' do
        subject

        expect(response).to have_gitlab_http_status(:not_found)
        expect(image.reload).to eq(image)
      end
    end

    where(:user_role, :own_issue, :issue_confidential, :expected_status) do
      :not_member | false | false | :unauthorized_delete
      :not_member | true  | false | :unauthorized_delete
      :not_member | true  | true  | :unauthorized_delete
      :guest      | false | true  | :not_found
      :guest      | false | false | :unauthorized_delete
      :guest      | true  | false | :can_delete_metric_image
      :reporter   | true  | false | :can_delete_metric_image
      :reporter   | false | false | :can_delete_metric_image
    end

    with_them do
      before do
        stub_licensed_features(incident_metric_upload: true)
        project.send(:"add_#{user_role}", user2) unless user_role == :not_member
      end

      let!(:issue) do
        author = own_issue ? user2 : user
        confidential = issue_confidential

        create(:incident, project: project, confidential: confidential, author: author)
      end

      it_behaves_like params[:expected_status].to_s
    end

    context 'user has access' do
      let_it_be(:issue, freeze: false) { create(:incident, project: project) }

      before_all do
        project.add_reporter(user2)
      end

      context 'metric image not found' do
        subject do
          delete api("/projects/#{project.id}/issues/#{issue.iid}/metric_images/#{non_existing_record_id}", user2)
        end

        it 'returns an error' do
          subject

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('Metric image not found')
        end
      end
    end
  end

  describe 'granular token authorization for metric images' do
    include WorkhorseHelpers
    include_context 'workhorse headers'

    let_it_be(:incident) { create(:incident, project: project) }

    let(:boundary_object) { project }
    let(:base_path) { "/projects/#{project.id}/issues/#{incident.iid}/metric_images" }

    before do
      stub_licensed_features(incident_metric_upload: true)
      stub_uploads_object_storage(MetricImageUploader, enabled: false)
    end

    it_behaves_like 'authorizing granular token permissions', :read_issuable_metric_image do
      let(:request) { get api(base_path, personal_access_token: pat) }
    end

    context 'when uploading an image' do
      before do
        allow_next_instance_of(MetricImageUploader) do |instance|
          allow(instance).to receive(:file_storage?).and_return(true)
        end
      end

      it_behaves_like 'authorizing granular token permissions', :create_issuable_metric_image do
        let(:request) do
          workhorse_finalize(
            api(base_path, personal_access_token: pat),
            method: :post,
            file_key: :file,
            params: { file: fixture_file_upload('spec/fixtures/rails_sample.jpg', 'image/jpg'),
                      url: 'http://gitlab.com' },
            headers: workhorse_headers,
            send_rewritten_field: true
          )
        end
      end
    end

    context 'with an existing image' do
      let!(:image) { create(:issuable_metric_image, issue: incident) }

      it_behaves_like 'authorizing granular token permissions', :update_issuable_metric_image do
        let(:request) do
          put api("#{base_path}/#{image.id}", personal_access_token: pat),
            params: { url: 'http://test.example.com', url_text: 'Example website' }
        end
      end

      it_behaves_like 'authorizing granular token permissions', :delete_issuable_metric_image do
        let(:request) { delete api("#{base_path}/#{image.id}", personal_access_token: pat) }
      end
    end
  end

  private

  def issue_response_by_id(issue_id)
    Array.wrap(json_response).find { |issue| issue['id'] == issue_id }
  end
end

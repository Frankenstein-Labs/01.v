# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ProjectApprovalRules, :aggregate_failures, feature_category: :source_code_management do
  let_it_be(:group) { create(:group_with_members) }
  let_it_be(:group2) { create(:group_with_members) }
  let_it_be(:user) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be_with_reload(:project) { create(:project, :public, :repository, creator: user, namespace: user.namespace, only_allow_merge_if_pipeline_succeeds: false) }
  let_it_be_with_reload(:approver) { create(:user) }
  let_it_be(:other_approver) { create(:user) }

  before do
    stub_licensed_features(merge_request_approvers: true)
  end

  describe 'GET /projects/:id/approval_rules/:approval_rule_id' do
    let_it_be(:private_project) { create(:project, :private, creator: user, namespace: user.namespace) }

    let!(:approval_rule) { create(:approval_project_rule, project: private_project) }
    let(:url) { "/projects/#{private_project.id}/approval_rules/#{approval_rule.id}" }

    context 'when the request is correct' do
      it 'matches the response schema' do
        get api(url, user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/project_approval_rule', dir: 'ee')

        rule = json_response

        expect(rule['approvals_required']).to eq(approval_rule.approvals_required)
        expect(rule['id']).to eq(approval_rule.id)
        expect(rule['name']).to eq(approval_rule.name)
      end
    end

    context 'when the user is not authorized' do
      it 'does not display rule information' do
        get api(url, user2)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when license is missing' do
      before do
        stub_licensed_features(merge_request_approvers: false)
      end

      it 'returns 403 error' do
        get api(url, user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_approval_rule do
      let(:boundary_object) { private_project }
      let(:request) { get api(url, personal_access_token: pat) }
    end

    context 'when the user is an auditor' do
      let_it_be(:auditor) { create(:user, :auditor) }

      it 'returns 403 for a private project without membership' do
        get api(url, auditor)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'GET /projects/:id/approval_rules' do
    let(:url) { "/projects/#{project.id}/approval_rules" }

    context 'when the request is correct' do
      let!(:rule) do
        rule = create(:approval_project_rule, name: 'vulnerability', project: project, approvals_required: 7)
        rule.users << approver
        rule
      end

      let(:developer) do
        user = create(:user)
        project.add_guest(user)
        user
      end

      it 'matches the response schema' do
        get api(url, developer)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
        expect(response).to match_response_schema('public_api/v4/project_approval_rules', dir: 'ee')

        json = json_response

        expect(json.size).to eq(1)

        rule = json.first

        expect(rule['approvals_required']).to eq(7)
        expect(rule['name']).to eq('vulnerability')
      end

      context 'private group filtering' do
        let_it_be(:private_group) { create :group, :private }

        before do
          rule.groups << private_group
        end

        it 'excludes private groups if user has no access' do
          get api(url, developer)

          json = json_response
          rule = json.first

          expect(rule['groups'].size).to eq(0)
        end

        it 'includes private groups if user has access' do
          private_group.add_owner(developer)

          get api(url, developer)

          json = json_response
          rule = json.first

          expect(rule['groups'].size).to eq(1)
        end
      end

      context 'report_approver rules' do
        let!(:report_approver_rule) do
          create(:approval_project_rule, :code_coverage, project: project)
        end

        it 'includes report_approver rules' do
          get api(url, developer)

          json = json_response

          expect(json.size).to eq(2)
          expect(json.map { |rule| rule['name'] }).to contain_exactly(rule.name, report_approver_rule.name)
          expect(json.map { |rule| rule['report_type'] }).to contain_exactly(nil, 'code_coverage')
        end
      end

      context 'rules from scan result policy' do
        let_it_be(:scan_finding_rule) do
          create(:approval_project_rule, :scan_finding, project: project)
        end

        it 'returns 404' do
          get api(url, developer)

          json = json_response

          expect(json.size).to eq(1)
          expect(json.map { |rule| rule['name'] }).not_to include(scan_finding_rule.name)
        end
      end
    end

    context 'when project is archived' do
      let_it_be(:archived_project) { create(:project, :archived, creator: user) }

      let(:url) { "/projects/#{archived_project.id}/approval_rules" }

      context 'when user has normal permissions' do
        it 'returns 403' do
          archived_project.add_guest(user2)

          get api(url, user2)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when user has project admin permissions' do
        it 'allows access' do
          archived_project.add_maintainer(user2)

          get api(url, user2)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'when license is missing' do
      before do
        stub_licensed_features(merge_request_approvers: false)
      end

      it 'returns 403 error' do
        get api(url, user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_approval_rule do
      let(:boundary_object) { project }
      let(:request) { get api(url, personal_access_token: pat) }
    end
  end

  describe 'POST /projects/:id/approval_rules' do
    let(:schema) { 'public_api/v4/project_approval_rule' }
    let(:url) { "/projects/#{project.id}/approval_rules" }

    it_behaves_like 'an API endpoint for creating project approval rule'

    it_behaves_like 'authorizing granular token permissions', :create_approval_rule do
      let(:boundary_object) { project }
      let(:request) do
        post api(url, personal_access_token: pat),
          params: { name: 'security', approvals_required: 10 }
      end
    end
  end

  describe 'PUT /projects/:id/approval_rules/:approval_rule_id' do
    let!(:approval_rule) { create(:approval_project_rule, project: project) }
    let(:schema) { 'public_api/v4/project_approval_rule' }
    let(:url) { "/projects/#{project.id}/approval_rules/#{approval_rule.id}" }

    it_behaves_like 'an API endpoint for updating project approval rule'

    it_behaves_like 'authorizing granular token permissions', :update_approval_rule do
      let(:boundary_object) { project }
      let(:request) do
        put api(url, personal_access_token: pat),
          params: { name: 'updated_name' }
      end
    end
  end

  describe 'DELETE /projects/:id/approval_rules/:approval_rule_id' do
    let!(:approval_rule) { create(:approval_project_rule, project: project) }
    let(:url) { "/projects/#{project.id}/approval_rules/#{approval_rule.id}" }

    it_behaves_like 'an API endpoint for deleting project approval rule'

    it_behaves_like 'authorizing granular token permissions', :delete_approval_rule do
      let(:boundary_object) { project }
      let(:request) { delete api(url, personal_access_token: pat) }
    end
  end

  describe 'editing project approval rules when overriding is disabled', :aggregate_failures do
    let_it_be(:maintainer) { create(:user) }
    let!(:approval_rule) { create(:approval_project_rule, project: project) }
    let(:put_url) { "/projects/#{project.id}/approval_rules/#{approval_rule.id}" }
    let(:delete_url) { "/projects/#{project.id}/approval_rules/#{approval_rule.id}" }

    before_all do
      project.add_maintainer(maintainer)
    end

    before do
      stub_licensed_features(merge_request_approvers: true, admin_merge_request_approvers_rules: true)
    end

    context 'when only the project-level setting prevents overriding' do
      before do
        project.update!(disable_overriding_approvers_per_merge_request: true)
      end

      it 'still allows editing the project approval rules list' do
        put api(put_url, maintainer), params: { name: 'updated' }
        expect(response).to have_gitlab_http_status(:ok)

        delete api(delete_url, maintainer)
        expect(response).to have_gitlab_http_status(:no_content)
        expect(ApprovalProjectRule.exists?(approval_rule.id)).to be(false)
      end
    end

    context 'when the instance-level setting locks the rules list' do
      before do
        stub_application_setting(disable_overriding_approvers_per_merge_request: true)
      end

      it 'forbids updating and does not silently swallow a forbidden delete' do
        put api(put_url, maintainer), params: { name: 'updated' }
        expect(response).to have_gitlab_http_status(:forbidden)

        delete api(delete_url, maintainer)
        expect(response).to have_gitlab_http_status(:forbidden)
        expect(ApprovalProjectRule.exists?(approval_rule.id)).to be(true)
      end
    end
  end

  describe 'coverage_minimum_threshold' do
    let(:url) { "/projects/#{project.id}/approval_rules" }

    before_all do
      project.add_maintainer(user)
    end

    before do
      stub_feature_flags(coverage_minimum_threshold: true)
    end

    context 'when creating a code_coverage rule with threshold' do
      it 'creates the rule with the threshold' do
        post api(url, user), params: {
          name: 'Coverage-Check',
          approvals_required: 1,
          report_type: 'code_coverage',
          coverage_minimum_threshold: 80.0
        }

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['coverage_minimum_threshold']).to eq(80.0)
      end
    end

    context 'when updating a code_coverage rule threshold' do
      let!(:coverage_rule) { create(:approval_project_rule, :code_coverage, project: project, coverage_minimum_threshold: 70.0) }
      let(:update_url) { "/projects/#{project.id}/approval_rules/#{coverage_rule.id}" }

      it 'updates the threshold' do
        put api(update_url, user), params: { coverage_minimum_threshold: 85.0 }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['coverage_minimum_threshold']).to eq(85.0)
      end
    end
  end
end

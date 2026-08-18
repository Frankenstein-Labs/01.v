# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IssuePolicy, feature_category: :team_planning do
  let_it_be(:admin, freeze: false) { create(:user, :admin) }
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:guest, freeze: false) { create(:user) }
  let_it_be(:planner, freeze: false) { create(:user) }
  let_it_be(:reporter, freeze: false) { create(:user) }
  let_it_be(:owner, freeze: false) { create(:user) }
  let_it_be_with_refind(:project) { create(:project, :private) }
  let_it_be_with_refind(:issue) { create(:issue, project: project) }

  let_it_be(:root_group, freeze: false) do
    create(:group, :public).tap do |g|
      g.add_planner(planner)
      g.add_reporter(reporter)
      g.add_owner(owner)
    end
  end

  let_it_be(:group, freeze: false) do
    create(:group, :public, parent: root_group).tap do |g|
      g.add_guest(guest)
      g.add_planner(planner)
      g.add_reporter(reporter)
      g.add_owner(owner)
    end
  end

  let_it_be(:support_bot, freeze: false) { create(:support_bot) }

  subject { described_class.new(user, issue) }

  def permissions(user, issue)
    described_class.new(user, issue)
  end

  describe 'summarize_comments', :with_cloud_connector do
    let(:authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }

    context 'when user is nil' do
      let(:user) { nil }
      let_it_be_with_refind(:project) { create(:project, :public) }

      before do
        allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
      end

      it { is_expected.to be_disallowed(:summarize_comments, :generate_description) }
    end

    context 'when user is logged in' do
      before do
        allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
        allow(project).to receive(:duo_features_enabled).and_return(true)
      end

      context "when feature is authorized" do
        before do
          allow(authorizer).to receive(:allowed?).and_return(true)
        end

        context 'when user can read issue' do
          before_all do
            project.add_guest(user)
          end

          it { is_expected.to be_allowed(:summarize_comments) }

          context 'when feature is not enabled' do
            before do
              allow(authorizer).to receive(:allowed?).and_return(false)
            end

            it { is_expected.to be_disallowed(:summarize_comments) }
          end
        end

        context 'when user cannot read issue' do
          it { is_expected.to be_disallowed(:summarize_comments) }

          context 'with confidential issue' do
            let_it_be(:confidential_issue, freeze: false) { create(:issue, :confidential, project: project) }

            it 'does not allow guest to summarize issue' do
              project.add_guest(guest)
              project.add_planner(planner)

              expect(permissions(guest, confidential_issue)).to be_disallowed(:read_issue, :summarize_comments)
              expect(permissions(planner, confidential_issue)).to be_allowed(:read_issue, :summarize_comments)
            end
          end
        end
      end

      context "when feature is not authorized" do
        before_all do
          project.add_guest(user)
        end

        before do
          allow(authorizer).to receive(:allowed?).and_return(false)
        end

        it { is_expected.to be_disallowed(:summarize_comments) }
      end
    end
  end

  describe 'reopen_issue for group level issue' do
    let(:non_member) { user }

    let_it_be_with_reload(:group_issue) { create(:issue, :group_level, namespace: group) }

    it 'does not allow non members' do
      expect(permissions(non_member, group_issue)).to be_disallowed(:reopen_issue)
    end

    it 'does not allow for anonymous' do
      expect(permissions(nil, group_issue)).to be_disallowed(:reopen_issue)
    end

    context 'without group level issue license' do
      it 'dis-allows it for members', :aggregate_failures do
        expect(permissions(guest, group_issue)).to be_disallowed(:reopen_issue)
        expect(permissions(reporter, group_issue)).to be_disallowed(:reopen_issue)
        expect(permissions(planner, group_issue)).to be_disallowed(:reopen_issue)
        expect(permissions(owner, group_issue)).to be_disallowed(:reopen_issue)
      end
    end

    context 'with group level issue license' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'allows it for members', :aggregate_failures do
        expect(permissions(guest, group_issue)).to be_disallowed(:reopen_issue)
        expect(permissions(reporter, group_issue)).to be_allowed(:reopen_issue)
        expect(permissions(planner, group_issue)).to be_allowed(:reopen_issue)
        expect(permissions(owner, group_issue)).to be_allowed(:reopen_issue)
      end
    end
  end

  describe 'admin_issue_relation' do
    let(:non_member) { user }
    let_it_be_with_reload(:group_issue) { create(:issue, :group_level, namespace: group) }
    let_it_be(:public_project, freeze: false) { create(:project, :public, group: group) }
    let_it_be(:private_project, freeze: false) { create(:project, :private, group: group) }
    let_it_be(:public_issue, freeze: false) { create(:issue, project: public_project) }
    let_it_be(:private_issue, freeze: false) { create(:issue, project: private_project) }

    it 'allows non-members to admin_issue_relation in public projects' do
      expect(permissions(non_member, public_issue)).to be_allowed(:admin_issue_relation)
    end

    it 'does not allow non-members to admin_issue_relation in private projects or group issues' do
      expect(permissions(non_member, group_issue)).to be_disallowed(:admin_issue_relation)
      expect(permissions(non_member, private_issue)).to be_disallowed(:admin_issue_relation)
    end

    it 'allow guest to admin_issue_relation' do
      expect(permissions(guest, group_issue)).to be_disallowed(:admin_issue_relation)
      expect(permissions(guest, private_issue)).to be_allowed(:admin_issue_relation)
      expect(permissions(guest, public_issue)).to be_allowed(:admin_issue_relation)
    end

    context 'with group level issue license' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'allows it for guest', :aggregate_failures do
        expect(permissions(guest, group_issue)).to be_allowed(:admin_issue_relation)
      end
    end

    context 'when issue is confidential' do
      let_it_be(:confidential_issue, freeze: false) { create(:issue, :confidential, project: public_project) }

      it 'does not allow guest to admin_issue_relation' do
        expect(permissions(guest, confidential_issue)).to be_disallowed(:admin_issue_relation)
      end

      it 'allow reporter to admin_issue_relation' do
        expect(permissions(reporter, confidential_issue)).to be_allowed(:admin_issue_relation)
      end
    end

    context 'when user is support bot and service desk is enabled' do
      before do
        allow(::Gitlab::Email::IncomingEmail).to receive(:enabled?).and_return(true)
        allow(::Gitlab::Email::IncomingEmail).to receive(:supports_wildcard?).and_return(true)
        allow(::ServiceDesk).to receive(:enabled?).and_return(true)
      end

      it 'allows support_bot to admin_issue_relation on project issues, but does not allow it on group issues' do
        expect(permissions(support_bot, group_issue)).to be_disallowed(:admin_issue_relation, :read_issue)
        expect(permissions(support_bot, public_issue)).to be_allowed(:admin_issue_relation)
        expect(permissions(support_bot, private_issue)).to be_allowed(:admin_issue_relation)
      end

      context 'with group level issue license' do
        before do
          stub_licensed_features(epics: true)
        end

        it 'allows it for support_bot', :aggregate_failures do
          expect(permissions(support_bot, group_issue)).to be_allowed(:admin_issue_relation, :read_issue)
        end
      end
    end

    context 'when user is support bot and service desk is disabled' do
      it 'does not allow support_bot to admin_issue_relation' do
        expect(permissions(support_bot, group_issue)).to be_disallowed(:admin_issue_relation, :read_issue)
        expect(permissions(support_bot, public_issue)).to be_disallowed(:admin_issue_relation)
        expect(permissions(support_bot, private_issue)).to be_disallowed(:admin_issue_relatio)
      end
    end

    context 'when issue has a synced epic' do
      let_it_be_with_reload(:group_issue) { create(:issue, :with_synced_epic, namespace: group) }

      before do
        stub_licensed_features(issuable_resource_links: true, epics: true)
      end

      context 'without group level issue license' do
        before do
          stub_licensed_features(epics: false)
        end

        it 'does not allow' do
          # allows some permissions as guest
          expect(permissions(guest, group_issue)).to be_disallowed(
            :read_issue, :read_issuable, :admin_issue_link, :read_issuable_participables, :read_note, :read_work_item,
            :read_issuable_metric_image, :read_incident_management_timeline_event, :read_cross_project
          )

          # allows read permissions
          expect(permissions(planner, group_issue)).to be_disallowed(:read_internal_note, :read_crm_contacts)
          expect(permissions(reporter, group_issue)).to be_disallowed(:read_internal_note, :read_crm_contacts)

          # allows some permissions that modify the issue
          expect(permissions(owner, group_issue)).to be_disallowed(
            :admin_issue, :update_issue, :set_issue_metadata, :create_note, :admin_issue_relation, :award_emoji,
            :create_todo, :update_subscription, :set_confidentiality, :set_issue_crm_contacts, :set_note_created_at,
            :mark_note_as_internal, :create_timelog, :destroy_issue, :admin_note,
            :move_issue, :clone_issue
          )
        end

        it 'does not allow' do
          # these read permissions are not yet defined for group level issues
          expect(permissions(owner, group_issue)).to be_disallowed(
            :read_issuable_resource_link, :read_issue_iid, :read_design
          )

          # these permissions are either not yet defined for group level issues or not allowed
          expect(permissions(owner, group_issue)).to be_disallowed(
            :create_requirement_test_report,
            :reposition_note, :create_design, :update_design, :destroy_design, :move_design,
            :upload_issuable_metric_image, :update_issuable_metric_image, :delete_issuable_metric_image,
            :admin_issuable_resource_link, :admin_timelog, :admin_issue_metrics, :admin_issue_metrics_list
          )
        end
      end

      context 'with group level issue license' do
        before do
          stub_licensed_features(epics: true)
        end

        it 'does allow' do
          # allows some permissions as guest
          expect(permissions(guest, group_issue)).to be_allowed(
            :read_issue, :read_issuable, :admin_issue_link, :read_issuable_participables, :read_note, :read_work_item,
            :read_issuable_metric_image, :read_incident_management_timeline_event, :read_cross_project
          )

          # allows read permissions
          expect(permissions(planner, group_issue)).to be_allowed(:read_internal_note, :read_crm_contacts)
          expect(permissions(reporter, group_issue)).to be_allowed(:read_internal_note, :read_crm_contacts)

          # allows some permissions that modify the issue
          expect(permissions(owner, group_issue)).to be_allowed(
            :admin_issue, :update_issue, :set_issue_metadata, :create_note, :admin_issue_relation, :award_emoji,
            :create_todo, :update_subscription, :set_confidentiality, :set_issue_crm_contacts, :set_note_created_at,
            :mark_note_as_internal, :create_timelog, :destroy_issue, :admin_note
          )

          # This group issue is actually an epic work item, and for now we only allow move and clone for:
          # Issue, Incident and Test Case, see Issue#supports_move_and_clone?
          expect(permissions(owner, group_issue)).to be_disallowed(
            :move_issue, :clone_issue
          )
        end

        it 'does not allow' do
          expect(permissions(owner, group_issue)).to be_allowed(
            :upload_issuable_metric_image, :update_issuable_metric_image, :delete_issuable_metric_image
          )

          # these read permissions are not yet defined for group level issues
          expect(permissions(owner, group_issue)).to be_disallowed(
            :read_issuable_resource_link, :read_issue_iid, :read_design,
            :create_requirement_test_report,
            :reposition_note, :create_design, :update_design, :destroy_design, :move_design,
            :admin_issuable_resource_link, :admin_timelog, :admin_issue_metrics, :admin_issue_metrics_list
          )
        end
      end
    end
  end

  context 'when work item type is epic' do
    let_it_be(:author, freeze: false) { create(:user) }
    let_it_be(:assignee, freeze: false) { create(:user) }
    let_it_be(:project, freeze: false) { create(:project, :private, group: group) }
    let_it_be(:project_epic, freeze: false) { create(:issue, :epic, project: project) }

    context 'when epics feature is available' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'allows read permissions for guest users' do
        expect(permissions(guest, project_epic)).to be_allowed(:read_issue)
      end

      context 'when project_work_item_epics feature flag is disabled' do
        before do
          stub_feature_flags(project_work_item_epics: false)
        end

        it_behaves_like 'prevents access to project-level {issues|work_items} with type Epic', :issue
      end
    end

    context 'when epics feature is not available' do
      before do
        stub_licensed_features(epics: false)
      end

      it_behaves_like 'prevents access to project-level {issues|work_items} with type Epic', :issue
    end
  end

  context 'when work item type is requirement' do
    let_it_be_with_refind(:project) { create(:project, :private, group: group) }
    let_it_be_with_refind(:requirement) { create(:work_item, :requirement, project: project) }

    before do
      stub_licensed_features(requirements: true)
    end

    it 'allows reporters to read and update the requirement' do
      expect(permissions(reporter, requirement)).to be_allowed(:read_issue, :update_issue)
    end

    context 'when the requirements project feature is disabled' do
      before do
        project.project_feature.update!(requirements_access_level: ::ProjectFeature::DISABLED)
      end

      it 'prevents reporters from reading or modifying the requirement', :aggregate_failures do
        expect(permissions(reporter, requirement)).to be_disallowed(
          :read_issue, :update_issue, :admin_issue, :destroy_issue
        )
      end

      it 'prevents guests from reading the requirement via the generic issues surface' do
        project.add_guest(guest)

        expect(permissions(guest, requirement)).to be_disallowed(:read_issue)
      end

      it 'still allows reporters to read regular issues in the same project' do
        regular_issue = build(:issue, project: project)

        expect(permissions(reporter, regular_issue)).to be_allowed(:read_issue)
      end
    end

    context 'when the requirements license is unavailable' do
      before do
        stub_licensed_features(requirements: false)
      end

      it 'prevents reporters from reading or modifying the requirement', :aggregate_failures do
        expect(permissions(reporter, requirement)).to be_disallowed(
          :read_issue, :update_issue, :admin_issue, :destroy_issue
        )
      end
    end
  end
end

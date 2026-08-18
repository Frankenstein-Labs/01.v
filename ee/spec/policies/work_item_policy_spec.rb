# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItemPolicy, feature_category: :team_planning do
  let_it_be(:admin, freeze: false) { create(:user, :admin) }
  let_it_be(:guest, freeze: false) { create(:user) }
  let_it_be(:planner, freeze: false) { create(:user) }
  let_it_be(:reporter, freeze: false) { create(:user) }
  let_it_be(:owner, freeze: false) { create(:user) }
  let_it_be(:group, freeze: false) do
    create(:group, :public).tap do |g|
      g.add_guest(guest)
      g.add_planner(planner)
      g.add_reporter(reporter)
      g.add_owner(owner)
    end
  end

  let_it_be(:project, freeze: false) { create(:project, group: group) }
  let_it_be(:support_bot, freeze: false) { create(:support_bot) }

  def permissions(user, work_item)
    described_class.new(user, work_item)
  end

  context 'when work item has a synced epic' do
    let_it_be_with_reload(:work_item) { create(:epic, :with_synced_work_item, group: group).work_item }
    let_it_be_with_reload(:confidential_work_item) do
      create(:epic, :with_synced_work_item, confidential: true, group: group).work_item
    end

    before do
      stub_licensed_features(issuable_resource_links: true, epics: true)
      allow_next_instance_of(::Gitlab::Llm::FeatureAuthorizer) do |instance|
        allow(instance).to receive(:allowed?).and_return(false)
      end
    end

    it 'does allow' do
      # allows read permissions for guest users
      expect(permissions(guest, work_item)).to be_allowed(
        :read_cross_project, :read_issue, :read_incident_management_timeline_event, :read_issuable,
        :read_issuable_participables, :read_issuable_metric_image, :read_note, :read_work_item
      )

      # allows read permissions
      expect(permissions(reporter, work_item)).to be_allowed(:read_internal_note, :read_crm_contacts, :reopen_issue)
      expect(permissions(planner, work_item)).to be_allowed(:read_internal_note, :read_crm_contacts, :reopen_issue)

      # allows some permissions that modify the issue
      expect(permissions(owner, work_item)).to be_allowed(
        :admin_issue, :update_issue, :set_issue_metadata, :create_note, :admin_issue_relation, :award_emoji,
        :create_todo, :update_subscription, :set_confidentiality, :set_issue_crm_contacts, :set_note_created_at,
        :mark_note_as_internal, :create_timelog, :destroy_issue, :admin_note
      )
    end

    it 'does not allow' do
      expect(permissions(owner, work_item)).to be_allowed(
        :upload_issuable_metric_image, :update_issuable_metric_image, :delete_issuable_metric_image
      )
      # these permissions are either not yet defined for group level issues or not allowed
      expect(permissions(owner, work_item)).to be_disallowed(
        :read_issuable_resource_link, :read_issue_iid, :read_design,
        :create_requirement_test_report,
        :reposition_note, :create_design, :update_design, :destroy_design, :move_design,
        :admin_issuable_resource_link, :admin_timelog, :admin_issue_metrics, :admin_issue_metrics_list,
        :summarize_comments
      )

      expect(permissions(owner, confidential_work_item)).to be_disallowed(:summarize_comments)
    end

    context 'when summarize_comments is authorized' do
      before do
        allow_next_instance_of(::Gitlab::Llm::FeatureAuthorizer) do |instance|
          allow(instance).to receive(:allowed?).and_return(true)
        end

        allow(group).to receive(:duo_features_enabled).and_return(true)
      end

      it 'checks the ability to summarize_comments' do
        expect(permissions(guest, work_item)).to be_allowed(:read_issue, :read_work_item, :summarize_comments)
        expect(permissions(guest, confidential_work_item)).to be_disallowed(
          :read_issue, :read_work_item, :summarize_comments
        )

        expect(permissions(owner, confidential_work_item)).to be_allowed(:summarize_comments)
      end
    end

    context 'when user is support bot and service desk is enabled' do
      before do
        allow(::Gitlab::Email::IncomingEmail).to receive_messages(enabled?: true, supports_wildcard?: true)
        allow_next_found_instance_of(Project) do |instance|
          allow(instance).to receive(:service_desk_enabled?).and_return(true)
        end
      end

      it 'allow support_bot to admin_parent_link and read work_item' do
        expect(permissions(support_bot, work_item)).to be_allowed(:admin_parent_link, :read_work_item)
      end
    end

    context 'when user is support bot and service desk is disabled' do
      it 'does not allow support_bot to admin_parent_link' do
        expect(permissions(support_bot, work_item)).to be_disallowed(:admin_parent_link)
      end
    end

    context 'when related_epics feature is available' do
      before do
        stub_licensed_features(related_epics: true, epics: true)
      end

      it 'allow linking of epic work items' do
        expect(permissions(guest, work_item)).to be_allowed(
          :admin_work_item_link
        )
      end
    end

    context 'when related_epics feature is not available' do
      before do
        stub_licensed_features(related_epics: false, epics: true)
      end

      it 'does not allow linking of epic work items' do
        expect(permissions(guest, work_item)).to be_disallowed(
          :admin_work_item_link
        )
      end
    end
  end

  context 'with move and clone permission on various work item types' do
    let_it_be(:issue, freeze: false) { create(:work_item, :issue, project: project) }
    let_it_be(:incident, freeze: false) { create(:work_item, :incident, project: project) }
    let_it_be(:test_case, freeze: false) { create(:work_item, :test_case, project: project) }
    let_it_be(:task, freeze: false) { create(:work_item, :task, project: project) }
    let_it_be(:objective, freeze: false) { create(:work_item, :objective, project: project) }
    let_it_be(:key_result, freeze: false) { create(:work_item, :key_result, project: project) }
    let_it_be(:epic, freeze: false) { create(:work_item, :epic, namespace: group) }

    it 'checks move and clone permission on work item' do
      move_and_clone_permissions = [:move_work_item, :move_issue, :clone_work_item, :clone_issue]

      expect(permissions(owner, issue)).to be_allowed(*move_and_clone_permissions)
      expect(permissions(owner, incident)).to be_allowed(*move_and_clone_permissions)
      expect(permissions(owner, test_case)).to be_allowed(*move_and_clone_permissions)

      expect(permissions(owner, task)).to be_disallowed(*move_and_clone_permissions)
      expect(permissions(owner, objective)).to be_disallowed(*move_and_clone_permissions)
      expect(permissions(owner, key_result)).to be_disallowed(*move_and_clone_permissions)
      expect(permissions(owner, epic)).to be_disallowed(*move_and_clone_permissions)
    end
  end

  context 'when work item type is epic' do
    let_it_be(:author, freeze: false) { create(:user) }
    let_it_be(:assignee, freeze: false) { create(:user) }
    let_it_be(:project_epic, freeze: false) { create(:work_item, :epic, project: project) }

    context 'when epics feature is available' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'allows read permissions for guest users' do
        expect(permissions(guest, project_epic)).to be_allowed(:read_work_item)
      end

      context 'when project_work_item_epics feature flag is disabled' do
        before do
          stub_feature_flags(project_work_item_epics: false)
        end

        it_behaves_like 'prevents access to project-level {issues|work_items} with type Epic', :work_item
      end
    end

    context 'when epics feature is not available' do
      before do
        stub_licensed_features(epics: false)
      end

      it_behaves_like 'prevents access to project-level {issues|work_items} with type Epic', :work_item
    end

    context 'with a hidden work item' do
      let(:user) { create(:user) }
      let(:banned_user) { create(:user, :banned) }
      let(:hidden_work_item) { create(:work_item, :task, project: project, author: banned_user) }

      it 'does not allow non-admin user to access or modify the work item' do
        expect(permissions(user,
          hidden_work_item)).not_to be_allowed(:read_work_item, :update_work_item, :admin_work_item)
      end

      it 'allows admin to access and modify the work item', :enable_admin_mode do
        expect(permissions(admin, hidden_work_item)).to be_allowed(:read_work_item, :update_work_item, :admin_work_item)
      end
    end
  end
end

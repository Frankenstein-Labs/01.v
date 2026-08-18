# frozen_string_literal: true

require "spec_helper"

RSpec.describe EE::WorkItemsHelper, feature_category: :team_planning do
  include Devise::Test::ControllerHelpers

  describe '#work_items_data' do
    subject(:work_items_data) { helper.work_items_data(project, current_user) }

    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- group must be persisted so group.id is non-nil and so the
    # GroupPolicy create_projects_disabled parent-association lookup in allowed_levels_for_user resolves
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:current_user) { create(:user, owner_of: project) }
    # rubocop:enable RSpec/FactoryBot/AvoidCreate

    before do
      stub_licensed_features(
        blocked_issues: feature_available,
        group_bulk_edit: feature_available
      )
      allow(helper).to receive(:can?).and_call_original
      allow(helper).to receive(:can?).with(current_user, :bulk_admin_epic, project).and_return(feature_available)
    end

    context 'when features are available' do
      let(:feature_available) { true }

      it 'returns true for the features' do
        expect(work_items_data).to include(
          {
            has_blocked_issues_feature: "true",
            has_group_bulk_edit_feature: "true",
            can_bulk_edit_epics: "true",
            group_issues_path: issues_group_path(project),
            labels_fetch_path: group_labels_path(
              project, format: :json, only_group_labels: true, include_ancestor_groups: true
            ),
            new_comment_template_paths: include({ text: "Your comment templates",
                                                  href: profile_comment_templates_path }.to_json),
            epics_list_path: group_epics_path(project)
          })
      end

      context "when gitlab_com_subscriptions is available" do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
        end

        context "when project has parent group" do
          it 'returns the correct new trial path' do
            expect(group.id).not_to be_nil
            expect(work_items_data).to include(new_trial_path: new_trial_path(namespace_id: group.id))
          end
        end

        context "when project is in a personal namespace" do
          let_it_be(:project) { build(:project, :in_user_namespace, owners: current_user) }

          it 'returns the correct new trial path' do
            expect(work_items_data).to include(new_trial_path: new_trial_path(namespace_id: nil))
          end
        end
      end
    end

    context 'when feature not available' do
      let(:feature_available) { false }

      it 'returns false for the features' do
        expect(work_items_data).to include(
          {
            has_blocked_issues_feature: "false",
            has_group_bulk_edit_feature: "false"
          }
        )
      end

      context "when gitlab_com_subscriptions is unavailable" do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'returns the correct new trial path' do
          expect(helper).to respond_to(:self_managed_new_trial_url)
          allow(helper).to receive(:self_managed_new_trial_url).and_return('subscription_portal_trial_url')
          expect(helper.work_items_data(project, current_user)).to include(
            { new_trial_path: "subscription_portal_trial_url" }
          )
        end
      end
    end
  end

  describe '#add_work_item_show_breadcrumb' do
    subject(:add_work_item_show_breadcrumb) { helper.add_work_item_show_breadcrumb(resource_parent, work_item.iid) }

    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Needed for querying the work item type
    let_it_be(:resource_parent) { create(:group) }

    context 'when an epic' do
      let(:work_item) { create(:work_item, :epic, namespace: resource_parent) }

      it 'adds the correct breadcrumb' do
        expect(helper).to receive(:add_to_breadcrumbs).with('Epics', group_epics_path(resource_parent))

        add_work_item_show_breadcrumb
      end
    end
    # rubocop:enable RSpec/FactoryBot/AvoidCreate
  end
end

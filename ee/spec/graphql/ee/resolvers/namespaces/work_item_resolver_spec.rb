# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'EE::Resolvers::Namespaces::WorkItemResolver', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user, developer_of: group) }

  before_all do
    group.add_developer(current_user)
  end

  def resolve_work_item(obj, args = {})
    resolve(Resolvers::Namespaces::WorkItemResolver, obj: obj, args: args,
      ctx: { current_user: current_user }, arg_style: :internal)
  end

  describe 'recent_services_map' do
    context 'when epics are enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'maps epic base type to RecentEpics service' do
        expect(Resolvers::Namespaces::WorkItemResolver.recent_services_map['epic'])
          .to eq(::Gitlab::Search::RecentEpics)
      end

      it 'includes FOSS mappings' do
        expect(Resolvers::Namespaces::WorkItemResolver.recent_services_map['issue'])
          .to eq(::Gitlab::Search::RecentIssues)
      end
    end
  end

  describe 'Epic WorkItem recent view logging' do
    let(:namespace) { group }

    context 'when epics are enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'with an Epic WorkItem that has synced_epic' do
        let_it_be(:work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
        let_it_be(:epic) { work_item.synced_epic }

        it 'logs the Epic to both RecentEpics and RecentWorkItems' do
          recent_epics_service = instance_double(::Gitlab::Search::RecentEpics)
          recent_work_items_service = instance_double(::Gitlab::Search::RecentWorkItems)

          expect(::Gitlab::Search::RecentEpics).to receive(:new).with(user: current_user)
            .and_return(recent_epics_service)
          expect(::Gitlab::Search::RecentWorkItems).to receive(:new).with(user: current_user)
            .and_return(recent_work_items_service)

          expect(recent_epics_service).to receive(:log_view).with(epic)
          expect(recent_work_items_service).to receive(:log_view).with(work_item)

          result = resolve_work_item(namespace, { iid: work_item.iid.to_s })

          expect(result).to eq(work_item)
        end

        it 'does not log the WorkItem to RecentEpics' do
          recent_epics_service = instance_double(::Gitlab::Search::RecentEpics)
          expect(::Gitlab::Search::RecentEpics).to receive(:new).with(user: current_user)
            .and_return(recent_epics_service)
          expect(recent_epics_service).not_to receive(:log_view).with(work_item)
          expect(recent_epics_service).to receive(:log_view).with(epic)

          resolve_work_item(namespace, { iid: work_item.iid.to_s })
        end
      end

      context 'with an Epic WorkItem without synced_epic (edge case)' do
        let_it_be(:epic_work_item) { create(:work_item, :epic, namespace: group) }

        before do
          # Simulate Epic WorkItem without synced_epic (e.g., Epic creation failed)
          allow(epic_work_item).to receive(:synced_epic).and_return(nil)
        end

        it 'falls back to FOSS behavior, logs WorkItem to RecentEpics, but does not crash' do
          # Falls back to super (FOSS), but FOSS still has access to EE services_map
          # So it will try to log the WorkItem (not Epic model) to RecentEpics
          recent_epics_service = instance_double(::Gitlab::Search::RecentEpics)
          expect(::Gitlab::Search::RecentEpics).to receive(:new).with(user: current_user)
            .and_return(recent_epics_service)
          expect(recent_epics_service).to receive(:log_view).with(epic_work_item)

          result = resolve_work_item(namespace, { iid: epic_work_item.iid.to_s })

          expect(result).to eq(epic_work_item)
        end
      end

      context 'with non-Epic WorkItems (delegation to parent)' do
        let_it_be(:project) { create(:project, group: group) }
        let_it_be(:issue_work_item) { create(:work_item, :issue, project: project) }

        before_all do
          project.add_developer(current_user)
        end

        it 'delegates to FOSS implementation for Issues' do
          recent_issues_service = instance_double(::Gitlab::Search::RecentIssues)
          expect(::Gitlab::Search::RecentIssues).to receive(:new).with(user: current_user)
            .and_return(recent_issues_service)
          expect(recent_issues_service).to receive(:log_view).with(issue_work_item)

          # Should not touch RecentEpics
          expect(::Gitlab::Search::RecentEpics).not_to receive(:new)

          result = resolve_work_item(project.project_namespace, { iid: issue_work_item.iid.to_s })

          expect(result).to eq(issue_work_item)
        end

        context 'with unsupported WorkItem types' do
          let_it_be(:task_work_item) { create(:work_item, :task, project: project) }

          it 'delegates to FOSS and does not log anything' do
            expect(::Gitlab::Search::RecentIssues).not_to receive(:new)
            expect(::Gitlab::Search::RecentEpics).not_to receive(:new)

            result = resolve_work_item(project.project_namespace, { iid: task_work_item.iid.to_s })

            expect(result).to eq(task_work_item)
          end
        end
      end
    end

    context 'when epics are disabled' do
      let_it_be(:epic_work_item) { create(:work_item, :epic, namespace: group) }

      before do
        stub_licensed_features(epics: false)
      end

      it 'does not return the Epic WorkItem' do
        result = resolve_work_item(namespace, { iid: epic_work_item.iid.to_s })

        expect(result).to be_nil
      end

      it 'does not attempt recent view logging' do
        expect(::Gitlab::Search::RecentEpics).not_to receive(:new)

        resolve_work_item(namespace, { iid: epic_work_item.iid.to_s })
      end
    end

    context 'when current_user is nil' do
      let_it_be(:work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

      before do
        stub_licensed_features(epics: true)
      end

      it 'returns the Epic WorkItem but does not log recent view' do
        expect(::Gitlab::Search::RecentEpics).not_to receive(:new)

        result = resolve(Resolvers::Namespaces::WorkItemResolver, obj: namespace,
          args: { iid: work_item.iid.to_s }, ctx: { current_user: nil })

        expect(result).to eq(work_item)
      end
    end
  end
end

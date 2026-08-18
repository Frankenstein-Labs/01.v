# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IssuablesHelper, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }

  describe '#issuable_initial_data' do
    let(:permission) { true }

    before do
      allow(helper).to receive(:current_user).and_return(user)
      allow(helper).to receive(:can?).and_return(permission)
      stub_commonmark_sourcepos_disabled
    end

    context 'for an issue' do
      let(:issue) { create(:issue, author: user, description: 'issue text') }

      before do
        allow(issue.project).to receive(:licensed_feature_available?).and_return(true)
      end

      it 'returns the correct data' do
        @project = issue.project

        expected_data = {
          canAdmin: true,
          canAdminRelation: true,
          hasIssueWeightsFeature: true,
          hasIterationsFeature: true,
          hasStatusFeature: false,
          publishedIncidentUrl: nil
        }
        expect(helper.issuable_initial_data(issue)).to include(expected_data)
      end

      context 'when custom status is available' do
        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, group: group) }
        let(:issue) { create(:issue, author: user, project: project) }

        before do
          stub_licensed_features(work_item_status: true)
        end

        it 'returns the correct data' do
          @project = issue.project

          expect(helper.issuable_initial_data(issue)).to include({
            hasStatusFeature: true
          })
        end
      end

      context 'when published to a configured status page' do
        it 'returns the correct data that includes publishedIncidentUrl' do
          @project = issue.project

          expect(Gitlab::StatusPage::Storage).to receive(:details_url).with(issue).and_return('http://status.com')
          expect(helper.issuable_initial_data(issue)).to include(
            publishedIncidentUrl: 'http://status.com'
          )
        end
      end

      describe '#promotedToEpicUrl' do
        let(:issue) { create(:issue, author: user) }
        let(:epic) { create(:epic, author: user) }

        before do
          assign(:project, issue.project)
        end

        context 'when issue is promoted' do
          let(:issue) { create(:issue, promoted_to_epic: epic, author: user) }

          it 'returns url' do
            expect(helper.issuable_initial_data(issue)[:promotedToEpicUrl]).to eq(group_epic_url(epic.group, epic))
          end
        end

        context 'when issue is not promoted' do
          it 'returns nil' do
            expect(helper.issuable_initial_data(issue)[:promotedToEpicUrl]).to be_nil
          end
        end
      end
    end

    context 'for an incident' do
      let_it_be(:issue) { create(:issue, :incident, author: user, description: 'issue text') }

      let(:params) do
        ActionController::Parameters.new({
          controller: "projects/issues",
          action: "show",
          namespace_id: "foo",
          project_id: "bar",
          id: issue.iid,
          incident_tab: 'timeline'
        }).permit!
      end

      before do
        allow(helper).to receive(:safe_params).and_return(params)
      end

      context 'default state' do
        it 'returns the correct data' do
          @project = issue.project

          expect(helper.issuable_initial_data(issue)).to include(uploadMetricsFeatureAvailable: "false")
          expect(helper.issuable_initial_data(issue)).to include(canUpdateTimelineEvent: permission)
        end
      end

      context 'when incident metric upload is available' do
        before do
          stub_licensed_features(incident_metric_upload: true)
        end

        it 'correctly returns uploadMetricsFeatureAvailable as true' do
          @project = issue.project

          expect(helper.issuable_initial_data(issue)).to include(uploadMetricsFeatureAvailable: "true")
        end
      end
    end
  end

  describe '#new_comment_template_paths' do
    let_it_be(:group) { create(:group) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    context 'when user does not have permission' do
      before do
        allow(helper).to receive(:can?).with(user, :create_saved_replies, group).and_return(false)
      end

      it { expect(helper.new_comment_template_paths(group).size).to eq(1) }
    end

    context 'when user has permission' do
      before do
        allow(helper).to receive(:can?).with(user, :create_saved_replies, group).and_return(true)
      end

      it 'returns array with group comment templates path' do
        expect(helper.new_comment_template_paths(group).size).to eq(2)
        expect(helper.new_comment_template_paths(group).last).to eq({
          text: "Group comment templates",
          href: group_comment_templates_path(group)
        })
      end
    end

    context 'with project' do
      let_it_be(:project) { create(:project) }

      context 'when user does not have permission' do
        before do
          allow(helper).to receive(:can?).with(user, :create_saved_replies, group).and_return(false)
          allow(helper).to receive(:can?).with(user, :create_saved_replies, project).and_return(false)
        end

        it { expect(helper.new_comment_template_paths(group, project).size).to eq(1) }
      end

      context 'when user has permission' do
        before do
          allow(helper).to receive(:can?).with(user, :create_saved_replies, group).and_return(true)
          allow(helper).to receive(:can?).with(user, :create_saved_replies, project).and_return(true)
        end

        it 'returns array with project comment templates path' do
          expect(helper.new_comment_template_paths(group, project).size).to eq(3)
          expect(helper.new_comment_template_paths(group, project)).to include({
            text: "Project comment templates",
            href: project_comment_templates_path(project)
          })
        end
      end
    end
  end
end

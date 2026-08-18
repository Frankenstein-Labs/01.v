# frozen_string_literal: true

require "spec_helper"

RSpec.describe EE::IssuesHelper, feature_category: :team_planning do
  let_it_be(:group) { create :group }
  let_it_be(:project) { create :project, group: group }
  let_it_be(:issue) { create :issue, project: project }

  describe '#show_timeline_view_toggle?' do
    subject { helper.show_timeline_view_toggle?(issue) }

    it { is_expected.to be_falsy }

    context 'issue is an incident' do
      let(:issue) { build_stubbed(:incident) }

      it { is_expected.to be_falsy }

      context 'with license' do
        before do
          stub_licensed_features(incident_timeline_view: true)
        end

        it { is_expected.to be_truthy }

        context 'when issue is created at the group level' do
          let(:issue) { build_stubbed(:issue, :incident, :group_level) }

          it { is_expected.to be_truthy }
        end

        context 'when issue is created at the user namespace level' do
          let(:issue) { build_stubbed(:issue, :incident, :user_namespace_level) }

          it { is_expected.to be_truthy }
        end
      end
    end
  end

  describe '#dashboard_issues_list_data' do
    let(:current_user) { double.as_null_object }

    before do
      allow(helper).to receive(:current_user).and_return(current_user)
      allow(helper).to receive(:image_path).and_return('#')
      allow(helper).to receive(:url_for).and_return('#')
    end

    context 'when features are enabled' do
      before do
        stub_licensed_features(
          blocked_issues: true,
          issuable_health_status: true,
          issue_weights: true,
          okrs: true,
          quality_management: true,
          scoped_labels: true
        )
      end

      it 'returns data with licensed features enabled' do
        expected = {
          has_blocked_issues_feature: 'true',
          has_issuable_health_status_feature: 'true',
          has_issue_weights_feature: 'true',
          has_okrs_feature: 'true',
          has_quality_management_feature: 'true',
          has_scoped_labels_feature: 'true'
        }

        expect(helper.dashboard_issues_list_data(current_user)).to include(expected)
      end

      it 'does not include duo_remote_flows_availability for dashboard' do
        result = helper.dashboard_issues_list_data(current_user)

        expect(result).not_to include(:duo_remote_flows_availability)
      end
    end

    context 'when features are disabled' do
      before do
        stub_licensed_features(
          blocked_issues: false,
          issuable_health_status: false,
          issue_weights: false,
          okrs: false,
          quality_management: false,
          scoped_labels: false
        )
      end

      it 'returns data with licensed features disabled' do
        expected = {
          has_blocked_issues_feature: 'false',
          has_issuable_health_status_feature: 'false',
          has_issue_weights_feature: 'false',
          has_okrs_feature: 'false',
          has_quality_management_feature: 'false',
          has_scoped_labels_feature: 'false'
        }

        expect(helper.dashboard_issues_list_data(current_user)).to include(expected)
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::HookData::IssueBuilder, feature_category: :webhooks do
  let_it_be(:issue) { create(:issue) }

  let(:builder) { described_class.new(issue) }

  describe '#build' do
    subject(:data) { builder.build }

    it 'includes safe attribute' do
      %w[
        assignee_id
        author_id
        closed_at
        confidential
        created_at
        description
        due_date
        start_date
        id
        iid
        last_edited_at
        last_edited_by_id
        milestone_id
        moved_to_id
        project_id
        relative_position
        state_id
        time_estimate
        title
        updated_at
        updated_by_id
        weight
        health_status
      ].each do |key|
        expect(data).to include(key)
      end
    end

    context 'when the issue has an image in the description' do
      let(:issue_with_description) { create(:issue, description: 'test![Issue_Image](/uploads/abc/Issue_Image.png)') }
      let(:builder) { described_class.new(issue_with_description) }

      it 'sets the image to use an absolute URL' do
        expected_path = "-/project/#{issue_with_description.project.id}/uploads/abc/Issue_Image.png)"
        expect(data[:description]).to eq("test![Issue_Image](#{Settings.gitlab.url}/#{expected_path}")
      end
    end

    context 'for incident with escalation policies feature enabled' do
      let_it_be(:issue) { create(:incident, :with_escalation_status) }

      before do
        stub_licensed_features(oncall_schedules: true, escalation_policies: true)
      end

      it { is_expected.to include(:escalation_policy) }
    end

    context "when current status exists" do
      let_it_be(:group) { create(:group) }
      let_it_be_with_reload(:issue) { create(:work_item, namespace: group) }

      context "when the licence is disabled" do
        before do
          stub_licensed_features(work_item_status: false)
        end

        it { is_expected.not_to include(:status) }
      end

      context "when the license exists" do
        before do
          stub_licensed_features(work_item_status: true)
        end

        it { is_expected.to include(:status) }
      end

      context "when status with callback is nil" do
        let_it_be_with_reload(:issue) { create(:incident, namespace: group) }

        it { is_expected.not_to include(:status) }
      end
    end
  end
end

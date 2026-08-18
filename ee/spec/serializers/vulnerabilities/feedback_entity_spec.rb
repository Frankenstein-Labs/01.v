# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::FeedbackEntity, feature_category: :vulnerability_management do
  # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Requires persisted records for permissions and URL generation
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project) }
  # rubocop:enable RSpec/FactoryBot/AvoidCreate

  let(:request) { double('request') }
  let(:entity) { described_class.represent(feedback, request: request) }

  subject { entity.as_json }

  before do
    allow(request).to receive(:current_user).and_return(user)
  end

  describe '#as_json' do
    let(:feedback) { build_stubbed(:vulnerability_feedback, :issue, project: project) }

    it { is_expected.to include(:created_at, :project_id, :author, :category, :feedback_type) }

    context 'when feedback type is issue' do
      context 'when issue is present' do
        it 'exposes the issue iid' do
          is_expected.to include(:issue_iid)
        end

        context 'when user can view issues' do
          before do
            project.add_developer(user)
          end

          it 'exposes issue url' do
            is_expected.to include(:issue_url)
          end
        end

        context 'when user cannot view issues' do
          it 'does not expose issue url' do
            is_expected.not_to include(:issue_url)
          end
        end
      end

      context 'when there is no current user' do
        before do
          allow(request).to receive(:current_user).and_return(nil)
          allow(feedback).to receive(:author).and_return(nil)
        end

        it 'does not include fields related to current user' do
          is_expected.not_to include(:issue_url)
          is_expected.not_to include(:merge_request_path)
        end
      end

      context 'when issue is not present' do
        it 'does not expose issue information' do
          feedback.issue = nil

          is_expected.not_to include(:issue_iid)
          is_expected.not_to include(:issue_url)
        end
      end
    end

    context 'when feedback type is merge_request' do
      let(:feedback) { build_stubbed(:vulnerability_feedback, :merge_request, project: project) }

      context 'when merge request is present' do
        it 'exposes the merge request iid' do
          is_expected.to include(:merge_request_iid)
        end

        context 'when user can view merge requests' do
          before do
            project.add_developer(user)
          end

          it 'exposes merge request url' do
            is_expected.to include(:merge_request_path)
          end
        end

        context 'when user cannot view merge requests' do
          it 'does not expose merge request url' do
            is_expected.not_to include(:merge_request_path)
          end
        end
      end

      context 'when merge request is not present' do
        it 'does not expose merge request information' do
          feedback.merge_request = nil

          is_expected.not_to include(:merge_request_iid)
          is_expected.not_to include(:merge_request_path)
        end
      end
    end
  end

  context 'when comment is not present' do
    let(:feedback) { build_stubbed(:vulnerability_feedback, :dismissal, project: project) }

    it { is_expected.not_to include(:comment_details) }
  end

  context 'when comment is present' do
    let(:feedback) { build_stubbed(:vulnerability_feedback, :comment, project: project) }

    it 'exposes comment information' do
      expect(subject).to include(:comment_details)
      expect(subject[:comment_details]).to include(:comment)
      expect(subject[:comment_details]).to include(:comment_timestamp)
      expect(subject[:comment_details]).to include(:comment_author)
    end
  end

  context 'when finding_uuid is not present' do
    let(:feedback) { build_stubbed(:vulnerability_feedback, :issue, project: project, finding_uuid: nil) }

    it 'has a nil finding_uuid' do
      expect(subject[:finding_uuid]).to be_nil
    end
  end

  context 'when finding_uuid is present' do
    let(:finding) { build_stubbed(:vulnerabilities_finding) }
    let(:feedback) { build_stubbed(:vulnerability_feedback, finding_uuid: finding.uuid, project: project) }

    it 'exposes finding_uuid' do
      expect(subject[:finding_uuid]).to eq(finding.uuid)
    end
  end

  context 'when dismissal_reason is not present' do
    let(:feedback) { build_stubbed(:vulnerability_feedback, :issue, project: project) }

    it "returns nil" do
      expect(subject[:dismissal_reason]).to be_nil
    end
  end

  context 'when dismissal_reason is present' do
    let(:feedback) { build_stubbed(:vulnerability_feedback, :dismissal, project: project) }

    it 'exposes dismissal_reason' do
      expect(subject[:dismissal_reason]).to eq(feedback.dismissal_reason)
    end
  end

  context 'when issue is a group-level work item' do
    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Requires persisted records for URL generation and permissions
    let_it_be(:group) { create(:group) }
    let_it_be(:group_user) { create(:user, developer_of: [group, project]) }
    let_it_be(:group_issue) { create(:issue, :group_level, namespace: group) }
    let_it_be(:feedback) { create(:vulnerability_feedback, :issue, project: project, issue: group_issue) }
    # rubocop:enable RSpec/FactoryBot/AvoidCreate

    let(:request) { double('request') }
    let(:entity) { described_class.represent(feedback, request: request) }

    subject { entity.as_json }

    before do
      project.update!(group: group)
      allow(request).to receive(:current_user).and_return(group_user)
      stub_licensed_features(epics: true)
    end

    context 'when user can view the issue' do
      it 'generates issue_url without raising error' do
        expect { subject[:issue_url] }.not_to raise_error
      end

      it 'exposes issue_url with group-level path' do
        expect(subject[:issue_url]).to match(
          %r{/groups/#{Regexp.escape(group.full_path)}/-/work_items/#{group_issue.iid}}
        )
      end
    end
  end
end

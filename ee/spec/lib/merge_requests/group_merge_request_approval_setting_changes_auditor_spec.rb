# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::GroupMergeRequestApprovalSettingChangesAuditor, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  context 'when group_merge_request_approval_setting is created' do
    let(:params) do
      { allow_author_approval: false,
        allow_committer_approval: false,
        allow_overrides_to_approver_list_per_merge_request: false,
        retain_approvals_on_push: false,
        require_reauthentication_to_approve: true,
        require_password_to_approve: true }
    end

    let(:approval_setting) { create(:group_merge_request_approval_setting, group: group, **params) }

    subject(:auditor) { described_class.new(user, approval_setting, params) }

    it 'creates audit events' do
      expect { auditor.execute }.to change { AuditEventReader.count }.by(6)

      events = AuditEventReader.last(6).map { |e| e.details[:custom_message] }

      expect(events.sort)
        .to match_array ["Changed prevent merge request approval from committers from false to true",
          "Changed prevent users from modifying MR approval rules in merge requests " \
            "from false to true",
          "Changed prevent merge request approval from authors from false to true",
          "Changed require new approvals when new commits are added to an MR from false to true",
          "Changed require user authentication for approvals from false to true",
          "Changed require user password for approvals from false to true"].sort
    end
  end

  context 'when group_merge_request_approval_setting is updated' do
    let_it_be(:approval_setting, freeze: false) do
      create(
        :group_merge_request_approval_setting,
        group: group,
        allow_author_approval: false,
        allow_committer_approval: false,
        allow_overrides_to_approver_list_per_merge_request: false,
        retain_approvals_on_push: false,
        require_reauthentication_to_approve: false,
        require_password_to_approve: false
      )
    end

    let_it_be(:auditor) { described_class.new(user, approval_setting, {}) }

    ::GroupMergeRequestApprovalSetting::AUDIT_LOG_ALLOWLIST.each do |column, desc|
      it "creates an audit event for #{column}", quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/467630' do
        approval_setting.update_attribute(column, true)

        if column == :require_password_to_approve || column == :require_reauthentication_to_approve
          # both values should be kept in sync
          expect { auditor.execute }.to change { AuditEventReader.count }.by(2)

          last_two = AuditEventReader.last(2)
          reauth = last_two.detect do |event|
            event.details[:event_name] == "require_reauthentication_to_approve_updated"
          end
          password = last_two.detect { |event| event.details[:event_name] == "require_password_to_approve_updated" }
          if column == :require_reauthentication_to_approve
            expect(reauth.details).to include({ change: desc, from: false, to: true })
          else
            expect(password.details).to include({ change: desc, from: false, to: true })
          end
        else
          expect(::Gitlab::Audit::Auditor)
            .to receive(:audit).with(hash_including({ name: "#{column}_updated" })).and_call_original

          expect { auditor.execute }.to change { AuditEventReader.count }.by(1)
          expect(AuditEventReader.last.details).to include({ change: desc, from: true, to: false })
        end
      end
    end
  end
end

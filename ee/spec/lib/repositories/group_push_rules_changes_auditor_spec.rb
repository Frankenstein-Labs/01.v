# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Repositories::GroupPushRulesChangesAuditor, feature_category: :source_code_management do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:current_user) { create(:user, owner_of: group) }

  let(:push_rule) { group.build_group_push_rule }

  before do
    stub_licensed_features(audit_events: true, external_audit_events: true)
    create(:audit_events_group_external_streaming_destination, group: group)
  end

  subject(:changes_auditor) { described_class.new(current_user, push_rule) }

  context 'when auditing group-level changes in push rules' do
    using RSpec::Parameterized::TableSyntax

    # rubocop:disable Layout/LineLength
    where(:key, :old_value, :new_value, :event_name) do
      :commit_committer_check        | false      | true                | 'group_push_rules_commit_committer_check_updated'
      :commit_committer_check        | true       | false               | 'group_push_rules_commit_committer_check_updated'
      :reject_unsigned_commits       | false      | true                | 'group_push_rules_reject_unsigned_commits_updated'
      :reject_unsigned_commits       | true       | false               | 'group_push_rules_reject_unsigned_commits_updated'
      :deny_delete_tag               | false      | true                | 'group_push_rules_reject_deny_delete_tag_updated'
      :deny_delete_tag               | true       | false               | 'group_push_rules_reject_deny_delete_tag_updated'
      :member_check                  | false      | true                | 'group_push_rules_reject_member_check_updated'
      :member_check                  | true       | false               | 'group_push_rules_reject_member_check_updated'
      :prevent_secrets               | false      | true                | 'group_push_rules_prevent_secrets_updated'
      :prevent_secrets               | true       | false               | 'group_push_rules_prevent_secrets_updated'
      :branch_name_regex             | nil        | "\\Asecurity-.*\\z" | 'group_push_rules_branch_name_regex_updated'
      :branch_name_regex             | ".*\\w{2}" | "\\Asecurity-.*\\z" | 'group_push_rules_branch_name_regex_updated'
      :commit_message_regex          | nil        | "\\Asecurity-.*\\z" | 'group_push_rules_commit_message_regex_updated'
      :commit_message_regex          | ".*\\w{2}" | "\\Asecurity-.*\\z" | 'group_push_rules_commit_message_regex_updated'
      :commit_message_negative_regex | nil        | "\\Asecurity-.*\\z" | 'group_push_rules_commit_message_negative_regex_updated'
      :commit_message_negative_regex | ".*\\w{2}" | "\\Asecurity-.*\\z" | 'group_push_rules_commit_message_negative_regex_updated'
      :author_email_regex            | nil        | "\\Asecurity-.*\\z" | 'group_push_rules_author_email_regex_updated'
      :author_email_regex            | ".*\\w{2}" | "\\Asecurity-.*\\z" | 'group_push_rules_author_email_regex_updated'
      :file_name_regex               | nil        | "\\Asecurity-.*\\z" | 'group_push_rules_file_name_regex_updated'
      :file_name_regex               | ".*\\w{2}" | "\\Asecurity-.*\\z" | 'group_push_rules_file_name_regex_updated'
      :max_file_size                 | 0          | 132                 | 'group_push_rules_max_file_size_updated'
      :max_file_size                 | 12         | 42                  | 'group_push_rules_max_file_size_updated'
    end
    # rubocop:enable Layout/LineLength

    with_them do
      before do
        push_rule.update!(key => old_value)
        push_rule.update!(key => new_value)
      end

      it 'audits the change in push rule correctly', :aggregate_failures do
        expect do
          changes_auditor.execute
        end.to change { AuditEventReader.count }.by(1)

        event = AuditEventReader.last

        expect(event.author).to eq(current_user)
        expect(event.details[:change]).to eq(::GroupPushRule::AUDIT_LOG_ALLOWLIST[key])
        expect(event.details[:from]).to eq(old_value)
        expect(event.details[:to]).to eq(new_value)
        expect(event.entity).to eq(group)
      end

      it 'streams correct audit event', :aggregate_failures do
        expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async)
          .with(event_name, anything, anything)
        changes_auditor.execute
      end
    end
  end

  context 'for EVENT_TYPE_PER_ATTR' do
    it 'defines audit event types for all the audit log allowlist attributes for group push rule changes' do
      expect(
        GroupPushRule::AUDIT_LOG_ALLOWLIST.keys -
          ::Repositories::GroupPushRulesChangesAuditor::EVENT_TYPE_PER_ATTR.keys
      ).to be_empty
    end
  end
end

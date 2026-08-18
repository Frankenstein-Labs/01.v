# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::SyncCodeOwnerApprovalRules, feature_category: :code_review_workflow do
  let_it_be_with_reload(:merge_request) { create(:merge_request) }
  let_it_be(:rb_owners) { create_list(:user, 2) }
  let_it_be(:doc_owners) { create_list(:user, 2) }
  let(:rb_role_approvers) { [Gitlab::Access::DEVELOPER] }
  let(:rb_role_approvers_text) { '@@developer' }
  let(:doc_role_approvers) { [Gitlab::Access::DEVELOPER, Gitlab::Access::MAINTAINER] }
  let(:doc_role_approvers_text) { '@@developer @@maintainer' }
  let_it_be(:rb_group_owners) { create_list(:group, 2) }
  let_it_be(:doc_group_owners) { create_list(:group, 2) }
  let_it_be(:rb_approvals_required) { 2 }
  let_it_be(:doc_approvals_required) { 3 }

  let(:rb_entry) do
    build_entry('*.rb', rb_owners, rb_group_owners, rb_role_approvers_text, 'codeowners', rb_approvals_required)
  end

  let(:doc_entry) do
    build_entry('doc/*', doc_owners, doc_group_owners, doc_role_approvers_text, 'codeowners', doc_approvals_required)
  end

  let(:entries) { [rb_entry, doc_entry] }
  let(:params) { {} }

  def build_entry(pattern, users, groups, roles, section = Gitlab::CodeOwners::Section::DEFAULT, approvals_required = 0)
    text = "#{(users + groups).map(&:to_reference).join(' ')} #{roles}"
    entry = Gitlab::CodeOwners::Entry.new(pattern, text, section: section, optional: false,
      approvals_required: approvals_required)

    entry.add_matching_users_from(users)
    entry.add_matching_groups_from(groups)

    entry
  end

  def verify_correct_code_owners
    [
      [rb_entry, rb_owners, rb_group_owners, rb_role_approvers, rb_approvals_required],
      [doc_entry, doc_owners, doc_group_owners, doc_role_approvers, doc_approvals_required]
    ].each do |entry, users, groups, role_approvers|
      rule = merge_request.approval_rules.code_owner.find_by(name: entry.pattern, section: entry.section)

      expect(rule.users).to match_array(users)
      expect(rule.groups).to match_array(groups)
      expect(rule.role_approvers).to match_array(role_approvers)
    end
  end

  subject(:service) { described_class.new(merge_request, **params) }

  describe '#execute' do
    before do
      allow(Gitlab::CodeOwners)
        .to receive(:entries_for_merge_request).with(merge_request, merge_request_diff: nil)
              .and_return(entries)
    end

    it 'creates rules for code owner entries that do not have a rule' do
      expect { service.execute }.to change { merge_request.approval_rules.count }.by(2)

      verify_correct_code_owners
    end

    it 'deletes rules that are not relevant anymore' do
      other_rule = create(:code_owner_rule, merge_request: merge_request)

      service.execute

      expect(merge_request.approval_rules).not_to include(other_rule)
      expect { other_rule.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'when an outdated rule has the same pattern as the section' do
      let(:entries) { [section_code_owner_rule] }
      let(:section_code_owner_rule) { build_entry('*', rb_owners, rb_group_owners, '', 'Rb owners') }

      it 'deletes rules that are not relevant anymore' do
        default_section_rule = create(:code_owner_rule, merge_request: merge_request, name: '*')

        service.execute

        new_approval_rule = merge_request.approval_rules.first
        expect(new_approval_rule.name).to eq('*')
        expect(new_approval_rule.section).to eq('Rb owners')

        expect(merge_request.approval_rules.count).to eq(1)
        expect { default_section_rule.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    it 'updates rules for which the users changed' do
      other_rule = create(:code_owner_rule, merge_request: merge_request, name: '*.rb')
      other_rule.users += doc_owners
      other_rule.groups += doc_group_owners
      other_rule.approvals_required += doc_approvals_required
      other_rule.save!

      service.execute

      expect(other_rule.reload.users).to match_array(rb_owners)
      expect(other_rule.reload.groups).to match_array(rb_group_owners)
      expect(other_rule.reload.approvals_required).to eq(rb_approvals_required)
    end

    context 'when multiple rules for the same pattern with different sections are specified' do
      let(:rb_entry) { build_entry('doc/', rb_owners, rb_group_owners, rb_role_approvers_text, 'Rb owners') }
      let(:doc_entry) { build_entry('doc/', doc_owners, doc_group_owners, doc_role_approvers_text, 'Doc owners') }

      it 'creates and updates the rules that are mapped to the entries' do
        expect { service.execute }.to change { merge_request.approval_rules.count }.by(2)

        verify_correct_code_owners

        service.execute

        verify_correct_code_owners
      end
    end

    context 'when merge request is already merged' do
      let(:merge_request) { build(:merge_request, :merged) }

      it 'logs an error' do
        expect(Gitlab::ErrorTracking)
          .to receive(:track_exception)
          .with(
            instance_of(described_class::AlreadyMergedError),
            hash_including(
              merge_request_id: merge_request.id,
              merge_request_iid: merge_request.iid,
              project_id: merge_request.project_id
            )
          ).and_call_original

        expect(service.execute).to be_nil
      end
    end
  end

  context 'when given param expire_unapproved_key is not present' do
    it 'does not expire the unapproved key for the MR' do
      merge_request.approval_state.temporarily_unapprove!
      expect(merge_request.temporarily_unapproved?).to be_truthy

      service.execute

      expect(merge_request.temporarily_unapproved?).to be_truthy
    end
  end

  context 'when given param expire_unapproved_key is true' do
    let(:params) { { expire_unapproved_key: true } }

    it 'expires the unapproved key for the MR' do
      merge_request.approval_state.temporarily_unapprove!
      expect(merge_request.temporarily_unapproved?).to be_truthy

      service.execute

      expect(merge_request.temporarily_unapproved?).to be_falsey
    end

    it_behaves_like 'triggers GraphQL subscription mergeRequestMergeStatusUpdated' do
      let(:action) { service.execute }
    end

    it_behaves_like 'triggers GraphQL subscription mergeRequestApprovalStateUpdated' do
      let(:action) { service.execute }
    end
  end
end

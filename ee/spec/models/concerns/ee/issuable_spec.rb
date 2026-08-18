# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Issuable, feature_category: :team_planning do
  describe "Validation" do
    context 'general validations' do
      subject { build(:epic) }

      before do
        allow(InternalId).to receive(:generate_next).and_return(nil)
      end

      it { is_expected.to validate_presence_of(:author) }
      it { is_expected.to validate_presence_of(:title) }
      it { is_expected.to validate_length_of(:title).is_at_most(::Issuable::TITLE_LENGTH_MAX) }

      it_behaves_like 'validates description length with custom validation' do
        before do
          allow(InternalId).to receive(:generate_next).and_call_original
        end
      end

      it_behaves_like 'truncates the description to its allowed maximum length on import'
    end
  end

  describe '#matches_cross_reference_regex?' do
    context "epic description with long path string" do
      let(:mentionable) { build(:epic, description: "/a" * 50000) }

      it_behaves_like 'matches_cross_reference_regex? fails fast'
    end
  end

  describe '#supports_epic?' do
    let(:group) { build_stubbed(:group) }
    let(:project_with_group) { build_stubbed(:project, group: group) }
    let(:project_without_group) { build_stubbed(:project) }

    where(:issuable_type, :project, :supports_epic) do
      [
        [:issue, :project_with_group, true],
        [:issue, :project_without_group, false],
        [:incident, :project_with_group, false],
        [:incident, :project_without_group, false],
        [:merge_request, :project_with_group, false],
        [:merge_request, :project_without_group, false]
      ]
    end

    with_them do
      let(:issuable) { build_stubbed(issuable_type, project: send(project)) }

      subject { issuable.supports_epic? }

      it { is_expected.to eq(supports_epic) }
    end
  end

  describe '#weight_available?' do
    let(:group) { build_stubbed(:group) }
    let(:project_with_group) { build_stubbed(:project, group: group) }
    let(:project_without_group) { build_stubbed(:project) }

    where(:issuable_type, :project, :weight_available) do
      [
        [:issue, :project_with_group, true],
        [:issue, :project_without_group, true],
        [:incident, :project_with_group, false],
        [:incident, :project_without_group, false],
        [:merge_request, :project_with_group, false],
        [:merge_request, :project_without_group, false]
      ]
    end

    with_them do
      let(:issuable) { build_stubbed(issuable_type, project: send(project)) }

      subject { issuable.weight_available? }

      it { is_expected.to eq(weight_available) }
    end
  end

  describe '#supports_iterations?' do
    let(:group) { build_stubbed(:group) }
    let(:project_with_group) { build_stubbed(:project, group: group) }
    let(:project_without_group) { build_stubbed(:project) }

    where(:issuable_type, :project, :supports_iterations) do
      [
        [:issue, :project_with_group, true],
        [:issue, :project_without_group, true],
        [:incident, :project_with_group, true],
        [:incident, :project_without_group, true],
        [:merge_request, :project_with_group, false],
        [:merge_request, :project_without_group, false]
      ]
    end

    with_them do
      let(:issuable) { build_stubbed(issuable_type, project: send(project)) }

      subject { issuable.supports_iterations? }

      it { is_expected.to eq(supports_iterations) }
    end
  end

  describe '#supports_confidentiality?' do
    let(:issuable) { build_stubbed(:epic) }

    subject { issuable.supports_confidentiality? }

    it { is_expected.to be_truthy }
  end

  describe '#sla_available?' do
    where(issuable_type: [:merge_request, :epic])

    with_them do
      it 'returns false unless overridden in child class' do
        issuable = build_stubbed(issuable_type)

        expect(issuable.sla_available?).to be_falsey
      end
    end
  end

  describe '#escalation_policies_available?' do
    where(:issuable_type, :oncall_schedules_enabled, :escalation_policies_enabled, :available) do
      [
        [:issue, true, true, false],
        [:incident, false, false, false],
        [:incident, true, false, false],
        [:incident, false, true, false],
        [:incident, true, true, true]
      ]
    end

    with_them do
      let(:issuable) { build_stubbed(issuable_type) }

      before do
        stub_licensed_features(oncall_schedules: oncall_schedules_enabled, escalation_policies: escalation_policies_enabled)
      end

      subject { issuable.escalation_policies_available? }

      it { is_expected.to eq(available) }
    end
  end

  describe '#to_hook_data' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project) }
    let_it_be(:escalation_policy) { create(:incident_management_escalation_policy, project: project) }

    let(:builder) { double }

    context 'escalation status is updated' do
      let(:issue) { create(:incident, :with_escalation_status) }
      let(:policy_changes) { { policy: escalation_policy, escalations_started_at: Time.current } }
      let(:status_changes) { {} }
      let(:old_associations) { { escalation_status: :triggered, escalation_policy: nil } }
      let(:expected_policy_hash) { { 'id' => escalation_policy.id, 'name' => escalation_policy.name } }

      before do
        stub_licensed_features(oncall_schedules: true, escalation_policies: true)

        issue.escalation_status.update!(**policy_changes, **status_changes)

        expect(Gitlab::DataBuilder::Issuable).to receive(:new).with(issue).and_return(builder)
      end

      it 'delegates to Gitlab::DataBuilder::Issuable#build' do
        expect(builder).to receive(:build).with(
          user: user,
          changes: hash_including(
            'escalation_policy' => [nil, expected_policy_hash]
          ),
          action: 'open',
          actioned_at: nil
        )

        issue.to_hook_data(user, old_associations: old_associations, action: 'open')
      end

      context 'with policy and status changes' do
        let(:status_changes) { { status: IncidentManagement::IssuableEscalationStatus::STATUSES[:acknowledged] } }

        it 'includes both status and policy fields simultaneously' do
          expect(builder).to receive(:build).with(
            user: user,
            changes: hash_including(
              'escalation_status' => %i[triggered acknowledged],
              'escalation_policy' => [nil, expected_policy_hash]
            ),
            action: 'open',
            actioned_at: nil
          )

          issue.to_hook_data(user, old_associations: old_associations, action: 'open')
        end
      end
    end

    context "with status changes" do
      let_it_be_with_reload(:project) { create(:project, group: group) }
      let(:old_associations) { { status: old_status } }

      before do
        stub_licensed_features(work_item_status: true)
        expect(Gitlab::DataBuilder::Issuable).to receive(:new).with(issue).and_return(builder)
      end

      shared_examples "builder has status changes" do
        it 'includes status fields' do
          expect(builder).to receive(:build).with(
            user: user,
            changes: hash_including(
              'status' => [old_status.hook_attrs, new_status.hook_attrs]
            ),
            action: 'open',
            actioned_at: nil
          )

          issue.to_hook_data(user, old_associations: old_associations, action: 'open')
        end
      end

      shared_examples "builder does not have status changes" do
        it 'does not include status fields' do
          expect(builder).to receive(:build).with(
            user: user,
            changes: hash_excluding(
              'status' => [old_status.hook_attrs, new_status.hook_attrs]
            ),
            action: 'open',
            actioned_at: nil
          )

          issue.to_hook_data(user, old_associations: old_associations, action: 'open')
        end
      end

      context "with system defined statuses" do
        let(:old_status) { build_stubbed(:work_item_system_defined_status, :to_do) }
        let(:new_status) { build_stubbed(:work_item_system_defined_status, :in_progress) }
        let(:issue) { create(:work_item, project: project) }

        context "when status changes" do
          before do
            current_status = issue.build_current_status
            current_status.status = new_status
            current_status.save!
          end

          it_behaves_like "builder has status changes"

          context "when old_associations status is nil" do
            let(:old_associations) { nil }

            it_behaves_like "builder does not have status changes"
          end
        end

        context "when status is unchanged" do
          it_behaves_like "builder does not have status changes"
        end

        context "with feature flag disabled" do
          before do
            stub_licensed_features(work_item_status: false)
          end

          it_behaves_like "builder does not have status changes"
        end
      end

      context "with custom statuses" do
        let_it_be_with_reload(:project) { create(:project, group: group) }

        let(:issue) { create(:work_item, :task, project: project) }
        let!(:custom_lifecycle) do
          lifecycle = create(:work_item_custom_lifecycle, namespace: group)
          lifecycle.work_item_types |= [issue.work_item_type]
          lifecycle.save!
          lifecycle
        end

        let(:old_status) { custom_lifecycle.default_open_status }
        let(:new_status) { custom_lifecycle.default_closed_status }

        context "when status changes" do
          before do
            current_status = issue.build_current_status
            current_status.status = new_status
            current_status.save!
          end

          it_behaves_like "builder has status changes"
          context "when old_associations status is nil" do
            let(:old_associations) { nil }

            it_behaves_like "builder does not have status changes"
          end
        end

        context "when status is unchanged" do
          it_behaves_like "builder does not have status changes"
        end
      end
    end

    context 'approval rules webhook payload' do
      let_it_be(:merge_request) { create(:merge_request, source_project: project) }
      let_it_be(:approval_rule) { create(:approval_merge_request_rule, merge_request: merge_request) }

      before do
        stub_licensed_features(merge_request_approvers: true)
      end

      context 'when MR is updated without changing approval rules' do
        it 'does not include false approval rule changes' do
          # Capture current approval rules state (simulating what IssuableBaseService does)
          current_approval_rules = merge_request.approval_rules.map(&:hook_attrs)

          expect(Gitlab::DataBuilder::Issuable).to receive(:new).with(merge_request).and_return(builder)
          expect(builder).to receive(:build).with(
            user: user,
            changes: hash_excluding('approval_rules'),
            action: 'update',
            actioned_at: nil
          )

          merge_request.to_hook_data(
            user,
            old_associations: { approval_rules: current_approval_rules },
            action: 'update'
          )
        end
      end
    end

    context 'when approval_rules missing from old_associations (fallback scenario)' do
      let_it_be(:merge_request) { create(:merge_request, source_project: project) }
      let_it_be(:approval_rule) { create(:approval_merge_request_rule, merge_request: merge_request) }

      before do
        stub_licensed_features(merge_request_approvers: true)
      end

      it 'falls back to current approval_rules hook_attrs without showing false changes' do
        # This directly tests the old_approval_rules method fix
        # Before fix: would return approval_rules (ActiveRecord proxy)
        # After fix: returns approval_rules.map(&:hook_attrs) (array of hook attributes)

        # Call hook_association_changes with empty old_associations
        changes = merge_request.send(:hook_association_changes, {})

        # When :approval_rules is missing from old_associations, the fallback uses current approval_rules
        # Since old (fallback) and current are the same, there should be no change
        expect(changes).not_to have_key('approval_rules')
      end
    end
  end

  describe '#allows_scoped_labels?' do
    let_it_be(:project) { build_stubbed(:project) }

    it 'allows scoped labels with licensed project' do
      issue = build_stubbed(:issue, project: project)

      stub_licensed_features(scoped_labels: true)

      expect(issue.allows_scoped_labels?).to be(true)
    end

    it 'allows scoped labels with licensed group' do
      epic = build_stubbed(:epic, group: build_stubbed(:group))

      stub_licensed_features(scoped_labels: true)

      expect(epic.allows_scoped_labels?).to be(true)
    end

    it 'does not allow scoped labels without license' do
      issue = build_stubbed(:issue, project: project)

      stub_licensed_features(scoped_labels: false)

      expect(issue.allows_scoped_labels?).to be(false)
    end
  end

  describe '#issuable_resource_links_available?' do
    let_it_be(:project) { build_stubbed(:project) }

    it 'returns false for issuable type as issue' do
      issue = build_stubbed(:issue, project: project)

      stub_licensed_features(issuable_resource_links: true)

      expect(issue.issuable_resource_links_available?).to be(false)
    end

    it 'returns true for issuable type as incident' do
      issue = build_stubbed(:incident, project: project)

      stub_licensed_features(issuable_resource_links: true)

      expect(issue.issuable_resource_links_available?).to be(true)
    end

    it 'returns false when feature is not avaiable' do
      issue = build_stubbed(:incident, project: project)

      stub_licensed_features(issuable_resource_links: false)

      expect(issue.issuable_resource_links_available?).to be(false)
    end
  end

  context 'with exportable associations' do
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:project) { create(:project, group: group) }

    context 'for issues' do
      let_it_be_with_reload(:resource) { create(:issue, project: project) }
      let_it_be(:epic_issue) { create(:epic_issue, issue: resource, epic: create(:epic, group: group)) }

      it_behaves_like 'an exportable', restricted_association: :epic_issue
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Note, feature_category: :team_planning do
  include ::EE::GeoHelpers

  it_behaves_like 'an editable mentionable with EE-specific mentions' do
    subject { create :note, noteable: issue, project: issue.project }

    let(:issue) { create(:issue, project: create(:project, :repository)) }
    let(:backref_text) { issue.gfm_reference }
    let(:set_mentionable_text) { ->(txt) { subject.note = txt } }
  end

  describe 'associations' do
    it 'has many `duo_workflow_links`' do
      is_expected.to have_many(:duo_workflow_links)
        .class_name('Ai::DuoWorkflows::WorkflowNote').with_foreign_key(:note_id)
        .inverse_of(:note)
    end

    it { is_expected.to have_many(:linked_duo_workflows).through(:duo_workflow_links).source(:workflow) }

    it 'has one `duo_created_workflow_link`' do
      is_expected.to have_one(:duo_created_workflow_link)
        .class_name('Ai::DuoWorkflows::WorkflowNote').with_foreign_key(:note_id)
        .inverse_of(:note)
    end

    it '`duo_created_workflow_link` returns the link for the flow that created the note' do
      note = create(:note)
      workflow = create(:duo_workflows_workflow, project: note.project)
      Ai::DuoWorkflows::WorkflowNote.ensure_link(workflow: workflow, artifact: note, link_type: :created)

      expect(note.duo_created_workflow_link.workflow_id).to eq(workflow.id)
    end
  end

  describe 'validation' do
    describe 'confidentiality' do
      context 'for a new note' do
        let(:note_params) { { confidential: true, noteable: noteable, project: noteable.project } }

        subject(:note) { build(:note, **note_params) }

        context 'when noteable is a epic' do
          let_it_be(:noteable) { create(:epic) }

          it 'can not be set confidential' do
            expect(note).to be_valid
          end
        end
      end
    end
  end

  describe 'callbacks' do
    describe '#touch_noteable' do
      it 'calls #touch on the noteable' do
        noteable = create(:issue)
        note = build(:note, project: noteable.project, noteable: noteable)

        expect(note).to receive(:touch_noteable).and_call_original
        expect(note.noteable).to receive(:touch)

        note.save!
      end

      context 'when noteable is an epic' do
        let_it_be(:noteable) { create(:epic) }
        let(:note) { build(:note, project: nil, noteable: noteable) }
        let(:noteable_association) { note.association(:noteable) }

        before do
          allow(noteable_association).to receive(:loaded?).and_return(object_loaded)
          allow(note).to receive(:touch_noteable).and_call_original
        end

        context 'when noteable is loaded' do
          let(:object_loaded) { true }

          it 'calls #touch and #sync_work_item_updated_at on the noteable' do
            expect(note.noteable).to receive(:touch)
            expect(note.noteable).to receive(:sync_work_item_updated_at)

            note.save!
          end
        end

        context 'when noteable is not loaded' do
          let(:object_loaded) { false }

          it 'calls #touch and #sync_work_item_updated_at on the noteable' do
            expect_any_instance_of(::Epic) do |epic|
              expect(epic).to receive(:touch)
              expect(epic).to receive(:sync_work_item_updated_at)
            end

            note.save!
          end
        end
      end
    end
  end

  describe '#ensure_namespace_id' do
    context 'for an epic note' do
      let_it_be_with_reload(:epic) { create(:epic) }

      it 'copies the group_id of the epic' do
        note = build(:note, noteable: epic, project: nil)

        note.valid?

        expect(note.namespace_id).to eq(epic.group_id)
      end

      context 'when noteable is changed' do
        let_it_be(:another_epic) { create(:epic) }

        it 'updates the namespace_id' do
          note = create(:note, noteable: epic, project: nil)

          note.noteable = another_epic
          note.valid?

          expect(note.namespace_id).to eq(another_epic.group_id)
        end
      end
    end

    context 'for a group wiki page note' do
      it 'keeps namespace_id set from the noteable', :aggregate_failures do
        note = build(:note, :on_group_level_wiki)

        note.valid?

        expect(note.namespace_id).to eq(note.noteable.namespace_id)
        expect(note.project_id).to be_nil
      end
    end
  end

  describe '#readable_by?' do
    let(:owner) { create(:group_member, :owner, group: group, user: create(:user)).user }
    let(:guest) { create(:group_member, :guest, group: group, user: create(:user)).user }
    let(:reporter) { create(:group_member, :reporter, group: group, user: create(:user)).user }
    let(:maintainer) { create(:group_member, :maintainer, group: group, user: create(:user)).user }
    let(:non_member) { create(:user) }

    let(:group) { create(:group, :public) }
    let(:epic) { create(:epic, group: group, author: owner, created_at: 1.day.ago) }

    before do
      stub_licensed_features(epics: true)
    end

    context 'note created after epic' do
      let(:note) { create(:system_note, noteable: epic, created_at: 1.minute.ago) }

      it_behaves_like 'users with note access' do
        let(:users) { [owner, reporter, maintainer, guest, non_member, nil] }
      end

      context 'when group is private' do
        let(:group) { create(:group, :private) }

        it_behaves_like 'users with note access' do
          let(:users) { [owner, reporter, maintainer, guest] }
        end

        it 'returns visible but not readable for a non-member user' do
          expect(note.system_note_visible_for?(non_member)).to be_truthy
          expect(note.readable_by?(non_member)).to be_falsy
        end

        it 'returns visible but not readable for a nil user' do
          expect(note.system_note_visible_for?(nil)).to be_truthy
          expect(note.readable_by?(nil)).to be_falsy
        end
      end
    end

    context 'when note is older than epic' do
      let(:note) { create(:system_note, noteable: epic, created_at: 2.days.ago) }

      it_behaves_like 'users with note access' do
        let(:users) { [owner, reporter, maintainer] }
      end

      it_behaves_like 'users without note access' do
        let(:users) { [guest, non_member, nil] }
      end

      context 'when group is private' do
        let(:group) { create(:group, :private) }

        it_behaves_like 'users with note access' do
          let(:users) { [owner, reporter, maintainer] }
        end

        it_behaves_like 'users without note access' do
          let(:users) { [guest, non_member, nil] }
        end
      end
    end
  end

  describe '#system_note_with_references?' do
    [:relate_epic, :unrelate_epic].each do |type|
      it "delegates #{type} system note to the cross-reference regex" do
        note = create(:note, :system)
        create(:system_note_metadata, note: note, action: type)

        expect(note).to receive(:matches_cross_reference_regex?).and_return(false)

        note.system_note_with_references?
      end
    end
  end

  describe '#resource_parent' do
    it 'returns group for epic notes' do
      group = create(:group)
      note = create(:note_on_epic, noteable: create(:epic, group: group))

      expect(note.resource_parent).to eq(group)
    end
  end

  describe '.by_humans' do
    it 'excludes notes by bots and service users' do
      user_note = create(:note)
      create(:system_note)
      create(:note, author: create(:user, :bot))
      create(:note, author: create(:user, :service_user))

      expect(described_class.by_humans).to match_array([user_note])
    end
  end

  describe '.count_for_vulnerability_id' do
    it 'counts notes by vulnerability id' do
      vulnerability_1 = create(:vulnerability)
      vulnerability_2 = create(:vulnerability)

      create(:note, noteable: vulnerability_1, project: vulnerability_1.project)
      create(:note, noteable: vulnerability_2, project: vulnerability_2.project)
      create(:note, noteable: vulnerability_2, project: vulnerability_2.project)

      expect(described_class.count_for_vulnerability_id([vulnerability_1.id,
        vulnerability_2.id])).to eq(vulnerability_1.id => 1, vulnerability_2.id => 2)
    end
  end

  describe '#skip_notification?' do
    subject(:skip_notification?) { note.skip_notification? }

    context 'when there is no review' do
      context 'when the note is not for vulnerability' do
        let(:note) { build(:note) }

        it { is_expected.to be_falsey }
      end

      context 'when the note is for vulnerability' do
        let(:note) { build(:note, :on_vulnerability) }

        it { is_expected.to be_truthy }
      end
    end

    context 'when the review exists' do
      context 'when the note is not for vulnerability' do
        let(:note) { build(:note, :with_review) }

        it { is_expected.to be_truthy }
      end

      context 'when the note is for vulnerability' do
        let(:note) { build(:note, :with_review, :on_vulnerability) }

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '#updated_by_or_author' do
    subject(:updated_by_or_author) { note.updated_by_or_author }

    context 'when updated_by is nil' do
      let(:note) { create(:note, updated_by: nil) }

      it 'returns the author' do
        expect(updated_by_or_author).to be(note.author)
      end
    end

    context 'when updated_by is present' do
      let(:user) { create(:user) }
      let(:note) { create(:note, updated_by: user) }

      it 'returns the last user who updated the note' do
        expect(updated_by_or_author).to be(user)
      end
    end
  end

  describe '#for_group_wiki?' do
    it 'returns true for a group-level wiki page' do
      expect(build_stubbed(:note_on_wiki_page, :on_group_level_wiki).for_group_wiki?).to be_truthy
    end

    it 'returns false for a project-level wiki page' do
      expect(build_stubbed(:note_on_wiki_page, :on_project_level_wiki).for_group_wiki?).to be_falsy
    end
  end

  describe '.note_starting_with' do
    it 'returns a note matching the prefix' do
      create(:note)
      create(:note, note: 'non-matching prefix note')
      create(:note, note: 'non-matching')
      matching_note = create(:note, note: 'prefix note')

      expect(described_class.note_starting_with('prefix')).to contain_exactly(matching_note)
    end
  end

  describe 'elasticsearch indexing', :elastic, feature_category: :global_search do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:work_item) { create(:work_item, project: project) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
      allow(Elastic::ProcessBookkeepingService).to receive(:track!)
    end

    describe '#maintain_elasticsearch_create' do
      context "when a note is created" do
        it 'always calls track for the note and the noteable on work items' do
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).twice

          create(:note, noteable: work_item, project: project, note: 'Some pig')
        end

        it 'calls track for only the note on a merge request' do
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).once

          create(:note, noteable: merge_request, project: project, note: 'Some pig')
        end
      end
    end

    describe '#maintain_elasticsearch_destroy' do
      context "when a note is destroyed" do
        it 'calls track for the note and the noteable on work items' do
          delete_note = create(:note, noteable: work_item, project: project, note: 'Some pig')

          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(delete_note)
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(delete_note.noteable)

          delete_note.destroy!
        end

        it 'calls track for notes on merge requests' do
          mr_note = create(:note, noteable: merge_request, project: project, note: 'Some pig')

          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(mr_note)
          expect(Elastic::ProcessBookkeepingService).not_to receive(:track!).with(mr_note.noteable)

          mr_note.destroy!
        end
      end
    end

    describe '#maintain_elasticsearch_update' do
      context 'when an elastic tracked field is updated' do
        it 'invokes maintain_elasticsearch_update and calls track for the note and the notable' do
          work_item_note = create(:note, noteable: work_item, project: project, note: 'Some pig')

          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(work_item_note)
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(work_item_note.noteable)

          work_item_note.update!(note: 'Terrific')
        end

        it 'calls track for the note on merge requests' do
          mr_note = create(:discussion_note_on_merge_request, noteable: merge_request,
            project: project, note: 'Some pig')

          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(mr_note)
          expect(Elastic::ProcessBookkeepingService).not_to receive(:track!).with(mr_note.noteable)

          mr_note.update!(note: 'Hello')
        end
      end

      context 'when a non-elastic field is updated' do
        it 'calls track for the note only on work items' do
          work_item_note = create(:note, noteable: work_item, project: project, note: 'Some pig')

          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(work_item_note)
          expect(work_item_note.noteable).not_to receive(:maintain_elasticsearch_update)

          work_item_note.update!(updated_at: Time.zone.now)
        end
      end

      it 'invokes maintain_elasticsearch_update callback' do
        work_item_note = create(:note, noteable: work_item, project: project, note: 'Some pig')
        expect(work_item_note).to receive(:maintain_elasticsearch_update).once

        work_item_note.update!(note: 'Terrific')
      end
    end
  end

  context 'with loose foreign key on dast_pre_scan_verifications.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:vulnerability) }
      let_it_be(:model) { create(:note, noteable: parent, project: parent.project) }
    end
  end

  describe '#authored_by_duo_bot?' do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
    let_it_be(:note) do
      create(
        :diff_note_on_merge_request,
        noteable: merge_request,
        project: project,
        author: ::Users::Internal.in_organization(project.organization_id).duo_code_review_bot
      )
    end

    subject(:authored_by_duo_bot?) { note.authored_by_duo_bot? }

    it 'returns true' do
      expect(authored_by_duo_bot?).to be(true)
    end

    context 'when author is not GitLab Duo' do
      before do
        allow(note).to receive(:author).and_return(project.creator)
      end

      it 'returns false' do
        expect(authored_by_duo_bot?).to be(false)
      end
    end
  end

  describe '#duo_bot_mentioned?' do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
    let_it_be(:author) { create(:user) }
    let_it_be(:duo_code_review_bot) { Users::Internal.in_organization(project.organization_id).duo_code_review_bot }

    let(:note) do
      create(
        :diff_note_on_merge_request,
        noteable: merge_request,
        project: project,
        note: "@#{duo_code_review_bot.username} Hello!",
        author: author
      )
    end

    subject(:duo_bot_mentioned?) { note.duo_bot_mentioned? }

    it 'returns true' do
      expect(duo_bot_mentioned?).to be(true)
    end

    context 'when note is authored by GitLab Duo' do
      let(:author) { duo_code_review_bot }

      it 'returns false' do
        expect(duo_bot_mentioned?).to be(false)
      end
    end

    context 'when note does not mention GitLab Duo' do
      let(:note) do
        create(
          :diff_note_on_merge_request,
          noteable: merge_request,
          project: project
        )
      end

      it 'returns false' do
        expect(duo_bot_mentioned?).to be(false)
      end
    end
  end

  describe '#human_max_access' do
    let_it_be(:user) { create(:user) }

    subject { note.human_max_access }

    context 'when parent is a group' do
      let_it_be(:group) { create(:group) }
      let(:noteable) { create(:wiki_page_meta, container: group) }
      let(:note) { create(:note, author: user, noteable: noteable, namespace: group, project: nil) }

      before_all do
        group.add_owner(user)
      end

      it { is_expected.to be('Owner') }
    end
  end

  describe '#noteable_ability_name' do
    it 'returns compliance_violations_report for a compliance violation note' do
      expect(build(:note_on_compliance_violation).noteable_ability_name).to eq('compliance_violations_report')
    end
  end

  describe 'compliance violation note subscriptions' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be_with_reload(:violation) do
      create(:project_compliance_violation, project: project, namespace: project.namespace)
    end

    describe '#trigger_note_subscription?' do
      it 'returns true for compliance violation notes' do
        note = build(:note, noteable: violation, project: project)

        expect(note.send(:trigger_note_subscription?)).to be(true)
      end
    end

    describe '#trigger_note_subscription_create' do
      it 'triggers work_item_note_created subscription for compliance violation notes' do
        note = build(:note, noteable: violation, project: project)

        expect(GraphqlTriggers).to receive(:work_item_note_created).with(violation.to_global_id, note)

        note.send(:trigger_note_subscription_create)
      end
    end

    describe '#trigger_note_subscription_update' do
      it 'triggers work_item_note_updated subscription for compliance violation notes' do
        note = create(:note, noteable: violation, project: project)

        expect(GraphqlTriggers).to receive(:work_item_note_updated).with(violation.to_global_id, note)

        note.send(:trigger_note_subscription_update)
      end
    end

    describe '#trigger_note_subscription_destroy' do
      it 'triggers work_item_note_deleted subscription for compliance violation notes' do
        note = create(:note, noteable: violation, project: project)
        expected_data = {
          id: note.id,
          model_name: 'Note',
          discussion_id: note.discussion_id,
          last_discussion_note: true
        }

        expect(GraphqlTriggers).to receive(:work_item_note_deleted).with(violation.to_global_id, expected_data)

        note.send(:trigger_note_subscription_destroy)
      end
    end
  end

  describe '.with_noteable_type' do
    let_it_be(:issue) { create(:issue, project: create(:project)) }
    let_it_be_with_reload(:epic) { create(:epic) }

    let_it_be(:note1) { create(:note, noteable: issue, project: issue.project) }
    let_it_be_with_reload(:note2) { create(:note, noteable: epic, project: nil) }

    subject { described_class.with_noteable_type(noteable_type) }

    context 'when noteable_type matches some notes' do
      let(:noteable_type) { 'Issue' }

      it { is_expected.to contain_exactly(note1) }
    end

    context 'when noteable_type matches no notes' do
      let(:noteable_type) { 'MergeRequest' }

      it { is_expected.to be_empty }
    end
  end

  describe '.with_noteable_ids' do
    let_it_be(:issue1) { create(:issue, project: create(:project)) }
    let_it_be(:issue2) { create(:issue, project: create(:project)) }

    let_it_be(:note1) { create(:note, noteable: issue1, project: issue1.project) }
    let_it_be_with_reload(:note2) { create(:note, noteable: issue2, project: issue2.project) }
    let_it_be_with_reload(:note3) { create(:note, noteable: issue2, project: issue2.project) }

    subject { described_class.with_noteable_ids(ids) }

    context 'when some ids match notes' do
      let(:ids) { [issue2.id] }

      it { is_expected.to contain_exactly(note2, note3) }
    end

    context 'when no ids match notes' do
      let(:ids) { [9999] }

      it { is_expected.to be_empty }
    end
  end

  describe '.distinct_on_noteable_id' do
    let_it_be(:issue) { create(:issue, project: create(:project)) }
    let_it_be(:note1) { create(:note, noteable: issue, project: issue.project, created_at: 2.days.ago) }
    let_it_be_with_reload(:note2) { create(:note, noteable: issue, project: issue.project, created_at: 1.day.ago) }
    # Making sure epic id doesn't match issue id
    let_it_be_with_reload(:epic) do
      create(:epic, id: non_existing_record_id)
    end

    let_it_be_with_reload(:note3) { create(:note, noteable: epic, project: nil) }

    subject(:distinct_notes) { described_class.distinct_on_noteable_id }

    it 'returns one note per noteable_id' do
      noteable_ids = distinct_notes.map(&:noteable_id)

      expect(noteable_ids).to contain_exactly(issue.id, epic.id)
    end

    it 'returns any one note for noteable_id' do
      notes_for_issue = distinct_notes.select { |note| note.noteable_id == issue.id }

      expect(notes_for_issue.size).to eq(1)
      expect([note1.id, note2.id]).to include(notes_for_issue.first.id)
    end
  end

  describe '.order_by_noteable_latest_first' do
    let_it_be(:issue) { create(:issue, project: create(:project)) }
    let_it_be(:note1) { create(:note, noteable: issue, project: issue.project, created_at: 3.days.ago) }
    let_it_be_with_reload(:note2) { create(:note, noteable: issue, project: issue.project, created_at: 1.day.ago) }
    let_it_be_with_reload(:note3) { create(:note, noteable: issue, project: issue.project, created_at: 1.day.ago) }

    subject(:ordered_notes) { described_class.order_by_noteable_latest_first }

    it 'orders notes by noteable_id ascending and created_at descending' do
      expect(ordered_notes).to eq([note3, note2, note1])
    end
  end

  describe '.inc_relations_for_view', feature_category: :duo_agent_platform do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:issue) { create(:issue, project: project) }
    let_it_be(:note) { create(:note, project: project, noteable: issue) }
    let_it_be(:workflow) { create(:duo_workflows_workflow, project: project) }
    let_it_be(:duo_metadata) { create(:note_duo_metadata, note: note, workflow_id: workflow.id, namespace: group) }

    it 'preloads duo_metadata to avoid N+1 queries' do
      loaded_notes = issue.notes.inc_relations_for_view(issue).to_a

      expect { loaded_notes.map { |n| n.duo_metadata&.workflow_id } }
        .not_to exceed_query_limit(0).for_model(Notes::NoteDuoMetadata)
    end

    it 'preloads workflow to avoid N+1 queries' do
      loaded_notes = issue.notes.inc_relations_for_view(issue).to_a

      expect { loaded_notes.map { |n| n.duo_metadata&.workflow&.id } }
        .not_to exceed_query_limit(0).for_model(Ai::DuoWorkflows::Workflow)
    end

    it 'preloads duo_created_workflow_link to avoid N+1 queries' do
      linked_note = create(:note, project: project, noteable: issue)
      Ai::DuoWorkflows::WorkflowNote.ensure_link(workflow: workflow, artifact: linked_note, link_type: :created)

      loaded_notes = issue.notes.inc_relations_for_view(issue).to_a

      expect { loaded_notes.map { |n| n.duo_created_workflow_link&.workflow_id } }
        .not_to exceed_query_limit(0).for_model(Ai::DuoWorkflows::WorkflowNote)
    end

    it 'preloads the linked workflow to avoid N+1 queries' do
      linked_note = create(:note, project: project, noteable: issue)
      Ai::DuoWorkflows::WorkflowNote.ensure_link(workflow: workflow, artifact: linked_note, link_type: :created)

      loaded_notes = issue.notes.inc_relations_for_view(issue).to_a

      expect { loaded_notes.map { |n| n.duo_created_workflow_link&.workflow } }
        .not_to exceed_query_limit(0).for_model(Ai::DuoWorkflows::Workflow)
    end
  end
end

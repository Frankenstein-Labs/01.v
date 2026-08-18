# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::SystemNotes::IssuablesService, feature_category: :team_planning do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be_with_reload(:author) { create(:user) }
  let_it_be_with_reload(:epic) { create(:epic, group: group) }
  let_it_be_with_reload(:issue1) { create(:issue, project: project) }
  let_it_be_with_reload(:issue2) { create(:issue, project: project) }
  let_it_be_with_reload(:noteable) { create(:issue, project: project, health_status: 'on_track') }

  let(:service) { described_class.new(noteable: noteable, container: project, author: author) }

  describe '#duo_mention_started' do
    let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: author) }
    let(:note) { create(:note, noteable: noteable, project: project) }

    subject(:duo_mention_started) do
      described_class
        .new(noteable: noteable, container: project, author: author)
        .duo_mention_started(workflow, note.discussion)
    end

    shared_examples 'a duo mention started note' do
      it 'creates a system reply in the discussion with the session link', :aggregate_failures do
        expect(duo_mention_started.note).to include("session #{workflow.id}")
        expect(duo_mention_started.discussion_id).to eq(note.discussion_id)
        expect(duo_mention_started).to be_system
      end

      it 'sets the system_note_metadata action to duo_mention_started' do
        expect(duo_mention_started.system_note_metadata.action).to eq('duo_mention_started')
      end

      it 'builds a NoteDuoMetadata record linking the note to the workflow', :aggregate_failures do
        expect(duo_mention_started.duo_metadata.workflow_id).to eq(workflow.id)
        expect(duo_mention_started.duo_metadata.namespace_id).to eq(project.namespace_id)
      end
    end

    context 'when the noteable is an issue' do
      it_behaves_like 'a duo mention started note'
    end

    context 'when the noteable is a merge request' do
      let_it_be(:noteable) { create(:merge_request, source_project: project, target_project: project) }

      it_behaves_like 'a duo mention started note'
    end

    context 'when the noteable is a work item' do
      let_it_be(:noteable) { create(:work_item, project: project) }

      it_behaves_like 'a duo mention started note'
    end
  end

  describe '#change_health_status_note' do
    subject { service.change_health_status_note(noteable.health_status_before_last_save) }

    context 'when health_status changed' do
      before do
        noteable.update!(health_status: 'at_risk')
      end

      it_behaves_like 'a system note' do
        let(:action) { 'health_status' }
      end

      it 'sets the note text' do
        expect(subject.note).to eq "changed health status to **at risk**"
      end
    end

    context 'when health_status removed' do
      before do
        noteable.update!(health_status: nil)
      end

      it_behaves_like 'a system note' do
        let(:action) { 'health_status' }
      end

      it 'sets the note text' do
        expect(subject.note).to eq 'removed health status **on track**'
      end
    end

    describe 'events tracking', :snowplow do
      it 'tracks the issue event in usage ping' do
        expect(Gitlab::UsageDataCounters::IssueActivityUniqueCounter).to receive(:track_issue_health_status_changed_action)
                                                                           .with(author: author, project: project)

        subject
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { Gitlab::UsageDataCounters::IssueActivityUniqueCounter::ISSUE_HEALTH_STATUS_CHANGED }
        let(:user) { author }
        let(:namespace) { project.namespace }
      end
    end
  end

  describe "#change_custom_field_number_type_note" do
    let(:custom_field) { build(:custom_field, field_type: :number) }
    let(:previous_value) { 2 }
    let(:value) { 5 }

    subject { service.change_custom_field_number_type_note(custom_field, previous_value: previous_value, value: value) }

    it_behaves_like 'a system note', skip_persistence_check: true do
      let(:action) { "custom_field" }
    end

    context "when the value is set" do
      let(:previous_value) { nil }
      let(:value) { 5 }

      it 'sets the note text' do
        note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">5</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when a value is removed" do
      let(:previous_value) { 2 }
      let(:value) { nil }

      it 'sets the note text' do
        note_text = "<p>removed #{custom_field.name}: <code class=\"idiff\">2</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when value is a decimal" do
      context "when there are unnecessary zeros" do
        let(:previous_value) { nil }
        let(:value) { 5.0 }

        it 'strips unnecessary zeros' do
          note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">5</code></p>"
          expect(subject.note).to eq note_text
        end
      end

      context "when there are no unnecessary zeros" do
        let(:previous_value) { nil }
        let(:value) { 5.5 }

        it 'strips unnecessary zeros' do
          note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">5.5</code></p>"
          expect(subject.note).to eq note_text
        end
      end
    end
  end

  describe "#change_custom_field_text_type_note" do
    let(:custom_field) { build(:custom_field, field_type: :number) }
    let(:previous_value) { "previous text" }
    let(:value) { "new text" }

    subject { service.change_custom_field_text_type_note(custom_field, previous_value: previous_value, value: value) }

    it_behaves_like 'a system note', skip_persistence_check: true do
      let(:action) { "custom_field" }
    end

    context "when the value is set" do
      let(:previous_value) { nil }
      let(:value) { "new text" }

      it 'sets the note text' do
        note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">#{value}</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when a value is removed" do
      let(:previous_value) { "previous text" }
      let(:value) { nil }

      it 'sets the note text' do
        note_text = "<p>removed #{custom_field.name}: <code class=\"idiff\">#{previous_value}</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when the value has extra spaces" do
      let(:previous_value) { nil }
      let(:value) { "text  " }

      it 'strips the unnecessary spaces' do
        note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">text</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when the value contains html characters" do
      let(:previous_value) { nil }
      let(:value) { "<b>text</b>" }

      it 'escape the html characters' do
        note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">&lt;b&gt;text&lt;/b&gt;</code></p>"
        expect(subject.note).to eq note_text
      end
    end
  end

  describe "#change_custom_field_select_type_note" do
    let(:custom_field) { build(:custom_field, field_type: :multi_select) }
    let(:previous_options) { [] }
    let(:new_options) { ["red"] }

    subject { service.change_custom_field_select_type_note(custom_field, previous_options: previous_options, new_options: new_options) }

    it_behaves_like 'a system note', skip_persistence_check: true do
      let(:action) { "custom_field" }
    end

    context "when there is only 1 added options" do
      let(:previous_options) { [] }
      let(:new_options) { ["red"] }

      it 'sets the note text' do
        note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">red</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when there are multiple added options" do
      let(:previous_options) { [] }
      let(:new_options) { %w[red black] }

      it 'sets the note text' do
        note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">red, black</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when there is only 1 removed option" do
      let(:previous_options) { ["red"] }
      let(:new_options) { [] }

      it 'sets the note text' do
        note_text = "<p>removed #{custom_field.name}: <code class=\"idiff\">red</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when there are multiple removed options" do
      let(:previous_options) { %w[red black] }
      let(:new_options) { [] }

      it 'sets the note text' do
        note_text = "<p>removed #{custom_field.name}: <code class=\"idiff\">red, black</code></p>"
        expect(subject.note).to eq note_text
      end
    end
  end

  describe "#change_custom_field_date_type_note" do
    let(:custom_field) { build(:custom_field, field_type: :date) }
    let(:previous_value) { generate(:sequential_date) }
    let(:value) { generate(:sequential_date) }

    subject { service.change_custom_field_date_type_note(custom_field, previous_value: previous_value, value: value) }

    it_behaves_like 'a system note', skip_persistence_check: true do
      let(:action) { "custom_field" }
    end

    context "when the value is changed" do
      it 'sets the note text' do
        note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">#{value.to_fs(:long)}</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when the value is set" do
      let(:previous_value) { nil }

      it 'sets the note text' do
        note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">#{value.to_fs(:long)}</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when a value is removed" do
      let(:value) { nil }

      it 'sets the note text' do
        note_text = "<p>removed #{custom_field.name}: <code class=\"idiff\">#{previous_value.to_fs(:long)}</code></p>"
        expect(subject.note).to eq note_text
      end
    end
  end

  describe '#change_progress_note' do
    let_it_be_with_reload(:noteable) { create(:work_item, :objective, project: project) }
    let_it_be_with_reload(:progress) { create(:progress, work_item: noteable) }

    subject { service.change_progress_note }

    it_behaves_like 'a system note' do
      let(:action) { 'progress' }
    end

    it 'sets the progress text' do
      expect(subject.note).to eq "changed progress to **#{progress&.progress}%**"
    end
  end

  describe '#change_checkin_reminder_note' do
    let_it_be(:noteable, freeze: false) { create(:work_item, :objective, project: project) }
    let_it_be(:progress, freeze: false) { create(:progress, work_item: noteable) }

    subject { service.change_checkin_reminder_note }

    context 'with a weekly frequency' do
      before do
        progress.reminder_frequency = :weekly
      end

      it_behaves_like 'a system note' do
        let(:action) { 'checkin_reminder' }
      end

      it 'sets the checkin reminder note' do
        expect(subject.note).to eq "set a **#{progress&.reminder_frequency&.humanize(capitalize: false)}** checkin reminder"
      end
    end

    context 'with a frequency of never' do
      it 'sets the checkin reminder note' do
        progress.reminder_frequency = :never

        expect(subject.note).to eq "removed the checkin reminder"
      end
    end
  end

  describe '#publish_issue_to_status_page' do
    let_it_be_with_reload(:noteable) { create(:issue, project: project) }

    subject { service.publish_issue_to_status_page }

    it_behaves_like 'a system note' do
      let(:action) { 'published' }
    end

    it 'sets the note text' do
      expect(subject.note).to eq 'published this issue to the status page'
    end
  end

  describe '#cross_reference' do
    let(:mentioned_in) { create(:issue, project: project) }

    let(:new_note) { service.cross_reference(mentioned_in) }

    subject { service.cross_reference(mentioned_in) }

    context 'when noteable is an epic' do
      let(:noteable) { epic }

      it_behaves_like 'a system note', exclude_project: true do
        let(:action) { 'cross_reference' }
      end

      it 'tracks epic cross reference event in usage ping' do
        expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_cross_referenced)
          .with(author: author, namespace: group)

        subject
      end

      context 'with work item instrumentation tracking' do
        before do
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:cross_reference_disallowed?).and_return(false)
          end
        end

        context 'when mentioned_in is an Epic' do
          let_it_be_with_reload(:epic) { create(:epic, group: group) }
          let_it_be_with_reload(:epic_work_item) { create(:work_item, project: project) }
          let(:mentioned_in) { epic }

          before do
            allow(epic).to receive(:issue).and_return(epic_work_item)
          end

          it_behaves_like 'tracks work item event', :epic_work_item, :author, 'work_item_reference_add', :subject
        end
      end
    end

    context 'with project and group having the same path name' do
      using RSpec::Parameterized::TableSyntax

      let_it_be_with_reload(:root_group) { create(:group, path: 'same-path') }
      let_it_be_with_reload(:sub_group) { create(:group, path: 'same-path', parent: root_group) }
      let_it_be_with_reload(:sub_project) { create(:project, path: 'same-path', group: sub_group) }

      let_it_be_with_reload(:root_epic) { create(:work_item, :epic, namespace: root_group, iid: 100) }
      let_it_be_with_reload(:sub_epic) { create(:work_item, :epic, namespace: sub_group, iid: 100) }
      let_it_be_with_reload(:sub_project_issue) { create(:issue, project: sub_project, iid: 100) }

      where(:container, :mentioned_in, :noteable) do
        ref(:root_group) | ref(:root_epic) | ref(:sub_epic)
        ref(:sub_group) | ref(:sub_epic) | ref(:root_epic)
        ref(:root_group) | ref(:root_epic) | ref(:sub_project_issue)
        ref(:sub_project) | ref(:sub_project_issue) | ref(:root_epic)
        ref(:sub_group) | ref(:sub_epic) | ref(:sub_project_issue)
        ref(:sub_project) | ref(:sub_project_issue) | ref(:sub_epic)
      end

      with_them do
        let(:service) { described_class.new(noteable: noteable, container: container, author: author) }

        it 'has the correct link' do
          expect(new_note.note_html).to include(::Gitlab::UrlBuilder.build(mentioned_in, only_path: true))
        end
      end
    end

    context 'when notable is not an epic' do
      it 'does not tracks epic cross reference event in usage ping' do
        expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).not_to receive(:track_epic_cross_referenced)

        subject
      end
    end

    describe '#relate_issuable' do
      let(:noteable) { epic }
      let(:target) { create(:epic) }

      context 'for epics' do
        it 'creates system notes when relating epics' do
          result = service.relate_issuable(target)

          expect(result.note).to eq("marked as related to #{target.to_reference(target.group, full: true)}")
        end
      end

      context 'for work items' do
        let_it_be_with_reload(:target) { create(:work_item, :objective, project: project) }
        let_it_be_with_reload(:noteable) { create(:work_item, :objective, project: project) }

        it 'sets the note text without referencing the work item type' do
          result = service.relate_issuable(target)

          expect(result.note)
            .to eq("marked as related to #{target.to_reference(target.project)}")
        end
      end
    end
  end

  describe '#unrelate_issuable' do
    let(:noteable) { epic }
    let(:target) { create(:epic) }

    it 'creates system notes when epic gets unrelated' do
      result = service.unrelate_issuable(target)

      expect(result.note).to eq("removed the relation with #{target.to_reference(noteable.group)}")
    end
  end

  describe '#block_issuable' do
    subject(:system_note) { service.block_issuable(noteable_ref) }

    context 'when argument is a single issuable' do
      let_it_be(:noteable_ref, freeze: false) { issue1 }

      it_behaves_like 'a system note' do
        let(:action) { 'relate' }
      end

      it 'creates system note when issues gets marked as blocking' do
        expect(system_note.note).to eq "marked this item as blocking #{issue1.to_reference(project)}"
      end
    end

    context 'when argument is a collection of issuables' do
      let(:noteable_ref) { [issue1, issue2] }

      it_behaves_like 'a system note' do
        let(:action) { 'relate' }
      end

      it 'creates system note mentioning all issuables' do
        expect(system_note.note).to eq(
          "marked this item as blocking #{issue1.to_reference(project)} and #{issue2.to_reference(project)}"
        )
      end
    end
  end

  describe '#blocked_by_issuable' do
    subject(:system_note) { service.blocked_by_issuable(noteable_ref) }

    context 'when argument is a single issuable' do
      let_it_be(:noteable_ref, freeze: false) { issue1 }

      it_behaves_like 'a system note' do
        let(:action) { 'relate' }
      end

      it 'creates system note when issues gets marked as blocked by noteable' do
        expect(system_note.note).to eq "marked this item as blocked by #{issue1.to_reference(project)}"
      end
    end

    context 'when argument is a collection of issuables' do
      let(:noteable_ref) { [issue1, issue2] }

      it_behaves_like 'a system note' do
        let(:action) { 'relate' }
      end

      it 'creates system note mentioning all issuables' do
        expect(system_note.note).to eq(
          "marked this item as blocked by #{issue1.to_reference(project)} and #{issue2.to_reference(project)}"
        )
      end
    end
  end

  describe '#change_color_note' do
    let_it_be_with_reload(:noteable) { create(:work_item, :epic, namespace: group) }
    let_it_be_with_reload(:new_color) { create(:color, work_item: noteable, color: '#0052cc') }

    subject(:system_note) { service.change_color_note(previous_color) }

    context 'when previous color is a preset color and new color is custom' do
      let_it_be(:previous_color, freeze: false) { '#1068bf' }

      it 'creates system note with color swatches and display names' do
        expect(system_note.note).to eq "changed color from `#1068bf` **Blue** to `#0052cc` **Custom**"
      end
    end

    context 'when argument is nil and color is a custom color' do
      let_it_be(:previous_color, freeze: false) { nil }

      it 'creates system note with color swatch and Custom label' do
        expect(system_note.note).to eq "set color to `#0052cc` **Custom**"
      end
    end

    context 'when color was destroyed' do
      let_it_be(:previous_color, freeze: false) { nil }

      it 'creates system note with color swatch and Custom label' do
        allow(noteable.color).to receive(:destroyed?).and_return(true)

        expect(system_note.note).to eq "removed color `#0052cc` **Custom**"
      end
    end

    context 'when color matches a preset color name' do
      let_it_be_with_reload(:epic_with_blue) { create(:work_item, :epic, namespace: group) }
      let_it_be(:previous_color, freeze: false) { nil }

      before do
        create(:color, work_item: epic_with_blue, color: '#1068bf')
      end

      it 'shows the color swatch and display name in the system note' do
        preset_service = described_class.new(noteable: epic_with_blue, container: epic_with_blue.namespace,
          author: author)

        expect(preset_service.change_color_note(nil).note).to eq "set color to `#1068bf` **Blue**"
      end
    end
  end

  describe '#cross_reference_disallowed?' do
    context 'when noteable is an Epic' do
      let_it_be_with_reload(:group) { create(:group) }
      let_it_be_with_reload(:project) { create(:project, group: group) }
      let_it_be_with_reload(:noteable) { create(:epic, group: group) }

      context 'when mentioned_in is relevant work item' do
        let_it_be(:mentioned_in, freeze: false) { noteable.work_item }

        it 'is true' do
          expect(service.cross_reference_disallowed?(mentioned_in)).to be_truthy
        end
      end

      context 'when mentioned_in is a different epic work item' do
        let_it_be_with_reload(:epic) { create(:epic, group: group) }
        let_it_be(:mentioned_in, freeze: false) { epic.work_item }

        it 'is false' do
          expect(service.cross_reference_disallowed?(mentioned_in)).to be_falsey
        end
      end
    end
  end

  describe 'cross_reference_exists?' do
    let_it_be_with_reload(:noteable) { create(:work_item, :epic, namespace: group) }
    let(:service) { described_class.new(noteable: noteable, container: group, author: author) }

    context 'for group work item' do
      let_it_be_with_reload(:group_work_item) { create(:work_item, :epic, namespace: group) }

      it 'is true when already mentioned' do
        service.cross_reference(group_work_item)

        expect(service.cross_reference_exists?(group_work_item)).to be_truthy
      end

      it 'is false when not already mentioned' do
        expect(service.cross_reference_exists?(group_work_item)).to be_falsey
      end
    end
  end

  describe '#amazon_q_called' do
    subject(:system_note) { service.amazon_q_called('test') }

    it_behaves_like 'a system note' do
      let(:action) { 'notify_service' }
    end

    it 'creates system note mentioning q action' do
      expect(system_note.note).to eq "sent test request to Amazon Q"
    end
  end

  describe '#change_issue_confidentiality' do
    subject { service.change_issue_confidentiality }

    # System notes intentionally use the generic word "item" rather than the
    # specific work item type name. This keeps notes stable across type renames
    # (e.g. renaming "Task" to "To-do Item") and type conversions.
    context 'with custom work item type' do
      let(:custom_type) do
        create(:work_item_custom_type, :converted_from_issue, name: 'To-do Item', namespace: group)
      end

      let(:noteable) { create(:work_item, namespace: group) }
      let(:service) { described_class.new(noteable: noteable, container: group, author: author) }

      context 'when made confidential' do
        before do
          noteable.work_item_type = custom_type
          noteable.confidential = true
          noteable.save!
        end

        it 'uses the generic "item" wording in the note text' do
          expect(subject.note).to eq 'made the item confidential'
        end
      end

      context 'when made visible' do
        it 'uses the generic "item" wording in the note text' do
          expect(subject.note).to eq 'made the item visible to everyone'
        end
      end
    end
  end
end

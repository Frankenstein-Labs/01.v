# frozen_string_literal: true

RSpec.shared_examples 'cloneable and moveable for ee widget data' do
  def wi_weights_source(work_item)
    work_item.reload.weights_source&.slice(:rolled_up_weight, :rolled_up_completed_weight)
  end

  def wi_epic(work_item)
    return unless original_work_item.work_item_type.issue?

    work_item.reload.epic
  end

  def wi_vulnerabilities(work_item)
    work_item.reload.related_vulnerabilities.map(&:id)
  end

  def wi_linked_items(work_item)
    return [] unless original_work_item.group_epic_work_item?

    [
      IssueLink.for_source(work_item).map(&:target).pluck(:title),
      IssueLink.for_target(work_item).map(&:source).pluck(:title)
    ]
  end

  def wi_pending_escalations(work_item)
    work_item.reload.pending_escalations
  end

  def wi_status(work_item)
    return unless work_item_status_present?

    work_item.reload.current_status&.slice(:system_defined_status_id, :custom_status_id)
  end

  def wi_health_status(work_item)
    work_item.reload.health_status
  end

  def work_item_status_present?
    work_item_widgets.include?(::WorkItems::Widgets::Status) &&
      original_work_item.current_status.present?
  end

  let_it_be(:weights_source, freeze: false) do
    weights_source = create(:work_item_weights_source, work_item: original_work_item, rolled_up_weight: 20,
      rolled_up_completed_weight: 50)
    weights_source&.slice(:rolled_up_weight, :rolled_up_completed_weight)
  end

  let_it_be(:epic, freeze: false) do
    if original_work_item.work_item_type.issue?
      epic = create(:epic, :with_work_item_parent)
      parent_link = create(:parent_link, work_item: original_work_item, work_item_parent: epic.work_item)
      create(:epic_issue, issue: original_work_item, epic: epic, work_item_parent_link: parent_link)
      epic
    end
  end

  let_it_be(:related_vulnerabilities, freeze: false) do
    vulnerability_links = create_list(:vulnerabilities_issue_link, 2, issue: original_work_item)
    vulnerability_links.flat_map(&:vulnerability).map(&:id)
  end

  let_it_be(:related_items, freeze: false) do
    # related items for non epic WI are covered in FOSS
    if original_work_item.group_epic_work_item?
      create(:work_item, :epic_with_legacy_epic, namespace: original_work_item.namespace).tap do |related_wi_epic|
        create(:related_epic_link, :with_related_work_item_link, source: original_work_item.sync_object,
          target: related_wi_epic.sync_object, link_type: ::Enums::IssuableLink::TYPE_BLOCKS)
      end

      create(:work_item, :epic_with_legacy_epic, namespace: original_work_item.namespace).tap do |related_wi_epic|
        create(:related_epic_link, :with_related_work_item_link, source: related_wi_epic.sync_object,
          target: original_work_item.sync_object, link_type: ::Enums::IssuableLink::TYPE_BLOCKS)
      end

      [
        IssueLink.for_source(original_work_item).map(&:target).pluck(:title),
        IssueLink.for_target(original_work_item).map(&:source).pluck(:title)
      ]
    else
      []
    end
  end

  let_it_be(:pending_escalations, freeze: false) do
    if original_work_item.project.present?
      project = original_work_item.project
      policy = create(:incident_management_escalation_policy, project: project)
      create_list(:incident_management_pending_issue_escalation, 3, issue: work_item, project: project, policy: policy)
    end

    []
  end

  let_it_be(:status, freeze: false) do
    if work_item_status_present?
      current_status = create(:work_item_current_status, namespace: target_namespace)
      current_status&.slice(:system_defined_status_id, :custom_status_id)
    end
  end

  let_it_be(:health_status, freeze: false) do
    original_work_item.health_status
  end

  let_it_be(:move, freeze: false) { WorkItems::DataSync::MoveService }
  let_it_be(:clone, freeze: false) { WorkItems::DataSync::CloneService }

  # rubocop: disable Layout/LineLength -- improved readability with one line per widget
  let_it_be(:widgets, freeze: false) do
    [
      # for hierarchy widget, ensure that epic(through epic_issue) is being copied to the new work item
      { widget: :hierarchy,       assoc_name: :epic,                    eval_value: :wi_epic,                expected: epic,                    operations: [move, clone] },
      { widget: :weight,          assoc_name: :weights_source,          eval_value: :wi_weights_source,      expected: weights_source,          operations: [move, clone] },
      { widget: :linked_items,    assoc_name: :linked_work_items,       eval_value: :wi_linked_items,        expected: related_items,           operations: [move] },
      { widget: :status,          assoc_name: :current_status,          eval_value: :wi_status,              expected: status,                  operations: [move, clone] },
      { widget: :health_status,   assoc_name: :health_status,           eval_value: :wi_health_status,       expected: health_status,           operations: [move, clone] },
      # these are non widget associations, but we can test these the same way
      { widget: :vulnerabilities, assoc_name: :related_vulnerabilities, eval_value: :wi_vulnerabilities,     expected: related_vulnerabilities, operations: [move] },
      {                           assoc_name: :pending_escalations,     eval_value: :wi_pending_escalations, expected: pending_escalations,     operations: [move] }
    ]
  end
  # rubocop: enable Layout/LineLength

  let(:always_cleaned_up_widgets) { [:work_item_parent, :epic] }

  context "with widget" do
    it_behaves_like 'for clone and move services'
  end
end

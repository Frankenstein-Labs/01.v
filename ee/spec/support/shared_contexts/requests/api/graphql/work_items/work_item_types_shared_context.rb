# frozen_string_literal: true

RSpec.shared_context 'with work item types request context EE' do
  include_context 'with work item types request context'

  let_it_be(:widget_definitions_map, freeze: false) do
    WorkItems::TypesFramework::SystemDefined::WidgetDefinition.all.group_by(&:work_item_type_id)
  end

  let(:work_item_type_fields) do
    <<~GRAPHQL
      id
      name
      iconName
      widgetDefinitions {
        type
        ... on WorkItemWidgetDefinitionAssignees {
          canInviteMembers
          allowsMultipleAssignees
        }
        ... on WorkItemWidgetDefinitionHierarchy {
          allowedChildTypes {
            nodes { id name }
          }
          allowedParentTypes {
            nodes { id name }
          }
        }
        ... on WorkItemWidgetDefinitionLabels {
          allowsScopedLabels
        }
        ... on WorkItemWidgetDefinitionWeight {
          editable
          rollUp
        }
        ... on WorkItemWidgetDefinitionStatus {
          allowedStatuses {
            id
            name
            iconName
            color
            position
          }
          defaultOpenStatus {
            id
            name
          }
          defaultClosedStatus {
            id
            name
          }
        }
      }
      supportedConversionTypes {
        id
        name
      }
    GRAPHQL
  end

  let(:widget_attributes) do
    ee_attributes = {
      assignees: {
        'allowsMultipleAssignees' => true
      },
      labels: {
        'allowsScopedLabels' => false
      },
      weight: {
        'editable' => be_boolean,
        'rollUp' => be_boolean
      }
    }

    base_widget_attributes.deep_merge(ee_attributes)
  end

  def widgets_for(work_item_type, resource_parent)
    work_item_type.widget_classes(resource_parent).map do |widget|
      base_attributes = { 'type' => widget.type.to_s.upcase }

      if widget == WorkItems::Widgets::Hierarchy
        next hierarchy_widget_attributes(work_item_type, base_attributes, resource_parent)
      end

      if widget == WorkItems::Widgets::Status
        next status_widget_attributes(work_item_type,
          base_attributes, resource_parent)
      end

      next base_attributes unless widget_attributes[widget.type]

      base_attributes.merge(widget_attributes[widget.type])
    end
  end

  def status_widget_attributes(work_item_type, base_attributes, resource_parent)
    unless status_widget_available_for?(work_item_type, resource_parent)
      return base_attributes.merge({ 'allowedStatuses' => [] })
    end

    statuses = WorkItems::Statuses::SystemDefined::Status.all.map do |status|
      status.attributes.symbolize_keys.merge(iconName: status.icon_name)
    end

    base_attributes.merge({ 'allowedStatuses' => statuses })
  end

  def status_widget_available_for?(work_item_type, resource_parent)
    widget_available_for?(work_item_type_id: work_item_type.id, widget_type: 'status') &&
      resource_parent&.root_ancestor&.licensed_feature_available?(:work_item_status)
  end

  def widget_available_for?(widget_type:, work_item_type_id: nil, work_item_type_name: nil)
    raise unless work_item_type_id.present? || work_item_type_name.present?

    unless work_item_type_id.present?
      work_item_type_id = WorkItems::TypesFramework::Provider.new.find_by_name(work_item_type_name).id
    end

    widget_definitions_map[work_item_type_id].any? { |definition| definition.widget_type == widget_type }
  end
end

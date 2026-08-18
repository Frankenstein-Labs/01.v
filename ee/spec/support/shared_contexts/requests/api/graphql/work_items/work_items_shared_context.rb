# frozen_string_literal: true

RSpec.shared_context 'with work item request context EE' do
  include_context 'with work item request context'

  let(:licensed_widget_fields) do
    <<~GRAPHQL
      id
      widgets {
        ... on WorkItemWidgetHierarchy {
          type
          hasChildren
          hasParent
          depthLimitReachedByType {
            workItemType {
              id
              name
            }
            depthLimitReached
          }
          rolledUpCountsByType {
            countsByState {
              all
              closed
            }
            workItemType {
              id
              name
              iconName
            }
          }
        }
        type
        ... on WorkItemWidgetStartAndDueDate {
          dueDate
          startDate
        }
        ... on WorkItemWidgetWeight {
          weight
          rolledUpWeight
          widgetDefinition {
            editable
            rollUp
          }
        }
        ... on WorkItemWidgetHealthStatus {
          healthStatus
          rolledUpHealthStatus {
            count
            healthStatus
          }
        }
        ... on WorkItemWidgetIteration {
          iteration {
            id
            title
            startDate
            dueDate
            webUrl
            iterationCadence {
              id
              title
            }
          }
        }
        ... on WorkItemWidgetStatus {
          status {
            id
            name
            description
            iconName
            color
            position
          }
        }
      }
    GRAPHQL
  end

  def add_child(parent, type, container)
    container_type = container.is_a?(Group) ? 'namespace' : 'project'
    options = { "#{container_type}": container, work_item_parent: parent, health_status: :on_track }
    if type == :issue || type == :task
      options[:iteration] = iteration
      options[:weight] = 2
    end

    create(:work_item, type, options).tap do |child|
      create(:work_items_dates_source, work_item: child, due_date: due_date, start_date: start_date)
    end
  end
end

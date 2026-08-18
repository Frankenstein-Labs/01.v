# frozen_string_literal: true

module QA
  module EE
    module Resource
      class WorkItemEpic < QA::Resource::Base
        include QA::Support::Dates

        attribute :group do
          QA::Resource::Group.fabricate_via_api! do |group|
            group.path = "group-to-test-epic-work-items-#{SecureRandom.hex(8)}"
          end
        end

        attributes :id,
          :iid,
          :title,
          :description,
          :label_ids,
          :is_fixed,
          :confidential,
          :author,
          :start_date,
          :due_date,
          :parent_id

        def initialize
          @title = "WI-Epic-#{SecureRandom.hex(8)}"
          @description = "This is a work item epic description."
          @confidential = false
          @is_fixed = false
        end

        def fabricate!
          group.visit!

          QA::Page::Group::Menu.perform(&:go_to_epics)

          QA::EE::Page::Group::WorkItem::Epic::Index.perform(&:click_new_epic)

          QA::EE::Page::Group::WorkItem::Epic::New.perform do |new_epic_page|
            new_epic_page.select_epic_type
            new_epic_page.set_title(title)
            new_epic_page.enable_confidential_epic if @confidential
            new_epic_page.create_new_epic
          end

          QA::EE::Page::Group::WorkItem::Epic::Index.perform(&:click_first_epic)
        end

        def gid
          "gid://gitlab/WorkItem/#{id}"
        end

        # Work item epic attributes
        #
        # @return [String]
        def gql_attributes
          @gql_attributes ||= <<~GQL
            author {
              id
            }
            confidential
            createdAt
            updatedAt
            closedAt
            description
            id
            iid
            namespace {
              id
            }
            state
            title
            webUrl
            widgets {
              ... on WorkItemWidgetStartAndDueDate
              {
                type
                dueDate
                dueDateSourcingMilestone
                  {
                    id
                    title
                    dueDate
                  }
                isFixed
                rollUp
                startDate
                startDateSourcingMilestone
                  {
                    id
                    title
                    startDate
                  }
              }
              ... on WorkItemWidgetLabels
              {
                type
                labels
                {
                  nodes
                  {
                    title
                  }
                }
              }
              ... on WorkItemWidgetAwardEmoji
              {
                type
                upvotes
                downvotes
              }
              ... on WorkItemWidgetHierarchy
              {
                type
                children
                {
                  nodes
                  {
                    id
                    name
                  }
                }
                parent
                {
                  id
                }
              }
              ... on WorkItemWidgetColor
              {
                type
                color
                textColor
              }
            }
            workItemType {
              name
              id
            }
          GQL
        end

        # Path for fetching work item epic
        #
        # @return [String]
        def api_get_path
          "/graphql"
        end

        # Fetch work item epic
        #
        # @return [Hash]
        def api_get
          process_api_response(
            api_post_to(
              api_get_path,
              <<~GQL
                query {
                  workItem(id: "#{gid}") {
                    #{gql_attributes}
                  }
                }
              GQL
            )
          )
        end

        # Path to create work item epic
        #
        # @return [String]
        def api_post_path
          "/graphql"
        end

        # Graphql mutation for work item epic creation
        #
        # @return [String]
        def api_post_body
          <<~GQL
            mutation {
              workItemCreate(input: {
                namespacePath: "#{group.full_path}"
                title: "#{@title}"
                descriptionWidget: {
                  description: "#{@description}"
                }
                #{mutation_params}
                workItemTypeId: "#{get_work_item_type_id}"
              }) {
                workItem {
                  #{gql_attributes}
                }
                errors
              }
            }
          GQL
        end

        def get_work_item_type_id
          response = process_work_item_type_api_response(
            api_post_to(
              '/graphql',
              <<~GQL
                query getWorkItemTypeId {
                  namespace(fullPath: "#{@group.full_path}") {
                    workItemTypes(name: EPIC) {
                      edges {
                        node {
                          id
                        }
                      }
                    }
                  }
                }
              GQL
            )
          )
          response.dig(:work_item_types, :edges, 0, :node, :id)
        end

        def process_api_response(parsed_response)
          parsed_response = extract_graphql_resource(parsed_response, 'work_item') if parsed_response.key?(:work_item)

          super
        end

        def process_work_item_type_api_response(parsed_response)
          self.api_response = parsed_response
          self.api_resource = transform_api_resource(parsed_response.deep_dup)
        end

        # Graphql mutation for updating work item epic isFixed argument
        #
        # @param fixed [Boolean] what to set isFixed to. Defaults to true
        # @return [String]
        def set_is_fixed(fixed: true)
          mutation = <<~GQL
            mutation {
              workItemUpdate(input: {
                id: "#{gid}"
                startAndDueDateWidget: {
                  isFixed: #{fixed}
                }

              }) {
              workItem {
                #{gql_attributes}
              }
              errors
              }
            }
          GQL
          api_post_to(api_post_path, mutation)
        end

        # Graphql mutation for adding child items to work item epic
        #
        # @param item_id [String] id of work item to link
        # @return [String]
        def add_child_item(item_id)
          mutation = <<~GQL
            mutation {
              workItemUpdate(input: {
                id: "#{gid}"
                hierarchyWidget: {
                  childrenIds: "#{"gid://gitlab/WorkItem/#{item_id}"}"
                }
              }) {
              workItem {
                #{gql_attributes}
              }
              errors
              }
            }
          GQL
          api_post_to(api_post_path, mutation)
        end

        # Graphql mutation for removing child items from work item epic
        #
        # @param item_id [String] id of work item to link
        # @return [String]
        def remove_child_items(item_id)
          mutation = <<~GQL
            mutation {
              workItemUpdate(input: {
                id: "#{item_id}"
                hierarchyWidget: {
                  parentId: null
                }
              }) {
              workItem {
                #{gql_attributes}
              }
              errors
              }
            }
          GQL
          api_post_to(api_post_path, mutation)
        end

        # Add award emoji
        #
        # @param [String] name
        # @return [Hash]
        def award_emoji(name)
          mutation = <<~GQL
            mutation {
              workItemUpdate(input: {
                id: "#{gid}"
                awardEmojiWidget: {
                  action: ADD
                  name: "#{name}"
                }
              }) {
              workItem {
                #{gql_attributes}
              }
              errors
              }
            }
          GQL
          api_post_to(api_post_path, mutation)
        end

        def child_items
          reload! if api_response.nil?

          get_widget('HIERARCHY')&.dig(:children, :nodes)
        end

        def start_date
          reload! if api_response.nil?

          get_widget('START_AND_DUE_DATE')&.dig(:start_date)
        end

        def due_date
          reload! if api_response.nil?

          get_widget('START_AND_DUE_DATE')&.dig(:due_date)
        end

        def due_date_sourcing_milestone
          reload! if api_response.nil?

          get_widget('START_AND_DUE_DATE')&.dig(:due_date_sourcing_milestone)
        end

        def start_date_sourcing_milestone
          reload! if api_response.nil?

          get_widget('START_AND_DUE_DATE')&.dig(:start_date_sourcing_milestone)
        end

        def fixed?
          reload! if api_response.nil?

          get_widget('START_AND_DUE_DATE')&.dig(:is_fixed)
        end

        def parent_id
          reload! if api_response.nil?

          get_widget('HIERARCHY')&.dig(:parent, :id)&.split('/')&.last
        end

        protected

        # Return available parameters formatted to be used in a GraphQL query
        #
        # @return [String]
        def mutation_params
          params = %(confidential: #{@confidential})

          if defined?(@due_date) && defined?(@start_date)
            params += %(
            startAndDueDateWidget: {
              dueDate: "#{@due_date}"
              isFixed: #{@is_fixed}
              startDate: "#{@start_date}"
            })
          end

          if defined?(@parent_id)
            params += %(
            hierarchyWidget: {
              parentId: "gid://gitlab/WorkItem/#{@parent_id}"
            })
          end

          if defined?(@label_ids)
            ids = @label_ids.map do |label_id|
              "gid://gitlab/Label/#{label_id}"
            end

            params += %(
            labelsWidget: {
              labelIds: #{ids}
            })
          end

          params
        end

        # Return subset of fields for comparing work item epics to legacy epics
        #
        # @return [Hash]
        def comparable
          reload! if api_response.nil?

          api_resource[:labels] = get_widget('LABELS')&.dig(:labels, :nodes)
          api_resource[:upvotes] = get_widget('AWARD_EMOJI')&.dig(:upvotes)
          api_resource[:downvotes] = get_widget('AWARD_EMOJI')&.dig(:downvotes)
          api_resource[:is_fixed] = get_widget('START_AND_DUE_DATE')&.dig(:is_fixed)
          api_resource[:roll_up] = get_widget('START_AND_DUE_DATE')&.dig(:roll_up)
          api_resource[:start_date] = get_widget('START_AND_DUE_DATE')&.dig(:start_date)
          api_resource[:due_date] = get_widget('START_AND_DUE_DATE')&.dig(:due_date)
          api_resource[:color] = get_widget('COLOR')&.dig(:color)
          api_resource[:text_color] = get_widget('COLOR')&.dig(:text_color)

          api_resource.slice(
            :title,
            :description,
            :state,
            :is_fixed,
            :roll_up,
            :start_date,
            :due_date,
            :confidential,
            :labels,
            :upvotes,
            :downvotes,
            :color,
            :text_color
          )
        end

        def get_widget(type)
          api_resource[:widgets].find { |widget| widget[:type] == type }
        end
      end
    end
  end
end

# frozen_string_literal: true

module EE
  module Sidebars
    module Projects
      module Menus
        module MonitorMenu
          extend ::Gitlab::Utils::Override

          override :configure_menu_items
          def configure_menu_items
            return false unless super

            insert_item_before(:error_tracking, tracing_menu_item)
            insert_item_after(:tracing, metrics_menu_item)
            insert_item_after(:logs, logs_menu_item)
            insert_item_after(:incidents, on_call_schedules_menu_item)
            insert_item_after(:on_call_schedules, escalation_policies_menu_item)

            true
          end

          private

          def on_call_schedules_menu_item
            unless can?(context.current_user, :read_incident_management_oncall_schedule, context.project)
              return ::Sidebars::NilMenuItem.new(item_id: :on_call_schedules)
            end

            ::Sidebars::MenuItem.new(
              title: _('On-call Schedules'),
              link: project_incident_management_oncall_schedules_path(context.project),
              super_sidebar_parent: ::Sidebars::Projects::SuperSidebarMenus::MonitorMenu,
              active_routes: { controller: :oncall_schedules },
              item_id: :on_call_schedules,
              description: _('Define on-call rotations to ensure the right people are alerted'),
              library_icon: 'on-call-schedules',
              tier: :premium
            )
          end

          def escalation_policies_menu_item
            unless can?(context.current_user, :read_incident_management_escalation_policy, context.project)
              return ::Sidebars::NilMenuItem.new(item_id: :escalation_policies)
            end

            ::Sidebars::MenuItem.new(
              title: _('Escalation Policies'),
              link: project_incident_management_escalation_policies_path(context.project),
              super_sidebar_parent: ::Sidebars::Projects::SuperSidebarMenus::MonitorMenu,
              active_routes: { controller: :escalation_policies },
              item_id: :escalation_policies,
              description: _('Set escalation rules to ensure alerts reach the right responders'),
              library_icon: 'escalation-policy',
              tier: :premium
            )
          end

          def tracing_menu_item
            unless can?(context.current_user, :read_observability, context.project)
              return ::Sidebars::NilMenuItem.new(item_id: :tracing)
            end

            ::Sidebars::MenuItem.new(
              title: _('Tracing'),
              link: project_tracing_index_path(context.project),
              super_sidebar_parent: ::Sidebars::Projects::SuperSidebarMenus::MonitorMenu,
              active_routes: { controller: :tracing },
              item_id: :tracing,
              description: _('Trace requests across services to diagnose performance issues'),
              library_icon: 'tracing'
            )
          end

          def metrics_menu_item
            unless can?(context.current_user, :read_observability, context.project)
              return ::Sidebars::NilMenuItem.new(item_id: :metrics)
            end

            ::Sidebars::MenuItem.new(
              title: s_('ObservabilityMetrics|Metrics'),
              link: project_metrics_path(context.project),
              super_sidebar_parent: ::Sidebars::Projects::SuperSidebarMenus::MonitorMenu,
              active_routes: { controller: :metrics },
              item_id: :metrics,
              description: _('Visualize and monitor application and infrastructure metrics'),
              library_icon: 'metrics'
            )
          end

          def logs_menu_item
            unless can?(context.current_user, :read_observability, context.project)
              return ::Sidebars::NilMenuItem.new(item_id: :logs)
            end

            ::Sidebars::MenuItem.new(
              title: s_('ObservabilityLogs|Logs'),
              link: project_logs_path(context.project),
              super_sidebar_parent: ::Sidebars::Projects::SuperSidebarMenus::MonitorMenu,
              active_routes: { controller: :logs },
              item_id: :logs,
              description: _('Search and analyze application logs'),
              library_icon: 'log'
            )
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module EE
  module API
    module Groups
      extend ActiveSupport::Concern

      prepended do
        helpers do
          include ::API::Helpers::AuditEventsCursorHelper

          extend ::Gitlab::Utils::Override

          override :find_groups
          def find_groups(params, parent_id = nil)
            params.delete(:repository_storage) unless can?(current_user, :change_repository_storage)

            super(params, parent_id)
          end

          override :allowable_find_params
          def allowable_find_params
            super + [:repository_storage]
          end

          override :create_group
          def create_group
            ldap_link_attrs = {
              cn: params.delete(:ldap_cn),
              group_access: params.delete(:ldap_access)
            }

            authenticated_as_admin! if params[:shared_runners_minutes_limit]

            response = super
            group = response[:group]

            # NOTE: add backwards compatibility for single ldap link
            if response.success? && ldap_link_attrs[:cn].present?
              group.ldap_group_links.create(
                cn: ldap_link_attrs[:cn],
                group_access: ldap_link_attrs[:group_access]
              )
            end

            response
          end

          override :update_group
          def update_group(group)
            remove_unlicensed_params(group)
            remove_unpermitted_params(group)

            unless group.unique_project_download_limit_enabled?
              %i[
                unique_project_download_limit
                unique_project_download_limit_interval_in_seconds
                unique_project_download_limit_allowlist
                unique_project_download_limit_alertlist
                auto_ban_user_on_excessive_projects_download
              ].each do |param|
                params.delete(param)
              end
            end

            unless ::Feature.enabled?(:dap_group_customizable_permissions, group.root_ancestor)
              params[:ai_settings_attributes]&.except!(
                :minimum_access_level_execute,
                :minimum_access_level_execute_async,
                :minimum_access_level_manage,
                :minimum_access_level_enable_on_projects
              )
            end

            validate_merge_request_settings!(group)

            super
          end

          def remove_unlicensed_params(group)
            params.delete(:file_template_project_id) unless
              group.licensed_feature_available?(:custom_file_templates_for_namespace)

            params.delete(:ip_restriction_ranges) unless
              group.licensed_feature_available?(:group_ip_restriction)

            params.delete(:allowed_email_domains_list) unless
              group.licensed_feature_available?(:group_allowed_email_domains)

            unless group.built_in_project_templates_enabled_available?
              params.delete(:built_in_project_templates_enabled)
              params.delete(:lock_built_in_project_templates_enabled)
            end

            return if group.licensed_feature_available?(:group_level_merge_checks_setting)

            params.delete(:only_allow_merge_if_pipeline_succeeds)
            params.delete(:allow_merge_on_skipped_pipeline)
            params.delete(:only_allow_merge_if_all_discussions_are_resolved)
          end

          def remove_unpermitted_params(group)
            params.delete(:prevent_forking_outside_group) unless
              can?(current_user, :change_prevent_group_forking, group)

            params.delete(:service_access_tokens_expiration_enforced) unless
              group.root? && can?(current_user, :admin_service_accounts, group)
          end

          override :authorize_group_creation!
          def authorize_group_creation!
            authorize! :create_group_via_api
          end

          override :check_query_limit
          def check_query_limit
            # Short circuit if tracking is disabled
            return unless ::Gitlab::QueryLimiting.enabled?
            return super unless params[:duo_availability].present? && ::Ai::AmazonQ.connected?

            # AmazonQ can trigger service account removal from group and nested namespaces which causes too many queries
            ::Gitlab::QueryLimiting.disable!('https://gitlab.com/gitlab-org/gitlab/-/issues/510174', new_threshold: 200)
          end

          def check_audit_events_available!(group)
            forbidden! unless group.licensed_feature_available?(:audit_events)
          end

          def audit_event_finder_params
            params
              .slice(:created_after, :created_before, :pagination)
              .then { |params| filter_by_author(params) }
          end

          def filter_by_author(params)
            can?(current_user, :read_any_audit_event, user_group) ? params : params.merge(author_id: current_user.id)
          end

          def check_ssh_certificate_available_to_group(group)
            not_found!('Group') unless group
            not_found! unless group.licensed_feature_available?(:ssh_certificates)
            forbidden!('Group') if group.has_parent?
          end

          def validate_merge_request_settings!(group)
            return unless params.key?(:allow_merge_on_skipped_pipeline)
            return unless params[:allow_merge_on_skipped_pipeline] == true

            pipeline_succeeds = if params.key?(:only_allow_merge_if_pipeline_succeeds)
                                  params[:only_allow_merge_if_pipeline_succeeds]
                                else
                                  group.namespace_settings&.only_allow_merge_if_pipeline_succeeds
                                end

            return if pipeline_succeeds

            bad_request!(
              'allow_merge_on_skipped_pipeline can only be enabled when ' \
                'only_allow_merge_if_pipeline_succeeds is true'
            )
          end
        end

        resource :groups, requirements: ::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
          desc 'Sync a group with LDAP' do
            detail 'Syncs a specified group with its linked LDAP group. You must be an administrator or have the ' \
              'Owner role for the group.'
            tags ['ldap']
          end
          route_setting :authorization, permissions: :run_ldap_sync, boundary_type: :group
          post ":id/ldap_sync", feature_category: :system_access do
            not_found! unless ::Gitlab::Auth::Ldap::Config.group_sync_enabled?

            group = find_group!(params[:id])
            authorize! :admin_group, group

            if group.pending_ldap_sync
              ::LdapGroupSyncWorker.perform_async(group.id)
            end

            status 202
          end

          segment ':id/audit_events' do
            before do
              authorize! :read_audit_event, user_group
              check_audit_events_available!(user_group)
              increment_unique_values('a_compliance_audit_events_api', current_user.id)

              ::Gitlab::Tracking.event(
                'EE::API::Groups',
                'group_audit_event_request',
                user: current_user,
                namespace: user_group,
                context: [
                  ::Gitlab::Tracking::ServicePingContext
                    .new(data_source: :redis_hll, event: 'a_compliance_audit_events_api')
                    .to_context
                ]
              )
            end

            desc 'List all group audit events' do
              detail 'Lists all audit events for a specified group.'
              success ::API::Entities::AuditEvent
              is_array true
              tags ['audit_events']
            end
            params do
              optional :created_after,
                type: DateTime,
                desc: 'Return audit events created after the specified time',
                documentation: { type: 'dateTime', example: '2016-01-19T09:05:50.355Z' }
              optional :created_before,
                type: DateTime,
                desc: 'Return audit events created before the specified time',
                documentation: { type: 'dateTime', example: '2016-01-19T09:05:50.355Z' }

              use :pagination
            end
            route_setting :authorization, permissions: :read_audit_event, boundary_type: :group
            get '/', feature_category: :audit_events, urgency: :low do
              audit_event_finder_params[:optimize_offset] = true

              if params[:pagination] == 'keyset'
                params[:cursor] =
                  enrich_audit_event_cursor(params[:cursor], user_group)
              end

              audit_events = ::AuditEvents::GroupAuditEventFinder.new(
                group: user_group,
                params: audit_event_finder_params
              ).execute

              present paginate_with_strategies(audit_events), with: ::API::Entities::AuditEvent
            end

            desc 'Retrieve a group audit event' do
              detail 'Retrieves an audit event for a specified group. Only available to group Owners and ' \
                'administrators.'
              success ::API::Entities::AuditEvent
              tags %w[groups]
            end
            params do
              requires :audit_event_id, type: Integer, desc: 'The ID of the audit event'
            end
            route_setting :authorization, permissions: :read_audit_event, boundary_type: :group
            get '/:audit_event_id', feature_category: :audit_events do
              # rubocop: disable CodeReuse/ActiveRecord, Rails/FindById -- This is not `find_by!` from ActiveRecord
              audit_event = ::AuditEvents::GroupAuditEventFinder.new(
                group: user_group,
                params: audit_event_finder_params
              ).find_by!(id: params[:audit_event_id])
              # rubocop: enable CodeReuse/ActiveRecord, Rails/FindById
              present audit_event, with: ::API::Entities::AuditEvent
            end
          end

          desc 'List all SAML users' do
            detail 'Lists all SAML users for a specified top-level group. Use the `page` and `per_page` pagination ' \
              'parameters to filter the results.'
            success ::API::Entities::UserPublic
            is_array true
            tags %w[groups]
          end
          params do
            optional :username, type: String, desc: 'Return single user with a specific username.'
            optional :search, type: String, desc: 'Search users by name, email, username.'
            optional :active, type: Grape::API::Boolean, default: false, desc: 'Return only active users.'
            optional :blocked, type: Grape::API::Boolean, default: false, desc: 'Return only blocked users.'
            optional :created_after, type: DateTime, desc: 'Return users created after the specified time.'
            optional :created_before, type: DateTime, desc: 'Return users created before the specified time.'

            use :pagination
          end
          route_setting :authorization, permissions: :read_saml_user, boundary_type: :group
          get ':id/saml_users', feature_category: :system_access do
            authenticate!
            bad_request!('Must be a top-level group') unless user_group.root?

            finder = ::Authn::GroupSamlUsersFinder.new(
              current_user,
              declared_params.merge(group: user_group))

            users = finder.execute.preload(:identities, :group_scim_identities, :instance_scim_identities) # rubocop: disable CodeReuse/ActiveRecord -- preload

            present paginate(users), with: ::API::Entities::UserPublic
          end

          desc 'List all provisioned users' do
            detail 'Lists all provisioned users for a specified group.'
            success ::API::Entities::UserPublic
            tags %w[groups]
          end
          params do
            optional :username, type: String, desc: 'Return a single user with a specific username'
            optional :search, type: String, desc: 'Search users by name, email or username'
            optional :active, type: Grape::API::Boolean, default: false, desc: 'Return only active users'
            optional :blocked, type: Grape::API::Boolean, default: false, desc: 'Return only blocked users'
            optional :created_after, type: DateTime, desc: 'Return users created after the specified time'
            optional :created_before, type: DateTime, desc: 'Return users created before the specified time'

            use :pagination
          end
          # rubocop: disable CodeReuse/ActiveRecord
          route_setting :authorization, permissions: :read_provisioned_user, boundary_type: :group
          get ':id/provisioned_users', feature_category: :system_access do
            authorize! :read_provisioned_user, user_group

            finder = ::Auth::ProvisionedUsersFinder.new(
              current_user,
              declared_params.merge(provisioning_group: user_group))

            users = finder.execute.preload(:identities)

            present paginate(users), with: ::API::Entities::UserPublic
          end
          # rubocop: enable CodeReuse/ActiveRecord

          desc 'List all group SSH certificates' do
            detail 'Lists all SSH certificates for a specified group.'
            summary 'Get a list of Groups::SshCertificate for a Group.'
            success code: 200, model: ::API::Entities::SshCertificate
            failure [
              { code: 401, message: 'Unauthorized' },
              { code: 403, message: 'Forbidden' },
              { code: 404, message: '404 Not Found' }
            ]
            is_array true
            tags %w[keys]
          end
          params do
            use :pagination
          end
          route_setting :authorization, permissions: :read_ssh_certificate, boundary_type: :group
          get ":id/ssh_certificates", feature_category: :groups_and_projects, urgency: :low do
            group = find_group!(params[:id])
            authorize! :admin_group, group

            check_ssh_certificate_available_to_group(group)

            present paginate(group.ssh_certificates), with: ::API::Entities::SshCertificate
          end

          desc 'Add a group SSH certificate' do
            detail 'Adds a group SSH certificate for a specified group.'
            summary 'Add a Groups::SshCertificate.'
            success code: 201, model: ::API::Entities::SshCertificate
            failure [
              { code: 400, message: 'Bad request' },
              { code: 401, message: 'Unauthorized' },
              { code: 403, message: 'Forbidden' },
              { code: 404, message: 'Not found' }
            ]
            tags %w[keys]
          end
          params do
            requires :title, type: String, desc: 'The title of the ssh certificate'
            requires :key, type: String, desc: 'The key of the ssh certificate'
          end
          route_setting :authorization, permissions: :create_ssh_certificate, boundary_type: :group
          post ":id/ssh_certificates", feature_category: :groups_and_projects do
            group = find_group!(params[:id])
            authorize! :admin_group, group

            check_ssh_certificate_available_to_group(group)

            response = ::Groups::SshCertificates::CreateService.new(group, params, current_user).execute
            if response.success?
              present response.payload, with: ::API::Entities::SshCertificate
            else
              render_api_error!(response.message, response.reason)
            end
          end

          desc 'Delete a group SSH certificate' do
            detail 'Deletes a specified group SSH certificate.'
            success code: 204
            failure [
              { code: 400, message: 'Bad request' },
              { code: 401, message: 'Unauthorized' },
              { code: 403, message: 'Forbidden' },
              { code: 422, message: 'Unprocessable entity' }
            ]
            tags %w[keys]
          end
          params do
            requires :ssh_certificates_id, type: Integer, desc: 'The ID of a group SSH certificate'
          end
          route_setting :authorization, permissions: :delete_ssh_certificate, boundary_type: :group
          delete ":id/ssh_certificates/:ssh_certificates_id", feature_category: :groups_and_projects do
            group = find_group!(params[:id])
            authorize! :admin_group, group

            check_ssh_certificate_available_to_group(group)

            response = ::Groups::SshCertificates::DestroyService.new(group, params, current_user).execute

            if response.success?
              no_content!
            else
              render_api_error!(response.message, response.reason)
            end
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Ai
  module Catalog
    class McpServersBatchLoader
      class << self
        def load_for(agent_version, current_user)
          BatchLoader::GraphQL.for(agent_version.id).batch(default_value: []) do |item_version_ids, loader|
            results = batch_mcp_servers_for_item_versions(item_version_ids, current_user)
            item_version_ids.each { |id| loader.call(id, results.fetch(id, [])) }
          end
        end

        def batch_mcp_servers_for_item_versions(item_version_ids, current_user)
          item_version_ids = Array(item_version_ids).uniq
          return {} if item_version_ids.empty?

          item_versions_by_id = ::Ai::Catalog::ItemVersion.id_in(item_version_ids).index_by(&:id)
          allowed_org_ids = allowed_organization_ids_for(item_versions_by_id.values, current_user)
          mcp_server_ids = collect_mcp_server_ids(item_versions_by_id.values, allowed_org_ids)
          mcp_servers_by_id = load_mcp_servers(mcp_server_ids)

          item_version_ids.index_with do |id|
            mcp_servers_for_version(item_versions_by_id[id], allowed_org_ids, mcp_servers_by_id)
          end
        end

        private

        def allowed_organization_ids_for(item_versions, current_user)
          organization_ids = item_versions.filter_map(&:organization_id).uniq
          return Set.new if organization_ids.empty?
          return Set.new unless ::Ai::Catalog.mcp_servers_available?(current_user)
          return organization_ids.to_set if Ability.allowed?(current_user, :admin_all_resources)

          ::Organizations::Organization.with_user(current_user).id_in(organization_ids).pluck_primary_key.to_set
        end

        def collect_mcp_server_ids(item_versions, allowed_org_ids)
          item_versions
            .select { |version| allowed_org_ids.include?(version.organization_id) }
            .flat_map { |version| Array(version.def_mcp_servers) }
            .uniq
        end

        def load_mcp_servers(mcp_server_ids)
          return {} if mcp_server_ids.empty?

          ::Ai::Catalog::McpServer.id_in(mcp_server_ids).index_by(&:id)
        end

        def mcp_servers_for_version(version, allowed_org_ids, mcp_servers_by_id)
          return [] unless version
          return [] unless allowed_org_ids.include?(version.organization_id)

          Array(version.def_mcp_servers).uniq.filter_map { |sid| mcp_servers_by_id[sid] }
        end
      end
    end
  end
end

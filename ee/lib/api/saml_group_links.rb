# frozen_string_literal: true

module API
  class SamlGroupLinks < ::API::Base
    before { authenticate! }

    SAML_GROUP_LINKS = %w[saml_group_links].freeze
    feature_category :user_management

    params do
      requires :id, types: [String, Integer], desc: 'ID or URL-encoded path of the group'
    end
    resource :groups do
      helpers do
        # Disambiguation logic for cases where multiple links exist with the same name
        # but different providers.
        def find_saml_group_link_with_provider(group, saml_group_name, provider_param)
          saml_group_links = SamlGroupLink.by_group_id(group.id).by_saml_group_name(saml_group_name)

          saml_group_links = saml_group_links.by_provider(provider_param.presence) if params.key?(:provider)

          if saml_group_links.count > 1 && !params.key?(:provider)
            render_api_error!(
              'Multiple group links found with the same name. Please specify a provider parameter to disambiguate.',
              422
            )
          elsif saml_group_links.exists?
            saml_group_links.first
          else
            not_found!
          end
        end
      end

      desc 'Lists SAML group links' do
        detail 'Get SAML group links for a group'
        success ::API::Entities::SamlGroupLink
        is_array true
        tags SAML_GROUP_LINKS
      end
      route_setting :authorization, permissions: :read_saml_group_link, boundary_type: :group
      get ":id/saml_group_links" do
        group = find_group(params[:id])
        unauthorized! unless can?(current_user, :admin_saml_group_links, group)

        saml_group_links = group.saml_group_links

        present saml_group_links, with: ::API::Entities::SamlGroupLink
      end

      desc 'Add SAML group link' do
        detail 'Add a SAML group link for a group'
        success ::API::Entities::SamlGroupLink
        failure [
          { code: 400, message: 'Validation error' },
          { code: 404, message: 'Not found' },
          { code: 422, message: 'Unprocessable entity' }
        ]
        tags SAML_GROUP_LINKS
      end
      params do
        requires 'saml_group_name', type: String, desc: 'The name of a SAML group'
        # rubocop:disable API/AccessLevelStringType -- Introduced before the cop
        requires 'access_level', type: Integer, values: Gitlab::Access.values_with_minimal_access,
          desc: 'Level of permissions for the linked SA group'
        # rubocop:enable API/AccessLevelStringType
        optional 'member_role_id', type: Integer, desc: 'The ID of the Member Role for the linked SA group'
        optional 'provider', type: String,
          desc: 'Provider string that must match for this group link to be applied'
      end
      route_setting :authorization, permissions: :create_saml_group_link, boundary_type: :group
      post ":id/saml_group_links" do
        group = find_group(params[:id])

        unauthorized! unless can?(current_user, :admin_saml_group_links, group)

        params.delete(:member_role_id) unless group.custom_roles_enabled?

        service = ::GroupSaml::SamlGroupLinks::CreateService.new(
          current_user: current_user,
          group: group,
          params: declared_params(include_missing: false)
        )
        response = service.execute

        if response.success?
          present service.saml_group_link, with: ::API::Entities::SamlGroupLink
        else
          render_api_error!(response[:error], response.http_status)
        end
      end

      desc 'Get SAML group link' do
        detail 'Get a SAML group link for the group'
        success ::API::Entities::SamlGroupLink
        failure [
          { code: 404, message: 'Not found' },
          { code: 422, message: 'Multiple links found, provider parameter required' }
        ]
        tags SAML_GROUP_LINKS
      end
      params do
        requires :saml_group_name, type: String, desc: 'Name of an SAML group'
        optional 'provider', type: String,
          desc: 'Provider string to disambiguate when multiple links exist with same name'
      end
      route_setting :authorization, permissions: :read_saml_group_link, boundary_type: :group
      get ":id/saml_group_links/:saml_group_name",
        requirements: { saml_group_name: ::API::NO_SLASH_URL_PART_REGEX }.merge(::API::NO_FORMAT_SUFFIX_REQUIREMENT) do
        group = find_group(params[:id])

        unauthorized! unless can?(current_user, :admin_saml_group_links, group)

        saml_group_link = find_saml_group_link_with_provider(group, params[:saml_group_name], params[:provider])

        present saml_group_link, with: ::API::Entities::SamlGroupLink
      end

      desc 'Delete SAML group link' do
        detail 'Deletes a SAML group link for the group'
        success ::API::Entities::SamlGroupLink
        failure [
          { code: 404, message: 'Not found' },
          { code: 422, message: 'Multiple links found, provider parameter required' }
        ]
        tags SAML_GROUP_LINKS
      end
      params do
        requires :saml_group_name, type: String, desc: 'Name of a SAML group'
        optional 'provider', type: String,
          desc: 'Provider string to disambiguate when multiple links exist with same name'
      end
      route_setting :authorization, permissions: :delete_saml_group_link, boundary_type: :group
      delete ":id/saml_group_links/:saml_group_name",
        requirements: { saml_group_name: ::API::NO_SLASH_URL_PART_REGEX }.merge(::API::NO_FORMAT_SUFFIX_REQUIREMENT) do
        group = find_group(params[:id])

        unauthorized! unless can?(current_user, :admin_saml_group_links, group)

        saml_group_link = find_saml_group_link_with_provider(group, params[:saml_group_name], params[:provider])

        ::GroupSaml::SamlGroupLinks::DestroyService.new(
          current_user: current_user, group: group, saml_group_link: saml_group_link
        ).execute

        no_content!
      end
    end
  end
end

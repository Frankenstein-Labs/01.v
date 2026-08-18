# frozen_string_literal: true

module Ai
  module Catalog
    class FoundationalFlow
      include ActiveRecord::FixedItemsModel::Model
      include GlobalID::Identification
      include Gitlab::Utils::StrongMemoize
      include Ai::Catalog::FoundationalFlow::Attributes
      include Ai::Catalog::FoundationalFlow::Items

      def self.find_by_reference(reference)
        find_by(foundational_flow_reference: reference)
      end

      def self.[](key)
        definition = find_by(foundational_flow_reference: key) || find_by(display_name: key)

        definition&.tap do |def_obj|
          def_obj.agent_privileges = def_obj.pre_approved_agent_privileges if def_obj.agent_privileges.empty?
        end
      end

      def self.beta?(foundational_flow_reference)
        flow = find_by(foundational_flow_reference: foundational_flow_reference)
        !!flow&.beta?
      end

      def self.ultimate_only?(foundational_flow_reference)
        flow = find_by(foundational_flow_reference: foundational_flow_reference)
        !!flow&.ultimate_only?
      end

      def self.code_review
        find_by!(foundational_flow_reference: Definitions::CodeReview::REFERENCE)
      end

      def self.available_for_group(group)
        all.select { |flow| flow.available_for?(group) }
      end

      def available_for?(namespace)
        return false if beta? && !namespace.duo_beta_flows_enabled?
        return false if ultimate_only? && !namespace.licensed_feature_available?(:ai_features)

        !blocked_by_feature_flag?(namespace)
      end

      def beta?
        feature_maturity == 'beta'
      end

      def ultimate_only?
        Gitlab::Utils.to_boolean(ultimate_only)
      end

      def blocked_by_feature_flag?(group)
        return false if feature_flag.blank?

        # rubocop:disable Gitlab/FeatureFlagKeyDynamic -- Need to check the flag defined by flow dynamically.
        ::Feature.disabled?(feature_flag.to_sym, group)
        # rubocop:enable Gitlab/FeatureFlagKeyDynamic
      end

      def agent_privileges
        privileges = super

        return pre_approved_agent_privileges if privileges.empty?

        privileges
      end

      def agent_privileges=(value)
        super(Array(value).map { |v| Integer(v) })
      end

      def pre_approved_agent_privileges=(value)
        super(Array(value).map { |v| Integer(v) })
      end

      def resolve_noteable_for(project:, goal:)
        noteable_resolver&.call(project: project, goal: goal)
      end

      def resolve_source_pipeline_for(project:, goal:)
        source_pipeline_resolver&.call(project: project, goal: goal)
      end

      def resolve_additional_context_for(resource:)
        context = additional_context_resolver&.call(resource: resource) || {}

        context.map do |category, content|
          {
            "Category" => category.to_s,
            "Content" => ::Gitlab::Json.dump(content)
          }
        end
      end

      def resolve_flow_version_for(container:, user:)
        resolved_reference, resolved_version =
          flow_version_resolver&.call(container: container, user: user) || [foundational_flow_reference, flow_version]

        flow_config_id, flow_config_schema_version = resolved_reference.split('/', 2)

        {
          flow_config_id: flow_config_id,
          flow_config_schema_version: flow_config_schema_version,
          flow_version: resolved_version
        }
      end

      def translated_display_name
        # rubocop:disable Gettext/StaticIdentifier -- Translations available in `fixed_items`.
        s_("FoundationalFlow|#{display_name}") if display_name
        # rubocop:enable Gettext/StaticIdentifier
      end

      def translated_description
        # rubocop:disable Gettext/StaticIdentifier -- Translations available in `fixed_items`.
        s_("FoundationalFlow|#{description}") if description
        # rubocop:enable Gettext/StaticIdentifier
      end

      def catalog_item
        return if foundational_flow_reference.nil?

        Ai::Catalog::Item.with_foundational_flow_reference(foundational_flow_reference).first
      end
      strong_memoize_attr :catalog_item
    end
  end
end

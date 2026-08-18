# frozen_string_literal: true

module EE
  module ResolvesGroups
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    PRELOADS = {
      vulnerability_namespace_statistic: [:vulnerability_namespace_statistic],
      analyzer_statuses: [:analyzer_group_statuses],
      knowledge_graph_enabled: [:knowledge_graph_enabled_namespace]
    }.freeze

    private

    def unconditional_includes
      [:saml_provider]
    end

    override :preloads
    def preloads
      super.merge(PRELOADS)
    end
  end
end

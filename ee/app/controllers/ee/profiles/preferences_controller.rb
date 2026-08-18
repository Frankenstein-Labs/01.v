# frozen_string_literal: true

module EE::Profiles::PreferencesController
  extend ActiveSupport::Concern
  extend ::Gitlab::Utils::Override

  prepended do
    before_action :set_knowledge_graph_governing_namespace_form_data, only: [:show]
  end

  override :preferences_param_names
  def preferences_param_names
    super + preferences_param_names_ee
  end

  def preferences_param_names_ee
    params_ee = []

    params_ee.push(:duo_default_namespace_id)

    if ::Ai::Orbit::Settings.user_preference_flag_enabled?(current_user)
      params_ee.push(:orbit_enabled, *::Ai::Orbit::Settings::SUBSETTINGS.values.map(&:to_sym))
    end

    if can?(current_user, :update_governing_knowledge_graph_namespace)
      params_ee.push(:knowledge_graph_governing_namespace_id)
    end

    params_ee.push(:group_view) if License.feature_available?(:security_dashboard)

    params_ee
  end

  private

  def set_knowledge_graph_governing_namespace_form_data
    return unless can?(current_user, :update_governing_knowledge_graph_namespace)

    candidates = ::Analytics::KnowledgeGraph::GoverningNamespaceFinder.new(current_user).candidates.to_a
    return unless candidates.size > 1

    @knowledge_graph_governing_namespace_candidates = candidates
    @knowledge_graph_governing_namespace_id =
      current_user.user_preference.knowledge_graph_governing_namespace_with_fallback&.id
  end
end

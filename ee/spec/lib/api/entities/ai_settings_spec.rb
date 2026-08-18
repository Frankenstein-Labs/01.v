# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::AiSettings, feature_category: :workflow_catalog do
  let_it_be(:group) { create(:group) }
  let_it_be(:ai_settings) { create(:namespace_ai_settings, namespace: group) }

  subject(:entity) { described_class.new(ai_settings).as_json }

  describe 'always-exposed attributes' do
    it 'exposes the expected fields' do
      expect(entity.keys).to include(
        :duo_agent_platform_enabled,
        :duo_workflow_mcp_enabled,
        :foundational_agents_default_enabled,
        :ai_catalog_restricted_to_group_hierarchy,
        :ai_usage_data_collection_enabled,
        :prompt_injection_protection_level
      )
    end
  end

  describe 'network access control attributes' do
    it 'exposes the attributes' do
      expect(entity.keys).to include(
        :include_recommended_allowed,
        :allow_all_unix_sockets,
        :allow_project_extension
      )
    end
  end

  describe 'minimum access level attributes' do
    it 'exposes the attributes' do
      expect(entity.keys).to include(
        :minimum_access_level_execute,
        :minimum_access_level_execute_async,
        :minimum_access_level_manage,
        :minimum_access_level_enable_on_projects
      )
    end

    context 'when access levels are set to integer values' do
      let_it_be(:group_with_levels) { create(:group) }
      let_it_be(:ai_settings_with_levels) do
        create(:namespace_ai_settings, namespace: group_with_levels,
          minimum_access_level_execute: Gitlab::Access::DEVELOPER,
          minimum_access_level_execute_async: Gitlab::Access::DEVELOPER,
          minimum_access_level_manage: Gitlab::Access::MAINTAINER,
          minimum_access_level_enable_on_projects: Gitlab::Access::MAINTAINER)
      end

      subject(:entity) { described_class.new(ai_settings_with_levels).as_json }

      it 'returns string access level values', :aggregate_failures do
        expect(entity[:minimum_access_level_execute]).to eq('developer')
        expect(entity[:minimum_access_level_execute_async]).to eq('developer')
        expect(entity[:minimum_access_level_manage]).to eq('maintainer')
        expect(entity[:minimum_access_level_enable_on_projects]).to eq('maintainer')
      end
    end

    context 'when minimum_access_level_execute is set to PLANNER' do
      let_it_be(:group_with_planner) { create(:group) }
      let_it_be(:ai_settings_with_planner) do
        create(:namespace_ai_settings, namespace: group_with_planner,
          minimum_access_level_execute: Gitlab::Access::PLANNER)
      end

      subject(:entity) { described_class.new(ai_settings_with_planner).as_json }

      it 'returns planner as the string access level value' do
        expect(entity[:minimum_access_level_execute]).to eq('planner')
      end
    end

    context 'when access level is not set' do
      let_it_be(:group_without_level) { create(:group) }
      let_it_be(:ai_settings_without_level) do
        create(:namespace_ai_settings, namespace: group_without_level, minimum_access_level_execute: nil)
      end

      subject(:entity) { described_class.new(ai_settings_without_level).as_json }

      it 'returns nil' do
        expect(entity[:minimum_access_level_execute]).to be_nil
      end
    end

    context 'when the dap_group_customizable_permissions feature flag is disabled' do
      before do
        stub_feature_flags(dap_group_customizable_permissions: false)
      end

      it 'does not expose the attributes' do
        expect(entity.keys).not_to include(
          :minimum_access_level_execute,
          :minimum_access_level_execute_async,
          :minimum_access_level_manage,
          :minimum_access_level_enable_on_projects
        )
      end
    end
  end
end

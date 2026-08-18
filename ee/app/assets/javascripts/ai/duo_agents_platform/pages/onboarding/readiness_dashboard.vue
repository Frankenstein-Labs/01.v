<script>
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { parseBoolean } from '~/lib/utils/common_utils';
import ReadinessBanner from './components/readiness_banner.vue';
import InitializerSection from './components/initializer_section.vue';
import {
  PROJECT_STATE_NOT_ENABLED,
  SECTION_CUSTOMIZE_AGENTS,
  EVENT_TYPE_EXECUTION_ENV,
  EVENT_TYPE_IMPROVE_CI,
} from './constants';
import { resolveProjectState, resolveAudience, isSectionVisible } from './utils';

export default {
  name: 'ReadinessDashboard',
  components: {
    PageHeading,
    ReadinessBanner,
    InitializerSection,
  },
  data() {
    const readiness = window.gon?.onboarding_readiness || {};
    const capabilities = window.gon?.onboarding_capabilities || {};

    return {
      canAdminProject: parseBoolean(capabilities.can_admin_project),
      dapAvailable: parseBoolean(readiness.dap_available),
      environmentHealthy: parseBoolean(readiness.environment_healthy),
      groupSettingsPath: readiness.group_settings_path || '',
      initializers: window.gon?.onboarding_initializers || [],
      setupPath: window.gon?.onboarding_setup_path || '',
    };
  },
  computed: {
    projectState() {
      return resolveProjectState({
        dapAvailable: this.dapAvailable,
        environmentHealthy: this.environmentHealthy,
      });
    },
    audience() {
      return resolveAudience(this.canAdminProject);
    },
    isNotEnabled() {
      return this.projectState === PROJECT_STATE_NOT_ENABLED;
    },
    title() {
      return this.isNotEnabled
        ? s__('DuoAgentsPlatform|GitLab Duo Agent Platform')
        : s__('DuoAgentsPlatform|Get this project ready for GitLab Duo Agent Platform');
    },
    intro() {
      return this.isNotEnabled
        ? s__(
            "DuoAgentsPlatform|The Agent Platform isn't enabled for this project yet. Here's what your group needs to do, and what you can already start on.",
          )
        : s__(
            'DuoAgentsPlatform|Set up what your project needs to work well with the Agent Platform. Start with the highest-impact step; the rest are recommendations you can take as they fit.',
          );
    },
    customizeInitializers() {
      return this.initializers.filter(
        (item) => ![EVENT_TYPE_EXECUTION_ENV, EVENT_TYPE_IMPROVE_CI].includes(item.event_type),
      );
    },
    showCustomizeAgents() {
      return isSectionVisible(SECTION_CUSTOMIZE_AGENTS, {
        state: this.projectState,
        audience: this.audience,
      });
    },
  },
  i18n: {
    customizeAgentsTitle: s__('DuoAgentsPlatform|Customize agents for this project'),
    customizeAgentsDescription: s__(
      'DuoAgentsPlatform|Files that tune how agents read and act on this codebase',
    ),
  },
};
</script>

<template>
  <div>
    <page-heading :heading="title">
      <template #description>{{ intro }}</template>
    </page-heading>

    <readiness-banner :state="projectState" :group-settings-path="groupSettingsPath" />

    <div class="gl-flex gl-flex-col gl-gap-5">
      <initializer-section
        v-if="showCustomizeAgents"
        :title="$options.i18n.customizeAgentsTitle"
        :description="$options.i18n.customizeAgentsDescription"
        icon="settings"
        anchor-id="readiness-customize-agents"
        testid="customize-agents-section"
        :initializers="customizeInitializers"
        :setup-path="setupPath"
      />
    </div>
  </div>
</template>

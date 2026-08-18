<script>
import SettingsSection from '~/vue_shared/components/settings/settings_section.vue';
import AgentMapping from 'ee_component/workspaces/agent_mapping/components/agent_mapping.vue';

export default {
  components: {
    SettingsSection,
    AgentMapping,
  },
};
</script>
<template>
  <settings-section
    :heading="s__('Workspaces|Group agents')"
    :description="
      s__(
        'Workspaces|Agents connect workspaces to your Kubernetes cluster. To create a workspace with an allowed agent, group members must have at least the Developer role.',
      )
    "
  >
    <agent-mapping />
  </settings-section>
</template>

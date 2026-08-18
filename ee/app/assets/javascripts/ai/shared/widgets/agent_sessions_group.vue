<script>
import { GlButton, GlAnimatedChevronLgDownUpIcon, GlCollapse } from '@gitlab/ui';
import { __ } from '~/locale';
import AgentStatusIcon from './agent_status_icon.vue';
import AgentSessionRow from './agent_session_row.vue';

export default {
  name: 'AgentSessionsGroup',
  components: {
    GlButton,
    GlAnimatedChevronLgDownUpIcon,
    GlCollapse,
    AgentStatusIcon,
    AgentSessionRow,
  },
  props: {
    group: {
      type: Object,
      required: true,
    },
    headerBgClass: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      collapsed: false,
    };
  },
  computed: {
    toggleLabel() {
      return this.collapsed ? __('Expand') : __('Collapse');
    },
  },
};
</script>

<template>
  <div>
    <h3
      data-testid="sessions-group-heading"
      class="gl-mb-0 gl-mt-0 gl-flex gl-items-center gl-gap-3 gl-rounded-base gl-px-3 gl-py-2 gl-text-sm gl-font-semibold gl-text-default"
      :class="headerBgClass"
    >
      <agent-status-icon
        :status="group.representativeSession.status"
        :human-status="group.representativeSession.humanStatus"
      />
      <span class="gl-grow">{{ group.title }}</span>
      <gl-button
        category="tertiary"
        size="small"
        :aria-expanded="`${!collapsed}`"
        :aria-label="toggleLabel"
        class="btn-icon -gl-mr-1"
        :data-testid="`toggle-sessions-${group.key}`"
        @click="collapsed = !collapsed"
      >
        <gl-animated-chevron-lg-down-up-icon :is-on="!collapsed" />
      </gl-button>
    </h3>
    <gl-collapse
      :visible="!collapsed"
      class="gl-divide-x-0 gl-divide-y-1 gl-divide-solid gl-divide-subtle gl-overflow-hidden gl-rounded-b-base"
      data-testid="sessions-group-body"
    >
      <agent-session-row
        v-for="session in group.sessions"
        :key="session.id"
        :session="session"
        :show-view-details="group.showViewDetails"
      />
    </gl-collapse>
  </div>
</template>

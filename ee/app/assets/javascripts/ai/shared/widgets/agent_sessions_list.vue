<script>
import { GlButton, GlAnimatedChevronLgDownUpIcon, GlCollapse } from '@gitlab/ui';
import { __, n__, sprintf } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import AgentSessionsGroup from './agent_sessions_group.vue';
import {
  SESSION_OTHER_GROUPS,
  SESSION_AWAITING_INPUT_GROUP,
  AWAITING_INPUT_HEADER_BG_CLASS,
  OTHER_GROUP_HEADER_BG_CLASS,
} from './constants';

const mapGroup = ({ statuses, title }, sessions, headerBgClass) => {
  const groupSessions = sessions.filter((s) => statuses.includes(s.status));
  return {
    key: statuses[0],
    sessions: groupSessions,
    representativeSession: groupSessions[0],
    title: sprintf(
      n__(
        'DuoAgentPlatform|%{count} session %{title}',
        'DuoAgentPlatform|%{count} sessions %{title}',
        groupSessions.length,
      ),
      { count: groupSessions.length, title },
    ),
    headerBgClass,
  };
};

export default {
  name: 'AgentSessionsList',
  components: {
    CrudComponent,
    GlButton,
    GlAnimatedChevronLgDownUpIcon,
    GlCollapse,
    AgentSessionsGroup,
  },
  props: {
    sessions: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      otherCollapsed: true,
    };
  },
  computed: {
    hasSessions() {
      return this.sessions.length > 0;
    },
    sessionCount() {
      return this.sessions.length || null;
    },
    awaitingInputGroup() {
      const group = mapGroup(
        {
          ...SESSION_AWAITING_INPUT_GROUP,
          title: SESSION_AWAITING_INPUT_GROUP.title.toLowerCase(),
        },
        this.sessions,
        AWAITING_INPUT_HEADER_BG_CLASS,
      );
      return group.sessions.length ? { ...group, showViewDetails: true } : null;
    },
    otherSessionGroups() {
      return SESSION_OTHER_GROUPS.map((groupDef) => ({
        ...mapGroup(
          { ...groupDef, title: groupDef.title.toLowerCase() },
          this.sessions,
          OTHER_GROUP_HEADER_BG_CLASS,
        ),
        rawTitle: groupDef.title.toLowerCase(),
        showViewDetails: false,
      })).filter(({ sessions }) => sessions.length > 0);
    },
    hasOtherSessions() {
      return this.otherSessionGroups.length > 0;
    },
    otherGroupsSummary() {
      return this.otherSessionGroups
        .map(({ sessions, rawTitle }) =>
          sprintf(__('%{count} %{label}'), { count: sessions.length, label: rawTitle }),
        )
        .join(' · ');
    },
    otherToggleLabel() {
      return this.otherCollapsed ? __('Show') : __('Hide');
    },
  },
};
</script>

<template>
  <crud-component
    v-if="hasSessions"
    :title="s__('DuoAgentPlatform|Sessions')"
    icon="session-ai"
    :count="sessionCount"
    :is-loading="isLoading"
    :is-collapsible="true"
    :collapsed="!awaitingInputGroup"
    body-class="!gl-py-2"
    data-testid="agent-sessions-widget"
  >
    <div class="gl-flex gl-flex-col gl-gap-2" data-testid="agent-sessions-list">
      <agent-sessions-group
        v-if="awaitingInputGroup"
        :group="awaitingInputGroup"
        :header-bg-class="awaitingInputGroup.headerBgClass"
      />
      <template v-if="hasOtherSessions">
        <template v-if="awaitingInputGroup">
          <div>
            <div
              data-testid="other-sessions-heading"
              class="gl-flex gl-flex-row gl-items-center gl-rounded-base gl-bg-strong gl-px-3 gl-py-2 gl-text-sm gl-text-heading"
            >
              <gl-button
                category="tertiary"
                size="small"
                :aria-expanded="`${!otherCollapsed}`"
                class="-gl-ml-1 gl-flex gl-w-fit gl-flex-row gl-items-center gl-gap-2 gl-font-semibold"
                button-text-classes="gl-flex gl-flex-row gl-gap-2 gl-text-sm"
                data-testid="toggle-sessions-other"
                @click="otherCollapsed = !otherCollapsed"
              >
                <gl-animated-chevron-lg-down-up-icon :is-on="!otherCollapsed" />
                {{ otherToggleLabel }}
              </gl-button>
              <span class="gl-text-sm gl-text-subtle">{{ otherGroupsSummary }}</span>
            </div>
            <gl-collapse :visible="!otherCollapsed" class="gl-flex gl-flex-col gl-gap-2 gl-pt-2">
              <agent-sessions-group
                v-for="group in otherSessionGroups"
                :key="group.key"
                :group="group"
                :header-bg-class="group.headerBgClass"
              />
            </gl-collapse>
          </div>
        </template>
        <template v-else>
          <agent-sessions-group
            v-for="group in otherSessionGroups"
            :key="group.key"
            :group="group"
            :header-bg-class="group.headerBgClass"
          />
        </template>
      </template>
    </div>
  </crud-component>
</template>

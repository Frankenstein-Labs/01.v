<script>
import { uniqueId } from 'lodash-es';
import { GlDisclosureDropdown, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import { WORKSPACE_DESIRED_STATES, WORKSPACE_STATES } from '../constants';

const ACTIONS = [
  {
    key: 'restart',
    isVisible: (displayState) =>
      [WORKSPACE_STATES.failed, WORKSPACE_STATES.error, WORKSPACE_STATES.unknown].includes(
        displayState,
      ),
    desiredState: WORKSPACE_DESIRED_STATES.restartRequested,
    title: s__('Workspaces|Restart'),
  },
  {
    key: 'start',
    isVisible: (displayState) => displayState === WORKSPACE_STATES.stopped,
    desiredState: WORKSPACE_DESIRED_STATES.running,
    title: s__('Workspaces|Start'),
  },
  {
    key: 'stop',
    isVisible: (displayState) => displayState === WORKSPACE_STATES.running,
    desiredState: WORKSPACE_DESIRED_STATES.stopped,
    title: s__('Workspaces|Stop'),
  },
  {
    key: 'terminate',
    isVisible: (displayState) =>
      ![WORKSPACE_STATES.terminated, WORKSPACE_STATES.terminating].includes(displayState),
    desiredState: WORKSPACE_DESIRED_STATES.terminated,
    title: s__('Workspaces|Terminate'),
    variant: 'danger',
  },
];

export default {
  components: {
    GlDisclosureDropdown,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    workspaceDisplayState: {
      type: String,
      required: true,
      validator: (value) => Object.values(WORKSPACE_STATES).includes(value),
    },
  },
  emits: ['click'],
  computed: {
    actions() {
      return ACTIONS.filter(({ isVisible }) => isVisible(this.workspaceDisplayState)).map(
        ({ desiredState, key, title, extraAttrs }) => {
          return {
            key,
            id: uniqueId(`action-wrapper-${key}`),
            text: title,
            action: () => this.$emit('click', desiredState),
            extraAttrs,
          };
        },
      );
    },
  },
};
</script>

<template>
  <gl-disclosure-dropdown
    v-if="actions.length > 0"
    :items="actions"
    icon="ellipsis_v"
    toggle-text="Actions"
    text-sr-only
    category="tertiary"
    no-caret
    data-testid="workspace-actions-dropdown"
  >
    <template #list-item="{ item }">
      <span :id="item.id" :key="item.key" :data-testid="`workspace-${item.key}-button`">
        {{ item.text }}
      </span>
    </template>
  </gl-disclosure-dropdown>
</template>

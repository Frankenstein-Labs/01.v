<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import { WORKSPACE_STATES, CLICK_OPEN_WORKSPACE_BUTTON_EVENT_NAME } from '../constants';

const trackingMixin = InternalEvents.mixin();

export default {
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [trackingMixin],
  props: {
    workspaceDisplayState: {
      type: String,
      required: true,
      validator: (value) => Object.values(WORKSPACE_STATES).includes(value),
    },
    workspaceUrl: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    displayOpenWorkspaceButton() {
      return this.workspaceDisplayState === WORKSPACE_STATES.running && this.workspaceUrl !== '';
    },
    displayStartingWorkspaceIndicator() {
      return [WORKSPACE_STATES.creationRequested, WORKSPACE_STATES.starting].includes(
        this.workspaceDisplayState,
      );
    },
  },
  CLICK_OPEN_WORKSPACE_BUTTON_EVENT_NAME,
};
</script>
<template>
  <span>
    <gl-button
      v-if="displayOpenWorkspaceButton"
      :href="workspaceUrl"
      class="gl-w-full @sm/panel:gl-w-auto"
      data-testid="workspace-open-button"
      target="_blank"
      @click="trackEvent($options.CLICK_OPEN_WORKSPACE_BUTTON_EVENT_NAME)"
    >
      {{ s__('Workspaces|Open workspace') }}
    </gl-button>
    <span
      v-if="displayStartingWorkspaceIndicator"
      v-gl-tooltip
      :title="s__('Workspaces|You can open the workspace only once it is ready.')"
    >
      <gl-button loading>
        {{ s__('Workspaces|Starting workspace') }}
      </gl-button>
    </span>
  </span>
</template>

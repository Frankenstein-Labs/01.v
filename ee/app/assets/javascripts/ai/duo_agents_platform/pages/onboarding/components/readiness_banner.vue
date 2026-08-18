<script>
import { GlAlert } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import {
  PROJECT_STATE_READY,
  PROJECT_STATE_ENVIRONMENT_PROBLEM,
  PROJECT_STATE_NOT_ENABLED,
} from '../constants';

export default {
  name: 'ReadinessBanner',
  components: { GlAlert },
  props: {
    state: {
      type: String,
      required: true,
    },
    groupSettingsPath: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      dismissed: false,
    };
  },
  computed: {
    config() {
      return this.$options.banners[this.state] || null;
    },
    primaryButtonLink() {
      if (this.state === PROJECT_STATE_NOT_ENABLED) return this.groupSettingsPath;
      if (this.state === PROJECT_STATE_ENVIRONMENT_PROBLEM) return this.$options.setupGuideUrl;
      return '';
    },
  },
  methods: {
    onDismiss() {
      this.dismissed = true;
    },
  },
  setupGuideUrl: helpPagePath('user/duo_agent_platform/_index'),
  banners: {
    [PROJECT_STATE_READY]: {
      variant: 'success',
      dismissible: true,
      title: s__('DuoAgentsPlatform|Your project environment is healthy'),
      body: s__(
        'DuoAgentsPlatform|Agent Platform health checks pass and runners are available to this project.',
      ),
      primaryButtonText: null,
    },
    [PROJECT_STATE_ENVIRONMENT_PROBLEM]: {
      variant: 'warning',
      dismissible: true,
      title: s__("DuoAgentsPlatform|Flows can't run yet"),
      body: s__(
        'DuoAgentsPlatform|No runner is available to this project. You can still prepare the repository below while this is fixed.',
      ),
      primaryButtonText: s__('DuoAgentsPlatform|Open setup guide'),
    },
    [PROJECT_STATE_NOT_ENABLED]: {
      variant: 'warning',
      dismissible: false,
      title: s__("DuoAgentsPlatform|The Agent Platform isn't enabled for this project yet"),
      body: s__(
        "DuoAgentsPlatform|Until your group enables it, agents and flows can't run on this project. You can still install local tools below, and review what setup is required.",
      ),
      primaryButtonText: s__('DuoAgentsPlatform|Open group settings'),
    },
  },
};
</script>

<template>
  <gl-alert
    v-if="config && !dismissed"
    :variant="config.variant"
    :dismissible="config.dismissible"
    :title="config.title"
    :primary-button-text="config.primaryButtonText"
    :primary-button-link="primaryButtonLink"
    class="gl-mb-5"
    data-testid="readiness-banner"
    @dismiss="onDismiss"
  >
    {{ config.body }}
  </gl-alert>
</template>

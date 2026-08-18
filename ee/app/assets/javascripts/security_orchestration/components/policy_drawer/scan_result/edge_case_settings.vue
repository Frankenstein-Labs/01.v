<script>
import { s__, n__ } from '~/locale';
import {
  UNBLOCK_RULES_KEY,
  UNBLOCK_RULES_TEXT,
  TIME_WINDOW_KEY,
  TIME_WINDOW_TEXT,
} from '../../policy_editor/scan_result/advanced_settings/constants';

export default {
  name: 'EdgeCaseSettings',
  i18n: {
    title: s__('SecurityOrchestration|Edge case settings'),
    [UNBLOCK_RULES_KEY]: UNBLOCK_RULES_TEXT,
    [TIME_WINDOW_KEY]: TIME_WINDOW_TEXT,
  },
  props: {
    settings: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    settingsList() {
      return Object.entries(this.settings)
        .map(([key, value]) => {
          if (key === TIME_WINDOW_KEY) {
            return this.renderTimeWindowSetting(value);
          }

          return this.$options.i18n[key] || key;
        })
        .filter(Boolean);
    },
  },
  methods: {
    renderTimeWindowSetting(time) {
      if (!Number.isInteger(time)) {
        return '';
      }

      return `${TIME_WINDOW_TEXT}: ${n__('%d minute', '%d minutes', time)}`;
    },
  },
};
</script>

<template>
  <div class="gl-mt-5">
    <h5>{{ $options.i18n.title }}</h5>
    <p v-for="key in settingsList" :key="key" class="gl-mb-2">
      {{ key }}
    </p>
  </div>
</template>

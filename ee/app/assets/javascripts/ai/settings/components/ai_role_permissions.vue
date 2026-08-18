<script>
import { GlFormGroup, GlFormSelect } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  ACCESS_LEVEL_DEVELOPER_INTEGER,
  ACCESS_LEVEL_MAINTAINER_INTEGER,
  ACCESS_LEVEL_ADMIN_INTEGER,
  ACCESS_LEVEL_OWNER_INTEGER,
  ACCESS_LEVEL_ADMIN,
  ACCESS_LEVEL_LABELS,
  ACCESS_LEVEL_GUEST_INTEGER,
  ACCESS_LEVEL_REPORTER_INTEGER,
  ACCESS_LEVEL_PLANNER_INTEGER,
} from '~/access_level/constants';

import { ACCESS_LEVEL_EVERYONE_INTEGER } from '../constants';

const ALL_ACCESS_LEVELS_LABELS = {
  [ACCESS_LEVEL_EVERYONE_INTEGER]: s__('AiPowered|Everyone'),
  ...ACCESS_LEVEL_LABELS,
  [ACCESS_LEVEL_ADMIN_INTEGER]: ACCESS_LEVEL_ADMIN,
};

export default {
  name: 'AiRolePermissions',
  components: {
    GlFormGroup,
    GlFormSelect,
  },
  inject: ['isSaaS'],
  props: {
    initialMinimumAccessLevelExecuteAsync: {
      type: Number,
      required: true,
    },
    initialMinimumAccessLevelExecuteSync: {
      type: Number,
      required: true,
    },
  },
  emits: ['minimum-access-level-execute-async-change', 'minimum-access-level-execute-sync-change'],
  data() {
    return {
      minimumAccessLevelExecuteAsync: this.initialMinimumAccessLevelExecuteAsync,
      minimumAccessLevelExecuteSync: this.initialMinimumAccessLevelExecuteSync,
    };
  },
  computed: {
    minimumAccessLevelExecuteAsyncOptions() {
      const roles = [
        ACCESS_LEVEL_DEVELOPER_INTEGER,
        ACCESS_LEVEL_MAINTAINER_INTEGER,
        ACCESS_LEVEL_OWNER_INTEGER,
      ];
      if (!this.isSaaS) {
        roles.push(ACCESS_LEVEL_ADMIN_INTEGER);
      }
      return this.generateSelectOptions(roles);
    },
    minimumAccessLevelExecuteSyncOptions() {
      const roles = [
        ACCESS_LEVEL_EVERYONE_INTEGER,
        ACCESS_LEVEL_GUEST_INTEGER,
        ACCESS_LEVEL_PLANNER_INTEGER,
        ACCESS_LEVEL_REPORTER_INTEGER,
        ACCESS_LEVEL_DEVELOPER_INTEGER,
        ACCESS_LEVEL_MAINTAINER_INTEGER,
        ACCESS_LEVEL_OWNER_INTEGER,
      ];

      if (!this.isSaaS) {
        roles.push(ACCESS_LEVEL_ADMIN_INTEGER);
      }

      return this.generateSelectOptions(roles);
    },
  },
  methods: {
    generateSelectOptions(roles) {
      return roles.map((role) => ({
        text: ALL_ACCESS_LEVELS_LABELS[role],
        value: role,
      }));
    },
    changeMinimumAccessLevelExecuteAsync(role) {
      this.minimumAccessLevelExecuteAsync = role;
      this.$emit('minimum-access-level-execute-async-change', role);
    },
    changeMinimumAccessLevelExecuteSync(role) {
      this.minimumAccessLevelExecuteSync = role;
      this.$emit('minimum-access-level-execute-sync-change', role);
    },
  },
  i18n: {
    minimumAccessLevelExecuteAsyncLabel: s__('AiPowered|Features with CI/CD pipelines'),
    minimumAccessLevelExecuteSyncLabel: s__('AiPowered|Features without CI/CD pipelines'),
    sectionDescription: s__(
      'AiPowered|Control who can access AI-native features executed with or without CI/CD pipelines.',
    ),
    sectionTitle: s__('AiPowered|Access to GitLab Duo Agent Platform'),
  },
};
</script>
<template>
  <div>
    <gl-form-group :label="$options.i18n.sectionTitle" class="gl-mb-0">
      <template #label-description>
        <p class="gl-mb-3 gl-text-subtle">{{ $options.i18n.sectionDescription }}</p>
      </template>

      <div>
        <gl-form-group
          :label="$options.i18n.minimumAccessLevelExecuteAsyncLabel"
          label-for="minimum-access-level-execute-async-selector"
        >
          <gl-form-select
            id="minimum-access-level-execute-async-selector"
            v-model="minimumAccessLevelExecuteAsync"
            :options="minimumAccessLevelExecuteAsyncOptions"
            data-testid="minimum-access-level-execute-async-selector"
            class="gl-max-w-26"
            @change="changeMinimumAccessLevelExecuteAsync"
          />
        </gl-form-group>

        <gl-form-group
          :label="$options.i18n.minimumAccessLevelExecuteSyncLabel"
          label-for="minimum-access-level-execute-sync-selector"
        >
          <gl-form-select
            id="minimum-access-level-execute-sync-selector"
            v-model="minimumAccessLevelExecuteSync"
            :options="minimumAccessLevelExecuteSyncOptions"
            data-testid="minimum-access-level-execute-sync-selector"
            class="gl-max-w-26"
            @change="changeMinimumAccessLevelExecuteSync"
          />
        </gl-form-group>
      </div>
    </gl-form-group>
  </div>
</template>

<script>
import { GlFormCheckbox, GlFormGroup, GlTooltipDirective } from '@gitlab/ui';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';

export default {
  name: 'DuoCustomAgentsAndFlowsSettings',
  components: {
    CascadingLockIcon,
    GlFormCheckbox,
    GlFormGroup,
  },
  directives: {
    tooltip: GlTooltipDirective,
  },
  inject: {
    duoCustomAgentsCascadingSettings: { default: null },
    duoCustomFlowsCascadingSettings: { default: null },
    duoExternalAgentsCascadingSettings: { default: null },
  },
  props: {
    customAgentsEnabled: {
      type: Boolean,
      required: true,
    },
    customFlowsEnabled: {
      type: Boolean,
      required: true,
    },
    externalAgentsEnabled: {
      type: Boolean,
      required: true,
    },
    disabledCheckbox: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['change-custom-agents', 'change-custom-flows', 'change-external-agents'],
  computed: {
    customAgentsModel: {
      get() {
        return this.customAgentsEnabled;
      },
      set(value) {
        this.$emit('change-custom-agents', value);
      },
    },
    customFlowsModel: {
      get() {
        return this.customFlowsEnabled;
      },
      set(value) {
        this.$emit('change-custom-flows', value);
      },
    },
    externalAgentsModel: {
      get() {
        return this.externalAgentsEnabled;
      },
      set(value) {
        this.$emit('change-external-agents', value);
      },
    },
    customAgentsLockedByCascading() {
      return Boolean(
        this.duoCustomAgentsCascadingSettings?.lockedByAncestor ||
        this.duoCustomAgentsCascadingSettings?.lockedByApplicationSetting,
      );
    },
    customFlowsLockedByCascading() {
      return Boolean(
        this.duoCustomFlowsCascadingSettings?.lockedByAncestor ||
        this.duoCustomFlowsCascadingSettings?.lockedByApplicationSetting,
      );
    },
    externalAgentsLockedByCascading() {
      return Boolean(
        this.duoExternalAgentsCascadingSettings?.lockedByAncestor ||
        this.duoExternalAgentsCascadingSettings?.lockedByApplicationSetting,
      );
    },
  },
};
</script>

<template>
  <gl-form-group :label="s__('AiPowered|Custom and external agents and flows')" class="gl-my-4">
    <gl-form-checkbox
      v-model="customAgentsModel"
      data-testid="duo-custom-agents-checkbox"
      :disabled="disabledCheckbox || customAgentsLockedByCascading"
    >
      <div class="gl-flex">
        <span
          v-tooltip:[disabledCheckbox]="
            s__('AiPowered|This setting only applies when GitLab Duo is available.')
          "
          >{{ s__('AiPowered|Allow custom agents') }}</span
        >
        <cascading-lock-icon
          v-if="customAgentsLockedByCascading"
          class="gl-relative gl--inset-y-3"
          :is-locked-by-group-ancestor="duoCustomAgentsCascadingSettings.lockedByAncestor"
          :is-locked-by-application-settings="
            duoCustomAgentsCascadingSettings.lockedByApplicationSetting
          "
          :ancestor-namespace="duoCustomAgentsCascadingSettings.ancestorNamespace"
        />
      </div>
      <template #help>{{
        s__(
          'AiPowered|Users with the Maintainer or Owner role for a project can create new agents.',
        )
      }}</template>
    </gl-form-checkbox>

    <gl-form-checkbox
      v-model="externalAgentsModel"
      data-testid="duo-external-agents-checkbox"
      :disabled="disabledCheckbox || externalAgentsLockedByCascading"
    >
      <div class="gl-flex">
        <span
          v-tooltip:[disabledCheckbox]="
            s__('AiPowered|This setting only applies when GitLab Duo is available.')
          "
          >{{ s__('AiPowered|Allow external agents') }}</span
        >
        <cascading-lock-icon
          v-if="externalAgentsLockedByCascading"
          class="gl-relative gl--inset-y-3"
          :is-locked-by-group-ancestor="duoExternalAgentsCascadingSettings.lockedByAncestor"
          :is-locked-by-application-settings="
            duoExternalAgentsCascadingSettings.lockedByApplicationSetting
          "
          :ancestor-namespace="duoExternalAgentsCascadingSettings.ancestorNamespace"
        />
      </div>
      <template #help>{{
        s__(
          'AiPowered|Users with the Maintainer or Owner role for a project can use external agents.',
        )
      }}</template>
    </gl-form-checkbox>

    <gl-form-checkbox
      v-model="customFlowsModel"
      data-testid="duo-custom-flows-checkbox"
      :disabled="disabledCheckbox || customFlowsLockedByCascading"
    >
      <div class="gl-flex">
        <span
          v-tooltip:[disabledCheckbox]="
            s__('AiPowered|This setting only applies when GitLab Duo is available.')
          "
          >{{ s__('AiPowered|Allow custom flows') }}</span
        >
        <cascading-lock-icon
          v-if="customFlowsLockedByCascading"
          class="gl-relative gl--inset-y-3"
          :is-locked-by-group-ancestor="duoCustomFlowsCascadingSettings.lockedByAncestor"
          :is-locked-by-application-settings="
            duoCustomFlowsCascadingSettings.lockedByApplicationSetting
          "
          :ancestor-namespace="duoCustomFlowsCascadingSettings.ancestorNamespace"
        />
      </div>
      <template #help>{{
        s__('AiPowered|Users with the Maintainer or Owner role for a project can create new flows.')
      }}</template>
    </gl-form-checkbox>
  </gl-form-group>
</template>

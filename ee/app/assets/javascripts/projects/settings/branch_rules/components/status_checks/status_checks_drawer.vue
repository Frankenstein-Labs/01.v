<script>
import { GlDrawer } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import StatusChecksForm from './status_checks_form.vue';

export default {
  DRAWER_Z_INDEX,
  name: 'StatusChecksDrawer',
  i18n: {
    addStatusCheck: s__('BranchRules|Add status check'),
    editStatusCheck: s__('BranchRules|Edit status check'),
  },
  components: {
    GlDrawer,
    StatusChecksForm,
  },
  props: {
    selectedStatusCheck: {
      type: Object,
      required: false,
      default: () => null,
    },
    isOpen: {
      type: Boolean,
      required: false,
      default: false,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    serverValidationErrors: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['close-status-check-drawer', 'save-status-check-change'],
  computed: {
    getDrawerHeaderHeight() {
      return getContentWrapperHeight();
    },
    drawerTitle() {
      return this.selectedStatusCheck
        ? this.$options.i18n.editStatusCheck
        : this.$options.i18n.addStatusCheck;
    },
  },
  methods: {
    emitSaveEvent(statusCheck) {
      this.$emit(
        'save-status-check-change',
        statusCheck,
        this.selectedStatusCheck ? 'edit' : 'create',
      );
    },
  },
};
</script>

<template>
  <gl-drawer
    :header-height="getDrawerHeaderHeight"
    :z-index="$options.DRAWER_Z_INDEX"
    :open="isOpen"
    @close="$emit('close-status-check-drawer')"
  >
    <template #title>
      <h2 class="gl-my-0 gl-text-size-h2">
        {{ drawerTitle }}
      </h2>
    </template>

    <template #default>
      <status-checks-form
        :selected-status-check="selectedStatusCheck"
        :is-loading="isLoading"
        :server-validation-errors="serverValidationErrors"
        data-testid="status-checks-form"
        @save-status-check-change="emitSaveEvent"
        @close-status-check-drawer="$emit('close-status-check-drawer')"
      />
    </template>
  </gl-drawer>
</template>

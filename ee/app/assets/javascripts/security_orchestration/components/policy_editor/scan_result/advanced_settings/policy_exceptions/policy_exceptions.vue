<script>
import { isEmpty } from 'lodash-es';
import { GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import { ROLES } from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';
import PolicyExceptionsModal from './policy_exceptions_modal.vue';
import PolicyExceptionsSelectedList from './policy_exceptions_selected_list.vue';

export default {
  i18n: {
    addButtonText: s__('ScanResultPolicy|Add exception'),
    title: s__('ScanResultPolicy|Policy Exception settings'),
  },
  name: 'PolicyExceptions',
  components: {
    GlButton,
    PolicyExceptionsModal,
    PolicyExceptionsSelectedList,
  },
  props: {
    exceptions: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['changed'],
  data() {
    return {
      selectedTab: null,
    };
  },
  computed: {
    hasExceptions() {
      return !isEmpty(this.exceptions);
    },
  },
  methods: {
    emitChanges(changes) {
      this.$emit('changed', 'bypass_settings', changes);
    },
    selectTab(tab) {
      this.selectedTab = tab;
      this.showModal();
    },
    showModal() {
      this.$refs.modal.showModalWindow();
    },
    showNewModal() {
      this.selectedTab = null;
      this.showModal();
    },
    removeException(key) {
      const { [key]: removed, ...exceptions } = this.exceptions;

      if (key === ROLES) {
        delete exceptions.custom_roles;
      }

      this.emitChanges(exceptions);
    },
  },
};
</script>

<template>
  <div>
    <h4>{{ $options.i18n.title }}</h4>

    <policy-exceptions-modal
      ref="modal"
      :exceptions="exceptions"
      :selected-tab="selectedTab"
      @select-tab="selectTab"
      @changed="emitChanges"
    />

    <policy-exceptions-selected-list
      v-if="hasExceptions"
      :selected-exceptions="exceptions"
      @edit-item="selectTab"
      @remove="removeException"
    />

    <div class="security-policies-bg-subtle gl-w-full gl-rounded-base gl-px-2 gl-py-3">
      <gl-button
        icon="plus"
        category="tertiary"
        variant="confirm"
        size="small"
        @click="showNewModal"
      >
        {{ $options.i18n.addButtonText }}
      </gl-button>
    </div>
  </div>
</template>

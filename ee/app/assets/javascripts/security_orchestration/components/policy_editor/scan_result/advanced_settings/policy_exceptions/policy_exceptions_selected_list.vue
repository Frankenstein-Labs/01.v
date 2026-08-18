<script>
import { EXCEPTIONS_FULL_OPTIONS_MAP } from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';
import {
  countItemsLength,
  onlyValidKeys,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/utils';
import PolicyExceptionsSelectedItem from './policy_exceptions_selected_item.vue';

export default {
  name: 'PolicyExceptionsSelectedList',
  components: {
    PolicyExceptionsSelectedItem,
  },
  props: {
    selectedExceptions: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['edit-item', 'remove'],
  computed: {
    hasExceptions() {
      return this.formattedSelectedExceptions.length > 0;
    },
    formattedSelectedExceptions() {
      return onlyValidKeys(Object.keys(this.selectedExceptions)).map((key) => {
        return {
          title: EXCEPTIONS_FULL_OPTIONS_MAP[key]?.header,
          count: countItemsLength({ source: this.selectedExceptions, key }),
          key,
        };
      });
    },
  },
  methods: {
    editItem(key) {
      this.$emit('edit-item', key);
    },
    removeItem(key) {
      this.$emit('remove', key);
    },
  },
};
</script>

<template>
  <div :class="{ 'gl-mb-2': hasExceptions }">
    <policy-exceptions-selected-item
      v-for="exception in formattedSelectedExceptions"
      :key="exception.title"
      :count="exception.count"
      :exception-key="exception.key"
      :title="exception.title"
      @select-item="editItem"
      @remove="removeItem"
    />
  </div>
</template>

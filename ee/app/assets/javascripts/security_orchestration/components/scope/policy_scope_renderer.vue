<script>
import { isGroup as isGroupUtil } from 'ee/security_orchestration/components/utils';
import LoaderWithMessage from 'ee/security_orchestration/components/loader_with_message.vue';
import { resolveScopeType } from './scope_type_config';

export default {
  name: 'PolicyScopeRenderer',
  components: { LoaderWithMessage },
  inject: ['namespaceType'],
  props: {
    variant: {
      type: String,
      required: true,
      validator: (v) => ['drawer', 'list'].includes(v),
    },
    policyScope: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    isInstanceLevel: {
      type: Boolean,
      required: false,
      default: false,
    },
    linkedSppItems: {
      type: Array,
      required: false,
      default: () => [],
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    isGroup() {
      return isGroupUtil(this.namespaceType);
    },
    resolved() {
      return resolveScopeType(this.policyScope, this.variant, {
        isGroup: this.isGroup,
        isInstanceLevel: this.isInstanceLevel,
        linkedSppItems: this.linkedSppItems,
      });
    },
    resolvedProps() {
      return this.resolved.props || {};
    },
  },
};
</script>

<template>
  <loader-with-message v-if="loading" />
  <component :is="resolved.component" v-else v-bind="resolvedProps" />
</template>

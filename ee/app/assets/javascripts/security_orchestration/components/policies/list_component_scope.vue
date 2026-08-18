<script>
import { s__ } from '~/locale';
import { isProject } from 'ee/security_orchestration/components/utils';
import PolicyScopeRenderer from 'ee/security_orchestration/components/scope/policy_scope_renderer.vue';

export default {
  name: 'ListComponentScope',
  components: { PolicyScopeRenderer },
  i18n: {
    defaultText: s__('SecurityOrchestration|This project'),
  },
  inject: ['namespaceType'],
  props: {
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
    policyScope: {
      type: Object,
      required: false,
      default: null,
    },
  },
  computed: {
    isProject() {
      return isProject(this.namespaceType);
    },
    hasMultipleProjectsLinked() {
      return this.linkedSppItems.length > 1;
    },
    showDefaultText() {
      return this.isProject && !this.hasMultipleProjectsLinked;
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-baseline gl-gap-3">
    <p v-if="showDefaultText" class="gl-m-0" data-testid="default-text">
      {{ $options.i18n.defaultText }}
    </p>
    <policy-scope-renderer
      v-else
      variant="list"
      :policy-scope="policyScope"
      :is-instance-level="isInstanceLevel"
      :linked-spp-items="linkedSppItems"
    />
  </div>
</template>

<script>
import {
  DEFAULT_PROJECT_TEXT,
  SCOPE_TITLE,
} from 'ee/security_orchestration/components/policy_drawer/constants';
import { isGroup, isProject } from 'ee/security_orchestration/components/utils';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import PolicyScopeRenderer from '../scope/policy_scope_renderer.vue';
import InfoRow from './info_row.vue';

export default {
  name: 'ScopeInfoRow',
  components: { InfoRow, PolicyScopeRenderer },
  i18n: {
    scopeTitle: SCOPE_TITLE,
    defaultProjectText: DEFAULT_PROJECT_TEXT,
  },
  inject: ['namespaceType', 'namespacePath'],
  apollo: {
    linkedSppItems: {
      query: getSppLinkedProjectsGroups,
      variables() {
        return {
          fullPath: this.namespacePath,
        };
      },
      update(data) {
        const {
          securityPolicyProjectLinkedProjects: { nodes: linkedProjects = [] } = {},
          securityPolicyProjectLinkedGroups: { nodes: linkedGroups = [] } = {},
        } = data?.project || {};

        return [...linkedProjects, ...linkedGroups];
      },
      skip() {
        return this.isGroup;
      },
      error() {
        this.$emit('linked-spp-query-error');
      },
    },
  },
  props: {
    isInstanceLevel: {
      type: Boolean,
      required: false,
      default: false,
    },
    policyScope: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['linked-spp-query-error'],
  data() {
    return {
      linkedSppItems: [],
    };
  },
  computed: {
    isGroup() {
      return isGroup(this.namespaceType);
    },
    isProject() {
      return isProject(this.namespaceType);
    },
    hasMultipleProjectsLinked() {
      return this.linkedSppItems.length > 1;
    },
    showDefaultText() {
      return this.isProject && !this.hasMultipleProjectsLinked;
    },
    showLoader() {
      return this.$apollo.queries.linkedSppItems?.loading && this.isProject;
    },
  },
};
</script>

<template>
  <info-row :label="$options.i18n.scopeTitle" data-testid="policy-scope">
    <p v-if="showDefaultText && !showLoader" class="gl-m-0" data-testid="default-project-text">
      {{ $options.i18n.defaultProjectText }}
    </p>
    <policy-scope-renderer
      v-else
      variant="drawer"
      :policy-scope="policyScope"
      :is-instance-level="isInstanceLevel"
      :linked-spp-items="linkedSppItems"
      :loading="showLoader"
    />
  </info-row>
</template>

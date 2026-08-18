<script>
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { joinPaths } from '~/lib/utils/url_utility';
import FrameworkBadge from 'ee_component/compliance_dashboard/components/shared/framework_badge.vue';
import projectsComplianceFrameworks from '../graphql/project_compliance_frameworks.query.graphql';

export default {
  name: 'ComplianceInfo',
  components: {
    FrameworkBadge,
  },
  props: {
    projectPath: {
      type: String,
      required: true,
    },
    complianceCenterPath: {
      type: String,
      required: true,
    },
    canViewDashboard: {
      type: Boolean,
      required: true,
    },
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    project: {
      query: projectsComplianceFrameworks,
      variables() {
        return {
          fullPath: this.projectPath,
        };
      },
      update(data) {
        this.complianceFrameworks = data?.project?.complianceFrameworks?.nodes || [];
      },
      error(error) {
        Sentry.captureException(error);
      },
    },
  },
  data() {
    return {
      complianceFrameworks: [],
    };
  },
  computed: {
    hasComplianceFrameworks() {
      return this.complianceFrameworks.length > 0;
    },
  },
  methods: {
    getViewDetailsUrl(frameworkId) {
      return joinPaths(
        gon.gitlab_url,
        `${this.complianceCenterPath}?id=${getIdFromGraphQLId(frameworkId)}`,
      );
    },
  },
};
</script>

<template>
  <div
    v-if="hasComplianceFrameworks"
    class="project-page-sidebar-block gl-border-b gl-border-subtle gl-py-4"
  >
    <h5 class="gl-heading-5 gl-mb-3">
      {{ s__('ComplianceFrameworks|Compliance frameworks applied') }}
    </h5>
    <framework-badge
      v-for="(framework, index) in complianceFrameworks"
      :key="framework.id"
      class="gl-mb-2 gl-mr-2 gl-inline-block gl-cursor-pointer"
      :popover-mode="canViewDashboard ? 'details' : 'disabled'"
      :framework="framework"
      :data-testid="`framework-badge-${index}`"
      :view-details-url="getViewDetailsUrl(framework.id)"
    />
  </div>
</template>

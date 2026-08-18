<script>
import { MAX_DISPLAYED_VULNERABILITIES_PER_DEPENDENCY } from './constants';
import DependencyVulnerability from './dependency_vulnerability.vue';

export default {
  name: 'DependencyVulnerabilities',
  components: {
    DependencyVulnerability,
  },
  props: {
    vulnerabilities: {
      type: Array,
      required: true,
    },
  },
  computed: {
    renderableVulnerabilities() {
      return this.vulnerabilities.slice(0, MAX_DISPLAYED_VULNERABILITIES_PER_DEPENDENCY);
    },
    vulnerabilitiesNotShown() {
      return this.vulnerabilities.length - this.renderableVulnerabilities.length;
    },
  },
};
</script>

<template>
  <ul class="list-unstyled !gl-mb-0">
    <li
      v-for="(vulnerability, i) in renderableVulnerabilities"
      :key="vulnerability.id"
      :class="{ '!gl-mt-5': i > 0 }"
    >
      <dependency-vulnerability :vulnerability="vulnerability" />
    </li>
    <li
      v-if="vulnerabilitiesNotShown"
      ref="excessMessage"
      class="!gl-mt-5 !gl-text-center gl-text-subtle"
    >
      {{
        n__(
          'Dependencies|%d additional vulnerability not shown',
          'Dependencies|%d additional vulnerabilities not shown',
          vulnerabilitiesNotShown,
        )
      }}
    </li>
  </ul>
</template>

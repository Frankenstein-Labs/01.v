<script>
import { GlLink, GlTooltipDirective } from '@gitlab/ui';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import SectionedPercentageBar from '~/usage_quotas/components/sectioned_percentage_bar.vue';
import { DOCS_URL } from '~/constants';
import { s__, sprintf } from '~/locale';
import { PROJECT_VIEW_TYPE } from '~/usage_quotas/constants';

export default {
  name: 'PagesDeploymentsStats',
  components: { GlLink, SectionedPercentageBar, HelpIcon },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: [
    'deploymentsLimit',
    'deploymentsCount',
    'projectDeploymentsCount',
    'usesNamespaceDomain',
    'deploymentsByProject',
    'viewType',
    'domain',
  ],
  static: {
    helpLink: `${DOCS_URL}/user/project/pages/parallel_deployments#limits`,
  },
  i18n: {
    description: s__('PagesUsageQuota|Active parallel deployments'),
    remainingDeploymentsLabel: s__('PagesUsageQuota|Remaining deployments'),
    descriptionForNamespaceDomain: s__(
      'PagesUsageQuota|This project is using the namespace domain "%{domain}". The usage quota includes parallel deployments for all projects in the namespace that use this domain.',
    ),
    helpText: s__('PagesUsageQuota|Learn about limits for Pages deployments'),
    projectUsedLabel: s__('PagesUsageQuota|This project'),
    otherProjectsLabel: s__('PagesUsageQuota|Other projects in namespace'),
  },
  props: {
    title: {
      type: String,
      required: true,
    },
  },
  computed: {
    description() {
      if (this.usesNamespaceDomain) {
        return sprintf(this.$options.i18n.descriptionForNamespaceDomain, {
          domain: this.domain,
        });
      }
      return this.$options.i18n.description;
    },
    remainingDeployments() {
      return this.deploymentsLimit - this.deploymentsCount;
    },
    otherDeployments() {
      return this.deploymentsCount - this.projectDeploymentsCount;
    },
    usedDeploymentsSection() {
      if (this.viewType === PROJECT_VIEW_TYPE) {
        return this.projectLevelUsedSections;
      }
      return this.namespaceLevelUsedSections;
    },
    otherDeploymentsSection() {
      if (!this.usesNamespaceDomain) return [];

      return [
        {
          id: 'otherDeployments',
          label: this.$options.i18n.otherProjectsLabel,
          value: this.otherDeployments,
          formattedValue: String(this.otherDeployments),
          color: 'var(--gray-400)',
        },
      ];
    },
    projectLevelUsedSections() {
      return [
        {
          id: 'projectDeployments',
          label: this.$options.i18n.projectUsedLabel,
          value: this.projectDeploymentsCount,
          formattedValue: String(this.projectDeploymentsCount),
          color: 'var(--data-viz-blue-600)',
          hideLabel: !this.usesNamespaceDomain,
        },
        ...this.otherDeploymentsSection,
      ];
    },
    namespaceLevelUsedSections() {
      return this.deploymentsByProject
        .filter((project) => project.count > 0)
        .map((project, index) => ({
          id: index,
          label: project.name,
          value: project.count,
          formattedValue: String(project.count),
        }));
    },
    sections() {
      return [
        ...this.usedDeploymentsSection,
        {
          id: 'free',
          value: this.remainingDeployments,
          label: this.$options.i18n.remainingDeploymentsLabel,
          formattedValue: String(this.remainingDeployments),
          color: 'var(--gray-50)',
          hideLabel: true,
        },
      ];
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-flex gl-justify-between gl-align-top">
      <div class="gl-mb-6 gl-grow">
        <h2 class="gl-heading-2 gl-mb-2">{{ title }}</h2>
        <p class="gl-mb-0 gl-max-w-6/8">
          {{ description }}
          <gl-link
            v-gl-tooltip
            :href="$options.static.helpLink"
            target="_blank"
            class="gl-ml-2 gl-text-subtle"
            :title="$options.i18n.helpText"
            :aria-label="$options.i18n.helpText"
          >
            <help-icon />
          </gl-link>
        </p>
      </div>
      <p
        class="gl-mb-3 gl-grow-0 gl-text-nowrap gl-text-size-h-display gl-font-bold"
        data-testid="count"
      >
        {{ deploymentsCount }} / {{ deploymentsLimit }}
      </p>
    </div>
    <sectioned-percentage-bar :sections="sections" />
  </div>
</template>

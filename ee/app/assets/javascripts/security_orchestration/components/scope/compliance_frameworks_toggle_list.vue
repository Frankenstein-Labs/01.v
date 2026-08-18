<script>
import { uniqueId } from 'lodash-es';
import { GlButton, GlLabel, GlPopover } from '@gitlab/ui';
import { sprintf, s__, __ } from '~/locale';
import {
  COMPLIANCE_FRAMEWORKS_DESCRIPTION,
  COMPLIANCE_FRAMEWORKS_DESCRIPTION_NO_PROJECTS,
  COMPLIANCE_FRAMEWORKS_DESCRIPTION_OVER_MAX_NUMBER_OF_PROJECTS,
} from 'ee/security_orchestration/components/policy_drawer/constants';

export default {
  i18n: {
    editButtonText: s__('ComplianceFrameworks|Edit compliance framework'),
  },
  name: 'ComplianceFrameworksToggleList',
  components: {
    GlLabel,
    GlPopover,
    GlButton,
  },
  props: {
    complianceFrameworks: {
      type: Array,
      required: false,
      default: () => [],
    },
    labelsToShow: {
      type: Number,
      required: false,
      default: 0,
    },
    defaultProjectPageSize: {
      type: Number,
      required: false,
      default: 100,
    },
  },
  computed: {
    hasHiddenLabels() {
      const { length } = this.complianceFrameworks;

      return length > 0 && this.sanitizedLabelsTo > 0 && this.sanitizedLabelsTo < length;
    },
    hiddenLabelsText() {
      return sprintf(__('+ %{hiddenLabelsLength} more'), {
        hiddenLabelsLength: this.hiddenLabelsLength,
      });
    },
    hiddenLabelsLength() {
      const difference = this.complianceFrameworks.length - this.sanitizedLabelsTo;
      return Math.max(difference, 0);
    },
    complianceFrameworksFormatted() {
      const sanatizedFrameworks =
        this.sanitizedLabelsTo === 0
          ? this.complianceFrameworks
          : this.complianceFrameworks.slice(0, this.sanitizedLabelsTo);

      return sanatizedFrameworks.map((framework) => ({
        ...framework,
        id: uniqueId(framework.id),
      }));
    },
    sanitizedLabelsTo() {
      return Number.isNaN(this.labelsToShow) ? 0 : Math.ceil(this.labelsToShow);
    },
    header() {
      if (this.projectsLength === 0) {
        return COMPLIANCE_FRAMEWORKS_DESCRIPTION_NO_PROJECTS;
      }

      if (this.hasMoreProjects) {
        return sprintf(COMPLIANCE_FRAMEWORKS_DESCRIPTION_OVER_MAX_NUMBER_OF_PROJECTS, {
          pageSize: this.defaultProjectPageSize,
        });
      }

      return COMPLIANCE_FRAMEWORKS_DESCRIPTION(this.projectsLength);
    },
    hasMoreProjects() {
      return this.projectsLength >= this.defaultProjectPageSize && this.hasNextPage;
    },
    hasNextPage() {
      return this.complianceFrameworks.some(
        (framework) => framework.projects.pageInfo?.hasNextPage,
      );
    },
    projectsLength() {
      const allProjectsOfComplianceFrameworks = this.complianceFrameworks
        ?.flatMap(({ projects = {} }) => projects?.nodes?.map(({ id }) => id))
        .filter(Boolean);

      return Array.from(new Set(allProjectsOfComplianceFrameworks))?.length || 0;
    },
  },
};
</script>

<template>
  <div>
    <p class="gl-mb-2" data-testid="compliance-frameworks-header">
      {{ header }}
    </p>

    <div class="gl-flex gl-flex-wrap gl-gap-3">
      <div v-for="item in complianceFrameworksFormatted" :key="item.id">
        <gl-label :id="item.id" :background-color="item.color" :title="item.name" />
        <gl-popover :title="item.name" :target="item.id">
          <p>{{ item.description }}</p>
          <gl-button
            v-if="item.editPath"
            size="small"
            category="secondary"
            variant="confirm"
            :href="item.editPath"
          >
            {{ $options.i18n.editButtonText }}
          </gl-button>
        </gl-popover>
      </div>
    </div>

    <p v-if="hasHiddenLabels" data-testid="hidden-labels-text" class="gl-m-0 gl-mt-3">
      {{ hiddenLabelsText }}
    </p>
  </div>
</template>

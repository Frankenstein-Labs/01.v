<script>
import { GlAccordion, GlAccordionItem } from '@gitlab/ui';
import {
  STANDARDS_ADHERENCE_CHECK_LABELS,
  STANDARDS_ADHERENCE_STANARD_LABELS,
  CHECKS,
  PROJECTS,
} from 'ee/compliance_dashboard/components/standards_adherence_report/constants';
import AdherencesBaseTable from './base_table.vue';

export default {
  name: 'GroupAdherences',
  components: {
    GlAccordion,
    GlAccordionItem,
    AdherencesBaseTable,
  },
  props: {
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
    projectPath: {
      type: String,
      required: false,
      default: null,
    },
    filters: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    selected: {
      type: String,
      required: true,
    },
    projects: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  checkLabels: STANDARDS_ADHERENCE_CHECK_LABELS,
  standardLabels: STANDARDS_ADHERENCE_STANARD_LABELS,
  CHECKS,
  PROJECTS,
};
</script>

<template>
  <div class="gl-border-t" data-testid="adherences-grouped-by-checks">
    <gl-accordion :auto-collapse="false" :header-level="1">
      <div v-if="selected === $options.CHECKS">
        <div
          v-for="(value, key) in $options.checkLabels"
          :key="value.id"
          class="gl-border-b gl-flex gl-items-start @md/panel:gl-flex-row"
          data-testid="grouped-check"
        >
          <gl-accordion-item class="!gl-my-4" :title="value">
            <adherences-base-table
              :is-loading="false"
              :group-path="groupPath"
              :project-path="projectPath"
              :check="key"
              :filters="filters"
            />
          </gl-accordion-item>
        </div>
      </div>
      <div v-else-if="selected === $options.PROJECTS">
        <div
          v-for="value in projects"
          :key="value.id"
          class="gl-border-b gl-flex gl-items-start @md/panel:gl-flex-row"
          data-testid="grouped-project"
        >
          <gl-accordion-item class="!gl-my-4" :title="value.name">
            <adherences-base-table
              :is-loading="false"
              :group-path="groupPath"
              :project-path="value.fullPath"
              :filters="filters"
            />
          </gl-accordion-item>
        </div>
      </div>
      <div v-else>
        <div
          v-for="(value, key) in $options.standardLabels"
          :key="value.id"
          class="gl-border-b gl-flex gl-items-start @md/panel:gl-flex-row"
          data-testid="grouped-standard"
        >
          <gl-accordion-item class="!gl-my-4" :title="value">
            <adherences-base-table
              :is-loading="false"
              :group-path="groupPath"
              :project-path="projectPath"
              :standard="key"
              :filters="filters"
            />
          </gl-accordion-item>
        </div>
      </div>
    </gl-accordion>
  </div>
</template>

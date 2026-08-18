<script>
import {
  GlDrawer,
  GlButton,
  GlButtonGroup,
  GlIcon,
  GlTooltipDirective,
  GlTabs,
  GlTab,
} from '@gitlab/ui';
import { mapState } from 'pinia';
import { VULNERABILITY_TAB_NAMES } from 'ee/vulnerabilities/constants';
import { VULNERABILITY_DETAIL_CODE_FLOWS } from 'ee/security_dashboard/constants';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getSeverity } from '~/ci/reports/utils';
import { CODE_QUALITY_SCALE_KEY } from '~/ci/reports/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { s__ } from '~/locale';
import VulnerabilityCodeFlow from 'ee/vue_shared/components/code_flow/vulnerability_code_flow.vue';
import { useLegacyDiffs } from '~/diffs/stores/legacy_diffs';
import FindingsDrawerDetails from './findings_drawer_details.vue';

export const i18n = {
  codeQualityFinding: s__('FindingsDrawer|Code Quality Finding'),
  sastFinding: s__('FindingsDrawer|SAST Finding'),
  codeQuality: s__('FindingsDrawer|Code Quality'),
  detected: s__('FindingsDrawer|Detected in pipeline'),
  nextButton: s__('FindingsDrawer|Next finding'),
  previousButton: s__('FindingsDrawer|Previous finding'),
  VULNERABILITY_TAB_NAMES,
};

export default {
  name: 'FindingsDrawer',
  i18n,
  codeQuality: CODE_QUALITY_SCALE_KEY,
  components: {
    FindingsDrawerDetails,
    VulnerabilityCodeFlow,
    GlDrawer,
    GlButton,
    GlButtonGroup,
    GlIcon,
    GlTabs,
    GlTab,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    drawer: {
      type: Object,
      required: true,
    },
    project: {
      type: Object,
      required: false,
      default: () => {},
    },
  },
  emits: ['close'],
  data() {
    return {
      drawerIndex: 0,
      tabIndex: 0,
    };
  },
  computed: {
    ...mapState(useLegacyDiffs, ['branchName']),
    getDrawerHeaderHeight() {
      return getContentWrapperHeight();
    },
    projectFullPath() {
      return this.project?.fullPath;
    },
    isCodeQuality() {
      return this.activeElement.scale === this.$options.codeQuality;
    },
    activeElement() {
      return this.drawer.findings[this.drawerIndex];
    },
    showCodeFlowTabs() {
      const codeFlowData = this.activeElement.details?.find(
        (detail) => detail.type === VULNERABILITY_DETAIL_CODE_FLOWS,
      );
      return codeFlowData?.items?.length > 0;
    },
  },
  DRAWER_Z_INDEX,
  watch: {
    drawer(newVal) {
      this.drawerIndex = newVal.index;
    },
  },
  methods: {
    getSeverity,
    prev() {
      if (this.drawerIndex === 0) {
        this.drawerIndex = this.drawer.findings.length - 1;
      } else {
        this.drawerIndex -= 1;
      }
      this.tabIndex = 0;
    },
    next() {
      if (this.drawerIndex === this.drawer.findings.length - 1) {
        this.drawerIndex = 0;
      } else {
        this.drawerIndex += 1;
      }
      this.tabIndex = 0;
    },
    redirectToCodeFlowTab() {
      this.tabIndex = 1;
    },
  },
};
</script>
<template>
  <gl-drawer
    :header-height="getDrawerHeaderHeight"
    :z-index="$options.DRAWER_Z_INDEX"
    class="findings-drawer"
    :open="Object.keys(drawer).length !== 0"
    @close="$emit('close')"
  >
    <template #title>
      <h2 class="drawer-heading gl-mb-0 gl-mt-0 gl-w-28 gl-text-base">
        <gl-icon
          :size="12"
          :name="getSeverity(activeElement).name"
          :class="getSeverity(activeElement).class"
          class="inline-findings-severity-icon !gl-align-baseline"
        />
        <span class="drawer-heading-severity">{{ activeElement.severity }}</span>
        {{ isCodeQuality ? $options.i18n.codeQualityFinding : $options.i18n.sastFinding }}
      </h2>
      <div v-if="drawer.findings.length > 1">
        <gl-button-group>
          <gl-button
            v-gl-tooltip.bottom
            :title="$options.i18n.previousButton"
            :aria-label="$options.i18n.previousButton"
            size="small"
            data-testid="findings-drawer-prev-button"
            @click="prev"
          >
            <gl-icon
              :size="14"
              class="findings-drawer-nav-button gl-relative"
              name="chevron-lg-left"
            />
          </gl-button>
          <gl-button size="small" @click="next">
            <gl-icon
              v-gl-tooltip.bottom
              data-testid="findings-drawer-next-button"
              :title="$options.i18n.nextButton"
              :aria-label="$options.i18n.nextButton"
              class="findings-drawer-nav-button gl-relative"
              :size="14"
              name="chevron-lg-right"
            />
          </gl-button>
        </gl-button-group>
      </div>
    </template>

    <template #default>
      <gl-tabs v-if="showCodeFlowTabs" v-model="tabIndex" class="!gl-pt-0">
        <gl-tab :title="$options.i18n.VULNERABILITY_TAB_NAMES.DETAILS">
          <findings-drawer-details
            :drawer="activeElement"
            :project="project"
            :inside-tab="true"
            @redirect-to-code-flow-tab="redirectToCodeFlowTab()"
          />
        </gl-tab>

        <gl-tab :title="$options.i18n.VULNERABILITY_TAB_NAMES.CODE_FLOW">
          <vulnerability-code-flow
            :branch-ref="branchName"
            :details="activeElement.details[0]"
            :project-full-path="projectFullPath"
            :show-code-flow-file-viewer="false"
            :is-unverified="activeElement.unverified"
          />
        </gl-tab>
      </gl-tabs>
      <template v-else>
        <findings-drawer-details :drawer="activeElement" :project="project" />
      </template>
    </template>
  </gl-drawer>
</template>

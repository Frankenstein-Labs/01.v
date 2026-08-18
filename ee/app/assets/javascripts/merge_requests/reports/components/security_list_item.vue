<script>
import { GlButton, GlSprintf } from '@gitlab/ui';
import { n__, __, sprintf } from '~/locale';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import CiIcon from '~/vue_shared/components/ci_icon/ci_icon.vue';
import { EXTENSION_ICONS } from '~/vue_merge_request_widget/constants';
import StatusIcon from '~/vue_merge_request_widget/components/widget/status_icon.vue';

export default {
  name: 'SecurityListItem',
  components: {
    GlButton,
    GlSprintf,
    CiIcon,
    StatusIcon,
  },
  props: {
    policyName: {
      type: String,
      required: true,
    },
    active: {
      type: Boolean,
      required: false,
      default: false,
    },
    loading: {
      type: Boolean,
      required: false,
      default: true,
    },
    findings: {
      type: Array,
      required: false,
      default: () => [],
    },
    status: {
      type: String,
      required: true,
    },
    selectedFinding: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: ['open-drawer', 'open-finding'],
  computed: {
    statusIcon() {
      return this.status.toLowerCase();
    },
    headingText() {
      let message = n__(
        'Policy `%{policyName}` found %{count} violation',
        'Policy `%{policyName}` found %{count} violations',
        this.findings.length,
      );

      if (this.loading) {
        message = __('Policy `%{policyName}` is being evaluated');
      } else if (!this.hasFindings) {
        message = __('Policy `%{policyName}` passed');
      }

      return sprintf(message, { policyName: this.policyName, count: this.findings.length });
    },
    subHeadingText() {
      if (this.loading) {
        return __('Results pending…');
      }

      if (!this.hasFindings) {
        return __('No policy violations found');
      }

      return n__(
        '%d finding must be resolved',
        '%d findings must be resolved',
        this.findings.length,
      );
    },
    hasFindings() {
      return this.findings.length > 0;
    },
  },
  methods: {
    findingSeverity(finding) {
      return capitalizeFirstCharacter(finding.severity?.toLowerCase());
    },
    findingIcon(finding) {
      return (
        EXTENSION_ICONS[`severity${this.findingSeverity(finding)}`] ||
        EXTENSION_ICONS.severityCritical
      );
    },
    isFindingDrawerOpen(finding) {
      return finding.name === this.selectedFinding?.name;
    },
    onClickFinding(finding) {
      this.$emit('open-finding', finding);
    },
  },
  EVALUATING_ICON: { icon: 'status_running' },
};
</script>

<template>
  <div class="gl-grid gl-w-full gl-grid-cols-[38px_1fr_auto]">
    <div
      class="gl-col-span-3 -gl-mx-2 gl-grid gl-grid-cols-subgrid gl-gap-4 gl-rounded-base gl-px-4 gl-py-3"
      :class="{ 'gl-bg-strong': active }"
    >
      <div>
        <ci-icon v-if="status === 'RUNNING'" :status="$options.EVALUATING_ICON" :use-link="false" />
        <status-icon v-else :icon-name="statusIcon" />
      </div>
      <div>
        <strong class="gl-leading-[24px]" data-testid="security-item-heading">{{
          headingText
        }}</strong>
        <p class="gl-mb-0" data-testid="security-item-subheading">{{ subHeadingText }}</p>
      </div>
      <div class="gl-justify-self-end">
        <gl-button size="small" @click="$emit('open-drawer', policyName)">{{
          __('Details')
        }}</gl-button>
      </div>
    </div>
    <div
      v-if="!loading && findings.length"
      class="gl-col-span-3 gl-grid gl-grid-cols-subgrid gl-gap-4"
    >
      <ul class="gl-col-start-2 gl-mb-0 gl-mt-2 gl-list-none gl-p-0">
        <li
          v-for="(finding, index) in findings"
          :key="index"
          class="-gl-ml-4 -gl-mr-4 gl-mb-2"
          data-testid="security-item-finding"
        >
          <gl-button
            category="tertiary"
            class="gl-w-full !gl-justify-start"
            :class="{ '!gl-border-0 !gl-bg-strong': isFindingDrawerOpen(finding) }"
            :selected="isFindingDrawerOpen(finding)"
            data-testid="security-item-finding-button"
            @click="onClickFinding(finding)"
          >
            <gl-sprintf :message="__('%{icon} %{severity} - %{name}')">
              <template #icon>
                <status-icon
                  class="gl-inline-block"
                  :icon-name="findingIcon(finding)"
                  :level="2"
                  data-testid="security-item-finding-status-icon"
                />
              </template>
              <template #severity>
                {{ findingSeverity(finding) }}
              </template>
              <template #name>
                {{ finding.name }}
              </template>
            </gl-sprintf>
          </gl-button>
        </li>
      </ul>
    </div>
  </div>
</template>

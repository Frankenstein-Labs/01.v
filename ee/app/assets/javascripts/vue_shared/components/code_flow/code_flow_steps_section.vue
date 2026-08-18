<script>
import {
  GlBadge,
  GlButton,
  GlButtonGroup,
  GlCollapse,
  GlLink,
  GlPopover,
  GlTruncate,
  GlTooltipDirective,
} from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';

const SOURCE_NODE_TYPE = 'source';

export default {
  name: 'CodeFlowStepsSection',
  components: {
    GlPopover,
    GlButton,
    GlButtonGroup,
    GlCollapse,
    GlBadge,
    GlLink,
    GlTruncate,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    details: {
      type: Object,
      required: true,
    },
    rawTextBlobs: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    isUnverifiedSource: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['on-selected-step'],
  data() {
    return {
      stepsExpanded: [],
      selectedStepNumber: 1,
      selectedVulnerability: this.details?.items[0][0],
    };
  },
  computed: {
    steps() {
      return this.details.items[0];
    },
    stepsGroupedByFile() {
      return this.steps.reduce((acc, step, index) => {
        const { fileName, lineStart } = step.fileLocation;
        if (!acc[fileName]) {
          acc[fileName] = [];
        }
        const fileDescription = this.getDescription(this.rawTextBlobs[fileName], lineStart - 1);
        acc[fileName].push({
          ...step,
          nodeType: step.nodeType.toLowerCase(),
          stepNumber: index + 1,
          rawTextBlob: this.rawTextBlobs[fileName],
          fileDescription,
        });
        return acc;
      }, {});
    },
    nextStepNumber() {
      return this.selectedStepNumber + 1;
    },
    previousStepNumber() {
      return this.selectedStepNumber - 1;
    },
    numOfSteps() {
      return this.steps.length;
    },
    numOfFiles() {
      return Object.keys(this.stepsGroupedByFile).length;
    },
    stepsHeader() {
      return sprintf(__('%{numOfSteps} steps across %{numOfFiles} files'), {
        numOfSteps: this.numOfSteps,
        numOfFiles: this.numOfFiles,
      });
    },
  },
  mounted() {
    this.stepsExpanded = Array(this.numOfFiles).fill(true);
  },
  created() {
    this.$emit('on-selected-step', this.selectedStepNumber);
  },
  methods: {
    openFileSteps(index) {
      const copyStepsExpanded = [...this.stepsExpanded];
      copyStepsExpanded[index] = !this.stepsExpanded[index];
      this.stepsExpanded = copyStepsExpanded;
    },
    getPathIcon(index) {
      return this.stepsExpanded[index] ? 'chevron-down' : 'chevron-right';
    },
    getFileName(fileName) {
      return fileName.split('/').pop();
    },
    getFilePath(fileName) {
      return fileName.slice(0, fileName.lastIndexOf('/') + 1);
    },
    isOutOfRange(stepNumber) {
      return stepNumber > this.numOfSteps || stepNumber <= 0;
    },
    selectStep(stepNumber) {
      if (this.isOutOfRange(stepNumber)) return;
      this.selectedStepNumber = stepNumber;
      this.selectedVulnerability = this.steps.find((item) => item.stepNumber === stepNumber);
      this.$emit('on-selected-step', stepNumber);
    },
    showNodeTypePopover(nodeType) {
      if (nodeType === SOURCE_NODE_TYPE && this.isUnverifiedSource) {
        return this.$options.i18n.unverifiedSourceNodeTypePopover;
      }

      return nodeType === SOURCE_NODE_TYPE
        ? this.$options.i18n.sourceNodeTypePopover
        : this.$options.i18n.sinkNodeTypePopover;
    },
    toggleAriaLabel(index) {
      return this.stepsExpanded[index] ? __('Collapse') : __('Expand');
    },
    getDescription(rawTextBlob, startLine) {
      return rawTextBlob?.split(/\r?\n/)[startLine];
    },
    isVisibleCollapse(index) {
      return Boolean(this.stepsExpanded[index]);
    },
    nodeTypeLabel(nodeType) {
      if (nodeType === SOURCE_NODE_TYPE && this.isUnverifiedSource) {
        return this.$options.i18n.unverifiedSource;
      }
      return nodeType;
    },
  },
  i18n: {
    codeFlowInfoButton: s__('Vulnerability|What is code flow?'),
    codeFlowInfoAnswer: s__(
      "Vulnerability|Code flow helps trace and flag risky data ('tainted data') as it moves through your software. Vulnerabilities are detected by pinpointing how untrusted inputs, like user data or network traffic, are utilized. This technique finds and fixes data handling flaws, securing software from injection and cross-site scripting attacks.",
    ),
    steps: s__('Vulnerability|Steps'),
    sourceNodeTypePopover: s__(
      "Vulnerability|A 'source' refers to untrusted inputs like user data or external data sources. These inputs can introduce security risks into the software system and are monitored to prevent vulnerabilities.",
    ),
    sinkNodeTypePopover: s__(
      "Vulnerability|A 'sink' is where untrusted data is used in a potentially risky way, such as in SQL queries or HTML output. Sink points are monitored to prevent security vulnerabilities in the software.",
    ),
    unverifiedSource: s__('Vulnerability|Trace Entry Point'),
    unverifiedSourceNodeTypePopover: s__(
      "Vulnerability|This vulnerability was found but couldn't be traced back to the untrusted input that caused it. The root cause isn't fully understood, so review it carefully before making changes.",
    ),
  },
};
</script>

<template>
  <div>
    <div class="gl-flex gl-justify-between gl-pt-2">
      <div>
        <div class="item-title gl-text-lg">{{ $options.i18n.steps }}</div>
        <div class="gl-pt-2" data-testid="steps-header">{{ stepsHeader }}</div>
      </div>
      <gl-button-group>
        <gl-button
          icon="chevron-up"
          :aria-label="__(`Previous step`)"
          :disabled="isOutOfRange(previousStepNumber)"
          @click="selectStep(previousStepNumber)"
        />
        <gl-button
          icon="chevron-down"
          :aria-label="__(`Next step`)"
          :disabled="isOutOfRange(nextStepNumber)"
          @click="selectStep(nextStepNumber)"
        />
      </gl-button-group>
    </div>
    <div class="gl-ml-4 gl-pt-3">
      <div
        v-for="(vulnerabilityFlow, fileName, fileIndex) in stepsGroupedByFile"
        :key="fileIndex"
        class="-gl-ml-4"
        :data-testid="`file-steps-${fileIndex}`"
      >
        <div
          v-gl-tooltip
          :title="fileName"
          class="gl-inline-flex gl-max-w-full gl-items-center"
          :data-testid="`file-name-${fileIndex}`"
        >
          <gl-button
            :icon="getPathIcon(fileIndex)"
            category="tertiary"
            :aria-label="toggleAriaLabel(fileIndex)"
            @click="openFileSteps(fileIndex)"
          />
          <gl-truncate
            class="gl-min-w-0 gl-flex-shrink"
            :text="getFilePath(fileName)"
            position="end"
          /><gl-truncate
            class="gl-flex-shrink-0 gl-font-bold"
            :text="getFileName(fileName)"
            position="start"
          />
        </div>
        <gl-collapse class="gl-mt-2 gl-pl-6" :visible="isVisibleCollapse(fileIndex)">
          <gl-link
            v-for="(
              { stepNumber, nodeType, fileDescription, fileLocation: { lineStart } }, stepIndex
            ) in vulnerabilityFlow"
            :key="stepIndex"
            class="gl-flex !gl-content-center gl-justify-between !gl-rounded-base gl-pb-2 gl-pl-2 gl-pr-2 gl-pt-2 !gl-text-inherit !gl-no-underline"
            :class="{
              'gl-rounded-base gl-bg-blue-50': selectedStepNumber === stepNumber,
            }"
            :data-testid="`step-row-${stepIndex}`"
            @click="selectStep(stepNumber)"
          >
            <gl-badge
              class="gl-mr-3 gl-h-6 gl-w-6 gl-rounded-base gl-pl-4 gl-pr-4"
              :class="{
                '!gl-bg-blue-500 !gl-text-white': selectedStepNumber === stepNumber,
              }"
              size="lg"
              variant="neutral"
            >
              <strong v-if="selectedStepNumber === stepNumber">{{ stepNumber }}</strong>
              <span v-else>{{ stepNumber }}</span>
            </gl-badge>
            <span
              class="gl-mr-auto !gl-content-center gl-overflow-hidden gl-text-ellipsis gl-whitespace-nowrap"
            >
              <gl-badge
                v-if="['source', 'sink'].includes(nodeType)"
                :id="nodeType"
                :data-testid="nodeType"
                class="gl-mr-3 gl-pl-4 gl-pr-4"
                size="md"
                variant="neutral"
              >
                {{ nodeTypeLabel(nodeType) }}
              </gl-badge>
              <gl-popover
                triggers="hover focus"
                placement="top"
                :target="nodeType"
                :content="showNodeTypePopover(nodeType)"
                :show="false"
              />

              {{ fileDescription }}
            </span>
            <span class="!gl-content-center gl-pr-3 gl-text-subtle">{{ lineStart }}</span>
          </gl-link>
        </gl-collapse>
      </div>
    </div>
  </div>
</template>

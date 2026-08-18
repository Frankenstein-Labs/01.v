<script>
import { debounce } from 'lodash-es';
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';
import LineHighlighter from '~/blob/line_highlighter';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  i18n,
  AI_GENIE_DEBOUNCE,
  EXPLAIN_CODE_TRACKING_EVENT_NAME,
  GENIE_CHAT_EXPLAIN_MESSAGE,
} from '../constants';
import { sendDuoChatCommand } from '../utils';

const linesWithDigitsOnly = /^\d+$\n/gm;

export default {
  name: 'AiGenie',
  i18n,
  trackingEventName: EXPLAIN_CODE_TRACKING_EVENT_NAME,
  components: {
    GlButton,
  },
  directives: {
    SafeHtml,
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagsMixin()],
  provide() {
    return {
      trackingEventName: EXPLAIN_CODE_TRACKING_EVENT_NAME,
    };
  },
  inject: ['resourceId'],
  props: {
    containerSelector: {
      type: String,
      required: true,
    },
    filePath: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      selectedText: '',
      shouldShowButton: false,
      container: null,
      top: null,
      lineHighlighter: null,
    };
  },
  computed: {
    rootStyle() {
      if (!this.top) return null;
      return { top: `${this.top}px` };
    },
  },
  created() {
    this.debouncedSelectionChangeHandler = debounce(this.handleSelectionChange, AI_GENIE_DEBOUNCE);
  },
  mounted() {
    this.lineHighlighter = new LineHighlighter();
    document.addEventListener('selectionchange', this.debouncedSelectionChangeHandler);
  },
  beforeDestroy() {
    document.removeEventListener('selectionchange', this.debouncedSelectionChangeHandler);
  },
  methods: {
    handleSelectionChange() {
      this.container = document.querySelector(this.containerSelector);
      if (!this.container) {
        throw new Error(this.$options.i18n.GENIE_NO_CONTAINER_ERROR);
      }
      const selection = window.getSelection();
      this.shouldShowButton = this.isWithinContainer(selection) && this.setPosition(selection);
    },
    isWithinContainer(selection) {
      return (
        !selection.isCollapsed &&
        this.container.contains(selection.anchorNode) &&
        this.container.contains(selection.focusNode)
      );
    },
    setPosition(selection) {
      const { top: startSelectionTop } = selection.getRangeAt(0).getBoundingClientRect();
      const { top: finishSelectionTop } = selection
        .getRangeAt(selection.rangeCount - 1)
        .getBoundingClientRect();
      const { offsetParent } = this.$el;
      if (!offsetParent) return false;
      const { top: offsetParentTop } = offsetParent.getBoundingClientRect();

      this.top = Math.min(startSelectionTop, finishSelectionTop) - offsetParentTop;
      return true;
    },
    requestCodeExplanation() {
      this.selectedText = window.getSelection().toString().replace(linesWithDigitsOnly, '');

      this.setHighlightedLines();

      sendDuoChatCommand({
        question: GENIE_CHAT_EXPLAIN_MESSAGE,
        resourceId: this.resourceId,
        variables: {
          currentFileContext: {
            fileName: this.filePath,
            selectedText: this.selectedText,
          },
        },
        agenticPrompt: `${this.$options.i18n.AGENTIC_PROMPT_EXPLAIN_CODE}\n\n\`\`\`\n${this.selectedText}\n\`\`\``,
      });
    },
    setHighlightedLines() {
      const getSelection = window.getSelection();
      if (getSelection) {
        const rangeStart = this.getLineNumber(getSelection.focusNode);
        const rangeEnd = this.getLineNumber(getSelection.anchorNode);
        this.clearHighlightedLines();
        if (rangeStart && rangeEnd) {
          this.lineHighlighter.highlightRange([rangeStart, rangeEnd]);
        }
      }
    },
    getLineNumber(node) {
      const line = node?.parentElement?.closest('.line');
      const match = line?.id?.match(/\d+/);
      return match ? Number(match[0]) : null;
    },
    clearHighlightedLines() {
      window.getSelection()?.removeAllRanges();
      this.lineHighlighter.clearHighlight();
    },
  },
};
</script>
<template>
  <div class="gl-absolute gl-z-3 -gl-mx-3" :style="rootStyle">
    <gl-button
      v-show="shouldShowButton"
      v-gl-tooltip
      :title="$options.i18n.GENIE_TOOLTIP"
      :aria-label="$options.i18n.GENIE_TOOLTIP"
      category="tertiary"
      variant="default"
      icon="question"
      size="small"
      class="explain-the-code gl-block !gl-rounded-full !gl-bg-default !gl-p-0"
      @click="requestCodeExplanation"
    />
  </div>
</template>

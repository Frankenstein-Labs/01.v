<script>
import { defineAsyncComponent } from 'vue';
import { GlAlert, GlButton, GlSprintf } from '@gitlab/ui';
import { isEmpty, escape } from 'lodash-es';
import VulnerabilityFileContentViewer from 'ee/vue_shared/vulnerabilities/components/vulnerability_file_content_viewer.vue';
import BlobFilepath from '~/blob/components/blob_header_filepath.vue';
import { __, s__ } from '~/locale';
import { highlightContent } from '~/highlight_js';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  updateCodeBlocks,
  updateLinesToMarker,
} from 'ee/vue_shared/components/code_flow/utils/utils';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import markMultipleLines from './plugins/mark_multiple_lines';

export default {
  name: 'CodeFlowFileViewer',
  components: {
    BlobFilepath,
    VulnerabilityFileContentViewer,
    GlButton,
    GlSprintf,
    GlAlert,
    WebIdeLink: defineAsyncComponent(
      () => import('ee_else_ce/vue_shared/components/web_ide_link.vue'),
    ),
  },
  mixins: [glListenersMixin],
  props: {
    hlInfo: {
      type: Array,
      required: false,
      default: () => [],
    },
    blobInfo: {
      type: Object,
      required: true,
      default: () => {},
    },
    filePath: {
      type: String,
      required: true,
      default: undefined,
    },
    branchRef: {
      type: String,
      required: true,
    },
    selectedStepNumber: {
      type: Number,
      required: false,
      default: undefined,
    },
  },
  data() {
    return {
      loadingError: false,
      codeBlocks: [],
      linesToMarker: {},
      expanded: true,
      highlightedContent: '',
      blobContent: '',
    };
  },
  computed: {
    totalLines() {
      return this.content?.split('\n').length;
    },
    labelToggleFile() {
      return this.expanded ? __('Hide file contents') : __('Show file contents');
    },
    collapseIcon() {
      return this.expanded ? 'chevron-down' : 'chevron-right';
    },
    isHighlighted() {
      return Boolean(this.highlightedContent);
    },
    content() {
      return this.highlightedContent || this.blobContent;
    },
  },
  created() {
    this.getContent();
    this.mergeCodeBlocks(this.hlInfo);
  },
  methods: {
    getContent() {
      if (!this.blobInfo || isEmpty(this.blobInfo)) {
        this.loadingError = true;
        return;
      }
      const { rawTextBlob, language } = this.blobInfo;
      const plugins = [(result) => markMultipleLines(result, this.linesToMarker)];
      highlightContent(language, rawTextBlob, plugins)
        .then((res) => {
          // res is undefined when the file language is not recognized.
          // we need to mark the step in the viewer even if the language is not recognized.
          if (!res) {
            const markResult = { value: escape(rawTextBlob) };
            markMultipleLines(markResult, this.linesToMarker);
            this.highlightedContent = markResult.value;
          } else {
            this.highlightedContent = res;
          }
        })
        .catch((error) => {
          Sentry.captureException(error);
        });
      this.blobContent = rawTextBlob;
    },
    mergeCodeBlocks(codeBlocks) {
      const newCodeBlocks = updateCodeBlocks(codeBlocks);
      this.codeBlocks = newCodeBlocks;
      this.linesToMarker = updateLinesToMarker(newCodeBlocks);
    },
    handleToggleFile() {
      this.expanded = !this.expanded;
    },
    handleExpandLines(index) {
      if (index === 0) {
        // expand until line 1
        this.codeBlocks[index].blockStartLine = 1;
      } else if (index === this.codeBlocks.length) {
        // expand until total lines
        this.codeBlocks[this.codeBlocks.length - 1].blockEndLine = this.totalLines;
      } else {
        // expand in-between lines
        this.codeBlocks[index].blockStartLine = this.codeBlocks[index - 1].blockEndLine;
      }
      this.mergeCodeBlocks(this.codeBlocks);
    },
    getExpandedIcon(index) {
      return index !== 0 ? 'expand' : 'expand-up';
    },
    isEndOfCodeBlock(index) {
      return (
        index === this.codeBlocks.length - 1 &&
        this.codeBlocks[index].blockEndLine !== this.totalLines
      );
    },
  },
  i18n: {
    vulnerabilityNotFound: s__('Vulnerability|%{file} was not found in ref %{ref}'),
    expandAllLines: __('Expand all lines'),
  },
};
</script>

<template>
  <div class="file-holder">
    <gl-alert v-if="loadingError" :dismissible="false" variant="warning">
      <gl-sprintf :message="$options.i18n.vulnerabilityNotFound">
        <template #file>
          <code>{{ filePath }}</code>
        </template>
        <template #ref>
          <code>{{ branchRef }}</code>
        </template>
      </gl-sprintf>
    </gl-alert>

    <template v-else>
      <div class="file-title-flex-parent">
        <div class="gl-flex">
          <blob-filepath
            :blob="blobInfo"
            :show-path="true"
            :show-as-link="true"
            :show-blob-size="false"
          >
            <template #filepath-prepend>
              <gl-button
                class="gl-mr-2"
                category="tertiary"
                size="small"
                :icon="collapseIcon"
                :aria-label="labelToggleFile"
                data-testid="collapse-expand-file"
                @click="handleToggleFile"
              />
            </template>
          </blob-filepath>
        </div>

        <div class="file-actions gl-flex gl-flex-wrap">
          <web-ide-link
            button-variant="default"
            class="gl-mr-3"
            :edit-url="blobInfo.editBlobPath"
            :web-ide-url="blobInfo.ideEditPath"
            show-edit-button
            is-blob
            disable-fork-modal
            v-on="glListeners()"
          />
        </div>
      </div>

      <div
        v-if="expanded"
        class="file-content code code-syntax-highlight-theme js-syntax-highlight blob-content blob-viewer gl-flex gl-w-full gl-flex-col gl-overflow-auto"
        data-type="simple"
        data-testid="file-content"
      >
        <div v-for="(highlightSectionInfo, index) in codeBlocks" :key="index">
          <div
            v-if="highlightSectionInfo.blockStartLine !== 1"
            class="expansion-line gl-bg-strong gl-p-1"
          >
            <gl-button
              data-testid="expand-top-lines"
              :title="$options.i18n.expandAllLines"
              :aria-label="$options.i18n.expandAllLines"
              :icon="getExpandedIcon(index)"
              category="tertiary"
              size="small"
              class="mark-multiple-line-expand-button gl-border-0"
              @click="handleExpandLines(index)"
            />
          </div>

          <vulnerability-file-content-viewer
            class="gl-border-none"
            :is-highlighted="isHighlighted"
            :content="content"
            :start-line="highlightSectionInfo.blockStartLine"
            :end-line="highlightSectionInfo.blockEndLine"
            :highlight-info="highlightSectionInfo.highlightInfo"
            :selected-step-number="selectedStepNumber"
          />

          <div v-if="isEndOfCodeBlock(index)" class="expansion-line gl-bg-strong gl-p-1">
            <gl-button
              data-testid="expand-bottom-lines"
              :title="$options.i18n.expandAllLines"
              :aria-label="$options.i18n.expandAllLines"
              icon="expand-down"
              category="tertiary"
              size="small"
              class="mark-multiple-line-expand-button gl-border-0"
              @click="handleExpandLines(codeBlocks.length)"
            />
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

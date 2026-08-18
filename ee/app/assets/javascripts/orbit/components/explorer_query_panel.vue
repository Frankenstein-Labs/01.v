<script>
import { defineComponent } from 'vue';
import {
  GlAccordion,
  GlAccordionItem,
  GlAlert,
  GlButton,
  GlCard,
  GlCollapsibleListbox,
} from '@gitlab/ui';
import { editor as monacoEditor } from 'monaco-editor';
import { EDITOR_READY_EVENT } from '~/editor/constants';
import dark from '~/ide/lib/themes/dark';
import { darkModeEnabled } from '~/lib/utils/color_utils';
import { s__ } from '~/locale';
import SourceEditor from '~/vue_shared/components/source_editor.vue';

export default defineComponent({
  name: 'ExplorerQueryPanel',
  compatConfig: { MODE: 3 },
  components: {
    GlAccordion,
    GlAccordionItem,
    GlAlert,
    GlButton,
    GlCard,
    GlCollapsibleListbox,
    SourceEditor,
  },
  editorOptions: {
    minimap: { enabled: false },
    scrollBeyondLastLine: false,
    lineNumbers: 'on',
    renderLineHighlight: 'none',
    glyphMargin: false,
    folding: false,
    lineDecorationsWidth: 0,
    lineNumbersMinChars: 3,
    fontSize: 13,
    tabSize: 2,
  },
  props: {
    queryText: {
      type: String,
      required: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    templateItems: {
      type: Array,
      required: true,
    },
    selectedTemplate: {
      type: String,
      required: false,
      default: null,
    },
    errorMessage: {
      type: String,
      required: false,
      default: null,
    },
    errorDetails: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['update:query-text', 'execute', 'clear', 'close', 'template-select', 'dismiss-error'],
  i18n: {
    templatesPlaceholder: s__('Orbit|Templates'),
    showDetails: s__('Orbit|Show error details'),
    hideDetails: s__('Orbit|Hide error details'),
  },
  computed: {
    templateToggleText() {
      const match = this.templateItems.find((item) => item.value === this.selectedTemplate);
      return match?.text || this.$options.i18n.templatesPlaceholder;
    },
  },
  methods: {
    onEditorReady() {
      if (darkModeEnabled()) {
        monacoEditor.defineTheme('gl-dark', dark);
        monacoEditor.setTheme('gl-dark');
      }
    },
  },
  readyEvent: EDITOR_READY_EVENT,
});
</script>

<template>
  <gl-card
    class="gl-mt-3 gl-shrink-0"
    data-testid="explorer-query-panel"
    body-class="orbit-editor-body"
    footer-class="gl-px-4 gl-py-3"
  >
    <template #header>
      <div class="gl-flex gl-items-center gl-justify-between">
        <h3 class="gl-heading-scale-500 gl-mb-0">{{ s__('Orbit|Query editor') }}</h3>
        <gl-button
          size="small"
          category="tertiary"
          icon="close"
          :aria-label="s__('Orbit|Close')"
          data-testid="close-query"
          @click="$emit('close')"
        />
      </div>
    </template>

    <div v-if="errorMessage" class="gl-px-4 gl-pt-3">
      <gl-alert variant="danger" data-testid="query-error-alert" @dismiss="$emit('dismiss-error')">
        {{ errorMessage }}
        <gl-accordion v-if="errorDetails" :key="errorMessage" :header-level="6" class="gl-mt-2">
          <gl-accordion-item
            :title="$options.i18n.showDetails"
            :title-visible="$options.i18n.hideDetails"
          >
            <pre
              class="gl-mb-0 gl-whitespace-pre-wrap gl-break-words gl-rounded-base gl-bg-strong gl-p-3 gl-text-sm"
              data-testid="query-error-details"
              >{{ errorDetails }}</pre>
          </gl-accordion-item>
        </gl-accordion>
      </gl-alert>
    </div>

    <div class="orbit-editor-wrapper gl-h-28">
      <source-editor
        :value="queryText"
        :editor-options="$options.editorOptions"
        :use-dynamic-height="false"
        file-name="query.json"
        file-global-id="orbit-query-editor"
        data-testid="query-editor-textarea"
        @input="$emit('update:query-text', $event)"
        @[$options.readyEvent]="onEditorReady"
      />
    </div>

    <template #footer>
      <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-2" data-testid="query-panel-actions">
        <gl-collapsible-listbox
          :items="templateItems"
          :selected="selectedTemplate"
          :toggle-text="templateToggleText"
          size="small"
          data-testid="template-select"
          @select="$emit('template-select', $event)"
        />
        <div class="gl-flex-1"></div>
        <gl-button size="small" data-testid="clear-query-btn" @click="$emit('clear')">{{
          s__('Orbit|Clear')
        }}</gl-button>
        <gl-button
          size="small"
          variant="confirm"
          :loading="loading"
          data-testid="execute-query-btn"
          @click="$emit('execute')"
        >
          {{ s__('Orbit|Execute query') }}
        </gl-button>
      </div>
    </template>
  </gl-card>
</template>

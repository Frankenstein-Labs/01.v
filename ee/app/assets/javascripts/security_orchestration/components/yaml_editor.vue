<script>
import SourceEditor from '~/vue_shared/components/source_editor.vue';
import { EDITOR_READY_EVENT } from '~/editor/constants';
import { SecurityPolicySchemaExtension } from '~/editor/extensions/source_editor_security_policy_schema_ext';

export default {
  name: 'YamlEditorEE',
  components: {
    SourceEditor,
  },
  inject: ['namespacePath', 'namespaceType'],
  props: {
    policyType: {
      type: String,
      required: false,
      default: '',
    },
    value: {
      type: String,
      required: true,
    },
    readOnly: {
      type: Boolean,
      required: false,
      default: true,
    },
    fileGlobalId: {
      type: String,
      required: false,
      default: '',
    },
    disableSchema: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['input'],
  computed: {
    editorOptions() {
      return {
        lineNumbers: 'off',
        folding: false,
        // This represents 14px, which matches the number of pixels added to the left via glyphMargin
        padding: { top: 14 },
        renderIndentGuides: false,
        renderWhitespace: 'boundary',
        renderLineHighlight: 'none',
        lineDecorationsWidth: 0,
        lineNumbersMinChars: 0,
        occurrencesHighlight: false,
        hideCursorInOverviewRuler: true,
        overviewRulerBorder: false,
        readOnly: this.readOnly,
      };
    },
  },
  methods: {
    onInput(val) {
      this.$emit('input', val);
    },
    registerSchema({ detail: { instance } }) {
      if (!this.disableSchema) {
        instance.use({ definition: SecurityPolicySchemaExtension });
        instance.registerSecurityPolicyEditorSchema({
          namespacePath: this.namespacePath,
          namespaceType: this.namespaceType,
          policyType: this.policyType,
        });
      }
    },
  },
  readyEvent: EDITOR_READY_EVENT,
};
</script>

<template>
  <source-editor
    :value="value"
    file-name="*.yaml"
    :file-global-id="fileGlobalId"
    :editor-options="editorOptions"
    @[$options.readyEvent]="registerSchema($event)"
    @input="onInput"
  />
</template>

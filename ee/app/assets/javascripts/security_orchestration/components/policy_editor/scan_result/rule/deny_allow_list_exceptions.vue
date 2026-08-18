<script>
import { debounce } from 'lodash-es';
import { GlCollapsibleListbox, GlFormTextarea, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  EXCEPTION_KEY,
  EXCEPTION_TYPE_ITEMS,
  NO_EXCEPTION_KEY,
} from 'ee/security_orchestration/components/policy_editor/constants';
import {
  splitItemsByCommaOrSpace,
  parseExceptionsStringToItems,
  mapObjectsToString,
} from 'ee/security_orchestration/components/policy_editor/utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';

export default {
  i18n: {
    exceptionMessage: s__(
      'SecurityOrchestration|Use the format %{schemaStart}path-to-package@package-version%{schemaEnd}. For multiple packages, separate paths with commas. For example: npm/lodash@4.17.21, maven/org.apache.commons/commons-lang3@3.12.0, pypi/requests',
    ),
    duplicatesError: s__('ScanResultPolicy|Duplicates will be removed'),
    allowExceptionsPlaceholder: s__(
      'ScanResultPolicy|Specify the packages where this license requires approval before use',
    ),
    denyExceptionsPlaceholder: s__(
      'ScanResultPolicy|Specify the packages where this license does not require approval before use',
    ),
  },
  EXCEPTION_TYPE_ITEMS: [
    {
      value: EXCEPTION_KEY,
      text: s__('SecurityOrchestration|Except'),
    },
    {
      value: NO_EXCEPTION_KEY,
      text: s__('SecurityOrchestration|No exceptions'),
    },
  ],
  name: 'DenyAllowListExceptions',
  components: {
    GlCollapsibleListbox,
    GlFormTextarea,
    GlSprintf,
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    exceptionType: {
      type: String,
      required: false,
      default: NO_EXCEPTION_KEY,
    },
    exceptions: {
      type: Array,
      required: false,
      default: () => [],
    },
    isDeniedList: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['input', 'select-exception-type'],
  data() {
    const { parsedExceptions = [] } = parseExceptionsStringToItems(this.exceptions);

    return {
      parsedExceptions,
    };
  },
  computed: {
    withExceptions() {
      return this.exceptionType === EXCEPTION_KEY;
    },
    toggleText() {
      return EXCEPTION_TYPE_ITEMS.find(({ value }) => value === this.exceptionType).text;
    },
    convertedToStringPackages() {
      return mapObjectsToString(this.parsedExceptions, 'file');
    },
    hasDuplicates() {
      const items = new Set(splitItemsByCommaOrSpace(this.convertedToStringPackages));

      return items.size < this.parsedExceptions.length;
    },
    placeholder() {
      return this.isDeniedList
        ? this.$options.i18n.denyExceptionsPlaceholder
        : this.$options.i18n.allowExceptionsPlaceholder;
    },
  },
  created() {
    this.debouncedSetExceptions = debounce(this.setExceptions, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSetExceptions.cancel();
  },
  methods: {
    parsePackages(packages) {
      const { parsedExceptions = [] } = parseExceptionsStringToItems(packages);

      this.parsedExceptions = parsedExceptions;
    },
    setExceptions(packages) {
      const split = splitItemsByCommaOrSpace(packages);
      this.parsePackages(split);

      this.$emit('input', split);
    },
    selectExceptionType(type) {
      this.$emit('select-exception-type', type);
    },
  },
};
</script>

<template>
  <div>
    <gl-collapsible-listbox
      :disabled="disabled"
      size="small"
      :items="$options.EXCEPTION_TYPE_ITEMS"
      :toggle-text="toggleText"
      :selected="exceptionType"
      @select="selectExceptionType"
    />

    <div v-if="withExceptions" class="gl-mt-4">
      <gl-form-textarea
        no-resize
        :placeholder="placeholder"
        :value="convertedToStringPackages"
        @input="debouncedSetExceptions"
      />

      <p v-if="hasDuplicates" data-testid="error-duplicates-message" class="gl-my-2 gl-text-danger">
        {{ $options.i18n.duplicatesError }}
      </p>

      <p data-testid="format-description" class="gl-mt-3">
        <gl-sprintf :message="$options.i18n.exceptionMessage">
          <template #schema="{ content }">
            <code>{{ content }}</code>
          </template>
        </gl-sprintf>
      </p>
    </div>
  </div>
</template>

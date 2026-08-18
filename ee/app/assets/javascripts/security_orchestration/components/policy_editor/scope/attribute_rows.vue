<script>
import { GlAlert, GlButton } from '@gitlab/ui';
import { isEqual, uniqueId } from 'lodash-es';
import { s__, sprintf } from '~/locale';
import AttributeSelector from './attribute_selector.vue';
import { buildRows, getInitialCategoryKey, getNonReservedScope, getReservedScope } from './utils';

export default {
  name: 'AttributeRows',
  i18n: {
    addRowLabel: s__('SecurityOrchestration|Add another category'),
    removeRowLabel: s__('SecurityOrchestration|Remove row %{number}'),
    experimentNotice: s__(
      'SecurityOrchestration|Experimental feature. Only the four built-in security categories (Business impact, Application, Business unit, and Exposure) are supported. Custom categories are not supported.',
    ),
  },
  components: {
    AttributeSelector,
    GlAlert,
    GlButton,
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    isDirty: {
      type: Boolean,
      required: false,
      default: false,
    },
    policyScope: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['changed', 'error'],
  data() {
    return {
      rows: buildRows(this.policyScope),
      totalCategoriesCount: 0,
    };
  },
  computed: {
    reservedScope() {
      return getReservedScope(this.policyScope);
    },
    rowCategoryKeys() {
      return this.rows.map((row) => ({
        id: row.id,
        key: getInitialCategoryKey(row.scope),
      }));
    },
    hasEmptyRow() {
      return this.rowCategoryKeys.some(({ key }) => key === null);
    },
    reachedCategoryLimit() {
      return this.totalCategoriesCount > 0 && this.rows.length >= this.totalCategoriesCount;
    },
    isAddDisabled() {
      return this.disabled || this.hasEmptyRow || this.reachedCategoryLimit;
    },
    canRemoveRows() {
      return this.rows.length > 1;
    },
  },
  watch: {
    // Rebuild rows when an external replacement (e.g. YAML editor) diverges from the
    // aggregate we last emitted. The parent always hands us a fresh policyScope object
    // after every emit, so reference inequality alone is meaningless here — we compare
    // values via `isEqual` against the current row aggregate. Round-trip echoes match
    // and are skipped; real external changes differ and trigger a rebuild (children
    // re-mount via new row ids, picking the new scope up through `data()`).
    policyScope(newVal) {
      const incoming = getNonReservedScope(newVal);
      const current = Object.assign({}, ...this.rows.map((r) => r.scope));
      if (!isEqual(incoming, current)) {
        this.rows = buildRows(newVal);
      }
    },
  },
  methods: {
    disabledKeysForRow(rowId) {
      return this.rowCategoryKeys
        .filter(({ id, key }) => id !== rowId && key !== null)
        .map(({ key }) => key);
    },
    removeRowLabel(index) {
      return sprintf(this.$options.i18n.removeRowLabel, { number: index + 1 });
    },
    onCategoriesLoaded(count) {
      if (this.totalCategoriesCount !== count) this.totalCategoriesCount = count;
    },
    onRowChanged(rowId, payload) {
      const row = this.rows.find((r) => r.id === rowId);
      if (!row) return;
      row.scope = payload || {};
      this.emitChanged();
    },
    addRow() {
      this.rows.push({ id: uniqueId('scope-row-'), scope: {} });
    },
    removeRow(rowId) {
      this.rows = this.rows.filter((r) => r.id !== rowId);
      this.emitChanged();
    },
    emitChanged() {
      const aggregate = { ...this.reservedScope };
      this.rows.forEach((row) => {
        Object.assign(aggregate, row.scope);
      });
      this.$emit('changed', aggregate);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-3">
    <gl-alert variant="info" class="gl-mb-3" :dismissible="false" data-testid="experiment-notice">
      {{ $options.i18n.experimentNotice }}
    </gl-alert>
    <div
      v-for="(row, index) in rows"
      :key="row.id"
      class="gl-flex gl-items-start gl-gap-2"
      data-testid="scope-attribute-row"
    >
      <attribute-selector
        class="gl-grow"
        :disabled="disabled"
        :is-dirty="isDirty"
        :policy-scope="row.scope"
        :disabled-category-keys="disabledKeysForRow(row.id)"
        @changed="(payload) => onRowChanged(row.id, payload)"
        @error="(message) => $emit('error', message)"
        @categories-loaded="onCategoriesLoaded"
      />
      <gl-button
        v-if="canRemoveRows"
        :disabled="disabled"
        :aria-label="removeRowLabel(index)"
        icon="remove"
        category="tertiary"
        data-testid="remove-row"
        @click="removeRow(row.id)"
      />
    </div>
    <div>
      <gl-button
        :disabled="isAddDisabled"
        category="tertiary"
        variant="link"
        icon="plus"
        data-testid="add-row"
        @click="addRow"
      >
        {{ $options.i18n.addRowLabel }}
      </gl-button>
    </div>
  </div>
</template>

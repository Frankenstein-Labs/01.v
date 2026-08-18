<script>
import { GlModal, GlTableLite, GlButton, GlTooltipDirective } from '@gitlab/ui';
import { uniqueId, uniqWith, isEqual } from 'lodash-es';
import { s__, __, sprintf } from '~/locale';
import {
  EXCEPTION_KEY,
  NO_EXCEPTION_KEY,
} from 'ee/security_orchestration/components/policy_editor/constants';
import { DENIED, UNKNOWN_LICENSE } from './scan_filters/constants';
import DenyAllowLicenses from './deny_allow_licenses.vue';
import DenyAllowListExceptions from './deny_allow_list_exceptions.vue';

const createLicenseObject = ({ license, exceptions = [] } = {}) => ({
  license,
  exceptions,
  exceptionsType: exceptions?.length > 0 ? EXCEPTION_KEY : NO_EXCEPTION_KEY,
  id: uniqueId('license_'),
});

export default {
  ACTION_CANCEL: { text: __('Cancel') },
  i18n: {
    denyListTitle: s__('ScanResultPolicy|Edit denylist'),
    allowListTitle: s__('ScanResultPolicy|Edit allowlist'),
    denyListButton: s__('ScanResultPolicy|Save denylist'),
    allowListButton: s__('ScanResultPolicy|Save allowlist'),
    listDescription: s__('ScanResultPolicy|The product %{verb} use the selected licenses'),
    denyTableHeader: s__('ScanResultPolicy|Denied license'),
    allowTableHeader: s__('ScanResultPolicy|Allowed license'),
    exceptionsHeader: s__('ScanResultPolicy|Exceptions that require approval'),
    exceptionsDenyHeader: s__('ScanResultPolicy|Exceptions that do not require approval'),
    addLicenseButton: s__('ScanResultPolicy|Add new license'),
    disabledTooltip: s__('ScanResultPolicy|All licenses have been selected'),
  },
  name: 'DenyAllowListModal',
  components: {
    DenyAllowLicenses,
    DenyAllowListExceptions,
    GlButton,
    GlModal,
    GlTableLite,
  },
  directives: { GlTooltip: GlTooltipDirective },
  inject: ['parsedSoftwareLicenses'],
  props: {
    listType: {
      type: String,
      required: false,
      default: DENIED,
    },
    licenses: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['select-licenses'],
  data() {
    return {
      items: this.mapLicenses(this.licenses),
    };
  },
  computed: {
    allSelected() {
      const deduplicatedSelection = [
        ...new Set(this.allLicenses.map(({ text }) => text).filter(Boolean)),
      ];
      return deduplicatedSelection.length <= this.items.length;
    },
    allLicenses() {
      return [UNKNOWN_LICENSE, ...this.parsedSoftwareLicenses];
    },
    alreadySelectedLicenses() {
      return this.items.map((item) => item.license).filter(Boolean);
    },
    disabledTooltip() {
      return this.allSelected ? this.$options.i18n.disabledTooltip : '';
    },
    isDeniedList() {
      return this.listType === DENIED;
    },
    modalTitle() {
      return this.isDeniedList
        ? this.$options.i18n.denyListTitle
        : this.$options.i18n.allowListTitle;
    },
    primaryAction() {
      return {
        text: this.isDeniedList
          ? this.$options.i18n.denyListButton
          : this.$options.i18n.allowListButton,
        attributes: {
          variant: 'confirm',
        },
      };
    },
    modalDescription() {
      return sprintf(this.$options.i18n.listDescription, {
        verb: this.isDeniedList ? __('cannot') : __('can'),
      });
    },
    tableFields() {
      return [
        {
          key: 'licenses',
          label: this.isDeniedList
            ? this.$options.i18n.denyTableHeader
            : this.$options.i18n.allowTableHeader,
          thAttr: { 'data-testid': 'list-type-th' },
          thClass: '!gl-pl-0',
          tdClass: '!gl-pl-0 !gl-border-none !gl-pb-3',
        },
        {
          key: 'exceptions',
          label: this.isDeniedList
            ? this.$options.i18n.exceptionsDenyHeader
            : this.$options.i18n.exceptionsHeader,
          thAttr: { 'data-testid': 'exception-th' },
          thClass: '!gl-pl-0',
          tdClass: '!gl-pl-0 !gl-border-none !gl-pb-3',
        },
        {
          key: 'actions',
          label: '',
          columnClass: 'gl-w-4/20',
          thAttr: { 'data-testid': 'actions-th' },
          thClass: '!gl-pl-0',
          tdClass: '!gl-pl-0 !gl-border-none gl-text-right !gl-pb-3',
        },
      ];
    },
    mappedAndFilteredItems() {
      return this.items
        .filter(({ license }) => Boolean(license))
        .map(({ license, exceptions }) => ({ license, exceptions: uniqWith(exceptions, isEqual) }));
    },
  },
  /**
   * when modal was initially opened and licenses selected,
   * opening modal again won't trigger data
   */
  watch: {
    licenses(licenses) {
      this.items = this.mapLicenses(licenses);
    },
  },
  methods: {
    itemsWithoutDuplicatesInExceptions() {
      return this.items.map((item) => ({
        ...item,
        exceptions: uniqWith(item.exceptions, isEqual),
      }));
    },
    hasSelectedLicense(item) {
      return Boolean(item.license);
    },
    addLicense() {
      this.items = [...this.items, createLicenseObject()];
    },
    mapLicenses(licenses) {
      return licenses.length > 0 ? licenses.map(createLicenseObject) : [createLicenseObject()];
    },
    // eslint-disable-next-line vue/no-unused-properties -- called via $refs from DenyAllowList.vue
    showModalWindow() {
      this.$refs.modal.show();
    },
    hideModalWindow() {
      this.$refs.modal.hide();
      this.$emit('select-licenses', []);
    },
    selectExceptionType(value, item) {
      const index = this.items.findIndex(({ id }) => id === item.id);
      this.items.splice(index, 1, { ...item, exceptionsType: value, exceptions: [] });
    },
    selectLicense(license, item) {
      const index = this.items.findIndex(({ id }) => id === item.id);
      this.items.splice(index, 1, { ...item, license });
    },
    removeItem(id) {
      this.items = this.items.filter((item) => item.id !== id);
    },
    selectLicenses() {
      this.items = this.itemsWithoutDuplicatesInExceptions();
      this.$emit('select-licenses', this.mappedAndFilteredItems);
    },
    setExceptions(exceptions, item) {
      const index = this.items.findIndex(({ id }) => id === item.id);
      this.items.splice(index, 1, { ...item, exceptions });
    },
  },
};
</script>

<template>
  <gl-modal
    ref="modal"
    :action-cancel="$options.ACTION_CANCEL"
    :action-primary="primaryAction"
    :title="modalTitle"
    scrollable
    size="lg"
    content-class="security-policies-license-modal-min-height"
    modal-id="deny-allow-list-modal"
    @canceled="hideModalWindow"
    @primary="selectLicenses"
  >
    <p>{{ modalDescription }}</p>

    <gl-table-lite :fields="tableFields" :items="items" table-class="gl-border-b" stacked="md">
      <template #cell(licenses)="{ item = {} }">
        <deny-allow-licenses
          :all-licenses="allLicenses"
          :already-selected-licenses="alreadySelectedLicenses"
          :selected="item.license"
          @select="selectLicense($event, item)"
        />
      </template>
      <template #cell(exceptions)="{ item = {} }">
        <deny-allow-list-exceptions
          :disabled="!hasSelectedLicense(item)"
          :exception-type="item.exceptionsType"
          :exceptions="item.exceptions"
          :is-denied-list="isDeniedList"
          @select-exception-type="selectExceptionType($event, item)"
          @input="setExceptions($event, item)"
        />
      </template>
      <template #cell(actions)="{ item = {} }">
        <div>
          <gl-button
            icon="remove"
            category="tertiary"
            :aria-label="__('Remove')"
            data-testid="remove-license"
            @click="removeItem(item.id)"
          />
        </div>
      </template>
    </gl-table-lite>

    <span
      v-gl-tooltip="{
        disabled: !allSelected,
        title: disabledTooltip,
      }"
      data-testid="add-license-tooltip"
    >
      <gl-button
        :disabled="allSelected"
        data-testid="add-license"
        class="gl-mt-4"
        category="secondary"
        variant="confirm"
        size="small"
        @click="addLicense"
      >
        {{ $options.i18n.addLicenseButton }}
      </gl-button>
    </span>
  </gl-modal>
</template>

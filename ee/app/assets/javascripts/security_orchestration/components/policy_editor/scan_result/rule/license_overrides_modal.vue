<script>
import {
  GlModal,
  GlButton,
  GlFormInput,
  GlFormGroup,
  GlCollapsibleListbox,
  GlTableLite,
} from '@gitlab/ui';
import { uniqueId, debounce, countBy } from 'lodash-es';
import { s__, __ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import {
  MAX_LICENSE_OVERRIDES,
  MAX_PURL_LENGTH,
  OVERRIDE_MODE_PATCH,
  OVERRIDE_MODE_OVERWRITE,
  MODE_ITEMS,
  LICENSE_OVERRIDE_MODAL_FIELDS,
} from './scan_filters/constants';
import { filterLicenseItems } from './scan_filters/utils';

const emptyOverride = () => ({
  id: uniqueId('override_'),
  purl: '',
  license: '',
  mode: OVERRIDE_MODE_PATCH,
});

export default {
  name: 'LicenseOverridesModal',
  components: {
    GlModal,
    GlButton,
    GlFormInput,
    GlFormGroup,
    GlCollapsibleListbox,
    GlTableLite,
  },
  inject: {
    parsedSoftwareLicenses: {
      default: () => [],
    },
  },
  props: {
    overrides: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['save'],
  data() {
    return {
      localOverrides: [],
      licenseSearchTerms: {},
    };
  },
  computed: {
    actionPrimary() {
      return {
        text: __('Save'),
        attributes: {
          variant: 'confirm',
          disabled: this.duplicatePurls.size > 0 || this.hasFormatErrors,
        },
      };
    },
    actionCancel() {
      return { text: __('Cancel') };
    },
    allLicenseItems() {
      return (this.parsedSoftwareLicenses || []).map(({ value, text }) => ({
        value: value || text,
        text: text || value,
      }));
    },
    isAtMaxOverrides() {
      return this.localOverrides.length >= MAX_LICENSE_OVERRIDES;
    },
    duplicatePurls() {
      const counts = countBy(
        this.localOverrides.filter((o) => o.purl),
        'purl',
      );
      return new Set(Object.keys(counts).filter((purl) => counts[purl] > 1));
    },
    hasFormatErrors() {
      return this.localOverrides.some(({ purl }) => purl && !this.$options.PURL_REGEX.test(purl));
    },
    validOverrides() {
      return this.localOverrides
        .filter((o) => o.purl && o.license)
        .map(({ purl, license, mode }) => ({ purl, license, mode: mode || OVERRIDE_MODE_PATCH }));
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setLicenseSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- Called by parent via $refs
    show() {
      this.localOverrides = this.buildInitialOverrides();
      this.licenseSearchTerms = {};
      this.$refs.modal.show();
    },
    buildInitialOverrides() {
      if (!this.overrides.length) return [emptyOverride()];
      return this.overrides.map((o) => ({ ...o, id: uniqueId('override_') }));
    },
    addRow() {
      this.localOverrides.push(emptyOverride());
    },
    removeRow(index) {
      this.localOverrides.splice(index, 1);
    },
    onSave() {
      if (this.duplicatePurls.size > 0 || this.hasFormatErrors) return;
      this.$emit('save', this.validOverrides);
    },
    isPurlDuplicate(purl) {
      return purl ? this.duplicatePurls.has(purl) : false;
    },
    purlState(index) {
      const purl = this.localOverrides[index]?.purl;
      if (!purl) return null;
      if (!this.$options.PURL_REGEX.test(purl)) return false;
      if (this.isPurlDuplicate(purl)) return false;
      return true;
    },
    purlErrorMessage(index) {
      const purl = this.localOverrides[index]?.purl;
      if (!purl) return '';
      if (!this.$options.PURL_REGEX.test(purl)) return this.$options.i18n.purlFormatError;
      if (this.isPurlDuplicate(purl)) return this.$options.i18n.duplicatePurlError;
      return '';
    },
    updateMode(index, mode) {
      this.localOverrides[index].mode = mode;
    },
    selectLicense(index, licenseValue) {
      this.localOverrides[index].license = licenseValue;
    },
    setLicenseSearchTerm(index, searchTerm) {
      this.licenseSearchTerms = { ...this.licenseSearchTerms, [index]: searchTerm.trim() };
    },
    licenseItemsForRow(index) {
      return filterLicenseItems(
        this.allLicenseItems,
        this.licenseSearchTerms[index] || '',
        this.localOverrides[index]?.license,
      );
    },
    licenseToggleText(index) {
      const license = this.localOverrides[index]?.license;
      return license || s__('ScanResultPolicy|Choose a license');
    },
    selectedLicenseValue(index) {
      return this.localOverrides[index]?.license || '';
    },
  },
  i18n: {
    title: s__('ScanResultPolicy|Edit license overrides'),
    addRow: s__('ScanResultPolicy|Add override'),
    purlPlaceholder: 'pkg:pypi/urllib3',
    licenseSearchHeader: s__('ScanResultPolicy|Choose a license'),
    duplicatePurlError: s__('ScanResultPolicy|Duplicate package URL.'),
    purlFormatError: s__('ScanResultPolicy|Enter a valid package URL (e.g. pkg:pypi/urllib3).'),
  },
  fields: LICENSE_OVERRIDE_MODAL_FIELDS,
  modeItems: MODE_ITEMS,
  OVERRIDE_MODE_PATCH,
  OVERRIDE_MODE_OVERWRITE,
  MAX_PURL_LENGTH,
  PURL_REGEX: /^pkg:[^/]+\/.+/,
};
</script>

<template>
  <gl-modal
    ref="modal"
    modal-id="license-overrides-modal"
    size="lg"
    scrollable
    :title="$options.i18n.title"
    :action-primary="actionPrimary"
    :action-cancel="actionCancel"
    @primary="onSave"
  >
    <gl-table-lite :items="localOverrides" :fields="$options.fields" class="gl-mb-3">
      <template #cell(purl)="{ item, index }">
        <gl-form-group :state="purlState(index)" :invalid-feedback="purlErrorMessage(index)">
          <gl-form-input
            v-model="item.purl"
            :placeholder="$options.i18n.purlPlaceholder"
            :state="purlState(index)"
            :maxlength="$options.MAX_PURL_LENGTH"
            data-testid="override-purl-input"
          />
        </gl-form-group>
      </template>
      <template #cell(license)="{ index }">
        <gl-collapsible-listbox
          class="gl-max-w-30"
          :header-text="$options.i18n.licenseSearchHeader"
          :items="licenseItemsForRow(index)"
          :toggle-text="licenseToggleText(index)"
          :selected="selectedLicenseValue(index)"
          searchable
          data-testid="override-license-select"
          @search="debouncedSearch(index, $event)"
          @select="selectLicense(index, $event)"
        />
      </template>
      <template #cell(mode)="{ item, index }">
        <gl-collapsible-listbox
          :selected="item.mode || $options.OVERRIDE_MODE_PATCH"
          :items="$options.modeItems"
          data-testid="override-mode-select"
          @select="updateMode(index, $event)"
        />
      </template>
      <template #cell(actions)="{ index }">
        <gl-button
          class="gl-mt-2"
          category="tertiary"
          icon="remove"
          size="small"
          data-testid="remove-override-row"
          :aria-label="s__('ScanResultPolicy|Remove override')"
          @click="removeRow(index)"
        />
      </template>
    </gl-table-lite>
    <gl-button
      category="secondary"
      variant="confirm"
      size="small"
      :disabled="isAtMaxOverrides"
      data-testid="add-override-btn"
      @click="addRow"
    >
      {{ $options.i18n.addRow }}
    </gl-button>
  </gl-modal>
</template>

<script>
import { GlFilteredSearchToken, GlDropdownDivider, GlDropdownSectionHeader } from '@gitlab/ui';
import { VULNERABILITY_STATE_OBJECTS, DISMISSAL_REASONS } from 'ee/vulnerabilities/constants';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { s__, n__ } from '~/locale';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import SearchSuggestion from '../components/search_suggestion.vue';
import { ALL_ID as ALL_STATUS_VALUE } from '../constants';

const { detected, confirmed, dismissed, resolved } = VULNERABILITY_STATE_OBJECTS;

const ALL_DISMISSED_VALUE = dismissed.searchParamValue;
const STATUS_OPTIONS = [
  { value: ALL_STATUS_VALUE, text: s__('SecurityReports|All statuses') },
  { value: detected.searchParamValue, text: detected.buttonText },
  { value: confirmed.searchParamValue, text: confirmed.buttonText },
  { value: resolved.searchParamValue, text: resolved.buttonText },
];
const STATUS_OPTIONS_WITH_DISMISSED = [
  { value: ALL_STATUS_VALUE, text: s__('SecurityReports|All statuses') },
  { value: detected.searchParamValue, text: detected.buttonText },
  { value: confirmed.searchParamValue, text: confirmed.buttonText },
  { value: dismissed.searchParamValue, text: dismissed.buttonText },
  { value: resolved.searchParamValue, text: resolved.buttonText },
];
const DISMISSAL_REASON_OPTIONS = [
  { value: dismissed.searchParamValue, text: s__('SecurityReports|All dismissal reasons') },
  ...Object.entries(DISMISSAL_REASONS).map(([value, text]) => ({
    value: value.toUpperCase(),
    text,
  })),
];
const DISMISSAL_REASON_KEYS = Object.keys(DISMISSAL_REASONS);
const isDismissalReason = (value) => DISMISSAL_REASON_KEYS.includes(value.toLowerCase());

export default {
  defaultValues: ({ config } = {}) =>
    config?.defaultValue ?? [detected.searchParamValue, confirmed.searchParamValue],
  transformFilters: (filters) => {
    const dismissalReason = filters.filter(isDismissalReason);
    const state = filters.filter(
      (value) => !isDismissalReason(value) && value !== ALL_STATUS_VALUE,
    );

    return {
      state,
      dismissalReason,
    };
  },
  transformQueryParams: (filters) => {
    if (filters.length === 0) return ALL_STATUS_VALUE;
    return filters.join(',');
  },
  components: {
    GlFilteredSearchToken,
    GlDropdownDivider,
    GlDropdownSectionHeader,
    SearchSuggestion,
  },
  mixins: [glListenersMixin],
  props: {
    config: {
      type: Object,
      required: true,
    },
    // contains the token, with the selected operand (e.g.: '=') and the data (comma separated, e.g.: 'MIT, GNU')
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    // Default values are set on page load by parent component, when there is no query parameter.
    // Subsequent token mounts should use the ALL value because clearing tokens should reset to
    // ALL value and not default values.
    const defaultSelected = this.value.data || [ALL_STATUS_VALUE];

    return {
      selectedStatuses: defaultSelected,
    };
  },
  computed: {
    hideDismissalReasons() {
      return this.config.hideDismissalReasons === true;
    },
    statusOptions() {
      return this.hideDismissalReasons ? STATUS_OPTIONS_WITH_DISMISSED : STATUS_OPTIONS;
    },
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2467
        data: this.active ? null : this.selectedStatuses,
      };
    },
    isAllDismissedOnly() {
      return this.selectedStatuses.length === 1 && this.selectedStatuses[0] === ALL_DISMISSED_VALUE;
    },
    isOnlyDismissalReasons() {
      return this.selectedStatuses.every(isDismissalReason);
    },
    toggleText() {
      if (this.hideDismissalReasons) {
        return getSelectedOptionsText({
          options: this.statusOptions,
          selected: this.selectedStatuses,
          maxOptionsShown: 2,
        });
      }
      if (this.isAllDismissedOnly) {
        return s__('SecurityReports|Dismissed (all reasons)');
      }
      if (this.isOnlyDismissalReasons) {
        return n__('Dismissed (%d reason)', 'Dismissed (%d reasons)', this.selectedStatuses.length);
      }
      return getSelectedOptionsText({
        options: [...STATUS_OPTIONS, ...DISMISSAL_REASON_OPTIONS],
        selected: this.selectedStatuses,
        maxOptionsShown: 2,
      });
    },
  },
  methods: {
    resetSelected() {
      this.selectedStatuses = [];
    },
    toggleSelectedStatus(value) {
      const selected = new Set(this.selectedStatuses);

      // Toggle off
      if (selected.has(value)) {
        selected.delete(value);
        this.selectedStatuses = selected.size ? [...selected] : [ALL_STATUS_VALUE];
        return;
      }

      // "All statuses" resets everything
      if (value === ALL_STATUS_VALUE || selected.size === 0) {
        this.selectedStatuses = [ALL_STATUS_VALUE];
        return;
      }

      // Always remove the "All statuses" when picking a specific value
      selected.delete(ALL_STATUS_VALUE);

      if (value === ALL_DISMISSED_VALUE) {
        // "All dismissed" clears individual dismissal reasons
        this.selectedStatuses.filter(isDismissalReason).forEach((v) => selected.delete(v));
      } else if (isDismissalReason(value)) {
        // A specific reason clears the "All dismissed" value
        selected.delete(ALL_DISMISSED_VALUE);
      }

      selected.add(value);
      this.selectedStatuses = [...selected];
    },
    isStatusSelected(name) {
      return this.selectedStatuses.some((s) => name === s);
    },
  },
  dismissalReasonOptions: DISMISSAL_REASON_OPTIONS,
  i18n: {
    statusLabel: s__('SecurityReports|Status'),
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="selectedStatuses"
    :value="tokenValue"
    v-on="glListeners()"
    @select="toggleSelectedStatus"
    @destroy="resetSelected"
  >
    <template #view>
      <span data-testid="status-token-placeholder">{{ toggleText }}</span>
    </template>
    <template #suggestions>
      <gl-dropdown-section-header>{{ $options.i18n.statusLabel }}</gl-dropdown-section-header>
      <gl-dropdown-divider />
      <search-suggestion
        v-for="status in statusOptions"
        :key="status.value"
        :text="status.text"
        :value="status.value"
        :selected="isStatusSelected(status.value)"
        :data-testid="`suggestion-${status.value}`"
      />
      <template v-if="!hideDismissalReasons">
        <gl-dropdown-divider />
        <gl-dropdown-section-header>{{
          s__('SecurityReports|Dismissed as…')
        }}</gl-dropdown-section-header>
        <search-suggestion
          v-for="status in $options.dismissalReasonOptions"
          :key="status.value"
          :text="status.text"
          :value="status.value"
          :selected="isStatusSelected(status.value)"
          :data-testid="`suggestion-${status.value}`"
        />
      </template>
    </template>
  </gl-filtered-search-token>
</template>

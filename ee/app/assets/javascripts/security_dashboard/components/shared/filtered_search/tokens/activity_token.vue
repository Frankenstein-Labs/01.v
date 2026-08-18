<script>
import {
  GlBadge,
  GlFilteredSearchToken,
  GlDropdownDivider,
  GlDropdownSectionHeader,
} from '@gitlab/ui';
import { without } from 'lodash-es';
import { s__ } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { DASHBOARD_TYPE_GROUP, DASHBOARD_TYPE_PROJECT } from 'ee/security_dashboard/constants';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import { ALL_ID as ALL_ACTIVITY_VALUE } from '../constants';
import SearchSuggestion from '../components/search_suggestion.vue';

const ITEMS = {
  STILL_DETECTED: {
    value: 'STILL_DETECTED',
    text: s__('SecurityReports|Still detected'),
  },
  NO_LONGER_DETECTED: {
    value: 'NO_LONGER_DETECTED',
    text: s__('SecurityReports|No longer detected'),
  },
  HAS_ISSUE: {
    value: 'HAS_ISSUE',
    text: s__('SecurityReports|Has issue'),
  },
  DOES_NOT_HAVE_ISSUE: {
    value: 'DOES_NOT_HAVE_ISSUE',
    text: s__('SecurityReports|Does not have issue'),
  },
  HAS_MERGE_REQUEST: {
    value: 'HAS_MERGE_REQUEST',
    text: s__('SecurityReports|Has merge request'),
  },
  DOES_NOT_HAVE_MERGE_REQUEST: {
    value: 'DOES_NOT_HAVE_MERGE_REQUEST',
    text: s__('SecurityReports|Does not have merge request'),
  },
  HAS_SOLUTION: {
    value: 'HAS_SOLUTION',
    text: s__('SecurityReports|Has a solution'),
  },
  DOES_NOT_HAVE_SOLUTION: {
    value: 'DOES_NOT_HAVE_SOLUTION',
    text: s__('SecurityReports|Does not have a solution'),
  },
  AI_FP: {
    value: 'AI_FP',
    text: s__('SecurityReports|False positive'),
  },
  AI_NON_FP: {
    value: 'AI_NON_FP',
    text: s__('SecurityReports|Not identified as false positive'),
  },
  AI_RESOLUTION_AVAILABLE: {
    value: 'AI_RESOLUTION_AVAILABLE',
    text: s__('SecurityReports|Vulnerability Resolution available'),
  },
  AI_RESOLUTION_UNAVAILABLE: {
    value: 'AI_RESOLUTION_UNAVAILABLE',
    text: s__('SecurityReports|Vulnerability Resolution unavailable'),
  },
  DISMISSED_IN_MR: {
    value: 'DISMISSED_IN_MR',
    text: s__('SecurityReports|Dismissed in MR'),
  },
  DISMISSED_BY_POLICY: {
    value: 'DISMISSED_BY_POLICY',
    text: s__('SecurityReports|Dismissed by vulnerability policy'),
  },
  NOT_DISMISSED_BY_POLICY: {
    value: 'NOT_DISMISSED_BY_POLICY',
    text: s__('SecurityReports|Not dismissed by vulnerability policy'),
  },
};

export const GROUPS = [
  {
    text: '',
    options: [
      {
        value: ALL_ACTIVITY_VALUE,
        text: s__('SecurityReports|All activity'),
      },
    ],
  },
  {
    text: s__('SecurityReports|Detection'),
    options: [ITEMS.STILL_DETECTED, ITEMS.NO_LONGER_DETECTED],
    icon: 'check-circle-dashed',
    variant: 'info',
  },
  {
    text: s__('SecurityReports|Issue'),
    options: [ITEMS.HAS_ISSUE, ITEMS.DOES_NOT_HAVE_ISSUE],
    icon: 'work-item-issue',
  },
  {
    text: s__('SecurityReports|Merge Request'),
    options: [ITEMS.HAS_MERGE_REQUEST, ITEMS.DOES_NOT_HAVE_MERGE_REQUEST],
    icon: 'merge-request',
  },
  {
    text: s__('SecurityReports|Solution available'),
    options: [ITEMS.HAS_SOLUTION, ITEMS.DOES_NOT_HAVE_SOLUTION],
    icon: 'bulb',
  },
];

const setSelectedStatus = (keyWhenTrue, keyWhenFalse, selectedActivities = []) => {
  // The variables can be true, false, or unset, so we need to use if/else-if here instead
  // of if/else.
  if (selectedActivities.includes(ITEMS[keyWhenTrue].value)) return true;
  if (selectedActivities.includes(ITEMS[keyWhenFalse].value)) return false;
  return undefined;
};

const isGroupOrProjectDashboard = (dashboardType) => {
  return [DASHBOARD_TYPE_GROUP, DASHBOARD_TYPE_PROJECT].includes(dashboardType);
};

export default {
  defaultValues: () => [ITEMS.STILL_DETECTED.value],
  transformFilters: (filters, { dashboardType }) => {
    const showAiFpFilter = window.gon?.abilities?.accessAdvancedVulnerabilityManagement;
    const showAiResolutionFilter = window.gon?.abilities?.resolveVulnerabilityWithAi;
    const showPolicyViolationFilter =
      window.gon?.abilities?.accessAdvancedVulnerabilityManagement &&
      isGroupOrProjectDashboard(dashboardType);
    const showAutoDismissVulnerabilityFilter = isGroupOrProjectDashboard(dashboardType);

    const transformedFilters = {
      hasResolution: setSelectedStatus('NO_LONGER_DETECTED', 'STILL_DETECTED', filters),
      hasIssues: setSelectedStatus('HAS_ISSUE', 'DOES_NOT_HAVE_ISSUE', filters),
      hasMergeRequest: setSelectedStatus(
        'HAS_MERGE_REQUEST',
        'DOES_NOT_HAVE_MERGE_REQUEST',
        filters,
      ),
      hasRemediations: setSelectedStatus('HAS_SOLUTION', 'DOES_NOT_HAVE_SOLUTION', filters),
    };

    if (showAiResolutionFilter) {
      transformedFilters.hasAiResolution = setSelectedStatus(
        'AI_RESOLUTION_AVAILABLE',
        'AI_RESOLUTION_UNAVAILABLE',
        filters,
      );
    }

    if (showPolicyViolationFilter && filters.includes(ITEMS.DISMISSED_IN_MR.value)) {
      transformedFilters.policyViolations = ITEMS.DISMISSED_IN_MR.value;
    }

    if (showAutoDismissVulnerabilityFilter) {
      transformedFilters.policyAutoDismissed = setSelectedStatus(
        ITEMS.DISMISSED_BY_POLICY.value,
        ITEMS.NOT_DISMISSED_BY_POLICY.value,
        filters,
      );
    }

    if (showAiFpFilter) {
      transformedFilters.falsePositive = setSelectedStatus('AI_FP', 'AI_NON_FP', filters);
    }

    return transformedFilters;
  },
  transformQueryParams: (filters) => {
    if (filters.length === 0) return ALL_ACTIVITY_VALUE;
    return filters.join(',');
  },
  components: {
    GlBadge,
    GlFilteredSearchToken,
    GlDropdownDivider,
    GlDropdownSectionHeader,
    SearchSuggestion,
  },
  mixins: [glAbilitiesMixin(), glFeatureFlagsMixin(), glListenersMixin],
  inject: ['dashboardType', 'duoAgentPlatformAvailable'],
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
    const defaultSelected = this.value.data || [ALL_ACTIVITY_VALUE];

    return {
      selectedActivities: defaultSelected,
    };
  },
  computed: {
    showAutoDismissVulnerabilityFilter() {
      return [DASHBOARD_TYPE_GROUP, DASHBOARD_TYPE_PROJECT].includes(this.dashboardType);
    },
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2467
        data: this.active ? null : this.selectedActivities,
      };
    },
    toggleText() {
      return getSelectedOptionsText({
        options: Object.values(ITEMS),
        selected: this.selectedActivities,
        placeholder: this.$options.i18n.allItemsText,
        maxOptionsShown: 2,
      });
    },
    showAiFPFilter() {
      return (
        this.glAbilities?.accessAdvancedVulnerabilityManagement && this.duoAgentPlatformAvailable
      );
    },
    showAiResolutionFilter() {
      return this.glAbilities.resolveVulnerabilityWithAi;
    },
    showPolicyViolationsFilter() {
      return (
        this.glAbilities?.accessAdvancedVulnerabilityManagement &&
        isGroupOrProjectDashboard(this.dashboardType)
      );
    },
    activityTokenGroups() {
      const groups = [...GROUPS];

      if (this.showAiResolutionFilter) {
        groups.push({
          text: s__('SecurityReports|GitLab Duo resolution'),
          options: [ITEMS.AI_RESOLUTION_AVAILABLE, ITEMS.AI_RESOLUTION_UNAVAILABLE],
          icon: 'tanuki-ai',
          variant: 'info',
        });
      }

      if (this.showAiFPFilter) {
        groups.push({
          text: s__('SecurityReports|GitLab Duo FP detection'),
          options: [ITEMS.AI_FP, ITEMS.AI_NON_FP],
          icon: 'tanuki-ai',
          variant: 'info',
        });
      }

      if (this.showPolicyViolationsFilter) {
        groups.push({
          text: s__('SecurityReports|Policy violations'),
          options: [ITEMS.DISMISSED_IN_MR],
          icon: 'flag',
        });
      }

      if (this.showAutoDismissVulnerabilityFilter) {
        groups.push({
          text: s__('SecurityReports|Policy actions'),
          options: [ITEMS.DISMISSED_BY_POLICY, ITEMS.NOT_DISMISSED_BY_POLICY],
          icon: 'clear-all',
        });
      }

      return groups;
    },
  },
  methods: {
    resetSelected() {
      this.selectedActivities = [];
    },
    getGroupFromItem(value) {
      return this.activityTokenGroups.find((group) =>
        group.options.map((option) => option.value).includes(value),
      );
    },
    toggleSelected(selectedValue) {
      const allActivitiesSelected = selectedValue === ALL_ACTIVITY_VALUE;

      if (allActivitiesSelected) {
        this.selectedActivities = [ALL_ACTIVITY_VALUE];
        return;
      }

      const withoutSelectedValue = without(this.selectedActivities, selectedValue);
      const isSelecting = !this.selectedActivities.includes(selectedValue);
      // If a new item is selected, clear other selected items from the same group, clear all option and select the new item.
      if (isSelecting) {
        const group = this.getGroupFromItem(selectedValue);
        const groupItemValues = group.options.map((option) => option.value);
        this.selectedActivities = without(
          this.selectedActivities,
          ...groupItemValues,
          ALL_ACTIVITY_VALUE,
        ).concat(selectedValue);
      }
      // Otherwise, check whether selectedActivities would be empty and set based on that.
      else if (withoutSelectedValue.length === 0) {
        this.selectedActivities = [ALL_ACTIVITY_VALUE];
      } else {
        this.selectedActivities = withoutSelectedValue;
      }
    },

    isActivitySelected(name) {
      return this.selectedActivities.includes(name);
    },
  },
  i18n: {
    label: s__('SecurityReports|Activity'),
    allItemsText: s__('SecurityReports|All activity'),
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="selectedActivities"
    :value="tokenValue"
    v-on="glListeners()"
    @select="toggleSelected"
    @destroy="resetSelected"
  >
    <template #view>
      <span data-testid="activity-token-placeholder">{{ toggleText }}</span>
    </template>
    <template #suggestions>
      <template v-for="(group, index) in activityTokenGroups">
        <gl-dropdown-section-header v-if="group.text" :key="group.text">
          <div
            v-if="group.icon"
            class="gl-flex gl-items-center gl-justify-center"
            :data-testid="`header-${group.text}`"
          >
            <div class="gl-grow">{{ group.text }}</div>
            <gl-badge :icon="group.icon" :variant="group.variant" />
          </div>
        </gl-dropdown-section-header>
        <search-suggestion
          v-for="activity in group.options"
          :key="activity.value"
          :text="activity.text"
          :value="activity.value"
          :selected="isActivitySelected(activity.value)"
          :data-testid="`suggestion-${activity.value}`"
        />
        <gl-dropdown-divider
          v-if="index < activityTokenGroups.length - 1"
          :key="`${group.text}-divider`"
        />
      </template>
    </template>
  </gl-filtered-search-token>
</template>

<script>
import {
  GlBadge,
  GlDropdownDivider,
  GlDropdownSectionHeader,
  GlFilteredSearchSuggestion,
  GlFilteredSearchToken,
  GlIcon,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

const ALL_ACTIVITY_VALUE = 'ALL';

const ITEMS = {
  DISMISSED_IN_MR: {
    value: 'DISMISSED_IN_MR',
    text: s__('SecurityReports|Dismissed in MR'),
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
    text: s__('SecurityReports|Policy violations'),
    options: [ITEMS.DISMISSED_IN_MR],
    icon: 'flag',
  },
];

export default {
  activityTokenGroups: GROUPS,
  name: 'ActivityToken',
  components: {
    GlBadge,
    GlDropdownDivider,
    GlDropdownSectionHeader,
    GlFilteredSearchSuggestion,
    GlFilteredSearchToken,
    GlIcon,
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
    const defaultSelected = this.value.data || [ALL_ACTIVITY_VALUE];

    return {
      selectedActivities: defaultSelected,
    };
  },
  computed: {
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
  },
  methods: {
    resetSelected() {
      this.selectedActivities = [];
    },
    toggleSelected(selectedValue) {
      if (selectedValue === ALL_ACTIVITY_VALUE || this.selectedActivities.includes(selectedValue)) {
        this.selectedActivities = [ALL_ACTIVITY_VALUE];
      } else {
        this.selectedActivities = [selectedValue];
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
      <template v-for="(group, index) in $options.activityTokenGroups">
        <gl-dropdown-section-header v-if="group.text" :key="group.text">
          <div
            v-if="group.icon"
            class="gl-flex gl-items-center gl-justify-center"
            :data-testid="`header-${group.text}`"
          >
            <div class="gl-grow">{{ group.text }}</div>
            <gl-badge :icon="group.icon" />
          </div>
        </gl-dropdown-section-header>
        <gl-filtered-search-suggestion
          v-for="activity in group.options"
          :key="activity.value"
          :value="activity.value"
        >
          <div class="gl-flex gl-items-center">
            <gl-icon
              name="check"
              class="gl-mr-3 gl-shrink-0"
              :class="{ 'gl-invisible': !isActivitySelected(activity.value) }"
              variant="subtle"
            />
            {{ activity.text }}
          </div>
        </gl-filtered-search-suggestion>
        <gl-dropdown-divider
          v-if="index < $options.activityTokenGroups.length - 1"
          :key="`${group.text}-divider`"
        />
      </template>
    </template>
  </gl-filtered-search-token>
</template>

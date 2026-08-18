<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import {
  GlIcon,
  GlFilteredSearchToken,
  GlFilteredSearchSuggestion,
  GlLoadingIcon,
  GlIntersperse,
} from '@gitlab/ui';
import { DynamicScroller, DynamicScrollerItem } from 'vendor/vue-virtual-scroller';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  components: {
    GlIcon,
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
    GlLoadingIcon,
    GlIntersperse,
    DynamicScroller,
    DynamicScrollerItem,
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
    return {
      searchTerm: '',
      selectedLicenseNames: [],
    };
  },
  computed: {
    ...mapState(['licenses', 'fetchingLicensesInProgress']),
    filteredLicenses() {
      if (!this.searchTerm) {
        return this.licenses;
      }

      const nameIncludesSearchTerm = (license) =>
        license.name.toLowerCase().includes(this.searchTerm);
      const isSelected = (license) => this.selectedLicenseNames.includes(license.name);

      return this.licenses.filter(
        (license) => nameIncludesSearchTerm(license) || isSelected(license),
      );
    },
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2467
        data: this.active ? null : this.selectedLicenseNames,
      };
    },
  },
  created() {
    this.fetchLicenses();
  },
  methods: {
    ...mapActions(['fetchLicenses', 'setSearchFilters']),
    setSearchTerm(token) {
      // the data can be either a string or an array, in which case we don't want to perform the search
      if (typeof token.data === 'string') {
        this.searchTerm = token.data.toLowerCase();
      }
    },
    toggleSelectedLicense(name) {
      if (this.selectedLicenseNames.includes(name)) {
        this.selectedLicenseNames = this.selectedLicenseNames.filter((v) => v !== name);
      } else {
        this.selectedLicenseNames.push(name);
      }
    },
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="selectedLicenseNames"
    :value="tokenValue"
    v-on="glListeners()"
    @select="toggleSelectedLicense"
    @input="setSearchTerm"
  >
    <template #view>
      <gl-intersperse data-testid="selected-licenses">
        <span v-for="selectedLicense in selectedLicenseNames" :key="selectedLicense">{{
          selectedLicense
        }}</span>
      </gl-intersperse>
    </template>
    <template #suggestions>
      <gl-loading-icon v-if="fetchingLicensesInProgress" size="sm" />
      <div v-else-if="filteredLicenses.length">
        <dynamic-scroller
          :items="filteredLicenses"
          :min-item-size="32"
          class="gl-max-h-37"
          key-field="id"
          data-testid="dynamic-scroller"
        >
          <template #default="{ item: license, active: itemActive }">
            <dynamic-scroller-item :item="license" :active="itemActive">
              <gl-filtered-search-suggestion :value="license.name">
                <div class="gl-flex gl-items-center">
                  <gl-icon
                    v-if="config.multiSelect"
                    data-testid="check-icon"
                    name="check"
                    class="gl-mr-3 gl-shrink-0"
                    :class="{
                      'gl-invisible': !selectedLicenseNames.includes(license.name),
                    }"
                    variant="subtle"
                  />
                  <span>{{ license.name }}</span>
                </div>
              </gl-filtered-search-suggestion>
            </dynamic-scroller-item>
          </template>
        </dynamic-scroller>
      </div>
    </template>
  </gl-filtered-search-token>
</template>

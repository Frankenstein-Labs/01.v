<script>
import { GlModal, GlSearchBoxByType } from '@gitlab/ui';
import { s__ } from '~/locale';
import ScrollScrim from '~/super_sidebar/components/scroll_scrim.vue';
import { GLOBAL_SEARCH_MODAL_CLASS } from '~/super_sidebar/components/global_search/constants';
import DashboardFrequentProjects from './dashboard_frequent_projects.vue';
import DashboardFrequentGroups from './dashboard_frequent_groups.vue';
import DashboardSearchResults from './dashboard_search_results.vue';

export const LINK_TO_DASHBOARD_MODAL_ID = 'link-to-dashboard-modal';

export default {
  name: 'LinkToDashboardModal',
  components: {
    GlModal,
    GlSearchBoxByType,
    ScrollScrim,
    DashboardFrequentProjects,
    DashboardFrequentGroups,
    DashboardSearchResults,
  },
  props: {
    dashboardName: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      searchText: '',
    };
  },
  computed: {
    showDefaultItems() {
      return !this.searchText;
    },
  },
  methods: {
    onModalHidden() {
      this.searchText = '';
    },
  },
  LINK_TO_DASHBOARD_MODAL_ID,
  GLOBAL_SEARCH_MODAL_CLASS,
  i18n: {
    title: s__('Dashboards|Select a group or project for this analytics dashboard'),
    placeholder: s__('Dashboards|Search for a project or group...'),
  },
};
</script>

<template>
  <gl-modal
    :modal-id="$options.LINK_TO_DASHBOARD_MODAL_ID"
    :title="s__('Dashboards|Select a group or project for this analytics dashboard')"
    hide-footer
    scrollable
    :centered="false"
    body-class="!gl-p-0"
    :modal-class="$options.GLOBAL_SEARCH_MODAL_CLASS"
    content-class="gl-mt-2"
    @hidden="onModalHidden"
  >
    <div class="gl-relative gl-w-full">
      <div class="input-box-wrapper gl-border-b -gl-mb-1 gl-border-b-section gl-bg-section gl-p-2">
        <gl-search-box-by-type
          v-model="searchText"
          autocomplete="off"
          :placeholder="s__('Dashboards|Search for a project or group...')"
          borderless
        />
      </div>
      <div class="gl-flex gl-w-full gl-grow gl-flex-col gl-overflow-hidden">
        <scroll-scrim class="gl-grow !gl-overflow-x-hidden">
          <div class="gl-pb-3">
            <ul v-if="showDefaultItems" class="gl-m-0 gl-list-none gl-p-0 gl-pt-2">
              <dashboard-frequent-projects :dashboard-name="dashboardName" />
              <dashboard-frequent-groups bordered class="gl-mt-3" :dashboard-name="dashboardName" />
            </ul>
            <dashboard-search-results
              v-else
              :search-term="searchText"
              :dashboard-name="dashboardName"
            />
          </div>
        </scroll-scrim>
      </div>
    </div>
  </gl-modal>
</template>

<style scoped>
.input-box-wrapper {
  position: relative;
}
</style>

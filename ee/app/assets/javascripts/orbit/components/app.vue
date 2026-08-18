<script>
import { defineComponent } from 'vue';
import { GlBadge, GlButton, GlIcon } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import { s__ } from '~/locale';
import enabledMemberNamespacesQuery from '../graphql/queries/enabled_member_namespaces.query.graphql';
import ConnectSection from './connect_section.vue';
import AdminConfigureButton from './admin_configure_button.vue';
import GroupsConfigureButton from './groups_configure_button.vue';

const CONNECT_VISIBLE_KEY = 'orbit-connect-visible';

const CONFIGURE_VISIBLE_ROUTES = ['explore', 'schema'];

export default defineComponent({
  name: 'OrbitApp',
  compatConfig: { MODE: 3 },
  components: {
    GlBadge,
    GlButton,
    GlIcon,
    ConnectSection,
    AdminConfigureButton,
    GroupsConfigureButton,
  },
  mixins: [InternalEvents.mixin()],
  tabs: [
    { route: 'explore', label: s__('Orbit|Explore'), eventName: 'click_orbit_explore_tab' },
    { route: 'schema', label: s__('Orbit|Schema'), eventName: 'click_orbit_schema_tab' },
  ],
  props: {
    configureMode: {
      type: String,
      required: false,
      default: null,
    },
    adminConfigurationPath: {
      type: String,
      required: false,
      default: null,
    },
    duoAccessible: {
      type: Boolean,
      required: false,
      default: false,
    },
    orbitSettingsEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  apollo: {
    enabledMemberGroups: {
      query: enabledMemberNamespacesQuery,
      variables: { first: 100 },
      update(data) {
        return data?.groups?.nodes || [];
      },
    },
  },
  data() {
    return {
      enabledMemberGroups: [],
      connectVisible: localStorage.getItem(CONNECT_VISIBLE_KEY) !== 'false',
      appHeight: null,
    };
  },
  computed: {
    enabledMemberGroupsLoading() {
      return this.$apollo.queries.enabledMemberGroups.loading;
    },
    hasEnabledGroups() {
      return this.enabledMemberGroups.length > 0;
    },
    isExploreEmptyState() {
      return (
        this.$route.name === 'explore' && !this.enabledMemberGroupsLoading && !this.hasEnabledGroups
      );
    },
    showChrome() {
      return !this.isExploreEmptyState;
    },
    isConfigureRoute() {
      return CONFIGURE_VISIBLE_ROUTES.includes(this.$route.name);
    },
    showAdminConfigure() {
      return this.isConfigureRoute && this.configureMode === 'admin' && this.adminConfigurationPath;
    },
    showGroupsConfigure() {
      return this.isConfigureRoute && this.configureMode === 'groups';
    },
  },
  watch: {
    connectVisible(visible) {
      localStorage.setItem(CONNECT_VISIBLE_KEY, String(visible));
    },
  },
  mounted() {
    this.measureAppHeight();
    this.onResize = () => this.measureAppHeight();
    window.addEventListener('resize', this.onResize);
  },
  beforeUnmount() {
    window.removeEventListener('resize', this.onResize);
  },
  methods: {
    measureAppHeight() {
      // Below the lg breakpoint (992px) the schema tab stacks nav + graph
      // vertically. Fixing the height here traps scroll inside the nav panel's
      // overflow-auto entity list. Let the page scroll naturally on small viewports.
      if (window.innerWidth < 992) {
        this.appHeight = null;
        return;
      }

      // Set a definite height on orbit-app so flex children can fill it.
      const panel =
        this.$el?.closest('.panel-content-inner') || this.$el?.closest('[class*="content-inner"]');
      if (!panel || !this.$el) {
        this.appHeight = null;
        return;
      }
      const panelRect = panel.getBoundingClientRect();
      const appRect = this.$el.getBoundingClientRect();
      const raw = Math.floor(panelRect.bottom - appRect.top);
      // The intermediate container-fluid adds ~8px of its own height overhead.
      // Subtract it so the panel doesn't scroll when orbit-app fills exactly.
      const overhead = this.$el.parentElement
        ? this.$el.parentElement.offsetHeight - this.$el.offsetHeight
        : 8;
      const h = raw - Math.max(0, overhead);
      this.appHeight = h > 0 ? `${h}px` : null;
    },
    toggleConnect() {
      this.connectVisible = !this.connectVisible;
    },
    onTabClick(tab) {
      if (this.$route.name === tab.route) return;
      this.trackEvent(tab.eventName);
    },
  },
});
</script>

<template>
  <div
    class="orbit-app gl-flex gl-flex-col gl-pt-7"
    :class="appHeight ? 'gl-overflow-visible' : ''"
    :style="appHeight ? { height: appHeight } : {}"
  >
    <div v-if="showChrome" class="gl-flex gl-flex-col gl-gap-2" data-testid="orbit-chrome-wrapper">
      <div class="gl-flex gl-items-center gl-justify-between gl-gap-3">
        <div class="gl-flex gl-items-center gl-gap-3">
          <h1 class="gl-heading-1 gl-m-0">
            {{ s__('Orbit|Orbit') }}
          </h1>
          <gl-badge variant="info">{{ s__('Orbit|Beta') }}</gl-badge>
          <gl-button
            variant="link"
            size="small"
            class="gl-ml-3"
            href="https://gitlab.com/groups/gitlab-org/-/work_items/22232"
            target="_blank"
            rel="noopener noreferrer"
            >{{ s__('Orbit|Leave feedback') }} <gl-icon name="external-link" />
          </gl-button>
        </div>
        <div class="gl-flex gl-items-center gl-gap-3">
          <gl-button
            v-if="!connectVisible"
            size="small"
            icon="connected"
            category="tertiary"
            data-testid="toggle-connect"
            @click="toggleConnect"
          >
            {{ s__('Orbit|Connect') }}
          </gl-button>
          <admin-configure-button
            v-if="showAdminConfigure"
            :admin-configuration-path="adminConfigurationPath"
          />
          <groups-configure-button v-else-if="showGroupsConfigure" />
        </div>
      </div>

      <connect-section
        v-if="connectVisible"
        class="gl-mt-3 gl-w-full gl-shrink-0"
        :duo-accessible="duoAccessible"
        :orbit-settings-enabled="orbitSettingsEnabled"
        @close="toggleConnect"
      />

      <div
        class="gl-border-b gl-flex gl-flex-wrap gl-items-end gl-justify-between gl-gap-x-5 gl-gap-y-4 gl-border-default"
      >
        <div class="gl-tabs-wrapper -gl-mb-px gl-grow">
          <ul class="nav gl-tabs-nav">
            <li v-for="tab in $options.tabs" :key="tab.route" class="nav-item">
              <router-link
                :to="{ name: tab.route }"
                class="nav-link gl-tab-nav-item"
                :class="{ 'gl-tab-nav-item-active active': $route.name === tab.route }"
                @click="onTabClick(tab)"
              >
                {{ tab.label }}
              </router-link>
            </li>
          </ul>
        </div>
        <div
          id="orbit-tabs-actions"
          class="gl-flex gl-flex-wrap gl-items-center gl-gap-3 gl-pb-3"
        ></div>
      </div>
    </div>
    <router-view />
  </div>
</template>

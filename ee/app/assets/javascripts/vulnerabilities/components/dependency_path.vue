<script>
import { MountingPortal } from 'portal-vue';
import { GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import DependencyPathDrawer from 'ee/dependencies/components/dependency_path_drawer.vue';

export default {
  name: 'DependencyPath',
  components: {
    MountingPortal,
    GlButton,
    DependencyPathDrawer,
  },
  props: {
    component: {
      type: Object,
      required: true,
    },
    sbomOccurrences: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      isDrawerOpen: false,
    };
  },
  computed: {
    dropdownItems() {
      return this.sbomOccurrences.map(({ id: value, inputFilePath: text }) => ({ value, text }));
    },
  },
  methods: {
    toggleDrawer() {
      this.isDrawerOpen = !this.isDrawerOpen;
    },
    closeDrawer() {
      this.isDrawerOpen = false;
    },
  },
  i18n: {
    buttonText: s__('Vulnerability|View dependency paths'),
    drawerTitle: s__('Vulnerability|Dependency paths'),
  },
  getContentWrapperHeight,
  DRAWER_Z_INDEX,
};
</script>

<template>
  <div>
    <gl-button size="small" @click="toggleDrawer">{{ $options.i18n.buttonText }}</gl-button>
    <!-- Mount GlDrawer outside .md to fix z-index so it shows above navbar.
     More info: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/181949#note_2360144489 -->
    <mounting-portal mount-to="#js-dependency-paths-drawer-portal">
      <dependency-path-drawer
        :show-drawer="isDrawerOpen"
        :component="component"
        :dropdown-items="dropdownItems"
        @close="closeDrawer"
      />
    </mounting-portal>
  </div>
</template>

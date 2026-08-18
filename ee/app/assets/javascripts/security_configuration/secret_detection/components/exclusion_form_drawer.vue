<script>
import { GlDrawer } from '@gitlab/ui';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { s__ } from '~/locale';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { DRAWER_MODES } from '../constants';
import ExclusionForm from './exclusion_form.vue';
import ExclusionDetails from './exclusion_details.vue';

export default {
  name: 'ExclusionFormDrawer',
  components: {
    GlDrawer,
    ExclusionForm,
    ExclusionDetails,
  },
  emits: ['updated'],
  DRAWER_Z_INDEX,
  i18n: {
    addExclusionTitle: s__('SecurityExclusions|Add exclusion'),
    editExclusionTitle: s__('SecurityExclusions|Update exclusion'),
    viewExclusionTitle: s__('SecurityExclusions|Exclusion details'),
  },
  data() {
    return {
      isOpen: false,
      mode: DRAWER_MODES.ADD,
      exclusion: {},
    };
  },
  computed: {
    getDrawerHeaderHeight() {
      return getContentWrapperHeight();
    },
    isViewOnlyMode() {
      return this.mode === DRAWER_MODES.VIEW;
    },
    drawerTitle() {
      const titles = {
        [DRAWER_MODES.VIEW]: this.$options.i18n.viewExclusionTitle,
        [DRAWER_MODES.ADD]: this.$options.i18n.addExclusionTitle,
        [DRAWER_MODES.EDIT]: this.$options.i18n.editExclusionTitle,
      };

      return titles[this.mode];
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- `open()` is called from the parent component
    open(mode = DRAWER_MODES.ADD, item = {}) {
      this.exclusion = item;
      this.mode = mode;
      this.isOpen = true;
    },
    close() {
      this.isOpen = false;
    },
    submit() {
      this.$emit('updated');
      this.close();
    },
  },
};
</script>

<template>
  <gl-drawer
    :header-height="getDrawerHeaderHeight"
    :header-sticky="true"
    :open="isOpen"
    size="md"
    class="exclusion-form-drawer"
    :z-index="$options.DRAWER_Z_INDEX"
    @close="close"
  >
    <template #title
      ><h4 class="gl-my-0 gl-mr-3 gl-text-size-h2">{{ drawerTitle }}</h4></template
    >
    <exclusion-details v-if="isViewOnlyMode" :exclusion="exclusion" />
    <exclusion-form v-else :exclusion="exclusion" :mode="mode" @saved="submit" @cancel="close" />
  </gl-drawer>
</template>

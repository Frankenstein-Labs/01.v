<script>
import { GlButton, GlIcon, GlProgressBar } from '@gitlab/ui';
import { sprintf } from '~/locale';
import { I18N_FEATURES_ADOPTED_TEXT, PROGRESS_BAR_HEIGHT } from '../constants';
import DevopsAdoptionTableCellFlag from './devops_adoption_table_cell_flag.vue';

export default {
  name: 'DevopsAdoptionOverviewCard',
  progressBarHeight: PROGRESS_BAR_HEIGHT,
  components: {
    GlButton,
    GlIcon,
    GlProgressBar,
    DevopsAdoptionTableCellFlag,
  },
  props: {
    icon: {
      type: String,
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    featureMeta: {
      type: Array,
      required: false,
      default: () => [],
    },
    displayMeta: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['card-title-clicked'],
  computed: {
    featuresCount() {
      return this.featureMeta.length;
    },
    adoptedCount() {
      return this.featureMeta.filter((feature) => feature.adopted).length;
    },
    description() {
      return sprintf(I18N_FEATURES_ADOPTED_TEXT, {
        adoptedCount: this.adoptedCount,
        featuresCount: this.featuresCount,
        title: this.displayMeta ? this.title : '',
      });
    },
  },
  methods: {
    trackCardTitleClick() {
      this.$emit('card-title-clicked');
    },
  },
};
</script>
<template>
  <div class="devops-overview-card gl-mb-4 gl-flex gl-grow gl-flex-col @md/panel:gl-mr-5">
    <div class="gl-mb-3 gl-flex gl-items-center" data-testid="card-title">
      <gl-icon :name="icon" class="gl-mr-3" variant="subtle" />
      <gl-button
        v-if="displayMeta"
        class="gl-font-md gl-font-bold"
        variant="link"
        data-testid="card-title-link"
        @click="trackCardTitleClick"
        >{{ title }}
      </gl-button>
      <span v-else class="gl-font-md gl-font-bold">{{ title }} </span>
    </div>
    <gl-progress-bar
      :value="adoptedCount"
      :max="featuresCount"
      class="gl-mb-2 @md/panel:gl-mr-5"
      :height="$options.progressBarHeight"
    />
    <div class="gl-mb-1 gl-text-subtle" data-testid="card-description">{{ description }}</div>
    <template v-if="displayMeta">
      <div
        v-for="feature in featureMeta"
        :key="feature.title"
        class="gl-mt-2 gl-flex gl-items-center"
        data-testid="card-meta-row"
      >
        <devops-adoption-table-cell-flag
          :enabled="feature.adopted"
          :name="feature.title"
          class="gl-mr-3"
        />
        <span class="gl-text-sm gl-text-subtle" data-testid="card-meta-row-title">{{
          feature.title
        }}</span>
      </div>
    </template>
  </div>
</template>

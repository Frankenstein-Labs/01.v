<script>
import { GlIcon, GlLink, GlTruncate, GlTooltipDirective as GlTooltip } from '@gitlab/ui';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { __ } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';

export default {
  name: 'RelatedFeatureFlags',
  components: { GlIcon, GlLink, GlTruncate, CrudComponent },
  directives: {
    GlTooltip,
  },
  inject: {
    endpoint: { default: '' },
  },
  data() {
    return {
      featureFlags: [],
      loading: true,
    };
  },
  i18n: {
    title: __('Related feature flags'),
    error: __('There was an error loading related feature flags'),
    active: __('Active'),
    inactive: __('Inactive'),
  },
  computed: {
    shouldShowRelatedFeatureFlags() {
      return this.loading || this.numberOfFeatureFlags > 0;
    },
    numberOfFeatureFlags() {
      return this.featureFlags?.length ?? 0;
    },
  },
  mounted() {
    if (this.endpoint) {
      axios
        .get(this.endpoint)
        .then(({ data }) => {
          this.featureFlags = data;
        })
        .catch((error) =>
          createAlert({
            message: this.$options.i18n.error,
            error,
          }),
        )
        .finally(() => {
          this.loading = false;
        });
    } else {
      this.loading = false;
    }
  },
  methods: {
    icon({ active }) {
      return active ? 'feature-flag' : 'feature-flag-disabled';
    },
    iconTooltip({ active }) {
      return active ? this.$options.i18n.active : this.$options.i18n.inactive;
    },
  },
};
</script>
<template>
  <crud-component
    v-if="shouldShowRelatedFeatureFlags"
    anchor-id="related-feature-flags"
    :is-loading="loading"
    :title="$options.i18n.title"
    icon="feature-flag"
    :count="numberOfFeatureFlags"
    is-collapsible
    body-class="gl-p-3"
  >
    <ul class="content-list related-items-list">
      <li
        v-for="flag in featureFlags"
        :key="flag.id"
        class="!gl-border-b-0 !gl-p-0"
        data-testid="feature-flag-details"
      >
        <div class="item-body gl-p-3">
          <gl-icon
            v-gl-tooltip
            :name="icon(flag)"
            :title="iconTooltip(flag)"
            class="gl-mr-2"
            data-testid="feature-flag-details-icon"
          />
          <span class="item-title">
            <gl-link :title="flag.name" :href="flag.path" class="sortable-link">
              {{ flag.name }}
            </gl-link>
          </span>
          <span
            :title="flag.reference"
            class="gl-mt-3 gl-whitespace-nowrap gl-text-subtle @lg/panel:gl-ml-3 @lg/panel:gl-mt-0"
            data-testid="feature-flag-details-reference"
          >
            <gl-truncate :text="flag.reference" />
          </span>
        </div>
      </li>
    </ul>
  </crud-component>
</template>

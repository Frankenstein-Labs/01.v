<script>
import { GlFilteredSearch, GlFilteredSearchToken } from '@gitlab/ui';
import { __ } from '~/locale';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';

export default {
  name: 'FilterContainer',
  components: { GlFilteredSearch },
  emits: ['update'],
  filterTokens: [
    {
      type: 'active',
      icon: 'cloud-gear',
      title: __('Deployment status'),
      unique: true,
      operators: OPERATORS_IS,
      token: GlFilteredSearchToken,
      options: [
        {
          icon: 'earth',
          value: true,
          title: 'active',
        },
        {
          icon: 'dash-circle',
          value: false,
          title: 'inactive',
        },
      ],
    },
    {
      type: 'versioned',
      icon: 'environment',
      title: __('Environment'),
      unique: true,
      operators: OPERATORS_IS,
      token: GlFilteredSearchToken,
      options: [
        {
          icon: 'home',
          value: false,
          title: __('main'),
        },
        {
          icon: 'namespace',
          value: true,
          title: __('prefixed'),
        },
      ],
    },
  ],
  data() {
    return {
      filterRaw: [],
    };
  },
  computed: {
    filter() {
      const result = {};
      this.filterRaw.forEach((filter) => {
        result[filter.type] = filter.value.data;
      });
      return result;
    },
  },
  methods: {
    onUpdate(value) {
      this.filterRaw = value;
      this.$emit('update', this.filter);
    },
  },
};
</script>

<template>
  <gl-filtered-search
    v-model="filterRaw"
    :available-tokens="$options.filterTokens"
    show-friendly-text
    @submit="onUpdate"
  />
</template>

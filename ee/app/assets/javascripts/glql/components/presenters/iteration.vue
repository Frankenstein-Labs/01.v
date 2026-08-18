<script>
import { GlLink } from '@gitlab/ui';
import NullPresenter from '~/glql/components/presenters/null.vue';
import { getIterationPeriod } from 'ee/iterations/utils';

export default {
  name: 'IterationPresenterEE',
  components: {
    GlLink,
    NullPresenter,
  },
  props: {
    data: {
      required: true,
      type: Object,
    },
  },
  methods: { getIterationPeriod },
};
</script>
<template>
  <span v-if="data"
    ><span class="gl-text-subtle">{{ data.iterationCadence.title }}</span> &bull;
    <gl-link :href="data.webUrl"
      >{{ getIterationPeriod(data)
      }}<span v-if="data.title"> &bull; {{ data.title }}</span></gl-link
    ></span
  >
  <null-presenter v-else />
</template>

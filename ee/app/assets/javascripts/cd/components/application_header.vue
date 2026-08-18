<script>
import { GlBadge, GlIcon } from '@gitlab/ui';
import { n__ } from '~/locale';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { healthVariant, healthLabel } from '../utils';

export default {
  name: 'ApplicationHeader',
  components: {
    GlBadge,
    GlIcon,
    PageHeading,
    TimeAgoTooltip,
  },
  mixins: [glSlotsMixin],
  props: {
    application: {
      type: Object,
      required: true,
    },
  },
  computed: {
    health() {
      return this.application.health;
    },
    servicesText() {
      return n__(
        'ContinuousDeployment|%d service',
        'ContinuousDeployment|%d services',
        this.application.services?.count ?? 0,
      );
    },
    environmentsText() {
      return n__(
        'ContinuousDeployment|%d environment',
        'ContinuousDeployment|%d environments',
        this.application.environments?.count ?? 0,
      );
    },
    lastDeployedAt() {
      return this.application.lastDeployedAt;
    },
  },
  methods: { healthVariant, healthLabel },
};
</script>

<template>
  <page-heading>
    <template #heading-wrapper>
      <div class="gl-flex gl-flex-col gl-gap-2">
        <div class="gl-flex gl-items-center gl-gap-3">
          <h1 class="gl-heading-1 !gl-m-0 !gl-text-lg" data-testid="page-heading">
            {{ application.name }}
          </h1>
          <gl-badge v-if="health" :variant="healthVariant(health)" data-testid="health-badge">
            {{ healthLabel(health) }}
          </gl-badge>
        </div>

        <div
          class="gl-flex gl-flex-wrap gl-items-center gl-gap-x-5 gl-gap-y-2 gl-text-sm gl-text-subtle"
          data-testid="application-meta"
        >
          <span class="gl-flex gl-items-center gl-gap-2">
            <gl-icon name="container-image" />
            {{ servicesText }}
          </span>
          <span class="gl-flex gl-items-center gl-gap-2">
            <gl-icon name="environment" />
            {{ environmentsText }}
          </span>
          <span
            v-if="lastDeployedAt"
            class="gl-flex gl-items-center gl-gap-2"
            data-testid="last-deployed"
          >
            <gl-icon name="clock" />
            <time-ago-tooltip :time="lastDeployedAt" />
          </span>
        </div>

        <p v-if="application.description" class="gl-mb-0 gl-text-sm gl-text-subtle">
          {{ application.description }}
        </p>
      </div>
    </template>

    <template v-if="glSlots().actions" #actions>
      <slot name="actions"></slot>
    </template>
  </page-heading>
</template>

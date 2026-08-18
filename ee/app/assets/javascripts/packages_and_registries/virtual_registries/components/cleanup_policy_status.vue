<script>
import { GlIcon } from '@gitlab/ui';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { sprintf, s__ } from '~/locale';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import getVirtualRegistriesCleanupPolicyStatus from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_virtual_registries_cleanup_policy_status.query.graphql';

export default {
  name: 'CleanupPolicyStatus',
  components: {
    GlIcon,
  },
  mixins: [glAbilitiesMixin()],
  inject: ['fullPath'],
  props: {
    batchKey: {
      type: String,
      required: true,
    },
  },
  apollo: {
    group: {
      query: getVirtualRegistriesCleanupPolicyStatus,
      context() {
        return {
          batchKey: this.batchKey,
        };
      },
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      skip() {
        return !this.shouldRenderCleanupPolicy;
      },
    },
  },
  data() {
    return {
      group: {},
    };
  },
  computed: {
    cleanupPolicy() {
      return this.group?.virtualRegistriesCleanupPolicy;
    },
    shouldRenderCleanupPolicy() {
      return this.glAbilities.adminVirtualRegistry;
    },
    cleanupPolicyText() {
      if (!this.cleanupPolicy?.enabled) {
        return s__('VirtualRegistry|Cache cleanup disabled. Next run is not scheduled.');
      }

      if (this.cleanupPolicy.nextRunAt) {
        const nextRun = formatDate(this.cleanupPolicy.nextRunAt, 'mmm dd');
        return sprintf(
          s__('VirtualRegistry|Cache cleanup enabled. Next run scheduled for %{nextRun}.'),
          { nextRun },
        );
      }

      return s__('VirtualRegistry|Cache cleanup disabled. Next run is not scheduled.');
    },
  },
};
</script>

<template>
  <div
    v-if="shouldRenderCleanupPolicy"
    class="gl-mb-4 gl-flex gl-items-center gl-gap-2 gl-text-subtle"
    data-testid="cleanup-policy-status"
  >
    <gl-icon name="clock" />
    <span>{{ cleanupPolicyText }}</span>
  </div>
</template>

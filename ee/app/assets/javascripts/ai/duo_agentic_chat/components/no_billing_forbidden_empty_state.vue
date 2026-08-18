<script>
import { s__ } from '~/locale';
import TanukiAiIcon from '../../shared/widgets/tanuki_ai_icon.vue';

export default {
  name: 'NoBillingForbiddenEmptyState',
  components: {
    TanukiAiIcon,
  },
  i18n: {
    headline: s__('DuoAgenticChat|Usage billing not available'),
    description: s__(
      'DuoAgenticChat|Usage billing is not available for this account. To continue using GitLab Duo Agent Platform, contact your administrator.',
    ),
  },
};
</script>

<template>
  <div
    class="gl-flex gl-w-full gl-flex-col gl-items-start gl-gap-4 gl-py-8"
    data-testid="no-billing-forbidden-empty-state"
  >
    <tanuki-ai-icon />
    <h2 class="gl-my-0 gl-text-size-h2">
      {{ $options.i18n.headline }}
    </h2>
    <p class="gl-text-subtle">
      {{ $options.i18n.description }}
    </p>
  </div>
</template>

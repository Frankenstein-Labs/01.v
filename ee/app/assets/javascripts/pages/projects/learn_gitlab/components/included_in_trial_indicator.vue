<script>
import { s__ } from '~/locale';

export default {
  name: 'IncludedInTrialIndicator',
  i18n: {
    trialOnly: s__('LearnGitlab|- Included in trial'),
  },
};
</script>
<template>
  <span class="gl-italic gl-text-subtle" data-testid="trial-only">
    {{ $options.i18n.trialOnly }}
  </span>
</template>

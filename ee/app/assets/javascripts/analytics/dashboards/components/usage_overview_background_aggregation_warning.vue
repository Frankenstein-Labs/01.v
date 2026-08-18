<script>
import { GlLink, GlSprintf, GlAlert } from '@gitlab/ui';
import {
  ENABLE_BACKGROUND_AGGREGATION_WARNING_TEXT,
  BACKGROUND_AGGREGATION_DOCS_LINK,
  BACKGROUND_AGGREGATION_WARNING_TITLE,
} from '../constants';

export default {
  name: 'UsageOverviewBackgroundAggregationWarning',
  components: {
    GlAlert,
    GlLink,
    GlSprintf,
  },
  i18n: {
    alertTitle: BACKGROUND_AGGREGATION_WARNING_TITLE,
    alertText: ENABLE_BACKGROUND_AGGREGATION_WARNING_TEXT,
  },
  BACKGROUND_AGGREGATION_DOCS_LINK,
};
</script>
<template>
  <gl-alert
    data-testid="vsd-background-aggregation-disabled-warning"
    variant="warning"
    :title="$options.i18n.alertTitle"
    :dismissible="false"
  >
    <gl-sprintf :message="$options.i18n.alertText">
      <template #link="{ content }">
        <gl-link :href="$options.BACKGROUND_AGGREGATION_DOCS_LINK">{{ content }}</gl-link>
      </template>
    </gl-sprintf>
  </gl-alert>
</template>

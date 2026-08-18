<script>
import { GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'RiskScoreTooltip',
  components: {
    GlSprintf,
  },
  i18n: {
    riskScoreFormulaDescription: s__(
      'SecurityReports|(Sum of open vulnerability scores%{supStart}*%{supEnd} + Age penalty%{supStart}†%{supEnd}) * Diminishing factor%{supStart}‡%{supEnd} * Diversity factor%{supStart}§%{supEnd}',
    ),
    explanations: [
      {
        id: 'open-vulnerability-scores',
        message: s__(
          'SecurityReports|%{supStart}*%{supEnd}Base score (associated with severity level) + EPSS modifier + KEV modifier',
        ),
      },
      {
        id: 'age-penalty',
        message: s__(
          'SecurityReports|%{supStart}†%{supEnd}Sum of vulnerability ages in months * 0.005',
        ),
      },
      {
        id: 'diminishing-factor',
        message: s__(
          'SecurityReports|%{supStart}‡%{supEnd}Diminishing factor = 1.0 / √(vulnerability count)',
        ),
      },
      {
        id: 'diversity-factor',
        message: s__('SecurityReports|%{supStart}§%{supEnd}Diversity factor = 0.4'),
      },
    ],
  },
};
</script>

<template>
  <div>
    <p>
      <gl-sprintf :message="$options.i18n.riskScoreFormulaDescription">
        <template #sup="{ content }">
          <sup>{{ content }}</sup>
        </template>
      </gl-sprintf>
    </p>
    <ol class="gl-mb-0 gl-list-none gl-p-0 gl-text-gray-600">
      <li v-for="explanation in $options.i18n.explanations" :key="explanation.id">
        <gl-sprintf :message="explanation.message">
          <template #sup="{ content }">
            <sup class="gl-mr-1">{{ content }}</sup>
          </template>
        </gl-sprintf>
      </li>
    </ol>
  </div>
</template>

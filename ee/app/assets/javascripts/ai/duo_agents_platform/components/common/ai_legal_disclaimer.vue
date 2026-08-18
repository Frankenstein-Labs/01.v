<script>
export default {
  name: 'AiLegalDisclaimer',
};
</script>
<template>
  <p data-testid="ai-legal-disclaimer" class="gl-mt-3 gl-text-sm gl-text-subtle">
    {{
      s__(
        'DuoAgentsPlatform|GitLab Duo can autonomously change code. Responses and changes can be inaccurate. Review carefully.',
      )
    }}
  </p>
</template>

<script>
import tanukiAiSvgUrl from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';

export default {
  name: 'TanukiAiIcon',
  tanukiAiSvgUrl,
};
</script>

<template>
  <img
    :src="$options.tanukiAiSvgUrl"
    class="gl-h-10 gl-w-10"
    :alt="s__('DuoAgenticChat|GitLab Duo AI assistant')"
  />
</template>

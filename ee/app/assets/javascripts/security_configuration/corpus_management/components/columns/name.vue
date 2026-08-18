<script>
import { GlLink } from '@gitlab/ui';
import { decimalBytes } from '~/lib/utils/unit_format';
import { s__ } from '~/locale';

export default {
  name: 'ColumnsName',
  components: {
    GlLink,
  },
  props: {
    corpus: {
      type: Object,
      required: true,
    },
  },
  i18n: {
    latestJob: s__('CorpusManagement|Latest Job:'),
  },
  computed: {
    fileSize() {
      return decimalBytes(this.corpus.package.packageFiles.nodes[0].size, 0, {
        unitSeparator: ' ',
      });
    },
    jobUrl() {
      return this.corpus.package.pipelines.nodes[0]?.path;
    },
    ref() {
      return this.corpus.package.pipelines.nodes[0]?.ref;
    },
    latestJob() {
      return `${this.jobUrl} (${this.ref})`;
    },
    name() {
      return this.corpus.package.name;
    },
  },
};
</script>
<template>
  <div>
    <div class="gl-text-default" data-testid="corpus-name">
      {{ name }}
      <span class="gl-text-subtle" data-testid="file-size">({{ fileSize }})</span>
    </div>
    <div class="gl-truncate">
      {{ $options.i18n.latestJob }}
      <gl-link v-if="jobUrl" :href="jobUrl" target="_blank">
        {{ latestJob }}
      </gl-link>
      <template v-else>-</template>
    </div>
  </div>
</template>

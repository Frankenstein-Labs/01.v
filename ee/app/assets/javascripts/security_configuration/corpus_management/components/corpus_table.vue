<script>
import { GlTable } from '@gitlab/ui';
import Actions from 'ee/security_configuration/corpus_management/components/columns/actions.vue';
import Name from 'ee/security_configuration/corpus_management/components/columns/name.vue';
import Target from 'ee/security_configuration/corpus_management/components/columns/target.vue';
import { s__ } from '~/locale';
import UserDate from '~/vue_shared/components/user_date.vue';
import { ISO_SHORT_FORMAT } from '~/vue_shared/constants';

export default {
  name: 'CorpusTable',
  components: {
    GlTable,
    Name,
    Target,
    UserDate,
    Actions,
  },
  props: {
    corpuses: {
      type: Array,
      required: true,
    },
  },
  emits: ['delete'],
  fields: [
    {
      key: 'name',
      label: s__('CorpusManagement|Corpus name'),
      thClass: 'gl-w-8/20',
      tdClass: 'gl-truncate gl-max-w-15',
    },
    {
      key: 'target',
      label: s__('CorpusManagement|Target'),
      thClass: 'gl-w-4/20',
      tdClass: 'gl-break-anywhere',
    },
    {
      key: 'lastUpdated',
      label: s__('CorpusManagement|Last updated'),
      thClass: 'gl-w-3/20',
    },
    {
      key: 'lastUsed',
      label: s__('CorpusManagement|Last used'),
      thClass: 'gl-w-3/20',
    },
    {
      key: 'actions',
      label: s__('CorpusManagement|Actions'),
      thClass: 'gl-w-2/20',
    },
  ],
  i18n: {
    emptyTable: s__('CorpusManagement|Currently, there are no uploaded or generated corpuses.'),
  },
  methods: {
    onDelete({ package: { id } }) {
      this.$emit('delete', id);
    },
    target(corpus) {
      return corpus.package.pipelines.nodes[0]?.ref;
    },
    lastUpdated(corpus) {
      return corpus.package.updatedAt;
    },
    lastUsed(corpus) {
      return corpus.package.pipelines.nodes[0]?.updatedAt;
    },
  },
  dateFormat: ISO_SHORT_FORMAT,
};
</script>
<template>
  <gl-table :items="corpuses" :fields="$options.fields" show-empty>
    <template #empty>
      {{ $options.i18n.emptyTable }}
    </template>

    <template #cell(name)="{ item }">
      <name :corpus="item" />
    </template>

    <template #cell(target)="{ item }">
      <target :target="target(item)" />
    </template>

    <template #cell(lastUpdated)="{ item }">
      <user-date :date="lastUpdated(item)" :date-format="$options.dateFormat" />
    </template>

    <template #cell(lastUsed)="{ item }">
      <user-date :date="lastUsed(item)" :date-format="$options.dateFormat" />
    </template>

    <template #cell(actions)="{ item }">
      <actions :corpus="item" @delete="onDelete" />
    </template>
  </gl-table>
</template>

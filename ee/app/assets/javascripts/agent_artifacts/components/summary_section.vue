<script>
import { GlAttributeList } from '@gitlab/ui';
import { s__ } from '~/locale';
import { formatDate } from '~/lib/utils/datetime_utility';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { LONG_DATE_FORMAT_WITH_TZ } from '~/vue_shared/constants';

const EM_DASH = '—';

// GlAttributeList validates that every item's `text` is a String, so ids and
// other non-string values have to be coerced before they reach it.
const displayValue = (value) =>
  value === null || value === undefined || value === '' ? EM_DASH : String(value);

export default {
  name: 'SummarySection',
  components: {
    CrudComponent,
    GlAttributeList,
  },
  props: {
    event: {
      type: Object,
      required: true,
    },
    targetType: {
      type: String,
      required: false,
      default: '',
    },
    targetDetails: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    items() {
      const { event } = this;

      return [
        {
          label: this.$options.i18n.authorId,
          text: displayValue(event.author?.id ? getIdFromGraphQLId(event.author.id) : null),
        },
        {
          label: this.$options.i18n.authorName,
          text: displayValue(event.author?.name),
        },
        {
          label: this.$options.i18n.targetType,
          text: displayValue(this.targetType),
        },
        {
          label: this.$options.i18n.targetDetails,
          text: displayValue(this.targetDetails),
        },
        {
          label: this.$options.i18n.eventType,
          text: displayValue(event.eventName),
        },
        {
          label: this.$options.i18n.ipAddress,
          text: displayValue(event.ipAddress),
        },
        {
          label: this.$options.i18n.timestamp,
          text: displayValue(
            event.createdAt ? formatDate(event.createdAt, LONG_DATE_FORMAT_WITH_TZ) : null,
          ),
        },
      ];
    },
  },
  i18n: {
    title: s__('AgentArtifacts|Summary'),
    authorId: s__('AgentArtifacts|Author ID'),
    authorName: s__('AgentArtifacts|Author name'),
    targetType: s__('AgentArtifacts|Target type'),
    targetDetails: s__('AgentArtifacts|Target details'),
    eventType: s__('AgentArtifacts|Event type'),
    ipAddress: s__('AgentArtifacts|IP address'),
    timestamp: s__('AgentArtifacts|Timestamp'),
  },
};
</script>

<template>
  <crud-component :title="$options.i18n.title" is-collapsible>
    <div class="gl-@container">
      <gl-attribute-list layout="horizontal" :items="items" />
    </div>
  </crud-component>
</template>

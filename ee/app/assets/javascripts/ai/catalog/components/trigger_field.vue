<script>
import { GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import FlowTriggerEventTokens from 'ee/ai/duo_agents_platform/components/common/flow_trigger_event_tokens.vue';
import {
  FLOW_TRIGGERS_NEW_ROUTE,
  FLOW_TRIGGERS_EDIT_ROUTE,
} from 'ee/ai/duo_agents_platform/router/constants';
import { canManageAiFlowTriggers } from '../permissions';
import { AI_CATALOG_ITEM_LABELS } from '../constants';
import AiCatalogItemField from './ai_catalog_item_field.vue';

export default {
  name: 'TriggerFieldEE',
  components: {
    GlIcon,
    GlLink,
    GlSprintf,
    AiCatalogItemField,
    FlowTriggerEventTokens,
  },
  mixins: [glAbilitiesMixin()],
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  computed: {
    flowTrigger() {
      return this.item.configurationForProject?.flowTrigger;
    },
    itemTypeLabel() {
      return AI_CATALOG_ITEM_LABELS[this.item.itemType];
    },
    canManageTriggers() {
      return canManageAiFlowTriggers({ glAbilities: this.glAbilities });
    },
  },
  methods: {
    triggerEditPath(triggerId) {
      return {
        name: FLOW_TRIGGERS_EDIT_ROUTE,
        params: { id: getIdFromGraphQLId(triggerId) },
      };
    },
  },
  FLOW_TRIGGERS_NEW_ROUTE,
};
</script>

<template>
  <ai-catalog-item-field :title="s__('DuoAgentsPlatform|Triggers')">
    <div v-if="flowTrigger" class="gl-mt-3 gl-flex gl-justify-between">
      <flow-trigger-event-tokens :flow-trigger="flowTrigger" />
      <gl-link
        v-if="flowTrigger.id && !item.foundational && canManageTriggers"
        :to="triggerEditPath(flowTrigger.id)"
        class="gl-flex gl-items-center gl-gap-2 gl-whitespace-nowrap"
      >
        <gl-icon name="pencil" />
        {{ __('Edit') }}
      </gl-link>
    </div>
    <div v-else class="gl-text-subtle">
      <gl-sprintf
        v-if="canManageTriggers"
        :message="
          s__(
            'AICatalog|No triggers configured. %{linkStart}Add a trigger%{linkEnd} to make this %{itemType} available.',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :to="{ name: $options.FLOW_TRIGGERS_NEW_ROUTE }">{{ content }}</gl-link>
        </template>
        <template #itemType>{{ itemTypeLabel }}</template>
      </gl-sprintf>
      <template v-else>
        {{ s__('AICatalog|No triggers configured.') }}
      </template>
    </div>
  </ai-catalog-item-field>
</template>

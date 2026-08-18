<script>
import { GlButton, GlLink, GlTable, GlTooltipDirective } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import PipelineSubscriptionsForm from './pipeline_subscriptions_form.vue';

export default {
  name: 'PipelineSubscriptionsTable',
  i18n: {
    newBtnText: s__('PipelineSubscriptions|Add new'),
    deleteTooltip: s__('PipelineSubscriptions|Delete subscription'),
  },
  fields: [
    {
      key: 'project',
      label: __('Project'),
      columnClass: 'gl-w-6/10',
      tdClass: '!gl-align-middle',
    },
    {
      key: 'namespace',
      label: __('Namespace'),
      columnClass: 'gl-w-3/10',
      tdClass: '!gl-align-middle',
    },
    {
      key: 'actions',
      label: '',
      columnClass: 'gl-w-2/10',
      tdClass: 'gl-text-right',
    },
  ],
  components: {
    GlButton,
    CrudComponent,
    GlLink,
    GlTable,
    PipelineSubscriptionsForm,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    count: {
      type: Number,
      required: true,
    },
    emptyText: {
      type: String,
      required: true,
    },
    subscriptions: {
      type: Array,
      required: true,
    },
    showActions: {
      type: Boolean,
      required: false,
      default: false,
    },
    title: {
      type: String,
      required: true,
    },
  },
  emits: ['refetch-subscriptions', 'show-modal'],
  computed: {
    toggleText() {
      return this.showActions ? this.$options.i18n.newBtnText : '';
    },
  },
};
</script>

<template>
  <crud-component
    ref="pipelineSubscriptionsTable"
    :title="title"
    icon="pipeline"
    :count="count"
    class="gl-mt-5"
  >
    <template v-if="showActions" #actions="{ showForm, isFormVisible }">
      <gl-button
        v-if="!isFormVisible"
        size="small"
        data-testid="add-new-subscription-button"
        @click="showForm"
      >
        {{ toggleText }}
      </gl-button>
    </template>

    <template #form>
      <pipeline-subscriptions-form
        @canceled="$refs.pipelineSubscriptionsTable.hideForm"
        @add-subscription-success="$emit('refetch-subscriptions')"
      />
    </template>

    <gl-table
      :fields="$options.fields"
      :items="subscriptions"
      :empty-text="emptyText"
      show-empty
      stacked="md"
      fixed
    >
      <template #table-colgroup="{ fields }">
        <col v-for="field in fields" :key="field.key" :class="field.columnClass" />
      </template>

      <template #cell(project)="{ item }">
        <gl-link :href="item.project.webUrl">{{ item.project.name }}</gl-link>
      </template>

      <template #cell(namespace)="{ item }">
        <span data-testid="subscription-namespace">{{ item.project.namespace.name }}</span>
      </template>

      <template #cell(actions)="{ item }">
        <gl-button
          v-if="showActions"
          v-gl-tooltip
          :title="$options.i18n.deleteTooltip"
          category="tertiary"
          size="small"
          icon="remove"
          data-testid="delete-subscription-btn"
          @click="$emit('show-modal', item.id)"
        />
      </template>
    </gl-table>
  </crud-component>
</template>

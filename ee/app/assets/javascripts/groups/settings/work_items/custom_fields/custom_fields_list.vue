<script>
import {
  GlAlert,
  GlBadge,
  GlButton,
  GlButtonGroup,
  GlIntersperse,
  GlLoadingIcon,
  GlSprintf,
  GlTable,
  GlTooltipDirective,
} from '@gitlab/ui';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import { humanize } from '~/lib/utils/text_utility';
import { __, n__, s__, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import TimeagoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import CustomFieldForm from './custom_field_form.vue';
import groupCustomFieldsQuery from './group_custom_fields.query.graphql';
import customFieldArchiveMutation from './custom_field_archive.mutation.graphql';
import customFieldUnarchiveMutation from './custom_field_unarchive.mutation.graphql';

export default {
  name: 'CustomFieldsList',
  components: {
    CustomFieldForm,
    GlAlert,
    GlBadge,
    GlButton,
    GlButtonGroup,
    GlIntersperse,
    GlLoadingIcon,
    GlSprintf,
    GlTable,
    HelpPageLink,
    TimeagoTooltip,
    SettingsBlock,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    id: {
      type: String,
      required: true,
    },
    expanded: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['toggle-expand'],
  data() {
    return {
      customFields: [],
      customFieldsForList: [],
      showActive: true,
      archivingId: null,
      errorText: '',
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.customFields.loading;
    },
    titleText() {
      return this.showActive
        ? s__('WorkItem|Active custom fields')
        : s__('WorkItem|Archived custom fields');
    },
    archiveButtonIcon() {
      return this.showActive ? 'archive' : 'redo';
    },
    emptyStateText() {
      return this.showActive
        ? s__(
            'WorkItem|This group has no active custom fields. Create a custom field to track data that matters to your team.',
          )
        : s__(
            'WorkItem|No custom fields have been archived. Archive custom fields to remove them from active work items while preserving their data.',
          );
    },
  },
  apollo: {
    customFields: {
      query: groupCustomFieldsQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          active: this.showActive,
        };
      },
      update(data) {
        return data.group.customFields;
      },
      result() {
        // need a copy of the apollo query response as the table adds
        // properties to it for showing the detail view
        // prevents "Cannot add property _showDetails, object is not extensible" error
        this.customFieldsForList = this.customFields?.nodes?.map((field) => ({ ...field })) ?? [];
      },
      error(error) {
        this.errorText = s__('WorkItem|Failed to load custom fields.');
        Sentry.captureException(error.message);
      },
    },
  },
  methods: {
    detailsToggleIcon(detailsVisible) {
      return detailsVisible ? 'chevron-down' : 'chevron-right';
    },
    dismissAlert() {
      this.errorText = '';
    },
    formattedFieldType(item) {
      return humanize(item.fieldType.toLowerCase());
    },
    async setShowActive(val) {
      if (this.showActive === val) {
        return;
      }
      this.showActive = val;
      await this.$nextTick();
      this.$apollo.queries.customFields.refetch();
    },
    selectOptionsText(item) {
      if (item.selectOptions.length > 0) {
        return n__('%d option', '%d options', item.selectOptions.length);
      }
      return null;
    },
    archiveButtonText(item) {
      return this.showActive
        ? sprintf(s__('WorkItem|Archive %{itemName}'), { itemName: item.name })
        : sprintf(s__('WorkItem|Unarchive %{itemName}'), { itemName: item.name });
    },
    async archiveCustomField(id) {
      this.archivingId = id;
      try {
        await this.executeArchiveMutation(id);
      } catch (error) {
        this.handleArchiveError(error, id);
      } finally {
        this.archivingId = null;
      }
    },
    async executeArchiveMutation(id) {
      const field = this.getFieldById(id);
      const optimisticResponse = this.createOptimisticResponse(field);
      const update = this.updateCacheAfterArchive(field);

      const mutation = field.active ? customFieldArchiveMutation : customFieldUnarchiveMutation;

      const { data } = await this.$apollo.mutate({
        mutation,
        variables: { id },
        optimisticResponse,
        update,
      });

      if (data?.customFieldArchive?.errors?.length) {
        throw new Error(data.customFieldArchive.errors.join(', '));
      }
    },
    getFieldById(id) {
      return this.customFieldsForList.find((f) => f.id === id);
    },
    createOptimisticResponse(field) {
      const fieldName = field.active ? 'customFieldArchive' : 'customFieldUnarchive';
      const payloadTypename = field.active
        ? 'CustomFieldArchivePayload'
        : 'CustomFieldUnarchivePayload';

      return {
        [fieldName]: {
          __typename: payloadTypename,
          customField: {
            __typename: 'CustomField',
            id: field.id,
            name: field.name,
            fieldType: field.fieldType,
          },
          errors: [],
        },
      };
    },
    updateCacheAfterArchive(field) {
      return (cache, response) => {
        const fieldName = field.active ? 'customFieldArchive' : 'customFieldUnarchive';
        if (response.data[fieldName]?.errors?.length) return;

        const queryParams = {
          query: groupCustomFieldsQuery,
          variables: { fullPath: this.fullPath, active: field.active },
        };

        const prevData = cache.readQuery(queryParams);
        if (!prevData?.group?.customFields) return;

        const updatedCustomFields = {
          ...prevData.group.customFields,
          nodes: prevData.group.customFields.nodes.filter(
            (node) => node.id !== response.data[fieldName].customField.id,
          ),
          count: prevData.group.customFields.count - 1,
        };

        cache.writeQuery({
          ...queryParams,
          data: {
            group: {
              ...prevData.group,
              customFields: updatedCustomFields,
            },
          },
        });
      };
    },
    handleArchiveError(error, id) {
      const field = this.getFieldById(id);
      const errorText = field.active
        ? s__('WorkItem|Failed to archive custom field %{fieldName}.')
        : s__('WorkItem|Failed to unarchive custom field %{fieldName}.');
      this.errorText = sprintf(errorText, {
        fieldName: field.name,
      });
      Sentry.captureException(error);
    },
  },
  fields: [
    {
      key: 'show_details',
      label: s__('WorkItem|Toggle details'),
      class: 'gl-w-0 !gl-align-middle',
      thClass: 'gl-sr-only',
    },
    {
      key: 'name',
      label: s__('WorkItem|Field'),
      class: '!gl-align-middle',
    },
    {
      key: 'fieldType',
      label: s__('WorkItem|Type'),
      class: '!gl-align-middle',
    },
    {
      key: 'usage',
      label: s__('WorkItem|Usage'),
      class: '!gl-align-middle',
    },
    {
      key: 'lastModified',
      label: __('Last modified'),
      class: '!gl-align-middle',
    },
    {
      key: 'actions',
      label: __('Actions'),
      class: '!gl-align-middle',
    },
  ],
};
</script>

<template>
  <settings-block
    :id="id"
    :title="s__('WorkItem|Custom fields')"
    :expanded="expanded"
    @toggle-expand="$emit('toggle-expand', $event)"
  >
    <template #description>
      <p class="gl-mb-3 gl-text-subtle">
        {{
          s__(
            'WorkItem|Custom fields extend work items to track additional data. Fields will appear in alphanumeric order. All fields apply to all subgroups and projects.',
          )
        }}
        <help-page-link href="user/work_items/custom_fields" target="_blank">
          {{ s__('WorkItem|How do I use custom fields?') }}
        </help-page-link>
      </p>
    </template>
    <template #default>
      <gl-alert
        v-if="errorText"
        variant="danger"
        :dismissible="true"
        class="gl-mb-5"
        data-testid="alert"
        @dismiss="dismissAlert"
      >
        {{ errorText }}
      </gl-alert>

      <gl-button-group class="gl-mb-5">
        <gl-button
          :selected="showActive"
          data-testid="activeFilterButton"
          @click="setShowActive(true)"
        >
          {{ s__('WorkItem|Active') }}
        </gl-button>
        <gl-button
          :selected="!showActive"
          data-testid="archivedFilterButton"
          @click="setShowActive(false)"
        >
          {{ s__('WorkItem|Archived') }}
        </gl-button>
      </gl-button-group>

      <div
        class="gl-font-lg gl-border gl-flex gl-items-center gl-rounded-t-base gl-border-b-0 gl-px-5 gl-py-4 gl-font-bold"
        data-testid="table-title"
      >
        {{ titleText }}
        <template v-if="!isLoading">
          <gl-badge v-if="showActive" class="gl-mx-4">
            <!-- eslint-disable-next-line @gitlab/vue-require-i18n-strings -->
            {{ customFields.count }}/50
          </gl-badge>
          <gl-badge v-else class="gl-mx-4">
            {{ customFields.count }}
          </gl-badge>
        </template>

        <custom-field-form
          v-if="showActive"
          :full-path="fullPath"
          class="gl-ml-auto"
          @created="$apollo.queries.customFields.refetch()"
        />
      </div>
      <gl-table
        show-empty
        :empty-text="emptyStateText"
        :items="customFieldsForList"
        :fields="$options.fields"
        :busy="isLoading"
        outlined
        responsive
        class="gl-rounded-b-base !gl-bg-subtle"
        details-td-class="!gl-pt-0"
      >
        <template #table-busy>
          <gl-loading-icon size="lg" class="gl-my-5" />
        </template>
        <template #cell(show_details)="row">
          <gl-button
            :aria-label="s__('WorkItem|Toggle details')"
            :icon="detailsToggleIcon(row.detailsShowing)"
            category="tertiary"
            class="gl-align-self-flex-start"
            data-testid="toggleDetailsButton"
            @click="row.toggleDetails"
          />
        </template>
        <template #cell(name)="{ item }">
          {{ item.name }}
        </template>
        <template #cell(fieldType)="{ item }">
          {{ formattedFieldType(item) }}
          <div class="gl-text-subtle">{{ selectOptionsText(item) }}</div>
        </template>
        <template #cell(usage)="{ item }">
          <div v-if="item.workItemTypes.length === 0">{{ __('Not in use') }}</div>
          <gl-intersperse>
            <span v-for="workItemType in item.workItemTypes" :key="workItemType.id">{{
              workItemType.name
            }}</span>
          </gl-intersperse>
        </template>
        <template #cell(lastModified)="{ item }">
          <timeago-tooltip :time="item.updatedAt" />
        </template>
        <template #head(actions)>
          <div class="gl-ml-auto">{{ __('Actions') }}</div>
        </template>
        <template #cell(actions)="{ item }">
          <div class="gl-align-items-center gl-end gl-flex gl-justify-end gl-gap-1">
            <custom-field-form
              v-if="showActive"
              :custom-field-id="item.id"
              :custom-field-name="item.name"
              :full-path="fullPath"
              data-testid="editButton"
              @updated="$apollo.queries.customFields.refetch()"
            />
            <gl-button
              v-gl-tooltip="archiveButtonText(item)"
              :aria-label="archiveButtonText(item)"
              :icon="archiveButtonIcon"
              category="tertiary"
              data-testid="archiveButton"
              @click="archiveCustomField(item.id)"
            />
          </div>
        </template>
        <template #row-details="{ item }">
          <div class="gl-border gl-col-span-5 gl-rounded-lg gl-bg-default gl-p-5">
            <dl class="gl-mb-3 gl-flex gl-gap-3">
              <dt>{{ s__('WorkItem|Usage:') }}</dt>
              <dd>
                <gl-intersperse>
                  <span v-for="workItemType in item.workItemTypes" :key="workItemType.id">{{
                    workItemType.name
                  }}</span>
                </gl-intersperse>
              </dd>
            </dl>
            <dl v-if="item.selectOptions.length > 0" class="gl-mb-3">
              <dt>{{ s__('WorkItem|Options:') }}</dt>
              <dd>
                <ul>
                  <li v-for="option in item.selectOptions" :key="option.id">
                    {{ option.value }}
                  </li>
                </ul>
              </dd>
            </dl>
            <div class="gl-text-sm gl-text-subtle">
              <gl-sprintf :message="s__('WorkItem|Last updated %{timeago}')">
                <template #timeago>
                  <timeago-tooltip :time="item.updatedAt" />
                </template>
              </gl-sprintf>
              &middot;
              <gl-sprintf :message="s__('WorkItem|Created %{timeago}')">
                <template #timeago>
                  <timeago-tooltip :time="item.updatedAt" />
                </template>
              </gl-sprintf>
            </div>
          </div>
        </template>
      </gl-table>
    </template>
  </settings-block>
</template>

<style>
/* remove border between row and details row */
.gl-table tr.b-table-has-details td {
  border-bottom-style: none;
}
</style>

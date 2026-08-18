<script>
import { GlSprintf, GlCard, GlPopover, GlLink } from '@gitlab/ui';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import { __, s__ } from '~/locale';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';

export default {
  name: 'GeoReplicableItemRegistryInfo',
  components: {
    GlSprintf,
    GlCard,
    GlPopover,
    GlLink,
    TimeAgo,
    ClipboardButton,
    HelpIcon,
  },
  i18n: {
    copy: __('Copy'),
    registryInformation: s__('Geo|Registry information'),
    registryHelpText: s__(
      'Geo|Shows general information about this registry including the various ways it may be referenced.',
    ),
    registryId: s__('Geo|Registry ID: %{id}'),
    graphqlID: s__('Geo|GraphQL ID: %{id}'),
    modelRecord: s__('Geo|Model record: %{modelRecord}'),
    createdAt: s__('Geo|Created: %{timeAgo}'),
  },
  props: {
    registryId: {
      type: String,
      required: true,
    },
    replicableItem: {
      type: Object,
      required: true,
    },
    replicableClass: {
      type: Object,
      required: true,
    },
  },
  computed: {
    modelRecord() {
      return `${this.replicableClass.modelClassName}/${this.replicableItem.modelRecordId}`;
    },
    registryInformation() {
      return [
        {
          title: this.$options.i18n.registryId,
          value: String(this.registryId),
        },
        {
          title: this.$options.i18n.graphqlID,
          value: String(this.replicableItem.id),
        },
      ];
    },
  },
};
</script>

<template>
  <gl-card>
    <template #header>
      <div class="gl-flex gl-items-center">
        <h5 class="gl-my-0">{{ $options.i18n.registryInformation }}</h5>
        <help-icon id="registry-information-help-icon" class="gl-ml-2" />
        <gl-popover target="registry-information-help-icon" placement="top" triggers="hover focus">
          <p>
            {{ $options.i18n.registryHelpText }}
          </p>
        </gl-popover>
      </div>
    </template>

    <div class="gl-flex gl-flex-col gl-gap-4">
      <p
        v-for="(item, index) in registryInformation"
        :key="index"
        class="gl-mb-0"
        data-testid="copyable-registry-information"
      >
        <gl-sprintf :message="item.title">
          <template #id>
            <span class="gl-font-bold">{{ item.value }}</span>
          </template>
        </gl-sprintf>
        <clipboard-button
          :title="$options.i18n.copy"
          :text="item.value"
          size="small"
          category="tertiary"
        />
      </p>

      <p class="gl-mb-0" data-testid="model-record">
        <gl-sprintf :message="$options.i18n.modelRecord">
          <template #modelRecord>
            <gl-link
              v-if="replicableItem.dataManagementDetailsPath"
              :href="replicableItem.dataManagementDetailsPath"
              >{{ modelRecord }}</gl-link
            >
            <span v-else class="gl-font-bold">{{ modelRecord }}</span>
          </template>
        </gl-sprintf>
        <clipboard-button
          :title="$options.i18n.copy"
          :text="modelRecord"
          size="small"
          category="tertiary"
        />
      </p>

      <p class="gl-mb-0" data-testid="registry-info-created-at">
        <gl-sprintf :message="$options.i18n.createdAt">
          <template #timeAgo>
            <time-ago :time="replicableItem.createdAt" class="gl-font-bold" />
          </template>
        </gl-sprintf>
      </p>
    </div>
  </gl-card>
</template>

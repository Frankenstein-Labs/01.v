<script>
import { GlFormGroup, GlFormSelect, GlFormCheckbox, GlLink, GlPopover } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { SELECTIVE_SYNC_MORE_INFO, OBJECT_STORAGE_MORE_INFO } from '../constants';
import GeoSiteFormOrganizations from './geo_site_form_organizations.vue';
import GeoSiteFormNamespaces from './geo_site_form_namespaces.vue';
import GeoSiteFormShards from './geo_site_form_shards.vue';

export default {
  name: 'GeoSiteFormSelectiveSync',
  i18n: {
    syncSettings: s__('Geo|Synchronization settings'),
    syncSubtitle: s__('Geo|Set what should be replicated by this secondary site.'),
    learnMore: __('Learn more'),
    selectiveSyncFieldLabel: s__('Geo|Selective synchronization'),
    selectiveSyncFieldDescriptionOld: s__('Geo|Choose specific groups or storage shards.'),
    selectiveSyncPopoverTextOld: s__(
      'Geo|Geo allows you to choose specific groups or storage shards to replicate.',
    ),
    selectiveSyncFieldDescriptionNew: s__(
      'Geo|Choose specific groups, storage shards, or organizations.',
    ),
    selectiveSyncPopoverTextNew: s__(
      'Geo|Geo allows you to choose specific groups, storage shards, or organizations to replicate.',
    ),
    namespacesSelectFieldLabel: s__('Geo|Groups to synchronize'),
    shardsSelectFieldLabel: s__('Geo|Shards to synchronize'),
    organizationsSelectFieldLabel: s__('Geo|Organizations to synchronize'),
    objectStorageFieldLabel: s__('Geo|Object Storage replication'),
    objectStorageFieldDescription: s__(
      'Geo|If enabled, GitLab will handle Object Storage replication using Geo.',
    ),
    objectStorageFieldPopoverText: s__(
      'Geo|Geo can replicate objects stored in Object Storage (AWS S3, or other compatible object storage).',
    ),
    objectStorageCheckboxLabel: s__(
      'Geo|Allow this secondary site to replicate content on Object Storage',
    ),
  },
  components: {
    GlFormGroup,
    GlFormSelect,
    GeoSiteFormNamespaces,
    GeoSiteFormShards,
    GeoSiteFormOrganizations,
    GlFormCheckbox,
    GlLink,
    GlPopover,
    HelpIcon,
  },
  props: {
    siteData: {
      type: Object,
      required: true,
    },
    selectiveSyncTypes: {
      type: Object,
      required: true,
    },
    syncShardsOptions: {
      type: Array,
      required: true,
    },
  },
  emits: ['update-sync-options'],
  computed: {
    // TODO: Remove once `geo_selective_sync_by_organizations` has been rolled out https://gitlab.com/groups/gitlab-org/-/epics/16643
    selectiveSyncOrganizationsAvailable() {
      return Boolean(this.selectiveSyncTypes.ORGANIZATIONS);
    },
    selectiveSyncOptions() {
      return Object.values(this.selectiveSyncTypes);
    },
    selectiveSyncFieldDescription() {
      return this.selectiveSyncOrganizationsAvailable
        ? this.$options.i18n.selectiveSyncFieldDescriptionNew
        : this.$options.i18n.selectiveSyncFieldDescriptionOld;
    },
    selectiveSyncPopoverText() {
      return this.selectiveSyncOrganizationsAvailable
        ? this.$options.i18n.selectiveSyncPopoverTextNew
        : this.$options.i18n.selectiveSyncPopoverTextOld;
    },
    selectiveSyncNamespaces() {
      return this.siteData.selectiveSyncType === this.selectiveSyncTypes.NAMESPACES.value;
    },
    selectiveSyncShards() {
      return this.siteData.selectiveSyncType === this.selectiveSyncTypes.SHARDS.value;
    },
    selectiveSyncOrganizations() {
      if (!this.selectiveSyncOrganizationsAvailable) return false;

      return this.siteData.selectiveSyncType === this.selectiveSyncTypes.ORGANIZATIONS.value;
    },
  },
  methods: {
    selectiveSyncTypeChanged(value) {
      this.$emit('update-sync-options', { key: 'selectiveSyncType', value });
    },
  },
  SELECTIVE_SYNC_MORE_INFO,
  OBJECT_STORAGE_MORE_INFO,
};
</script>

<template>
  <div ref="geoSiteFormSelectiveSyncContainer">
    <h2 class="gl-my-5 gl-text-size-h2">{{ $options.i18n.syncSettings }}</h2>
    <p class="gl-mb-5">
      {{ $options.i18n.syncSubtitle }}
    </p>
    <gl-form-group
      :description="selectiveSyncFieldDescription"
      data-testid="selective-sync-form-group"
    >
      <template #label>
        <div class="gl-flex gl-items-center">
          <label for="site-selective-synchronization-field" class="gl-mb-0">{{
            $options.i18n.selectiveSyncFieldLabel
          }}</label>
          <help-icon ref="selectiveSyncPopover" tabindex="0" class="gl-ml-2" />
          <gl-popover
            :target="() => $refs.selectiveSyncPopover"
            placement="top"
            triggers="hover focus"
            :title="$options.i18n.selectiveSyncFieldLabel"
          >
            <p class="gl-text-base">
              {{ selectiveSyncPopoverText }}
            </p>
            <gl-link :href="$options.SELECTIVE_SYNC_MORE_INFO" target="_blank">{{
              $options.i18n.learnMore
            }}</gl-link>
          </gl-popover>
        </div>
      </template>
      <gl-form-select
        id="site-selective-synchronization-field"
        :value="siteData.selectiveSyncType"
        :options="selectiveSyncOptions"
        value-field="value"
        text-field="label"
        class="sm:gl-max-w-xs"
        @input="selectiveSyncTypeChanged"
      />
    </gl-form-group>
    <gl-form-group
      v-if="selectiveSyncNamespaces"
      :label="$options.i18n.namespacesSelectFieldLabel"
      label-for="site-synchronization-namespaces-field"
    >
      <geo-site-form-namespaces
        id="site-synchronization-namespaces-field"
        :selected-namespaces="siteData.selectiveSyncNamespaceIds"
        @update-sync-options="$emit('update-sync-options', $event)"
      />
    </gl-form-group>
    <gl-form-group
      v-if="selectiveSyncShards"
      :label="$options.i18n.shardsSelectFieldLabel"
      label-for="site-synchronization-shards-field"
    >
      <geo-site-form-shards
        id="site-synchronization-shards-field"
        :selected-shards="siteData.selectiveSyncShards"
        :sync-shards-options="syncShardsOptions"
        @update-sync-options="$emit('update-sync-options', $event)"
      />
    </gl-form-group>
    <gl-form-group
      v-if="selectiveSyncOrganizations"
      :label="$options.i18n.organizationsSelectFieldLabel"
      label-for="site-synchronization-organizations-field"
    >
      <geo-site-form-organizations
        id="site-synchronization-organizations-field"
        :selected-organization-ids="siteData.selectiveSyncOrganizationIds"
        @update-sync-options="$emit('update-sync-options', $event)"
      />
    </gl-form-group>
    <gl-form-group
      :description="$options.i18n.objectStorageFieldDescription"
      data-testid="object-storage-form-group"
    >
      <template #label>
        <div class="gl-flex gl-items-center">
          <label for="site-object-storage-field" class="gl-mb-0">{{
            $options.i18n.objectStorageFieldLabel
          }}</label>
          <help-icon ref="objectStoragePopover" tabindex="0" class="gl-ml-2" />
          <gl-popover
            :target="() => $refs.objectStoragePopover"
            placement="top"
            triggers="hover focus"
            :title="$options.i18n.objectStorageFieldLabel"
          >
            <p class="gl-text-base">
              {{ $options.i18n.objectStorageFieldPopoverText }}
            </p>
            <gl-link :href="$options.OBJECT_STORAGE_MORE_INFO" target="_blank">{{
              $options.i18n.learnMore
            }}</gl-link>
          </gl-popover>
        </div>
      </template>
      <!-- eslint-disable vue/no-mutating-props -->
      <gl-form-checkbox id="site-object-storage-field" v-model="siteData.syncObjectStorage">{{
        $options.i18n.objectStorageCheckboxLabel
      }}</gl-form-checkbox>
      <!-- eslint-enable vue/no-mutating-props -->
    </gl-form-group>
  </div>
</template>

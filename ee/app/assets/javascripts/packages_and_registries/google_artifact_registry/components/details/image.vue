<script>
import { GlBadge, GlSkeletonLoader, GlTruncate } from '@gitlab/ui';
import { numberToHumanSize } from '~/lib/utils/number_utils';
import { localeDateFormat } from '~/lib/utils/datetime_utility';
import { s__ } from '~/locale';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';

export default {
  name: 'ImageDetails',
  components: {
    ClipboardButton,
    GlBadge,
    GlSkeletonLoader,
    GlTruncate,
  },
  props: {
    data: {
      type: Object,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    formattedSize() {
      const { imageSizeBytes } = this.data;
      return numberToHumanSize(Number(imageSizeBytes));
    },
    buildTime() {
      return this.data.buildTime ? this.format(this.data.buildTime) : '';
    },
    uploadTime() {
      return this.data.uploadTime ? this.format(this.data.uploadTime) : '';
    },
    updateTime() {
      return this.data.updateTime ? this.format(this.data.updateTime) : '';
    },
    rows() {
      return Object.entries({
        mediaType: {
          label: s__('GoogleArtifactRegistry|Media type'),
          value: this.data.mediaType,
        },
        projectId: {
          label: s__('GoogleArtifactRegistry|Project ID'),
          value: this.data.projectId,
        },
        location: {
          label: s__('GoogleArtifactRegistry|Location'),
          value: this.data.location,
        },
        repository: {
          label: s__('GoogleArtifactRegistry|Repository'),
          value: this.data.repository,
        },
        image: {
          label: s__('GoogleArtifactRegistry|Image'),
          value: this.data.image,
        },
        digest: {
          label: s__('GoogleArtifactRegistry|Digest'),
          value: this.data.digest,
        },
        imageSizeBytes: {
          label: s__('GoogleArtifactRegistry|Virtual size'),
          value: this.formattedSize,
        },
        buildTime: {
          label: s__('GoogleArtifactRegistry|Built'),
          value: this.buildTime,
        },
        uploadTime: {
          label: s__('GoogleArtifactRegistry|Created'),
          value: this.uploadTime,
        },
        updateTime: {
          label: s__('GoogleArtifactRegistry|Updated'),
          value: this.updateTime,
        },
      });
    },
  },
  methods: {
    isDigest(key) {
      return key === 'digest';
    },
    format(time) {
      return localeDateFormat.asDateTimeFull.format(time);
    },
  },
};
</script>

<template>
  <gl-skeleton-loader v-if="isLoading" :lines="11" />
  <ul v-else class="gl-list-none gl-pl-0" data-testid="image-details">
    <li
      v-for="[key, row] in rows"
      :key="key"
      class="gl-flex gl-flex-col @md/panel:gl-flex-row @md/panel:gl-items-center"
      :class="{ 'gl-py-2': !isDigest(key) }"
    >
      <span class="gl-shrink-0 gl-font-bold @md/panel:gl-basis-13">{{ row.label }}</span>
      <span>
        <span class="gl-break-anywhere" :data-testid="key">{{ row.value }}</span>
        <clipboard-button
          v-if="isDigest(key)"
          :title="s__('GoogleArtifactRegistry|Copy digest')"
          :text="row.value"
          category="tertiary"
          size="small"
        />
      </span>
    </li>
    <li class="gl-flex gl-flex-col gl-py-2 @md/panel:gl-flex-row">
      <span class="gl-shrink-0 gl-font-bold @md/panel:gl-basis-13">{{
        s__('GoogleArtifactRegistry|Tags')
      }}</span>
      <span class="gl-flex gl-flex-wrap gl-gap-2" data-testid="tags">
        <gl-badge v-for="tag in data.tags" :key="tag" class="gl-max-w-12">
          <gl-truncate class="gl-max-w-80p" :text="tag" :with-tooltip="true" />
        </gl-badge>
      </span>
    </li>
  </ul>
</template>

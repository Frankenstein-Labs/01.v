<script>
import { GlButton } from '@gitlab/ui';
import { n__, s__ } from '~/locale';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';

export default {
  name: 'UpstreamDetailsHeader',
  components: {
    GlButton,
    TitleArea,
    MetadataItem,
  },
  mixins: [glAbilitiesMixin()],
  inject: {
    editUpstreamPath: {
      default: '',
    },
    i18n: { default: {} },
    routes: { default: {} },
  },
  props: {
    upstream: {
      type: Object,
      required: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    cacheEntriesCount: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  computed: {
    canEdit() {
      return this.glAbilities.updateVirtualRegistry;
    },
    editUpstreamRoute() {
      return {
        name: this.routes.editUpstreamRouteName,
        params: { id: getIdFromGraphQLId(this.upstream.id) },
      };
    },
    artifactsCountText() {
      if (this.loading) {
        return s__('VirtualRegistry|-- artifacts');
      }
      return n__(
        'VirtualRegistry|%d artifact',
        'VirtualRegistry|%d artifacts',
        this.cacheEntriesCount,
      );
    },
  },
};
</script>

<template>
  <title-area :title="upstream.name">
    <template v-if="canEdit" #right-actions>
      <gl-button :href="editUpstreamPath" :to="editUpstreamRoute">
        {{ __('Edit') }}
      </gl-button>
    </template>
    <template #metadata-registry-type>
      <metadata-item icon="infrastructure-registry" :text="i18n.registryType" />
    </template>
    <template #metadata-count>
      <metadata-item data-testid="artifacts-count" icon="doc-text" :text="artifactsCountText" />
    </template>
    <template #metadata-url>
      <metadata-item icon="earth" :text="upstream.url" size="xl" />
    </template>
    <p v-if="upstream.description" data-testid="description">{{ upstream.description }}</p>
  </title-area>
</template>

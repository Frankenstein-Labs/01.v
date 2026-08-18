<script>
import {
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlTooltipDirective,
  GlToastMixin,
} from '@gitlab/ui';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { sprintf, s__, __ } from '~/locale';

export default {
  name: 'MavenRegistryDetailsHeader',
  components: {
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    MetadataItem,
    TitleArea,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glAbilitiesMixin(), GlToastMixin],
  inject: {
    registryEditPath: {
      default: '',
    },
    i18n: {
      default: {},
    },
    maxRegistryUpstreamsCount: {
      default: 0,
    },
    routes: { default: {} },
  },
  props: {
    registry: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      isDropdownVisible: false,
    };
  },
  computed: {
    canEdit() {
      return this.glAbilities.updateVirtualRegistry;
    },
    id() {
      return getIdFromGraphQLId(this.registry.id);
    },
    copyText() {
      return sprintf(s__('VirtualRegistry|Copy virtual registry ID: %{id}'), {
        id: this.id,
      });
    },
    moreActionsTooltip() {
      return this.isDropdownVisible ? '' : this.$options.i18n.moreActionsLabel;
    },
    pageHeadingDescription() {
      return sprintf(s__('VirtualRegistry|You can add up to %{count} upstreams per registry.'), {
        count: this.maxRegistryUpstreamsCount,
      });
    },
    editRegistryRoute() {
      return {
        name: this.routes.editRegistryRouteName,
        params: { id: this.id },
      };
    },
  },
  methods: {
    showDropdown() {
      this.isDropdownVisible = true;
    },
    hideDropdown() {
      this.isDropdownVisible = false;
    },
    onCopy() {
      this.$toast.show(s__('VirtualRegistry|Virtual registry ID copied to clipboard.'));
    },
  },
  i18n: {
    moreActionsLabel: __('More actions'),
  },
};
</script>

<template>
  <title-area :title="registry.name">
    <template #right-actions>
      <gl-button v-if="canEdit" :href="registryEditPath" :to="editRegistryRoute">
        {{ __('Edit') }}
      </gl-button>
      <gl-disclosure-dropdown
        v-gl-tooltip
        category="tertiary"
        icon="ellipsis_v"
        :title="moreActionsTooltip"
        no-caret
        :toggle-text="$options.i18n.moreActionsLabel"
        text-sr-only
        @shown="showDropdown"
        @hidden="hideDropdown"
      >
        <gl-disclosure-dropdown-item :data-clipboard-text="id" @action="onCopy">
          <template #list-item>
            {{ copyText }}
          </template>
        </gl-disclosure-dropdown-item>
      </gl-disclosure-dropdown>
    </template>
    <template #metadata-registry-type>
      <metadata-item icon="infrastructure-registry" :text="i18n.registryType" />
    </template>
    <template #sub-header>
      <div>{{ pageHeadingDescription }}</div>
    </template>
    <p data-testid="description">{{ registry.description }}</p>
  </title-area>
</template>

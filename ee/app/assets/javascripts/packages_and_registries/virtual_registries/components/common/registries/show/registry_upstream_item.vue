<script>
import { GlButton, GlButtonGroup, GlLink, GlTooltipDirective, GlTruncate } from '@gitlab/ui';
import { s__, sprintf, n__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';

export default {
  name: 'RegistryUpstreamItem',
  components: {
    GlButton,
    GlButtonGroup,
    GlLink,
    GlTruncate,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glAbilitiesMixin()],
  inject: {
    editUpstreamPathTemplate: { default: '' },
    showUpstreamPathTemplate: { default: '' },
    routes: { default: {} },
  },
  props: {
    registryUpstream: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    upstreamsCount: {
      type: Number,
      required: true,
    },
    index: {
      type: Number,
      required: true,
    },
  },
  /**
   * Emitted when an upstream is reordered
   * @event reorder-upstream
   * @property {string} direction - The direction to move the upstream ('up' or 'down')
   * @property {string} registryUpstream - The registryUpstream item to reorder
   */
  /**
   * Emitted when the cache is cleared
   * @event clear-cache
   * @property {string} upstream - The upstream to clear the cache
   */
  /**
   * Emitted when the upstream is removed
   * @event remove-upstream
   * @property {string} upstreamId - ID of the registry upstream association
   */
  emits: ['reorder-upstream', 'clear-cache', 'remove-upstream'],
  computed: {
    upstream() {
      return this.registryUpstream.upstream;
    },
    name() {
      return this.upstream.name;
    },
    url() {
      return this.upstream.url;
    },
    id() {
      return this.upstream.id;
    },
    idFromGraphQL() {
      return getIdFromGraphQLId(this.id);
    },
    cacheValidityHours() {
      return this.upstream.cacheValidityHours;
    },
    metadataCacheValidityHours() {
      return this.upstream.metadataCacheValidityHours;
    },
    canUpdate() {
      return this.glAbilities.updateVirtualRegistry;
    },
    canRemove() {
      return this.glAbilities.destroyVirtualRegistry;
    },
    removeUpstreamAriaLabel() {
      return sprintf(s__('VirtualRegistry|Remove upstream %{name}'), { name: this.upstream.name });
    },
    editPath() {
      return this.editUpstreamPathTemplate?.replace(':id', this.idFromGraphQL);
    },
    editRoute() {
      return { name: this.routes.editUpstreamRouteName, params: { id: this.idFromGraphQL } };
    },
    showPath() {
      return this.showUpstreamPathTemplate?.replace(':id', this.idFromGraphQL);
    },
    showRoute() {
      return { name: this.routes.showUpstreamRouteName, params: { id: this.idFromGraphQL } };
    },
    isFirstUpstream() {
      return this.index === 0;
    },
    isLastUpstream() {
      return this.index === this.upstreamsCount - 1;
    },
    showButtons() {
      return this.canUpdate || this.canRemove;
    },
    cacheValidityHoursLabel() {
      return sprintf(
        n__(
          'VirtualRegistry|Artifact cache: %{hours} hour',
          'VirtualRegistry|Artifact cache: %{hours} hours',
          this.cacheValidityHours,
        ),
        { hours: this.cacheValidityHours },
      );
    },
    metadataCacheValidityHoursLabel() {
      return sprintf(
        n__(
          'VirtualRegistry|Metadata cache: %{hours} hour',
          'VirtualRegistry|Metadata cache: %{hours} hours',
          this.metadataCacheValidityHours,
        ),
        { hours: this.metadataCacheValidityHours },
      );
    },
  },
  methods: {
    reorderUpstream(direction) {
      this.$emit('reorder-upstream', direction, this.registryUpstream);
    },
    clearCache() {
      this.$emit('clear-cache', this.upstream);
    },
    removeUpstream() {
      const { id } = this.registryUpstream;
      this.$emit('remove-upstream', id);
    },
  },
  i18n: {
    moveUpLabel: s__('VirtualRegistry|Move upstream up'),
    moveDownLabel: s__('VirtualRegistry|Move upstream down'),
    clearCacheLabel: s__('VirtualRegistry|Clear cache'),
    editUpstreamLabel: s__('VirtualRegistry|Edit upstream'),
    removeUpstreamLabel: s__('VirtualRegistry|Remove upstream'),
  },
};
</script>
<template>
  <div
    data-testid="registry-upstream-item"
    class="gl-border gl-grid gl-grid-cols-[auto_1fr] gl-gap-3 gl-rounded-base gl-bg-default gl-p-3"
  >
    <div v-if="canUpdate" class="gl-flex gl-items-start gl-justify-between">
      <gl-button-group vertical>
        <gl-button
          size="small"
          icon="chevron-up"
          data-testid="reorder-up-button"
          :disabled="isFirstUpstream"
          :title="$options.i18n.moveUpLabel"
          :aria-label="$options.i18n.moveUpLabel"
          @click="reorderUpstream('up')"
        />
        <gl-button
          size="small"
          icon="chevron-down"
          data-testid="reorder-down-button"
          :disabled="isLastUpstream"
          :title="$options.i18n.moveDownLabel"
          :aria-label="$options.i18n.moveDownLabel"
          @click="reorderUpstream('down')"
        />
      </gl-button-group>
    </div>
    <div class="gl-flex gl-min-w-0 gl-flex-col gl-gap-3 @sm/panel:gl-flex-row">
      <div class="gl-flex gl-min-w-0 gl-flex-1 gl-flex-col gl-gap-2">
        <div
          class="gl-flex gl-min-w-0 gl-flex-col gl-flex-wrap gl-items-start gl-gap-x-2 @sm/panel:gl-flex-row @sm/panel:gl-items-center"
        >
          <gl-link
            :href="showPath"
            :to="showRoute"
            class="gl-mr-2 gl-min-w-0 gl-max-w-full gl-font-bold gl-text-default"
            data-testid="upstream-name"
          >
            <gl-truncate
              :text="name"
              class="gl-min-w-0 gl-max-w-full hover:gl-underline"
              with-tooltip
            />
          </gl-link>
          <span
            data-testid="upstream-url"
            class="gl-min-w-0 gl-max-w-full gl-overflow-hidden gl-text-default"
          >
            <gl-truncate :text="url" class="gl-min-w-0 gl-max-w-full" with-tooltip />
          </span>
        </div>
        <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-2">
          <div data-testid="cache-validity-hours">
            {{ cacheValidityHoursLabel }}
          </div>
          <template v-if="metadataCacheValidityHours">
            <div>&middot;</div>
            <div data-testid="metadata-cache-validity-hours">
              {{ metadataCacheValidityHoursLabel }}
            </div>
          </template>
        </div>
      </div>
      <template v-if="showButtons">
        <div
          class="gl-flex gl-flex-wrap gl-items-start gl-gap-2 @sm/panel:gl-flex-nowrap @sm/panel:gl-justify-end"
        >
          <gl-button
            v-if="canUpdate"
            size="small"
            category="tertiary"
            data-testid="clear-cache-button"
            @click="clearCache"
          >
            {{ $options.i18n.clearCacheLabel }}</gl-button
          >
          <gl-button
            v-if="canUpdate"
            v-gl-tooltip="$options.i18n.editUpstreamLabel"
            data-testid="edit-button"
            :aria-label="$options.i18n.editUpstreamLabel"
            size="small"
            category="tertiary"
            icon="pencil"
            :href="editPath"
            :to="editRoute"
          />
          <gl-button
            v-if="canRemove"
            v-gl-tooltip="$options.i18n.removeUpstreamLabel"
            data-testid="remove-button"
            :aria-label="removeUpstreamAriaLabel"
            size="small"
            category="tertiary"
            icon="remove"
            @click="removeUpstream"
          />
        </div>
      </template>
    </div>
  </div>
</template>

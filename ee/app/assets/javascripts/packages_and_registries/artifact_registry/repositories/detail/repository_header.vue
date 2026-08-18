<script>
import { GlBadge, GlButton, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { __ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import {
  REPOSITORY_EDIT_ROUTE_NAME,
  REPOSITORY_FORMAT_LABELS,
  REPOSITORY_FORMAT_LOGO_SIZE_HEADING,
  REPOSITORY_KIND_LABELS,
  REPOSITORY_VISIBILITY_ICONS,
  REPOSITORY_VISIBILITY_LABELS,
} from '../../constants';
import FormatLogo from '../components/format_logo.vue';
import RepositoryActions from './repository_actions.vue';

export default {
  name: 'ArtifactRegistryRepositoryHeader',
  components: {
    FormatLogo,
    GlBadge,
    GlButton,
    GlIcon,
    PageHeading,
    RepositoryActions,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    repository: {
      type: Object,
      required: true,
    },
  },
  computed: {
    formatLabel() {
      return REPOSITORY_FORMAT_LABELS[this.repository.format];
    },
    kindLabel() {
      return REPOSITORY_KIND_LABELS[this.repository.kind];
    },
    visibilityIcon() {
      return REPOSITORY_VISIBILITY_ICONS[this.repository.visibility];
    },
    visibilityLabel() {
      return REPOSITORY_VISIBILITY_LABELS[this.repository.visibility];
    },
    editRoute() {
      return { name: REPOSITORY_EDIT_ROUTE_NAME, params: { id: this.repository.name } };
    },
  },
  i18n: {
    // The heading beside it names the repository, so the button does not repeat it.
    edit: __('Edit'),
  },
  logoSize: REPOSITORY_FORMAT_LOGO_SIZE_HEADING,
};
</script>

<template>
  <page-heading>
    <!-- The heading renders inside an h1 with no flex context, so the row lays itself out. -->
    <template #heading>
      <span class="gl-flex gl-flex-wrap gl-items-center gl-gap-3">
        <format-logo
          :format="repository.format"
          :size="$options.logoSize"
          data-testid="repository-format-logo"
        />
        <!-- The logo is decorative, and nothing else in the header states the format, so
             the name it carries is the only one assistive technology gets. -->
        <span class="gl-sr-only" data-testid="repository-format-name">{{ formatLabel }}</span>
        <span class="gl-wrap-anywhere" data-testid="repository-name">{{ repository.name }}</span>
        <gl-button
          v-gl-tooltip
          :title="visibilityLabel"
          :aria-label="visibilityLabel"
          category="tertiary"
          size="small"
          class="!gl-min-h-5 !gl-min-w-5 !gl-p-0"
          data-testid="repository-visibility"
        >
          <gl-icon :name="visibilityIcon" variant="subtle" />
        </gl-button>
        <gl-badge>{{ kindLabel }}</gl-badge>
      </span>
    </template>

    <template #actions>
      <gl-button :to="editRoute" data-testid="edit-repository">
        {{ $options.i18n.edit }}
      </gl-button>
      <repository-actions :repository="repository" />
    </template>

    <template v-if="repository.description" #description>
      <p class="gl-mb-0" data-testid="repository-description">{{ repository.description }}</p>
    </template>
  </page-heading>
</template>

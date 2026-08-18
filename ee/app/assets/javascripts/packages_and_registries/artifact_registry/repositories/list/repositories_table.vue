<script>
import { GlBadge, GlLoadingIcon, GlTable } from '@gitlab/ui';
import { isEqual } from 'lodash-es';
import {
  REPOSITORIES_TABLE_FIELDS,
  REPOSITORY_DETAIL_ROUTE_NAME,
  REPOSITORY_FORMAT_LABELS,
  REPOSITORY_FORMAT_LOGO_SIZE_LIST,
  REPOSITORY_KIND_LABELS,
} from 'ee/packages_and_registries/artifact_registry/constants';
import FormatLogo from 'ee/packages_and_registries/artifact_registry/repositories/components/format_logo.vue';
import RowActionsMenu from 'ee/packages_and_registries/artifact_registry/repositories/components/row_actions_menu.vue';
import {
  buildRepositoryClientUrl,
  formattedCount,
  humanSize,
} from 'ee/packages_and_registries/artifact_registry/utils';
import { __, s__ } from '~/locale';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';

export default {
  name: 'ArtifactRegistryRepositoriesTable',
  components: {
    ClipboardButton,
    FormatLogo,
    GlBadge,
    GlLoadingIcon,
    GlTable,
    RowActionsMenu,
    TimeAgoTooltip,
  },
  inject: ['slug', 'clientBaseUrl'],
  props: {
    repositories: {
      type: Array,
      required: true,
    },
    sort: {
      type: Object,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['sort-changed'],
  data() {
    return {
      // `GlTable` seeds its sort state from the props in `data()` and never watches them,
      // so a sort it did not raise itself leaves the arrow and `aria-sort` on the previous
      // column. Remounting is the only way in. The counter advances only for a sort the
      // table did not ask for, so a header click keeps the focus the reader left on it.
      externalSortCount: 0,
      requestedSort: null,
    };
  },
  watch: {
    sort(sort) {
      if (isEqual(sort, this.requestedSort)) return;

      this.externalSortCount += 1;
    },
  },
  methods: {
    formatLabel(format) {
      return REPOSITORY_FORMAT_LABELS[format];
    },
    kindLabel(kind) {
      return REPOSITORY_KIND_LABELS[kind];
    },
    formattedCount,
    humanSize,
    detailRoute(name) {
      return { name: REPOSITORY_DETAIL_ROUTE_NAME, params: { id: name } };
    },
    clientUrl(repository) {
      return buildRepositoryClientUrl({
        clientBaseUrl: this.clientBaseUrl,
        slug: this.slug,
        format: repository?.format,
        name: repository?.name,
      });
    },
    // The header reports the whole table context; the column and direction are the part
    // the page turns into a query. Recording it is what the watcher above compares.
    requestSort({ sortBy, sortDesc }) {
      this.requestedSort = { sortBy, sortDesc };

      this.$emit('sort-changed', { sortBy, sortDesc });
    },
  },
  fields: REPOSITORIES_TABLE_FIELDS,
  logoSize: REPOSITORY_FORMAT_LOGO_SIZE_LIST,
  i18n: {
    never: __('Never'),
    copyUrl: s__('ArtifactRegistry|Copy repository URL'),
  },
};
</script>

<template>
  <!-- `no-local-sorting` is what keeps the rendered order the server's: without it the
       table would reorder the page in the browser, which disagrees with a page the
       endpoint sorted and paged as a whole. -->
  <gl-table
    :key="externalSortCount"
    :busy="isLoading"
    :fields="$options.fields"
    :items="repositories"
    :sort-by="sort.sortBy"
    :sort-desc="sort.sortDesc"
    no-local-sorting
    stacked="md"
    @sort-changed="requestSort"
  >
    <template #table-busy>
      <!-- The guard keeps the spinner tied to the busy state: a stubbed table renders
           this slot whatever `busy` holds. -->
      <gl-loading-icon v-if="isLoading" size="sm" class="gl-my-5" />
    </template>

    <template #cell(format)="{ item }">
      <span
        class="gl-flex gl-items-center gl-justify-end gl-gap-2 @md/panel:gl-justify-start"
        data-testid="repository-format"
      >
        <format-logo
          :format="item.format"
          :size="$options.logoSize"
          data-testid="repository-format-logo"
        />
        {{ formatLabel(item.format) }}
      </span>
    </template>

    <template #cell(name)="{ item }">
      <span
        class="gl-flex gl-items-center gl-justify-end gl-gap-2 @md/panel:gl-justify-start"
        data-testid="repository-name"
      >
        <router-link :to="detailRoute(item.name)">{{ item.name }}</router-link>
      </span>
    </template>

    <template #cell(kind)="{ item }">
      <gl-badge data-testid="repository-kind">{{ kindLabel(item.kind) }}</gl-badge>
    </template>

    <template #cell(downloadsCount)="{ item }">
      <span data-testid="repository-downloads">{{ formattedCount(item.downloadsCount) }}</span>
    </template>

    <template #cell(sizeBytes)="{ item }">
      <span data-testid="repository-size">{{ humanSize(item.sizeBytes) }}</span>
    </template>

    <template #cell(lastUpdatedAt)="{ item }">
      <span data-testid="repository-last-updated">
        <time-ago-tooltip v-if="item.lastUpdatedAt" :time="item.lastUpdatedAt" />
        <template v-else>{{ $options.i18n.never }}</template>
      </span>
    </template>

    <template #cell(actions)="{ item }">
      <!-- Left out rather than shown broken when the instance configures no Artifact
           Registry: there is no URL to hand over. -->
      <clipboard-button
        v-if="clientUrl(item)"
        :text="clientUrl(item)"
        :title="$options.i18n.copyUrl"
        category="tertiary"
      />
      <row-actions-menu v-if="item" :repository="item" />
    </template>
  </gl-table>
</template>
